$! GZIP$SETUP.COM - define the GNU gzip commands for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @GZIP$ROOT:[000000]GZIP$SETUP.COM
$!
$! Quote upper-case options, or SET PROCESS/PARSE_STYLE=EXTENDED: traditional DCL
$! parsing changes the case of unquoted arguments; batch jobs use the traditional style.
$!
$ if f$trnlnm("GZIP$ROOT") .eqs. ""
$ then
$   write sys$error "GZIP$SETUP: GZIP$ROOT is not defined; run GZIP$STARTUP.COM first"
$   exit 44
$ endif
$ gzip   :== $GZIP$ROOT:[BIN]GZIP.EXE
$ gunzip :== "$GZIP$ROOT:[BIN]GZIP.EXE -d"
$ zcat   :== "$GZIP$ROOT:[BIN]GZIP.EXE -dc"
$ exit 1
