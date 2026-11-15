# CLAUDE.md

Guidance for working in this repository: a port of GNU gzip to OpenVMS (IA64, x86-64 and Alpha)
that stores only our deltas over the upstream release tarball. Read README.md first; it
describes the workflow and design. This file covers the rules and the pitfalls.

## Ground rules

- **Never edit `staging/`, `cache/` or `out/`.** They are regenerated. Every VMS change is
  either a patch (`patches/NNNN-*.patch`, listed in `patches/series`) or a new file in
  `overlay/`. `tools/prepare.sh` refuses overlay files that would replace upstream files.
- **Change an upstream file with a patch.** Make a pristine copy under `a/` and an edited
  copy under `b/`, run `diff -u a/<path> b/<path>`, and put a `Subject:` line and a short
  explanation above the diff. Guard VMS-only code with `#ifdef __VMS` so the patch could go
  upstream. Patches to the same file stack, so diff against the tree as it stands after the
  earlier patches.
- **Configuration answers** go in `overlay/vms/config/vms-manual.site`, each with a comment
  explaining why. Plain `var=value` lines there override the generated
  `configure-<node>.cache`. Overriding a gnulib result often needs its `gl_cv_*` variable
  too, not just `ac_cv_*` (`mempcpy` needed `gl_cv_onwards_func_mempcpy`).
- **Committed files must not contain real node details.** Use `<ia64-host>`, `<x86-host>`
  and `DISK$USER:[USERNAME.VMS_GZIP]`. The real values live only in the git-ignored
  `tools/nodes.conf`.
- Keep `docs/TESTING.md` and the README status table in step with test results.

## Alpha

- `build.sh`/`test.sh`/`kit.sh`/`installcheck.sh` use `vms.sh batch` there (interactive ssh
  output is unreliable; a batch job starts in the login directory, so each job sets default
  to the work directory). `vms.sh` is vms-grep's (it retries a command that never started).
- DCL: compare architecture names with `.EQS.`, never `.EQ.` (integer compare: every name
  equals every other). `build.com` upper-cases `F$GETSYI("ARCH_NAME")` and accepts ALPHA.
- The AXPVMS kit has its own README (`README_AXPVMS.VMS`). Patch level 2 is the Alpha kit;
  the x86-64 and IA64 kits stay on 1.
- Floating point: `ccflags.txt` already has `/FLOAT=IEEE_FLOAT/IEEE_MODE=DENORM_RESULTS`
  for every architecture.
- No assembly: `ASMV`/`match.S` is only for MS-DOS (`tailor.h`), the `dfltcc.c` inline
  assembly (IBM Z) is not built (`IBM_Z_DFLTCC` undefined) and there is no CRC intrinsic
  path (`GL_CRC_X86_64_PCLMUL` undefined); the Alpha build is the portable C code.
- Alpha has no GNV and no Perl: smoke test plus manual round trips only (gzip's upstream
  test suite needs GNV).
- Configuration: the Alpha uses the shared IA64-derived `config.h`, justified by replaying
  configure's test programs on the node; see the Alpha note in
  `overlay/vms/config/vms-manual.site`.
- The Alpha compiler gives five `%CC-W-UNSUPCONVSPEC` in `gzip.c` (`%ju` in the "other link"
  message, `%*jd` in the `-l`/`-lv` listing; `intmax_t` is 64 bits). They are harmless: a
  probe built with the same qualifiers printed `%jd`, `%*jd`, `%ju`, `%*ju` correctly for
  0, -1, INT_MAX, INT_MAX+1, 2^32, 5396480, INT64_MIN/MAX and UINT_MAX, 2^32 and UINT64_MAX,
  and `gzip -l` on the Alpha gave the same line as Linux gzip for a 5.4 MB file
  (2026-11-15). The link then says `%LINK-W-WRNERS` (compilation warnings in gzip.OBJ) but
  writes the image. About 47 `%CC-I-QUESTCOMPARE` and 2 `QUESTCOMPARE1` are informational
  (gnulib's `ckd_*` and timespec macros).
- Manual checks on the Alpha (no Perl/GNV): a 4.4 MB BACKUP save set compresses and
  decompresses with identical CHECKSUM (and `cmp`-identical bytes when fetched to the host);
  a .gz made by Linux gzip (`-9`, 5.4 MB tar) tests and decompresses to a file with the same
  size and CHECKSUM as the original; a .gz made on the Alpha decompresses with Linux gzip to
  the original. DIFFERENCES cannot compare a Stream_LF tar (record too large): use CHECKSUM.
## Commands

```sh
tools/prepare.sh                        # always first after changing patches/overlay
tools/build.sh <ia64|x86|alpha> [ALL|CLEAN] [KEEP_GOING]
tools/test.sh <node>                    # smoke test
tools/vms.sh <node> dcl '<cmd>' ...     # run DCL; also run/batch/put/get
tools/kit.sh <node>                     # PCSI kit -> out/kits/ (producer ISSINOHO)
tools/installcheck.sh <node>            # install kit, verify, smoke-test, remove (changes system; ask first)
tools/vms_configure.sh <node>           # once per upstream release (slow)
```

A full build takes a few minutes per node; run configure (long) with `run_in_background`.
MMS does not track compiler flags: after changing `ccflags.txt` or `CFLAGS` in
`descrip.mms`, run `tools/build.sh <node> CLEAN` first.

## VMS and tooling pitfalls (learned the hard way)

- **Use `tools/vms.sh`, never raw `ssh host cmd`.** Raw ssh output is often lost, and
  sessions sometimes never close. vms.sh logs to a file and waits for a completion marker.
- **Never use `WAIT` in DCL run over ssh**; it hangs (batch jobs are fine).
- **Never edit a bash script that is running.** bash reads scripts incrementally. Replace
  long-running tools atomically (write a copy, then `mv`).
- **Don't use `pkill -f` / `pgrep -f`** with a pattern that also matches your own shell's
  command line. Kill by explicit PID. On VMS, stop only processes this session started
  (they are network/batch processes of the work account); leave interactive sessions alone.
- **DCL details:**
  - `F$SEARCH` with a wildcard needs a stream id when other `F$SEARCH` calls happen in the
    same loop.
  - Batch jobs default to `/LIST` and `/MAP`.
  - DCL command lines are limited to about 4096 bytes (hence the wildcard librarian step).
  - `CALL` arguments are upper-cased unless quoted.
  - `SYS$LOGIN:[.X]` is not valid on these nodes.
- **`sftp put -r` into an existing directory nests a copy**; push.sh uploads file by file.
- **Run `tools/prepare.sh` after every change to `patches/` or `overlay/`.** build.sh and
  kit.sh push whatever is in `staging/`; forgetting this once shipped a stale kit.
- **stdout on VMS is often record-oriented** (terminal, `/OUTPUT` log, mailbox). The CRTL
  turns each `fwrite` item into a record (patch 0005), and a host-side `grep` treats
  output containing a NUL as binary (use `grep -a`).
- **CRTL quirks that shaped this port:**
  - `open()` of a directory fails with ENOENT; a directory named in VMS syntax lists
    VMS-form entries (`one^.txt;1`) - patch 0004;
  - `st_size` of a variable-record file is not the byte count `read()` returns (hence
    `NO_SIZE_CHECK`);
  - `>` on the command line is not redirected; tests and users use `PIPE`;
  - `.gz` keeps no RMS attributes: binaries decompress as Stream_LF;
  - no `#include_next`; `mempcpy` is a macro; argument case under traditional parse style.
- **gzip's sources are at the top of the tree** (no `src/`); push.sh uploads `*.c`/`*.h`
  from there with `lib/` and `vms/`.

## Commits

Commit in logical steps with messages that explain the VMS reason for each change. Don't
push without the user asking. The GitHub remote is `origin`
(github.com/issinoho/vms-gzip), branch `main`.
