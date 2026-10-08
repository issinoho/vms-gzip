$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the GZIP kit, verify, smoke-test
$! the installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[GZIP], system logical GZIP$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ product install GZIP /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ write sys$output "=== install status ", $status
$ product show product GZIP /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:GZIP$STARTUP.COM"), "]"
$ show logical GZIP$ROOT
$ directory/nohead/notrail GZIP$ROOT:[000000...]*.*
$ @GZIP$ROOT:[000000]GZIP$SETUP.COM
$ show symbol gzip
$ show symbol gunzip
$ show symbol zcat
$ gzip "--version"
$ write sys$output "=== SMOKE TEST on installed image"
$ smoke = tree - "]" + ".VMS]TEST_SMOKE.COM"
$ @'smoke' GZIP$ROOT:[BIN]GZIP.EXE
$ write sys$output "=== REMOVE"
$ product remove GZIP /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "GZIP$ROOT after removal: [", f$trnlnm("GZIP$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[GZIP...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:GZIP$STARTUP.COM"), "]"
$ product show product GZIP /producer=ISSINOHO
$ delete/symbol/global gzip
$ delete/symbol/global gunzip
$ delete/symbol/global zcat
