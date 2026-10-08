# Testing

| Suite | Nodes | Needs | Command |
|---|---|---|---|
| DCL smoke test, 25 checks | IA64, x86-64 | nothing extra | `tools/test.sh <node>` |
| Install check | IA64, x86-64 | SYSTEM-level privileges for PRODUCT INSTALL | `tools/installcheck.sh <node>` |

The upstream test suite (`tests/`, shell scripts) has not been run under GNV yet.

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

## Pitfalls when writing DCL tests

- Pointing SYS$OUTPUT and SYS$ERROR at the same new file makes two versions (each
  stream creates one); capture them in separate files.
- DIFFERENCES takes the second file's defaults from the first: write `[]ref.txt`.
- `gzip -c ... > file` does not redirect (the C RTL leaves `>` to the program); use PIPE.
