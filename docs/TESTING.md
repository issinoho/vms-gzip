# Testing

| Suite | Nodes | Needs | Command |
|---|---|---|---|
| DCL smoke test, 25 checks | IA64, x86-64, Alpha | nothing extra | `tools/test.sh <node>` |
| Install check | IA64, x86-64 | SYSTEM-level privileges for PRODUCT INSTALL | `tools/installcheck.sh <node>` |

The upstream test suite (`tests/`, shell scripts) has not been run under GNV yet; the
Alpha node has no GNV (and no Perl), so only the smoke test and the manual checks below
run there. On the Alpha, `tools/test.sh` runs the smoke test as a batch job.

## DCL smoke test (`vms/test_smoke.com`)

Runs from the built tree, or against an installed kit
(`@[.VMS]TEST_SMOKE GZIP$ROOT:[BIN]GZIP.EXE`). Works in `[.SMOKE_TMP]`.

- `--version`; error messages begin `gzip:` (patch 0006); exit codes for a missing file
  and for data that is not gzip.
- Text round trip: a VMS variable-record file compresses with no size warning,
  `gzip -t` and `gzip -l` agree with Linux gzip (`79 67 19.4% t1.txt`), `gzip -dc` gives
  the lines, `gzip -d` gives a file with the same records (DIFFERENCES).
- `-k`, `-9`.
- `-r` / `-dr` on a directory named both `[.tree]` and `tree` (patch 0004).
- Binary round trip: the GZIP.EXE image (fixed 512-byte records) compressed and
  decompressed, record attributes set back, CHECKSUM identical.
- `PIPE gzip -c | gzip -dc | SEARCH`: compressed data through mailboxes.
- DCL `$SEVERITY` is 2 (error) after a failure (patch 0002).

Results, 2026-10-08: 25/25 on IA64 (V8.4-2L3) and x86-64 (E9.2-4), from the build tree
and from the installed kit (install check: kit installs, smoke passes, removal leaves
no files, startup procedure or GZIP$ROOT behind).

Alpha (V8.4-2L2, 2026-11-15): 25/25 from the build tree, and 25/25 from the installed kit (install check passed).

## Manual checks on the Alpha

- A 4.4 MB BACKUP save set (fixed 32256-byte records): `gzip -k`, `gzip -l`, `gzip -d`,
  `SET FILE/ATTRIBUTES` back, `CHECKSUM/FILE` identical (3211057696), `DIFFERENCES` identical,
  and `cmp` identical on the host.
- A 5.4 MB tar compressed on Linux (`gzip -9`): `gzip -t`, `gzip -l` (same line as Linux)
  and `gzip -d` on the Alpha give a file with the same size and CHECKSUM as the original.
  `gzip -9` of it on the Alpha decompresses with Linux gzip to the original.
- A C probe for the `%jd`/`%ju` formats behind the `%CC-W-UNSUPCONVSPEC` warnings
  (see CLAUDE.md).

## Pitfalls when writing DCL tests

- Pointing SYS$OUTPUT and SYS$ERROR at the same new file makes two versions (each
  stream creates one); capture them in separate files.
- DIFFERENCES cannot read a Stream_LF binary file with long "records" (RTB error): use
  CHECKSUM/FILE.
- DIFFERENCES takes the second file's defaults from the first: write `[]ref.txt`.
- `gzip -c ... > file` does not redirect (the C RTL leaves `>` to the program); use PIPE.
