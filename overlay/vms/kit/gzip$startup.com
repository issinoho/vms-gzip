$! GZIP$STARTUP.COM - system startup for GNU gzip on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! GZIP$ROOT, pointing at the installed [GZIP] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:GZIP$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign GZIP$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the commands with
$!     $ @GZIP$ROOT:[000000]GZIP$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("GZIP$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode GZIP$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[GZIP].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.GZIP.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "GZIP.]"
$ if root .eqs. dir + "GZIP.]"
$ then
$   write sys$error "GZIP$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed GZIP$ROOT 'dev''root'
$ if f$search("GZIP$ROOT:[BIN]GZIP.EXE") .eqs. ""
$ then
$   write sys$error "GZIP$STARTUP: GZIP.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for GNU gzip"
$ say ""
$ say "    At system startup: to define GZIP$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:GZIP$STARTUP.COM"
$ say "    For each user: to define the commands, add this line to LOGIN.COM:"
$ say "    $ @GZIP$ROOT:[000000]GZIP$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE GZIP removes the product and deassigns GZIP$ROOT."
$ say ""
$ exit 1
