$! TEST_SMOKE.COM - quick functional check of a built or installed GZIP.EXE
$!
$! Usage:  @[.VMS]TEST_SMOKE [gzip-image]
$!         The default image is [.BIN_<arch>]GZIP.EXE in this tree.
$! Exits with SS$_NORMAL if every test passes, otherwise reports failures.
$!
$ set noon
$ on control_y then goto finish
$ saved_default = f$environment("DEFAULT")
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ image = p1
$ if image .eqs. "" then image = f$parse("[.BIN_''arch']GZIP.EXE")
$ if f$search(image) .eqs. ""
$ then
$   write sys$error "SMOKE: no image ''image'"
$   exit 44
$ endif
$ gzip := $'image'
$ pass == 0
$ fail == 0
$ if f$search("SMOKE_TMP.DIR") .eqs. "" then create/directory [.SMOKE_TMP]
$ set default [.SMOKE_TMP]
$ if f$search("[.tree]*.*;*") .nes. "" then delete/nolog [.tree]*.*;*
$ if f$search("*.*;*") .nes. "" then delete/nolog *.*;*/exclude=*.DIR
$!
$! --- fixtures -------------------------------------------------------------
$! CREATE writes variable-length records: a VMS text file.
$ create ref.txt
the first line
line two, a little longer than the first
line three
$ if f$search("TREE.DIR") .eqs. "" then create/directory [.tree]
$ copy/nolog ref.txt [.tree]one.txt
$ copy/nolog ref.txt [.tree]two.txt
$ create bad.gz
this is not gzip data
$!
$! --- tests: name, expected exit code, expected output (| = newline), args --
$ call t version   0 ""                  "--version"
$ call t missing   1 "gzip: nosuch.gz: no such file or directory" "-d nosuch.gz"
$ call t corrupt   1 "gzip: bad.gz: not in gzip format" "-t bad.gz"
$!
$! Compress a text file: its records become LF-terminated lines, so the size
$! gzip reports is the Unix one (15 + 41 + 11 = 67 bytes), with no "file size
$! changed" warning (st_size of a record file counts record overhead).
$ copy/nolog ref.txt t1.txt
$ call t compress  0 ""                  "t1.txt"
$ call check NOSOURCE "f$search(""t1.txt"") .eqs. """""
$ call check GZFILE   "f$search(""t1.txt.gz"") .nes. """""
$ call t test      0 ""                  "-t t1.txt.gz"
$ call t list      0 "compressed uncompressed ratio uncompressed_name|79 67 19.4% t1.txt" "-l t1.txt.gz"
$ call t zcat      0 "the first line|line two, a little longer than the first|line three" "-dc t1.txt.gz"
$ call t decompress 0 ""                 "-d t1.txt.gz"
$ call same TEXT-ROUNDTRIP t1.txt ref.txt
$ copy/nolog ref.txt t2.txt
$ call t keep      0 ""                  "-k9 t2.txt"
$ call check KEPT     "f$search(""t2.txt"") .nes. """" .and. f$search(""t2.txt.gz"") .nes. """""
$!
$! A directory tree, by its VMS name and by its Unix name.
$ call t recurse   0 ""                  "-r [.tree]"
$ call check RECURSED "f$search(""[.tree]one.txt.gz"") .nes. """" .and. f$search(""[.tree]two.txt.gz"") .nes. """""
$ call t unrecurse 0 ""                  "-dr tree"
$ call check UNRECURSED "f$search(""[.tree]*.gz"") .eqs. """""
$ call t recurse-unix 0 ""               "-r tree"
$ call t unrecurse-vms 0 ""              "-dr [.tree]"
$ call same TREE-ROUNDTRIP [.tree]one.txt []ref.txt
$!
$! Binary data (fixed-length 512-byte records, as an image or a kit) is
$! compressed byte for byte.  gzip -d writes Stream_LF; with the record
$! attributes set back, the file must be identical to the original.
$ copy/nolog 'image' bin.exe
$ copy/nolog 'image' bin0.exe
$ call t binary    0 ""                  "bin.exe"
$ call t unbinary  0 ""                  "-d bin.exe.gz"
$ set file/attributes=(rfm:fix,lrl:512,mrs:512,rat:none) bin.exe
$ checksum bin.exe
$ c1 = checksum$checksum
$ checksum bin0.exe
$ if c1 .eq. checksum$checksum
$ then
$   write sys$output "PASS BINARY-ROUNDTRIP"
$   pass == pass + 1
$ else
$   write sys$output "FAIL BINARY-ROUNDTRIP: checksum ''c1' (want ''checksum$checksum')"
$   fail == fail + 1
$ endif
$!
$! Through DCL PIPE: compressed data into a mailbox and out of another one.
$ pipe gzip -c ref.txt | gzip -dc | search/nooutput sys$pipe "little longer"
$ if $severity .eq. 1
$ then
$   write sys$output "PASS PIPE"
$   pass == pass + 1
$ else
$   write sys$output "FAIL PIPE: ""little longer"" not found after gzip -c | gzip -dc"
$   fail == fail + 1
$ endif
$!
$! Under DCL a failure must have error severity, so ON ERROR and
$! IF .NOT. $STATUS see it.
$ define/user sys$output nl:
$ define/user sys$error nl:
$ gzip -d nosuch.gz
$ if $severity .eq. 2
$ then
$   write sys$output "PASS SEVERITY"
$   pass == pass + 1
$ else
$   write sys$output "FAIL SEVERITY: $SEVERITY ''$severity' (want 2)"
$   fail == fail + 1
$ endif
$!
$finish:
$ set default 'vmsdir'
$ set default [-]
$ set process/parse_style='saved_parse'
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed (''image')"
$ set default 'saved_default'
$ if fail .eq. 0 .and. pass .gt. 0 then exit 1
$ exit 44
$!
$! --- T name expected-exit expected-output args -------------------------
$t: subroutine
$ set noon
$ if f$search("out.txt") .nes. "" then delete/nolog out.txt;*
$ if f$search("err.txt") .nes. "" then delete/nolog err.txt;*
$! Separate files: two streams on one name would make two versions.
$ define/user sys$output out.txt
$ define/user sys$error err.txt
$ gzip 'p4'
$ st = $status
$! _POSIX_EXIT: the C exit code is in bits 3..10 of the VMS status.
$ code = (st .and. %X7F8) / 8
$ got = ""
$ do = "out.txt"
$readfile:
$ if f$search(do) .eqs. "" then goto nextfile
$ open/read f 'do'
$readloop:
$ read/end=readdone f line
$ if got .nes. "" then got = got + "|"
$ got = got + f$edit(line, "TRIM,COMPRESS")
$ if f$length(got) .gt. 300 then goto readdone
$ goto readloop
$readdone:
$ close f
$nextfile:
$ if do .eqs. "err.txt" then goto compare
$ do = "err.txt"
$ goto readfile
$compare:
$ ok = code .eq. f$integer(p2)
$! (DCL upper-cases the unquoted test name.)
$ if p1 .nes. "VERSION" then ok = ok .and. (got .eqs. f$edit(p3, "TRIM,COMPRESS"))
$ if p1 .eqs. "VERSION" then ok = ok .and. (f$locate("gzip 1.", got) .eq. 0)
$ if ok
$ then
$   write sys$output "PASS ", p1
$   pass == pass + 1
$ else
$   write sys$output "FAIL ", p1, ": exit ", code, " (want ", p2, "), output [", got, "] (want [", p3, "])"
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
$!
$! --- CHECK name dcl-expression ----------------------------------------
$check: subroutine
$ if 'p2'
$ then
$   write sys$output "PASS ", p1
$   pass == pass + 1
$ else
$   write sys$output "FAIL ", p1, ": ", p2
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
$!
$! --- SAME name file1 file2: the files have the same records ------------
$same: subroutine
$ set noon
$ if f$search("same.dif") .nes. "" then delete/nolog same.dif;*
$ define/user sys$error nl:
$ differences/output=same.dif 'p2' 'p3'
$ search/nooutput same.dif "Number of difference records found: 0"
$ if $severity .eq. 1
$ then
$   write sys$output "PASS ", p1
$   pass == pass + 1
$ else
$   write sys$output "FAIL ", p1, ": ''p2' and ''p3' differ"
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
