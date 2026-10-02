# 02 — Runner script (WP2, WP3)

Covers **WP2** (host-independent core) and **WP3** (launch lifecycle). Terms are defined in [00-overview.md](00-overview.md). The gate record `G1.md` is defined in [01-fixture-and-headless-gate.md](01-fixture-and-headless-gate.md).

All names in this file are **proposed** unless a finding marks them as existing.

G1 is complete. This file already contains its results: the two-launch sequence, the argument forms, the stop policy, and the constants. The values are in the "Constants for the script" table of [G1.md](G1.md).

## Change surface

All paths are **new**. The parent `.agents/skills/` exists.

| Path | Work package | Content |
| --- | --- | --- |
| `.agents/skills/vita3k-run-vpk/scripts/vita3k_vpk.py` | WP2, WP3 | The helper script. One file. Run through `python3`. |
| `.agents/skills/vita3k-run-vpk/tests/test_core.py` | WP2 | Unit tests for pure logic. |
| `.agents/skills/vita3k-run-vpk/tests/fixtures/xvfb-root.xwd` | WP2 | A real `xwd` dump of a small Xvfb root window. |
| `.agents/skills/vita3k-run-vpk/tests/fixtures/vita3k-sample.log` | WP3 | The sanitized real log excerpt from G1 check 7. |
| `.agents/skills/vita3k-run-vpk/tests/test_run.py` | WP3 | Integration tests with the stub emulator. |
| `.agents/skills/vita3k-run-vpk/tests/stub_vita3k.py` | WP3 | Stub emulator for tests. Mode 755 with a `python3` shebang, because `VITA3K_BIN` must name an executable. |
| `.agents/skills/vita3k-run-vpk/.gitignore` | WP2 | One line: `__pycache__/`. Reason: F5. |

Follow the import pattern in `.agents/skills/select-next-milestone/tests/test_validate_project.py`: compute the skill root from `__file__` and insert `scripts/` into `sys.path`.

Language constraints (D10): Python standard library only. Python 3.9 compatible. Start each file with `from __future__ import annotations`. Do not use `match` statements, `zip(strict=...)`, parenthesised multi-item `with` statements, `datetime.UTC`, or `X | Y` in a runtime expression such as `isinstance`.

Module contract for tests and documents: the script exposes `build_parser()` (returns the `argparse` parser), integer constants `EXIT_PASS = 0`, `EXIT_FAIL = 1`, `EXIT_USAGE = 2`, `EXIT_ENVIRONMENT = 3`, `EXIT_INCONCLUSIVE = 4`, and `xwd_to_png(xwd_bytes) -> png_bytes`.

Gate-derived constants (D14): the headless renderer profile (settings and environment), the default timeout (60 s), the install launch timeout (30 s), the kill grace period (2 s), the authoritative log source (captured stdout, plain redirect), the screenshot decision (keep), and the `eboot_matches` policy (gate) are constants in the script. The implementer copies their values from `G1.md`. The script never reads a file under `.agents/plans/`.

## Command contract

```text
python3 <skill-dir>/scripts/vita3k_vpk.py doctor [--display auto|xvfb|host]
python3 <skill-dir>/scripts/vita3k_vpk.py run <vpk> [options]
```

Both commands print exactly one JSON document on stdout. Diagnostics go to stderr. The one exception is a usage error (exit 2): `argparse` and path validation print the message to stderr, and stdout stays empty.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | `doctor`: ready. `run`: verdict `pass`. |
| 1 | `run`: verdict `fail`. |
| 2 | Usage error: bad arguments, unreadable VPK, rejected path. |
| 3 | `environment_error`: see the lifecycle failure codes. `doctor`: not ready. |
| 4 | `run`: verdict `inconclusive`. |

### Environment variables

| Variable | Meaning |
| --- | --- |
| `VITA3K_AGENT_HOME` | Instance root. Default `$HOME/.vita3k-agent`. |
| `VITA3K_BIN` | Emulator executable. Overrides discovery. |
| `VITA3K_VPK_HOST` | Test seam only. `linux` or `darwin`. Overrides host detection so one host's tests can exercise the other host's layout. Not documented in `SKILL.md`. |
| `VITA3K_VPK_INSTALL_TIMEOUT` | Test seam only. Seconds to wait for the install launch. Default 30. Not documented in `SKILL.md`. |

### `run` options

| Option | Meaning |
| --- | --- |
| `--timeout SECS` | Maximum run time of the boot launch. Default 60. |
| `--stop-when-satisfied` | Stop once every `--expect-*` condition has held for the settle period. Without it, the run lasts the full timeout. Without any `--expect-*` option it is a usage error. |
| `--settle SECS` | Settle period for `--stop-when-satisfied`. Default 5. |
| `--seed HOST_FILE=ux0:PATH` | Copy a host file into the emulated filesystem before launch. Repeatable. |
| `--clean ux0:PATH` | Delete a file or directory in the emulated filesystem before launch. Repeatable. |
| `--expect-file ux0:PATH` | The file must be fresh (D4) after the run. Repeatable. |
| `--expect-file-contains ux0:PATH=TEXT` | The file must be fresh and its fresh content must contain `TEXT`. Repeatable. |
| `--expect-log REGEX` | At least one log line must match. Repeatable. |
| `--reject-log REGEX` | No log line may match. Repeatable. |
| `--reject-file ux0:PATH` | The file must not be fresh after the run. Repeatable. |
| `--display auto\|xvfb\|host` | `auto`: `host` on macOS and when `DISPLAY` or `WAYLAND_DISPLAY` is set, otherwise `xvfb`. `doctor` takes the same option and computes the mode the same way. |
| `--no-screenshot` | Skip the screenshot even when the script owns the display. |

Argument splitting: `--expect-file-contains` splits at the first `=`. A `ux0:` path must not contain `=`. `--seed` splits at the last occurrence of `=ux0:`.

No option changes the renderer. In `xvfb` mode the script seeds the G1 renderer profile. In `host` mode the script does not touch the `backend-renderer` key, so the instance's persisted value applies: Vita3K's default, or OpenGL once an `xvfb` run has happened in that instance.

## WP2 — Host-independent core

Goal: every piece of logic that does not start a process, with unit tests. Prerequisite: none. G1 used a standalone converter, `xwd2png.py` in the G1 artifacts, which produced correct images from real dumps. Use it as the starting point for `xwd_to_png`.

### Instance layout

`InstancePaths` (conceptual) resolves from the instance root and the host:

| Field | Linux | macOS |
| --- | --- | --- |
| `config_file` | `xdg/config/Vita3K/config.yml` | `emulator/portable/config.yml` |
| `log_file` | `xdg/cache/Vita3K/vita3k.log` | `emulator/portable/vita3k.log` |
| `vita_fs` | `xdg/data/Vita3K/Vita3K/` | `emulator/portable/fs/` |
| `runs_dir` | `runs/` | `runs/` |
| `lock_file` | `run.lock` | `run.lock` |
| `state_file` | `run-state.json` | `run-state.json` |
| `version_cache` | `emulator-version.json` | `emulator-version.json` |

Linux values follow F15. macOS values follow F16 and stay unverified until G2.

Personal Vita3K paths, used only for the isolation check and never written:

| Host | Paths |
| --- | --- |
| Linux | `~/.config/Vita3K`, `~/.cache/Vita3K`, `~/.local/share/Vita3K` |
| macOS | `~/Library/Application Support/Vita3K` |

### Binary discovery

When `VITA3K_BIN` is set, it is the only candidate. A value that does not name an existing executable file gives `emulator_missing`. Otherwise the order is, first existing executable wins:

1. (`VITA3K_BIN`, handled above.)
2. Linux: `emulator/squashfs-root/AppRun`, then `emulator/Vita3K.AppImage`, then `emulator/Vita3K-aarch64.AppImage`, then `emulator/Vita3K-x86_64.AppImage`, then `Vita3K` on `PATH`.
3. macOS: `emulator/Vita3K.app/Contents/MacOS/Vita3K`.

macOS rule: the resolved binary must be at `<dir>/<name>.app/Contents/MacOS/<file>`, `<dir>` must equal the instance's `emulator/` directory, and `<dir>/portable/` must exist. Otherwise return `environment_error` with reason `isolation_unavailable`. Never fall back to `/Applications/Vita3K.app`. Reason: F16 and D3.

G1 ran the direct AppImage form at `emulator/Vita3K-aarch64.AppImage`.

### Privilege check

When the effective user ID is 0, or the real and effective user IDs differ, `run` returns `environment_error` with reason `privileged_user` before any other action, and `doctor` reports it as a problem that clears `ready` (D12).

### VPK inspection

- Open the VPK with `zipfile`. Require `eboot.bin` and `sce_sys/param.sfo`. Otherwise exit 2.
- Parse `param.sfo` and read `TITLE_ID`. The SFO format: 20-byte header with magic `\x00PSF`, key-table offset, data-table offset, and entry count, followed by 16-byte index entries. Read only the `TITLE_ID` string entry. Reject a malformed file with exit 2.
- Require `TITLE_ID` to match `^[A-Z0-9]{9}$`. The value becomes a path segment.
- Compute the SHA-256 of the VPK and of the `eboot.bin` member.
- Accept any file name. The script launches a copy named `<TITLE_ID>.vpk` (D15).

### Vita path mapping

`ux0:PATH` maps to `<vita_fs>/ux0/PATH`.

- Accept only the `ux0:` device.
- Reject empty paths, absolute paths, and any `..` segment.
- Resolve symlinks and require the result to stay inside `<vita_fs>/ux0/`. Otherwise exit 2.
- `--seed` creates missing parent directories. It requires the host file to exist and be a regular file.
- `--clean` accepts only a path at or below `ux0:data/<name>` or at or below `ux0:user/00/savedata/<TITLE_ID>`, where `<TITLE_ID>` is the VPK's own. It rejects everything else with exit 2. This excludes `ux0:app/...`, other titles' save data, and the `ux0:data` root.
- `--clean` deletes without following symlinks: inspect with `os.lstat`, unlink a symlink itself, and recurse only into real directories.

### Config seeding

Upsert top-level scalar keys in `config_file` line by line. Create the file when absent. Replace an existing `key: value` line. Append a missing key. Leave every other line unchanged.

Keys (F14, F19): `show-welcome: false`, `warn-missing-firmware: false`, `check-for-updates: false`, `check-for-updates-mode: 0`, `log-level: 0`, and `backend-renderer` only when the display mode is `xvfb`.

G1 confirmed that Vita3K accepts a file with only these keys and rewrites it to a full file on exit. The upsert must therefore handle both a minimal and a full file. Build 4111 drops the `check-for-updates` key on rewrite. Seeding it again on each run is harmless.

### Snapshot and diff

- A snapshot walks all of `<vita_fs>/ux0/` except `<vita_fs>/ux0/app/`, plus every path named by an expectation. It does not follow symlinks. `ux0/app/` is excluded because every run reinstalls the title there. An expectation may still name a path under `ux0:app`.
- The before-snapshot is taken after the install launch and before the boot launch. The diff therefore covers the boot launch only, and nothing that the installer writes can appear as app evidence. For an expectation under `ux0:app`, fresh means changed after the install.
- Vita3K itself writes `ux0/user/time.xml` and `ux0/user/<NN>/user.xml` (seen in the G1 instance). The diff reports paths that match these two patterns under a separate `emulator_owned` list and not under `created` or `modified`. An expectation that names one of them is still evaluated. G1 did not record a diff of a boot launch, so this list is provisional. WP5 step 3 records the real diff, and the list is extended from it.
- Each entry records relative path, size, `mtime_ns`, and SHA-256. Skip hashing for files larger than 16 MiB and record `sha256: null`.
- The diff lists `created`, `modified`, and `deleted` paths. `modified` means a changed `mtime_ns`, size, or hash.
- A file is **fresh** when it is in `created` or `modified` (D4).
- **Fresh content** is what `--expect-file-contains` searches:
  - created file: the whole file;
  - modified file that grew, where the SHA-256 of its first `before_size` bytes equals the before-snapshot hash: the bytes after `before_size` only. The file was appended to (vitair's `startup.log`, F23);
  - every other modified file: the whole file. The app rewrote it. bevypoc's `build.txt` is this case: each launch rewrites the same bytes, and the new `mtime_ns` makes it fresh.
- A file larger than 16 MiB has no before-hash. Treat its fresh content as the whole file and add warning `large_file_unhashed`.

### Log parsing

- Strip ANSI escape sequences from every line first (A8).
- Line pattern (F18): `[HH:MM:SS.mmm] |L| [function]: message`.
- Captured stdout also contains Qt and Mesa lines that do not match the pattern (G1). One app `eprintln!` produces several `*** TTY:` lines, so a regex must match one fragment, not the whole message.
- `log_summary` contains: the source name, line count, count per level, the first 20 `E` and `C` lines, every line containing `*** TTY: ` up to 200 lines, and the last 40 lines.
- Lines that do not match the pattern count as level `?` and stay available to regex expectations.
- Regex expectations and `log_summary` read the boot launch's captured stdout, `emulator-stdout.log` (D13). The install launch's stdout is used only for `install_logged`. Its last 40 lines are added to the result when the install fails.

### XWD conversion

`xwd_to_png` reads the XWD version-7 header (big-endian 32-bit fields), skips the header remainder and the colormap, and reads ZPixmap rows of 24 or 32 bits per pixel using the header's byte order, bytes per line, and channel masks. It writes an 8-bit RGB PNG with `zlib` and `struct`. It raises a specific error for any other format.

### Verdict evaluation

Precedence, first match wins:

1. `environment_error`: any lifecycle failure listed in WP3.
2. `fail` with reason `emulator_crashed`: in the boot launch, the emulator's process group became empty before the script sent any signal, and the leader's exit status was non-zero.
3. `fail`: any `--reject-log` match or fresh `--reject-file`.
4. `fail`: any unmet `--expect-*` condition.
5. `pass`: at least one `--expect-*` condition exists and all hold.
6. `inconclusive`: no `--expect-*` condition exists.

Rule 2 never applies to the install launch, and never applies once the script has sent `SIGTERM` or `SIGKILL`. The group leader is a shell wrapper on Linux (G1), so a Vita3K that dies from a signal is reported as exit code `128 + signal`. The script reports `emulator_signal` as the negative return code when the leader itself was signalled, and as `code - 128` when the code is above 128.

Rule 2 does not separate an app defect from an emulator defect. The result reports the exit code and signal, and `references/evidence.md` tells the agent to read the log tail before blaming the app.

Log severity never changes the verdict by itself. Error and critical lines appear in `log_summary` for the agent to judge.

### Result document

One JSON object. Field names are **proposed**:

```text
schema_version      1
verdict             pass | fail | inconclusive | environment_error
reason              short machine-readable code, or null
warnings            list of codes: emulator_exited_early, stopped_early,
                    screenshot_failed, orphan_cleaned, large_file_unhashed
host                {os, arch, display_mode}
emulator            {path, version, sha256}
vpk                 {path, sha256, title_id, eboot_sha256}
stages              {installed: bool, install_logged: bool, eboot_matches: bool,
                    install_exit_code,
                    emulator_exit_code, emulator_signal, seconds_running}
                    (the last three describe the boot launch)
expectations        list of {kind, target, satisfied, detail}
fs_diff             {created, modified, deleted, emulator_owned}
log_summary         see above; always from the boot launch's stdout
paths               {run_dir, vita_fs, log_copy, install_stdout, boot_stdout, screenshot or null}
started_at, finished_at   RFC 3339 UTC
```

The same object is written to `<run_dir>/result.json`. An expectation `detail` never contains the content of a seeded host file.

Every `run` that passes argument and VPK validation prints this object, also when it stops early. Fields that the run did not reach have defined values:

| Stop point | Field values |
| --- | --- |
| Before the run directory exists (`privileged_user`, `emulator_missing`, `isolation_unavailable`, `instance_busy`) | `paths.run_dir` and every other `paths` entry `null`, `stages` values `null`, `fs_diff` lists empty, `log_summary` `null`, each expectation listed with `satisfied: false` and `detail: "not_evaluated"`. No `result.json` is written. |
| `display_failed`, `emulator_start_failed`, `install_failed` | As above, except that `paths.run_dir` and the files that exist are set, `stages` holds what is known, and `log_summary` is built from `install-stdout.log` when that file exists. `result.json` is written. |
| The script receives `SIGINT` or `SIGTERM` | Teardown runs. Verdict `environment_error`, reason `interrupted`, exit 3, other fields as far as known. |

### WP2 tests (`tests/test_core.py`)

Each item is one or more `unittest` cases. Build SFO and VPK fixtures in the test with `struct` and `zipfile`. Use temporary directories only.

1. SFO parser returns the `TITLE_ID` from a synthetic `param.sfo` with three entries in mixed order.
2. SFO parser rejects a wrong magic, a truncated index, and an offset beyond the file.
3. VPK inspection rejects an archive without `eboot.bin`, without `sce_sys/param.sfo`, and with `TITLE_ID` `../../x`.
4. Path mapping accepts `ux0:data/app/file.txt`. It rejects `app0:x`, `ux0:../x`, `ux0:/abs`, `ux0:`, and a symlink that leaves `ux0/`.
5. `--clean` validation accepts `ux0:data/bevypoc` and `ux0:user/00/savedata/<own TITLE_ID>`. It rejects `ux0:data`, `ux0:app`, `ux0:app/OTHERID01`, `ux0:user`, `ux0:user/00`, and `ux0:user/00/savedata/OTHERID01`.
6. `--clean` deletion removes a symlink inside the target without touching the symlink's destination outside the instance.
7. Argument splitting: `--expect-file-contains ux0:data/a.txt=k=v` yields path `ux0:data/a.txt` and text `k=v`. `--seed /tmp/a=b.txt=ux0:data/x.txt` yields the host path `/tmp/a=b.txt`.
8. Config upsert creates a file, replaces an existing key, appends a missing key, and preserves unrelated lines and their order.
9. Diff reports created, modified (content change with equal size), touched (same content, new `mtime_ns`), and deleted files.
10. Freshness: a file present with identical `mtime_ns` and hash before and after is not fresh.
11. Fresh content: an appended file exposes only the appended bytes. A stale line that equals the expected text and sits in the old prefix does not satisfy `--expect-file-contains`. A file rewritten with different bytes exposes the whole file. A file rewritten with identical bytes and a new `mtime_ns` exposes the whole file.
12. Log parsing counts levels, extracts `*** TTY:` lines, strips ANSI sequences, and tolerates non-matching lines.
13. Verdict precedence: one case per rule above, including a reject match that overrides satisfied expectations and a crash that overrides satisfied expectations.
14. `InstancePaths` returns the Linux and macOS layouts for an injected host name.
15. macOS binary discovery with `VITA3K_VPK_HOST=darwin`: a temporary `emulator/Vita3K.app/Contents/MacOS/Vita3K` with `emulator/portable/` resolves. The same bundle without `portable/` returns `isolation_unavailable`. A `VITA3K_BIN` outside the instance returns `isolation_unavailable`.
16. `xwd_to_png` converts `tests/fixtures/xvfb-root.xwd` to a PNG. The test decodes the PNG with `zlib` and asserts the dimensions and the color of one known pixel. A truncated dump raises the specific error.
17. Python 3.9 syntax: `ast.parse(source, feature_version=(3, 9))` succeeds for the script and every test file. A text scan of `scripts/vita3k_vpk.py` only finds no `match ` statement at line start, no `strict=`, and no `datetime.UTC`. This check covers syntax only. Full 3.9 behavior is proven at G2.
18. Large file: a sparse file larger than 16 MiB that changes during the run is reported as modified with `sha256: null`, and the result carries warning `large_file_unhashed`.
19. Run directory naming and pruning order: a second directory for the same second and title gets the suffix `-2`. Sorting run directory names lexicographically gives creation order.

Create the XWD fixture once, on this host: start `Xvfb` with a `64x48x24` screen, run `xsetroot -solid '#336699'` (present on this host), and run `xwd -root -silent`. The expected pixel is RGB `(0x33, 0x66, 0x99)`. The file is about 12 KiB.

WP2 acceptance: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .agents/skills/vita3k-run-vpk/tests -p 'test_core.py'` exits 0.

## WP3 — Launch lifecycle

Goal: `run` and `doctor` work end to end. Prerequisites: WP2 complete. G1 is complete. Implement the recipe in [G1.md](G1.md). This section already follows it.

### Process handling rules

These rules apply to every process that the script starts: the version probe, its Xvfb, the run's Xvfb, the install launch, and the boot launch.

- Start each one in its own session (`start_new_session=True`), so each has its own process group and none shares the script's group.
- `run-state.json` is a list of entries `{role, pid, pgid, lstart}`. `role` is one of `probe_xvfb`, `probe`, `xvfb`, `install`, `boot`. `lstart` is the string that `ps -o lstart= -p <pid>` printed right after the start. `ps -o lstart=` works on Linux and macOS. Append an entry at each start. Remove it when that process group is confirmed empty.
- **Stop a launch** (one function, used for the probe, the install launch, and the boot launch): send `SIGTERM` to the process group, wait up to the kill grace constant (2 s) for the group to become empty, then send `SIGKILL` to the group and wait until it is empty. Reap the leader, so that a zombie does not keep the group non-empty. This function does not touch Xvfb.
- Before any signal to a process group, refuse a group ID equal to the script's own (`os.getpgrp()`).
- **Teardown** (one function, run in a `finally` path and on `SIGINT` and `SIGTERM` to the script): stop every process still listed in `run-state.json`, emulator roles first and Xvfb roles last, then remove the state file and release the lock. Vita3K aborts when its X connection breaks, so Xvfb always stops last.
- On Linux the process group of a launch holds a shell wrapper (the leader) and the Vita3K process (G1). "The emulator ended" always means that the process group is empty.

### `run` sequence

```text
1  parse arguments, privilege check, inspect VPK     → exit 2 or privileged_user
2  resolve instance and binary                       → emulator_missing, isolation_unavailable
3  take run.lock (non-blocking flock)                → instance_busy
4  clean up orphans named in run-state.json
5  create run_dir = runs/<UTC yyyymmddThhmmssZ>-<TITLE_ID>[-N]/, copy VPK to run_dir/<TITLE_ID>.vpk
6  record personal Vita3K paths (existence, mtime_ns)
7  emulator version: read cache or probe
8  seed config, remove ux0/app/<TITLE_ID>/, apply --clean, apply --seed
9  display: start Xvfb when mode is xvfb             → display_failed
10 install launch: <binary> -- <run_dir>/<TITLE_ID>.vpk, output → run_dir/install-stdout.log;
   wait for the install, then stop the launch
11 snapshot (before)
12 boot launch: <binary> -r <TITLE_ID>, output → run_dir/emulator-stdout.log
13 wait loop (poll once per second)
14 screenshot when the script owns the display
15 stop the boot launch
16 teardown: stop Xvfb, clear run-state.json
17 snapshot (after), diff
18 copy log and fresh evidence files into run_dir
19 isolation checks, stage checks, verdict
20 write result.json, print it, prune old run directories, release lock
```

When step 10 fails, skip steps 11–15 and continue at step 16. Steps 17–20 still run, so the result has the isolation checks, `stages`, and the install log tail.

Details:

- **Step 4, orphans.** When the lock was free and `run-state.json` exists, a previous script died without cleanup. For each entry, emulator roles first and Xvfb roles last: when the process still exists and `ps -o lstart=` prints the recorded string, stop its process group with the stop function, and add warning `orphan_cleaned`. When the start time differs or the process is gone, the ID was reused or the process ended: do not signal it. Then remove the state file. G1 found no stale AppImage mount after `SIGKILL`, so no mount cleanup is needed.
- **Step 5, run directory.** When the directory name exists, append `-2`, then `-3`, and so on. Never reuse a run directory.
- **Step 7, version.** `version_cache` stores the version string keyed by binary path, size, and `mtime_ns`. On a miss, probe with `<binary> --version` in the same isolation environment and on the same kind of display as the launch, with a 20-second timeout. On headless Linux the probe needs its own short-lived Xvfb, because the AppImage has no offscreen Qt platform (G1). The version is the first stdout line that starts with `Vita3K `. A failed probe in `run` sets `version` to `null` and does not stop the run. The probe runs only while the lock is held, because every Vita3K start truncates `vita3k.log` (F18).
- **Step 8, app directory.** Delete `<vita_fs>/ux0/app/<TITLE_ID>/` before the install launch, without following symlinks. Vita3K removes and reinstalls this directory itself (F13). Deleting it first means that an `eboot.bin` found afterwards was written by this run.
- **Step 9.** Start `Xvfb -displayfd <fd> -screen 0 1280x800x24 -nolisten tcp` (D6). Read the display number from the descriptor. Fail after 10 seconds without one. One Xvfb serves both launches.
- **Steps 10 and 12, common.** Redirect stdout and stderr to the named file. Linux environment: the three `XDG_*` variables (D3) plus the renderer environment constant when the display mode is `xvfb`. macOS environment: unchanged. Pass arguments as a list. When process creation raises an error, return `emulator_start_failed`.
- **Step 10, install launch.** Arguments: `--`, then the absolute path of the VPK copy. The `--` is required: without it the parser reads a leading `/` as an option and ignores the path (G1). Poll twice per second. The install is complete when both hold: `<vita_fs>/ux0/app/<TITLE_ID>/eboot.bin` has the SHA-256 of the VPK's `eboot.bin`, and `install-stdout.log` contains `installed successfully!`. Vita3K prints that line after it has extracted every file (G1). Then stop the launch. `SIGTERM` is enough here, because no app runs (G1). The install fails when the process group becomes empty before both conditions hold, or when the install timeout (30 s, or the test seam) elapses. On failure, stop the launch and record `install_exit_code`. Vita3K logs that it will auto-boot and does not (G1). Do not wait for a boot in this launch.
- **Step 12, boot launch.** Arguments: `-r`, then the title ID. `--timeout`, the wait loop, `seconds_running`, `emulator_exit_code`, and `emulator_signal` refer to this launch.
- **Step 13.** The loop ends when the timeout elapses or when the emulator ends. With `--stop-when-satisfied`, it also ends when every expectation has held continuously for the settle period. An early stop adds warning `stopped_early`. Evaluate file expectations against a fresh snapshot of the expectation paths. Evaluate log expectations against `emulator-stdout.log`.
- **Step 14.** Run `xwd -root -silent -display :N` and convert with `xwd_to_png`. Any failure adds warning `screenshot_failed` and never changes the verdict. The frame shows the game window at the top left and the emulator's main window, including its log panel, around it (G1).
- **Step 15.** Stop the boot launch with the stop function. Vita3K ignores `SIGTERM` while an app runs (G1), so this launch normally ends by `SIGKILL`. Record whether the script sent a signal. A launch that the script signalled is never a crash.
- **Step 18.** Copy `log_file` to `run_dir/vita3k.log`. During a run this file lags far behind stdout and is often empty (G1). It reflects the boot launch only, because each start truncates it. Copy each fresh file named by an expectation, and each created file up to 1 MiB, to `run_dir/evidence/` with its `ux0`-relative path. Limit the copy to 50 files.
- **Step 19, order of checks.** First `isolation_violated`, then the stage checks, then `isolation_unverified`. The first failing check decides the reason.
- **Step 19, `isolation_violated`.** Each personal Vita3K path must have the same existence and `mtime_ns` as recorded in step 6. Otherwise return `environment_error` with reason `isolation_violated`. Reason: R3. A user who runs a personal Vita3K during the run triggers this check. `references/evidence.md` states this.
- **Step 19, `isolation_unverified`.** Evaluated only when `installed` is true, because an emulator that never got far enough to install may never have opened its log. The `log_file` at the instance path must have a modification time at or after the start of the install launch. Vita3K truncates it at every start, so the time changes even when the file stays empty. Otherwise return `environment_error` with reason `isolation_unverified`.
- **Step 19, stage checks.** `eboot_matches` is true when `<vita_fs>/ux0/app/<TITLE_ID>/eboot.bin` exists and has the SHA-256 of the VPK's `eboot.bin`. `install_logged` is true when `install-stdout.log` contains `installed successfully!`. `installed` is true when both are true. When `installed` is false, return `environment_error` with reason `install_failed`.
- **Emulator ends before the loop ends.** This concerns the boot launch. Exit status 0: add warning `emulator_exited_early` and continue to the verdict rules. Non-zero exit status: verdict rule 2 applies.
- **Step 20, pruning.** After the result is written, keep the newest 20 run directories, counting the current one. Consider only direct children of `runs/` that are real directories (checked with `os.lstat`) and whose names match `^\d{8}T\d{6}Z-[A-Z0-9]{9}(-\d+)?$`. "Newest" means last in lexicographic name order. Delete from the start of that order. Never delete the current run directory. Never follow a symlink.

### Lifecycle failure codes

`privileged_user`, `emulator_missing`, `isolation_unavailable`, `instance_busy`, `display_failed`, `emulator_start_failed`, `install_failed`, `isolation_unverified`, `isolation_violated`, `interrupted`. Each returns exit 3 and a `reason`. `emulator_start_failed` means that process creation for the emulator raised an error. An emulator that starts and then ends without installing is `install_failed`. This includes a binary that cannot load its libraries, for example the `GLIBC_2.43 not found` case from G1. The install log tail in the result shows the cause. `interrupted` means that the script received `SIGINT` or `SIGTERM`.

### `doctor`

Output fields (**proposed**): `ready` (bool), `host`, `instance_root`, `emulator` (`path`, `version`, `sha256`, or `null`), `paths` (the `InstancePaths` values), `firmware` (`main`: `vs0/` has content, `font`: `sa0/` has content, per F20), `headless` (`needed`, `xvfb`, `xwd`), `problems` (list of `{code, detail, fix}`).

- `ready` is false when the user is privileged (D12), when the emulator is missing, when macOS isolation is unavailable, when the display mode would be `xvfb` and `Xvfb` is missing, or when the version probe ran and failed.
- The version probe is the readiness test for the binary: it proves that the emulator starts on this host. A failed probe adds a problem entry with the last 10 lines of the probe's output. That output names a missing library, a missing FUSE runtime, or a glibc mismatch (G1 deviation 1).
- Version: read `version_cache`. On a miss, take the lock without blocking and probe as in `run` step 7. On headless Linux `doctor` therefore starts and stops an Xvfb for the probe. On macOS the probe is the plain `--version` invocation, unverified until G2. When the lock is busy, skip the probe and report `version: null` with a problem entry that does not clear `ready`.
- A missing `xwd` or missing firmware is a problem entry that does not clear `ready`.
- Each `fix` names the section of `references/install.md` to follow.
- The version probe starts Vita3K, so it creates the instance's config, cache, and data directories and truncates the instance's `vita3k.log`. `doctor` changes nothing outside the instance and never downloads or installs anything.
- `doctor` prints the binary's SHA-256 so it can be compared with the release asset digest (F10).

### Stub emulator (`tests/stub_vita3k.py`)

A Python script, selected through `VITA3K_BIN`, that mimics the observable contract and nothing else. It resolves its paths the way Vita3K does: when a `portable/` directory exists beside the app bundle that contains it (F16), it uses that layout. Otherwise it uses the `XDG_*` variables (F15). It truncates the log file at start (F18).

The stub follows the argument contract from G1:

- `--version`: print `Vita3K v0.0.0 stub` and exit 0.
- `-- <vpk>` (install launch): unzip the VPK to `ux0/app/<TITLE_ID>/`, print a line ending in `installed successfully!`, and idle until `SIGTERM`. A VPK path without the `--` separator is ignored, as in Vita3K.
- `-r <TITLE_ID>` (boot launch): exit 1 when `ux0/app/<TITLE_ID>/` is absent. Otherwise run the app behavior and ignore `SIGTERM`, as Vita3K does with a running app. The app behavior is that of the `ok` row unless `STUB_MODE` names a boot mode. An unset `STUB_MODE` means `ok`.

The stub prints fixed lines in the real log format, so tests can quote them: `[HH:MM:SS.mmm] |I| [stub]: Game started: stub (<TITLE_ID>)` and `[HH:MM:SS.mmm] |T| [write_file]: *** TTY: stub ready` in every boot launch, and `[HH:MM:SS.mmm] |E| [stub]: late error` in `late_error`.

The stub appends one JSON line per invocation to the file named by `STUB_RECORD`: `{"launch": "version" | "install" | "boot", "argv": [...], "env": {...}}`. Tests read the list.

`STUB_MODE` changes one launch. Every other launch behaves as described above.

| Mode | Launch | Behavior |
| --- | --- | --- |
| `ok` | boot | Print boot log lines, write `ux0/data/stub/out.txt`, `ux0/temp/stub.tmp`, and `ux0/user/time.xml`, then sleep until killed. |
| `no_evidence` | boot | As `ok` without writing `out.txt`. |
| `append` | boot | As `ok`, and append one line to `ux0/data/stub/startup.log`. |
| `late_error` | boot | As `ok`, and print an error log line 3 seconds after writing `out.txt`. |
| `exit_early` | boot | As `ok`, then exit 0 after one second. |
| `crash` | boot | As `ok`, then end with `SIGSEGV` after one second. The test starts the stub through a `/bin/sh -c` wrapper script, so the leader reports exit code 139, as the real AppImage wrapper does. |
| `wrong_paths` | both | Write the log file outside the instance. |
| `touch_personal` | boot | As `ok`, and create a file under the personal Vita3K path of the temporary `HOME`. |
| `install_fail` | install | Print a log line, install nothing, exit 1. |
| `install_silent` | install | Print the `installed successfully!` line, install nothing, then idle. |
| `install_wrong_eboot` | install | Install an `eboot.bin` with different bytes, print the `installed successfully!` line, then idle. |
| `install_hang` | install | Install correctly and ignore `SIGTERM`. |
| `install_noload` | install | Exit 127 at once, without creating or touching the log file. This mimics a binary that cannot load its libraries. |
| `version_fail` | version | Print an error line and exit 127. |

### WP3 tests (`tests/test_run.py`)

Run the script as a subprocess with `--display host`, a temporary `VITA3K_AGENT_HOME`, a temporary `HOME`, short timeouts, and `VITA3K_VPK_INSTALL_TIMEOUT=3`. A test helper builds the instance for the host under test: on Linux the stub is `VITA3K_BIN`. For the macOS layout the helper copies the stub to `emulator/Vita3K.app/Contents/MacOS/Vita3K`, creates `emulator/portable/`, and sets `VITA3K_VPK_HOST=darwin`. Run tests 1–4 in both layouts on every host.

1. `ok` with `--expect-file-contains ux0:data/stub/out.txt=<text>` → exit 0, verdict `pass`, `fs_diff.created` lists the file, `run_dir/result.json` equals stdout.
2. `ok` with no expectation → exit 4, verdict `inconclusive`.
3. `no_evidence` with `--expect-file ux0:data/stub/out.txt` → exit 1, verdict `fail`.
4. Stale evidence: create `ux0/data/stub/out.txt` before the run, use `no_evidence` → verdict `fail`. This proves S2 for whole files. A file that the stub writes under `ux0/temp/` appears in `fs_diff.created`. Files under `ux0/app/` do not appear in `fs_diff`. `ux0/user/time.xml` appears under `fs_diff.emulator_owned` only.
5. Stale appended evidence: pre-create `startup.log` containing the expected line, run `append` with a different line, expect the old line → verdict `fail`. Expect the new line → verdict `pass`.
6. `ok` with `--reject-log` matching a stub boot log line → verdict `fail`. `--expect-log` for the `installed successfully!` line → verdict `fail`, because log expectations read the boot launch only.
7. `late_error` with `--stop-when-satisfied --settle 5` and `--reject-log` for the error line → verdict `fail`. The same with `--settle 0` → verdict `pass` with warning `stopped_early`. This documents what an early stop can and cannot observe.
8. `install_fail` → exit 3, reason `install_failed`, `stages.install_exit_code` is 1, the result holds the install log tail, and the record shows no boot launch. The failure is reported without waiting for the install timeout.
9. `install_silent` with a pre-created `ux0/app/<TITLE_ID>/eboot.bin` → exit 3, reason `install_failed`, `stages.eboot_matches` false. The pre-created file is gone, because step 8 deleted it. This proves that a stale install plus a log line cannot fake the install stage.
10. `install_wrong_eboot` → exit 3, reason `install_failed`, `stages.eboot_matches` false, `stages.install_logged` true.
11. `install_hang` → the install launch is killed after the grace period, and the run continues to the boot launch and returns a correct verdict.
12. `exit_early` with a satisfied expectation → verdict `pass` with warning `emulator_exited_early`.
13. `crash` behind the shell wrapper, with the same satisfied expectation → exit 1, verdict `fail`, reason `emulator_crashed`, `stages.emulator_exit_code` 139, `stages.emulator_signal` 11. `crash` with no expectation → verdict `fail`, not `inconclusive`.
14. `ok` → the boot launch ignores `SIGTERM`, the script returns within the grace period plus kill time, the verdict is not `emulator_crashed`, and no stub process remains.
15. `wrong_paths` → exit 3, reason `isolation_unverified`.
16. `touch_personal` → exit 3, reason `isolation_violated`.
17. Second concurrent run while the first holds the lock → exit 3, reason `instance_busy`.
18. Orphan cleanup, boot: start a run with `ok`, send `SIGKILL` to the script during the boot launch, confirm the stub survives, start a second run → the second run kills the orphan, reports warning `orphan_cleaned`, and returns a correct verdict.
19. Orphan cleanup, install: the same with `install_hang` and a `SIGKILL` to the script during the install launch.
20. Orphan safety: a `run-state.json` that names a live unrelated process with a different start time → that process is not signalled. An entry whose group ID equals the script's own → not signalled.
21. `--seed` places the file before the install launch. `--clean` removes a stale directory before the snapshot.
22. A VPK named `build output.bin` (space, wrong extension) runs. The record shows an install launch with `--` and `<run_dir>/<TITLE_ID>.vpk`, then a boot launch with `-r` and the title ID.
23. The recorded environment of both launches has all three `XDG_*` variables inside the instance (Linux layout).
24. Pruning: pre-create 20 matching run directories with older names, a symlink, and a directory named `keep-me` in `runs/`. After one run there are 21 matching directories, so the oldest-named one is deleted. The current run directory, the symlink, its target, and `keep-me` survive.
25. `VITA3K_BIN` pointing to a missing file → exit 3, reason `emulator_missing`. `doctor` in the same state → exit 3 with a problem entry.
26. `doctor --display host` with the stub present → exit 0, `headless.needed` false, the `paths` values match `InstancePaths`, the version string comes from the stub, and a second `doctor` call reads it from the cache: the record shows one version launch.
27. `doctor --display host` with `version_fail` → exit 3, `ready` false, and the problem entry holds the stub's error line.
28. Log parsing of `tests/fixtures/vita3k-sample.log` yields the level counts, the `*** TTY:` lines, and the `Game started:` line that the fixture contains. The fixture is an excerpt of a real boot launch from G1. It contains no install line. This ties the parser to real Vita3K output.

29. `install_noload` → exit 3, reason `install_failed`, not `isolation_unverified`.
30. `--reject-file ux0:data/stub/out.txt` with `ok` → verdict `fail`. The same with `no_evidence` and one satisfied expectation → verdict `pass`.
31. `run` with `version_fail` → the run completes with a correct verdict and `emulator.version` is `null`.
32. `VITA3K_BIN` naming an executable file with invalid content (not a program, no shebang) → exit 3, reason `emulator_start_failed`.
33. `--display xvfb` with a `PATH` that contains no `Xvfb` → exit 3, reason `display_failed`. This test needs no X server.
34. `SIGTERM` to the script during the boot launch → exit 3, reason `interrupted`, one JSON document on stdout, and no stub process remains.
35. `--stop-when-satisfied` without any `--expect-*` option → exit 2 and empty stdout.
36. A run that fails before the run directory exists (`instance_busy`) prints the result object with `paths.run_dir` `null` and each expectation `not_evaluated`.

Tests that need `Xvfb` must skip with a clear message when `Xvfb` is absent. Add two such tests. First: `--display xvfb` with the `ok` stub produces `paths.screenshot` with the PNG signature and the Xvfb screen dimensions, and leaves no `Xvfb` process. Second: `--display xvfb`, a `SIGKILL` to the script during the boot launch, then a second run → the second run stops the orphaned stub and the orphaned Xvfb.

The privilege check cannot be exercised as a normal user. Test it by calling the check function with injected user IDs in `test_core.py`.

WP3 acceptance:

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .agents/skills/vita3k-run-vpk/tests` exits 0 on this host.
- `python3 -m py_compile .agents/skills/vita3k-run-vpk/scripts/vita3k_vpk.py` exits 0.
- After the test run, `pgrep -fa 'stub_vita3k|Xvfb'` shows no process started by the tests.
- `git status --short` shows no `__pycache__` path under the new skill.
- `grep -rn "agents/plans" .agents/skills/vita3k-run-vpk` returns nothing (D14).

## Compatibility and lifecycle notes

- No existing interface changes. The application context records no compatibility requirement.
- The script writes only inside `VITA3K_AGENT_HOME`. It never writes to the VPK's repository.
- Recovery after any failure: the next `run` cleans orphans and reseeds the config. Deleting `VITA3K_AGENT_HOME/xdg` (Linux) or `emulator/portable/*` content (macOS) resets the emulated state without reinstalling the emulator.

## Risks, edge cases, and exclusions

- The stub proves script logic only (D11). A green test suite does not prove that Vita3K boots a VPK. The stub encodes the Linux behavior that G1 observed and this plan's reading of F16 for macOS. WP5 and G2 test it against the real emulator.
- macOS may differ from the Linux recipe in G1: the `--` separator, the missing auto-boot, and the `SIGTERM` behavior are observed on Linux only. G2 checks each one.
- The duplicate filter (F18) can hide repeated log lines. A log expectation must not depend on a line count.
- An early stop observes only the part of the run before the stop. `--reject-*` conditions are evaluated on that part.
- Log lines written just before the stop can be lost (A9, R8). The verdict rules therefore never require a boot-launch log line. The install wait reads its log line while the emulator still runs, so it is not affected.
- Excluded: renderer selection flags, input injection, save-state handling, title deletion, parallel instances, and a real-emulator test in the unit suite. No fixture VPK is committed to this repository.
