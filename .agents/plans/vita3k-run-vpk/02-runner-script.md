# 02 — Runner script (WP2, WP3)

Covers **WP2** (host-independent core) and **WP3** (launch lifecycle). Terms are defined in [00-overview.md](00-overview.md). The gate record `G1.md` is defined in [01-fixture-and-headless-gate.md](01-fixture-and-headless-gate.md).

All names in this file are **proposed** unless a finding marks them as existing.

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

Gate-derived constants (D14): the headless renderer profile (settings, environment, and required driver files as glob patterns), the default timeout, the kill grace period, the authoritative log source, the stdout capture method (plain redirect or pseudo-terminal), the stale-mount cleanup command, the screenshot decision, and the `eboot_matches` policy are constants in the script. The implementer copies their values from `G1.md`. The script never reads a file under `.agents/plans/`.

## Command contract

```text
python3 <skill-dir>/scripts/vita3k_vpk.py doctor
python3 <skill-dir>/scripts/vita3k_vpk.py run <vpk> [options]
```

Both commands print exactly one JSON document on stdout. Diagnostics go to stderr.

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

### `run` options

| Option | Meaning |
| --- | --- |
| `--timeout SECS` | Maximum run time after launch. Default: the constant from G1. |
| `--stop-when-satisfied` | Stop once every `--expect-*` condition has held for the settle period. Without it, the run lasts the full timeout. |
| `--settle SECS` | Settle period for `--stop-when-satisfied`. Default 5. |
| `--seed HOST_FILE=ux0:PATH` | Copy a host file into the emulated filesystem before launch. Repeatable. |
| `--clean ux0:PATH` | Delete a file or directory in the emulated filesystem before launch. Repeatable. |
| `--expect-file ux0:PATH` | The file must be fresh (D4) after the run. Repeatable. |
| `--expect-file-contains ux0:PATH=TEXT` | The file must be fresh and its fresh content must contain `TEXT`. Repeatable. |
| `--expect-log REGEX` | At least one log line must match. Repeatable. |
| `--reject-log REGEX` | No log line may match. Repeatable. |
| `--reject-file ux0:PATH` | The file must not be fresh after the run. Repeatable. |
| `--display auto\|xvfb\|host` | `auto`: `host` on macOS and when `DISPLAY` or `WAYLAND_DISPLAY` is set, otherwise `xvfb`. |
| `--no-screenshot` | Skip the screenshot even when the script owns the display. |

Argument splitting: `--expect-file-contains` splits at the first `=`. A `ux0:` path must not contain `=`. `--seed` splits at the last occurrence of `=ux0:`.

No option changes the renderer. The renderer profile is the G1 constant on headless Linux and Vita3K's default on a host display.

## WP2 — Host-independent core

Goal: every piece of logic that does not start a process, with unit tests. Prerequisite: none. WP2 may start before WP1. G1 check 8 needs `xwd_to_png` from this work package.

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

Order, first existing executable wins:

1. `VITA3K_BIN`.
2. Linux: `emulator/squashfs-root/AppRun`, then `emulator/Vita3K.AppImage`, then `emulator/Vita3K-aarch64.AppImage`, then `emulator/Vita3K-x86_64.AppImage`, then `Vita3K` on `PATH`.
3. macOS: `emulator/Vita3K.app/Contents/MacOS/Vita3K`.

macOS rule: the resolved binary must be at `<dir>/<name>.app/Contents/MacOS/<file>`, `<dir>` must equal the instance's `emulator/` directory, and `<dir>/portable/` must exist. Otherwise return `environment_error` with reason `isolation_unavailable`. Never fall back to `/Applications/Vita3K.app`. Reason: F16 and D3.

Adjust the Linux order to the binary form that `G1.md` records.

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

If `G1.md` records that a minimal file is not accepted, WP3 adds one emulator invocation that generates the default file before the upsert. The upsert logic stays the same.

### Snapshot and diff

- A snapshot walks all of `<vita_fs>/ux0/` except `<vita_fs>/ux0/app/`, plus every path named by an expectation. It does not follow symlinks. `ux0/app/` is excluded because every run reinstalls the title there. An expectation may still name a path under `ux0:app`.
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
- `log_summary` contains: the source name, line count, count per level, the first 20 `E` and `C` lines, every line containing `*** TTY: ` up to 200 lines, and the last 40 lines.
- Lines that do not match the pattern count as level `?` and stay available to regex expectations.
- Regex expectations use `re.search` per line against the authoritative log source (D13).

### XWD conversion

`xwd_to_png` reads the XWD version-7 header (big-endian 32-bit fields), skips the header remainder and the colormap, and reads ZPixmap rows of 24 or 32 bits per pixel using the header's byte order, bytes per line, and channel masks. It writes an 8-bit RGB PNG with `zlib` and `struct`. It raises a specific error for any other format.

### Verdict evaluation

Precedence, first match wins:

1. `environment_error`: any lifecycle failure listed in WP3.
2. `fail` with reason `emulator_crashed`: after a successful install, the emulator ended by itself with a non-zero exit code or from a signal that the script did not send.
3. `fail`: any `--reject-log` match or fresh `--reject-file`.
4. `fail`: any unmet `--expect-*` condition.
5. `pass`: at least one `--expect-*` condition exists and all hold.
6. `inconclusive`: no `--expect-*` condition exists.

Rule 2 does not separate an app defect from an emulator defect. The result reports the exit code or signal, and `references/evidence.md` tells the agent to read the log tail before blaming the app.

Log severity never changes the verdict by itself. Error and critical lines appear in `log_summary` for the agent to judge.

### Result document

One JSON object. Field names are **proposed**:

```text
schema_version      1
verdict             pass | fail | inconclusive | environment_error
reason              short machine-readable code, or null
warnings            list of codes: emulator_exited_early, stopped_early,
                    screenshot_failed, eboot_differs, orphan_cleaned, large_file_unhashed
host                {os, arch, display_mode}
emulator            {path, version, sha256}
vpk                 {path, sha256, title_id, eboot_sha256}
stages              {installed: bool, install_logged: bool, eboot_matches: bool,
                    emulator_exit_code, emulator_signal, seconds_running}
expectations        list of {kind, target, satisfied, detail}
fs_diff             {created, modified, deleted}
log_summary         see above
paths               {run_dir, vita_fs, log_copy, stdout_capture, screenshot or null}
started_at, finished_at   RFC 3339 UTC
```

The same object is written to `<run_dir>/result.json`. An expectation `detail` never contains the content of a seeded host file.

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
17. Python 3.9 syntax: `ast.parse(source, feature_version=(3, 9))` succeeds for the script and every test file. A source scan finds no `match ` statement at line start, no `strict=`, and no `datetime.UTC`. This check covers syntax only. Full 3.9 behavior is proven at G2.

Create the XWD fixture once, on this host: start `Xvfb` with a `64x48x24` screen, run `xsetroot -solid '#336699'` (present on this host), and run `xwd -root -silent`. The expected pixel is RGB `(0x33, 0x66, 0x99)`. The file is about 12 KiB.

WP2 acceptance: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .agents/skills/vita3k-run-vpk/tests -p 'test_core.py'` exits 0.

## WP3 — Launch lifecycle

Goal: `run` and `doctor` work end to end. Prerequisites: WP2 complete, G1 decided as go, and `G1.md` complete before any WP3 code is written. Implement the recipe that `G1.md` records. Where `G1.md` contradicts this section, `G1.md` wins, and the implementer records the difference in the skill references.

### `run` sequence

```text
1  parse arguments, privilege check, inspect VPK     → exit 2 or privileged_user
2  resolve instance and binary                       → emulator_missing, isolation_unavailable
3  take run.lock (non-blocking flock)                → instance_busy
4  clean up orphans named in run-state.json
5  create run_dir = runs/<UTC yyyymmddThhmmssZ>-<TITLE_ID>/, copy VPK to run_dir/<TITLE_ID>.vpk
6  record personal Vita3K paths (existence, mtime_ns)
7  emulator version: read cache or probe
8  seed config, remove ux0/app/<TITLE_ID>/, apply --clean, apply --seed
9  snapshot (before)
10 display: start Xvfb when mode is xvfb             → display_failed
11 launch emulator with the VPK copy, stdout+stderr → run_dir/emulator-stdout.log;
   write process group IDs to run-state.json
12 wait loop (poll once per second)
13 screenshot when the script owns the display
14 stop emulator, then stop Xvfb; clear run-state.json
15 snapshot (after), diff
16 copy log and fresh evidence files into run_dir
17 isolation checks, stage checks, verdict
18 write result.json, print it, prune old run directories, release lock
```

Details:

- **Step 4, orphans.** `run-state.json` holds, for the emulator and for Xvfb of the last run: the process ID, the process group ID, and the start time string that `ps -o lstart= -p <pid>` printed right after launch. `ps -o lstart=` works on Linux and macOS. When the lock was free and a recorded process still exists with the same start time string, a previous script died without cleanup. Send `SIGTERM` to its process group, wait the kill grace constant, and send `SIGKILL`. Add warning `orphan_cleaned`. When the start time differs or the process is gone, the ID was reused or the process ended: do not signal it. Then run the stale-mount cleanup constant when it is not `none`, and remove the state file.
- **Step 7, version.** `version_cache` stores the version string keyed by binary path, size, and `mtime_ns`. On a miss, probe with the method that `G1.md` records for check 1, in the same isolation environment as the launch, with a 20-second timeout. A failed probe sets `version` to `null`. The probe runs only while the lock is held, because every Vita3K start truncates `vita3k.log` (F18).
- **Step 8, app directory.** Delete `<vita_fs>/ux0/app/<TITLE_ID>/` before launch, without following symlinks. Vita3K removes and reinstalls this directory itself (F13). Deleting it first makes the install stage decidable from the filesystem alone.
- **Step 10.** Start `Xvfb -displayfd <fd> -screen 0 1280x800x24 -nolisten tcp` (D6). Read the display number from the descriptor. Fail after 10 seconds without one.
- **Step 11, capture.** Capture stdout and stderr with the method constant from G1: a plain file redirect, or a pseudo-terminal whose output the script copies to `emulator-stdout.log`.
- **Step 11.** Start the emulator in its own process group. Linux environment: the three `XDG_*` variables (D3) plus the renderer environment constant. macOS environment: unchanged. Arguments: the absolute path of the VPK copy, plus only what `G1.md` records. Pass arguments as a list.
- **Step 12.** The loop ends when the timeout elapses or when the emulator exits. With `--stop-when-satisfied`, it also ends when every expectation has held continuously for the settle period. An early stop adds warning `stopped_early`. Evaluate file expectations against a fresh snapshot of the expectation paths. Evaluate log expectations against the authoritative log source.
- **Step 13.** Run `xwd -root -silent -display :N` and convert with `xwd_to_png`. Any failure adds warning `screenshot_failed` and never changes the verdict. Skip this step when the screenshot decision constant is `drop`.
- **Step 14.** Send `SIGTERM` to the process group. Wait the kill grace constant. Then send `SIGKILL`. Always stop Xvfb. Run step 14 and the lock release in a `finally` path, and also on `SIGINT` and `SIGTERM` to the script.
- **Step 16.** Copy `log_file` to `run_dir/vita3k.log`. Copy each fresh file named by an expectation, and each created file up to 1 MiB, to `run_dir/evidence/` with its `ux0`-relative path. Limit the copy to 50 files.
- **Step 17, isolation checks.** Two checks. First, `log_file` at the instance path must be fresh for this run. Otherwise return `environment_error` with reason `isolation_unverified`. Second, each personal Vita3K path must have the same existence and `mtime_ns` as recorded in step 6. Otherwise return `environment_error` with reason `isolation_violated`. Reason: R3. A user who runs a personal Vita3K during the run triggers the second check. `references/evidence.md` states this.
- **Step 17, stage checks.** `installed` is true when `<vita_fs>/ux0/app/<TITLE_ID>/eboot.bin` exists after the run. Step 8 deleted the directory, so an existing file was written by this run. `install_logged` is true when either log source contains `Content installed, will auto-boot: <TITLE_ID>` (F12). It is informational and never changes the verdict. `eboot_matches` is true when the installed file has the SHA-256 of the VPK's `eboot.bin`. When `installed` is false, return `environment_error` with reason `install_failed`. When `eboot_matches` is false, apply the G1 policy constant (A7): return `install_failed` when G1 observed identical bytes, otherwise add warning `eboot_differs`.
- **Emulator exit before the loop ends.** When `installed` is false, the stage check reports `install_failed`. When `installed` is true and the exit code is 0, add warning `emulator_exited_early` and continue to the verdict rules. When `installed` is true and the exit code is non-zero or the process died from a signal, verdict rule 2 applies.
- **Step 18, pruning.** After the result is written, keep the newest 20 run directories. Consider only direct children of `runs/` that are real directories (checked with `os.lstat`) and whose names match `^\d{8}T\d{6}Z-[A-Z0-9]{9}$`. Never delete the current run directory. Never follow a symlink.

### Lifecycle failure codes

`privileged_user`, `emulator_missing`, `isolation_unavailable`, `instance_busy`, `display_failed`, `emulator_start_failed`, `install_failed`, `isolation_unverified`, `isolation_violated`. Each returns exit 3 and a `reason`. `emulator_start_failed` means that process creation for the emulator raised an error. An emulator that starts and then ends without installing is `install_failed`.

### `doctor`

Output fields (**proposed**): `ready` (bool), `host`, `instance_root`, `emulator` (`path`, `version`, `sha256`, or `null`), `paths` (the `InstancePaths` values), `firmware` (`main`: `vs0/` has content, `font`: `sa0/` has content, per F20), `headless` (`needed`, `xvfb`, `xwd`, `renderer_files`), `problems` (list of `{code, detail, fix}`).

- `ready` is false when the user is privileged (D12), when the emulator is missing, when macOS isolation is unavailable, when the display mode would be `xvfb` and `Xvfb` is missing, or when the display mode would be `xvfb` and no file matches a driver-file glob pattern of the renderer profile constant (for example `/usr/share/vulkan/icd.d/lvp_icd*.json`).
- A missing `xwd` or missing firmware is a problem entry that does not clear `ready`.
- Each `fix` names the section of `references/install.md` to follow.
- Version: read `version_cache`. On a miss, take the lock without blocking and probe as in `run` step 7. On macOS the probe is the plain `--version` invocation, unverified until G2. The 20-second timeout kills a probe that does not exit. When the lock is busy, macOS isolation is unavailable, or the probe fails, skip or abandon the probe and report `version: null` with a problem entry that does not clear `ready`.
- The version probe starts Vita3K, so it creates the instance's config, cache, and data directories and truncates the instance's `vita3k.log`. `doctor` changes nothing outside the instance and never downloads or installs anything.
- `doctor` prints the binary's SHA-256 so it can be compared with the release asset digest (F10).

### Stub emulator (`tests/stub_vita3k.py`)

A Python script, selected through `VITA3K_BIN`, that mimics the observable contract and nothing else. It resolves its paths the way Vita3K does: when a `portable/` directory exists beside the app bundle that contains it (F16), it uses that layout. Otherwise it uses the `XDG_*` variables (F15). It truncates the log file at start (F18). Behavior is chosen by environment variable `STUB_MODE`:

| Mode | Behavior |
| --- | --- |
| `ok` | Unzip the VPK to `ux0/app/<TITLE_ID>/`, write the two F12 log lines to the log file and stdout, write `ux0/data/stub/out.txt` and `ux0/temp/stub.tmp`, then sleep until signalled. |
| `no_evidence` | As `ok` without writing `out.txt`. |
| `append` | As `ok`, and append one line to `ux0/data/stub/startup.log`. |
| `late_error` | As `ok`, and write an error log line 3 seconds after `out.txt`. |
| `install_fail` | Write a log line, install nothing, exit 1. |
| `exit_early` | As `ok`, then exit 0 after one second. |
| `crash` | As `ok`, then end with `SIGSEGV` after one second. |
| `stale_app` | Write the log lines and install nothing, then sleep. Used with a pre-created `ux0/app/<TITLE_ID>/eboot.bin`. |
| `ignore_term` | As `ok`, and ignore `SIGTERM`. |
| `wrong_paths` | As `ok`, but write the log outside the instance. |
| `touch_personal` | As `ok`, and create a file under the personal Vita3K path of a temporary `HOME`. |
| `version` | Reached through `--version`: print a version string and exit 0. |

The stub writes its received environment and arguments to a file named by `STUB_RECORD`, so tests can assert the isolation environment and the argument list.

### WP3 tests (`tests/test_run.py`)

Run the script as a subprocess with `--display host`, a temporary `VITA3K_AGENT_HOME`, a temporary `HOME`, and short timeouts. A test helper builds the instance for the host under test: on Linux the stub is `VITA3K_BIN`. For the macOS layout the helper copies the stub to `emulator/Vita3K.app/Contents/MacOS/Vita3K`, creates `emulator/portable/`, and sets `VITA3K_VPK_HOST=darwin`. Run tests 1–4 in both layouts on every host.

1. `ok` with `--expect-file-contains ux0:data/stub/out.txt=<text>` → exit 0, verdict `pass`, `fs_diff.created` lists the file, `run_dir/result.json` equals stdout.
2. `ok` with no expectation → exit 4, verdict `inconclusive`.
3. `no_evidence` with `--expect-file ux0:data/stub/out.txt` → exit 1, verdict `fail`.
4. Stale evidence: create `ux0/data/stub/out.txt` before the run, use `no_evidence` → verdict `fail`. This proves S2 for whole files. A file that the stub writes under `ux0/temp/` appears in `fs_diff.created`. Files under `ux0/app/` do not appear in `fs_diff`.
5. Stale appended evidence: pre-create `startup.log` containing the expected line, run `append` with a different line, expect the old line → verdict `fail`. Expect the new line → verdict `pass`.
6. `ok` with `--reject-log` matching a stub log line → verdict `fail`.
7. `late_error` with `--stop-when-satisfied --settle 5` and `--reject-log` for the error line → verdict `fail`. The same with `--settle 0` → verdict `pass` with warning `stopped_early`. This documents what an early stop can and cannot observe.
8. `install_fail` → exit 3, reason `install_failed`.
9. `exit_early` with a satisfied expectation → verdict `pass` with warning `emulator_exited_early`. `crash` with the same satisfied expectation → exit 1, verdict `fail`, reason `emulator_crashed`. `crash` with no expectation → verdict `fail`, not `inconclusive`.

   `stale_app` with a pre-created `ux0/app/<TITLE_ID>/eboot.bin` → exit 3, reason `install_failed`, although the stub logged the install line. This proves that a stale install and a log line cannot fake the install stage.
10. `ignore_term` → the script returns within the grace period plus kill time, and no stub process remains.
11. `wrong_paths` → exit 3, reason `isolation_unverified`.
12. `touch_personal` → exit 3, reason `isolation_violated`.
13. Second concurrent run while the first holds the lock → exit 3, reason `instance_busy`.
14. Orphan cleanup: start a run with `ok`, send `SIGKILL` to the script, confirm the stub survives, start a second run → the second run kills the orphan, reports warning `orphan_cleaned`, and returns a correct verdict. A `run-state.json` that names a live unrelated process with a different start time → that process is not signalled.
15. `--seed` places the file before launch. `--clean` removes a stale directory before the snapshot.
16. A VPK named `build output.bin` (space, wrong extension) runs. The stub's recorded argument is `<run_dir>/<TITLE_ID>.vpk`.
17. The stub's recorded environment has all three `XDG_*` variables inside the instance (Linux layout).
18. Pruning: with 21 matching run directories, a symlink, and a directory named `keep-me` in `runs/`, one matching directory is deleted, and the symlink, its target, and `keep-me` survive.
19. `VITA3K_BIN` pointing to a missing file → exit 3, reason `emulator_missing`. `doctor` in the same state → exit 3 with a problem entry.
20. `doctor` with the stub present → exit 0, the `paths` values match `InstancePaths`, the version string comes from the stub, and a second `doctor` call reads it from the cache without starting the stub.
21. Log parsing of `tests/fixtures/vita3k-sample.log` yields the level counts and install line that the fixture contains. This ties the parser to real Vita3K output.

Tests that need `Xvfb` must skip with a clear message when `Xvfb` is absent. Add one such test: `--display xvfb` with the `ok` stub produces `paths.screenshot` with the PNG signature and the Xvfb screen dimensions, and leaves no `Xvfb` process.

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

- The stub proves script logic only (D11). A green test suite does not prove that Vita3K boots a VPK. The stub encodes this plan's reading of F12, F15, F16, and F18. WP5 and G2 test that reading against the real emulator.
- The duplicate filter (F18) can hide repeated log lines. A log expectation must not depend on a line count.
- An early stop observes only the part of the run before the stop. `--reject-*` conditions are evaluated on that part.
- Log lines written just before the stop can be lost (A9, R8). The verdict rules therefore never require a log line.
- Excluded: renderer selection flags, input injection, save-state handling, title deletion, parallel instances, and a real-emulator test in the unit suite. No fixture VPK is committed to this repository.
