# Choosing expectations and reading the result

Verified against `Vita3K v0.2.1 4111-ab71f829` on 2026-10-02 with the bevypoc fixture on headless aarch64 Linux and on macOS (Apple silicon). Log strings in this file were observed in real runs.

The script never infers that an app works. You tell it what success looks like, and it reports whether that happened during this run.

## Evidence channels

| Channel | Where in the result | What it proves | What it cannot prove |
| --- | --- | --- | --- |
| Emulated filesystem diff | `fs_diff`, `expectations`, copies under `<run_dir>/evidence/` | The app wrote or changed a file during the boot launch. | Anything about a file the app did not write. A file that an earlier run left behind is never evidence. |
| Log summary | `log_summary`, full text in `paths.boot_stdout` | What the emulator and the app printed during the boot launch. | Absence. Lines written just before the stop can be lost. |
| Screenshot | `paths.screenshot` | What the display showed at the end of the run, on headless Linux only. | Anything on macOS or on a Linux host with its own display: no screenshot is taken there. |

Rules for the filesystem diff:

- `fs_diff` covers `ux0:` outside `ux0:app`. Every run reinstalls the title under `ux0:app`, so a write there is visible only through an explicit `--expect-file` or `--expect-file-contains` for that path.
- Other devices, such as `ur0:`, are not examined.
- The before-snapshot is taken after the install and before the boot, so the diff covers the boot launch only.
- A file is **fresh** when it is in `created` or `modified`. `modified` means a changed modification time, size, or content hash.
- For a file that grew and still starts with its old bytes, only the appended bytes are fresh content. A line from an earlier run does not satisfy `--expect-file-contains`.
- `emulator_owned` lists files that Vita3K writes by itself (`ux0/user/time.xml`, `ux0/user/<NN>/user.xml`). They are not app evidence.
- A file larger than 16 MiB is not hashed. It is reported with `sha256: null`, and the result carries warning `large_file_unhashed`.

## Result fields

| Field | Content |
| --- | --- |
| `schema_version` | `1`. |
| `verdict` | `pass`, `fail`, `inconclusive`, or `environment_error`. |
| `reason` | A code, or `null` for `pass`. See the failure classes below. |
| `warnings` | `stopped_early`, `emulator_exited_early`, `screenshot_failed`, `orphan_cleaned`, `large_file_unhashed`. |
| `host` | `os`, `arch`, `display_mode`. |
| `emulator` | `path`, `version`, `sha256`. The version is null when the version probe failed. |
| `vpk` | `path`, `sha256`, `title_id`, `eboot_sha256`. |
| `stages` | `installed`, `install_logged`, `eboot_matches`, `install_exit_code` for the install launch. `emulator_exit_code`, `emulator_signal`, `seconds_running` for the boot launch. |
| `expectations` | One entry per condition: `kind`, `target`, `satisfied`, `detail`. For a `reject-*` condition, `satisfied` is true when the rejected thing did not happen. |
| `fs_diff` | `created`, `modified`, `deleted`, `emulator_owned`. Each is a list of entries: path, size, and SHA-256 for a created or modified file, the path for a deleted file, and the path with the kind of change for an emulator-owned file. |
| `log_summary` | `source`, `line_count`, `levels`, `errors` (first 20 error and critical lines), `tty` (app output lines, up to 200), `tail` (last 40 lines). Null when the run stopped before any launch. |
| `paths` | `run_dir`, `vita_fs`, `log_copy`, `install_stdout`, `boot_stdout`, `screenshot`. An entry is null when the run did not produce that file. |
| `started_at`, `finished_at` | UTC timestamps. |

When `paths.run_dir` is set, the same document is in `<run_dir>/result.json`, and the run directory also holds the tested copy of the VPK. The script keeps the newest 20 run directories.

The script stops the emulator with a signal at the end of every normal run, so `emulator_signal` 9 or 15 without reason `emulator_crashed` is the script's own stop. Vita3K ignores `SIGTERM` while an app runs, and on macOS it ignored it in the install launch too. In a healthy macOS run both `install_exit_code` and `emulator_exit_code` are therefore -9.

## Choosing expectations

1. Search the project for writes to `ux0:` and for output on stdout or stderr at startup.
2. Prefer a file whose content identifies the build, for example a source SHA. Pass it with `--expect-file-contains`.
3. Add `--reject-log` for the project's own error strings.
4. Use `--seed` for files the app reads at startup, and `--clean` for evidence directories that must start empty.
5. When the app leaves no file and no log line, only `inconclusive` is possible. Say so, and propose that the project add a startup breadcrumb. Do not add the breadcrumb as part of this skill.

With `--stop-when-satisfied` the run ends once the expectations have held for the settle period. A failure that comes later is not observed. Use the full timeout when a late failure matters.

## Project patterns

| Project type | Build output | Typical evidence | Status |
| --- | --- | --- | --- |
| Rust with `cargo-vita` (bevypoc) | `target/armv7-sony-vita-newlibeabihf/release/<bin>.vpk` | `ux0:data/bevypoc/build.txt` contains the source SHA. `ux0:data/bevypoc/server.txt` is an input file: seed it with `--seed`. Without it the log repeats `*** TTY: SpacetimeDB unavailable: ` and the screen shows `ERR`. | Exercised on headless aarch64 Linux and on macOS. |
| Rust with `cargo-vita` (vitair) | same layout, `vitair-app.vpk` | `ux0:data/vitair/startup.log` gains lines of the form `<source SHA> <message>`. The file is append-only, so an expectation matches appended lines only. The on-screen `ux0:` listing needs the screenshot. vitair's README requires firmware in Vita3K. | not exercised |
| Nim with a VitaSDK script (clckr spike) | path set by the project's `scripts/build_vita.sh` | Breadcrumb file `ux0:data/clckr_vita_spike.txt`. The last line names the last step reached. | not exercised |
| Nim with a network client (topdown) | same | Host `127.0.0.1` reaches a server on the same machine only inside the emulator. | not exercised |

Example for bevypoc, where `<sha>` is the source commit that the build script prints:

```text
python3 <skill-dir>/scripts/vita3k_vpk.py run target/armv7-sony-vita-newlibeabihf/release/bevypoc.vpk \
  --expect-file-contains ux0:data/bevypoc/build.txt=<sha> --stop-when-satisfied
```

## Reading the log

`paths.boot_stdout` (`emulator-stdout.log`) is the log to read. It is the emulator's captured stdout. `vita3k.log` lags far behind and is often short or empty, so its copy is secondary.

- Line format: `[HH:MM:SS.mmm] |L| [function]: message`. `L` is one of `T` (trace), `D` (debug), `I` (info), `W` (warning), `E` (error), `C` (critical).
- Vita3K suppresses identical messages repeated within two seconds. Never depend on a line count.
- App stdout and stderr appear as `*** TTY: <text>` lines. One print call becomes several lines, so a pattern must match one fragment. bevypoc prints `bevypoc source commit: <sha>`, and the log holds `*** TTY: bevypoc source commit: ` and `*** TTY: <sha>` as separate lines. Match the SHA line: `--expect-log '\*\*\* TTY: <sha>'`.
- Boot markers: `App session phase: Launching -> Running` and `Game started: <title> (<TITLE_ID>)`.
- Every file access is logged. `Missing file at "<host path>" (target path: ux0:...)` shows a file that the app tried to read and did not find.
- Error-level lines occur in healthy runs: the `os0:kd/*.skprx` lines without firmware, and at least one `Missing file at` line for every file that the app probes and does not find. Never use the presence of `|E|` lines as a failure signal. Log severity never changes the verdict.
- Lines without a timestamp (Qt, Mesa, MoltenVK, and other library output) are noise. They count as level `?`. On macOS MoltenVK prints most of them: `[mvk-info] …` and a tab-indented list of Vulkan extensions. In a passing run 191 of 208 lines of the install launch and 387 of 472 lines of the boot launch were noise.
- The install launch logs `Content installed, will auto-boot: <TITLE_ID>` and does not boot. That is why the script makes a second launch.

## Failure classes

| Signature in the result | Meaning | Next action |
| --- | --- | --- |
| `environment_error`, reason `privileged_user` | The script ran as root or with differing real and effective user IDs. | Run as a normal user. |
| `environment_error`, reason `emulator_missing` | No Vita3K executable in the instance, and on Linux none named `Vita3K` on `PATH`. | Follow [install.md](install.md), then run `doctor`. |
| `environment_error`, reason `isolation_unavailable` | macOS: the emulator is not the instance's own `Vita3K.app` with `portable/` beside it. | Follow the macOS section of [install.md](install.md). |
| `environment_error`, reason `instance_busy` | Another run holds the instance. | Wait for it. One run at a time. |
| `environment_error`, reason `display_failed` | `Xvfb` is missing or did not start. | Ask the user to install the host package. |
| `environment_error`, reason `emulator_start_failed` | The emulator executable could not be started at all. | Check the file and its mode. Reinstall it. |
| `environment_error`, reason `install_failed` | The install launch did not complete within 30 seconds. An install is complete when the emulator has logged it (`stages.install_logged`) and the installed `eboot.bin` has the bytes of the VPK's (`stages.eboot_matches`). `log_summary` then holds the install log. | Read the two stage values and `log_summary.tail`. An emulator that cannot load its libraries ends here: a loader error that names `GLIBC_2.43` means the Vita3K build is too new for the host. |
| `environment_error`, reason `isolation_violated` | A personal Vita3K path appeared, disappeared, or changed its modification time during the run: a personal Vita3K ran at the same time, or the emulator ignored the isolation settings. | Rerun with the personal Vita3K closed. If it repeats, treat it as an emulator change and stop. |
| `environment_error`, reason `isolation_unverified` | The emulator did not write its log inside the instance. | Treat it as an emulator change. Stop and report. |
| `environment_error`, reason `interrupted` | The script was signalled. | Rerun. |
| `environment_error`, reason `internal_error` | The script failed unexpectedly. The traceback is on stderr. | Report it. It says nothing about the app. |
| `fail`, reason `emulator_crashed` | In the boot launch the emulator ended by itself with a non-zero status, for example 139 for a segmentation fault. | Read `stages.emulator_exit_code`, `stages.emulator_signal`, and the log tail before blaming the app. The cause can be the app or the emulator. |
| `fail`, reason `reject_matched` | A `--reject-log` pattern matched, or a `--reject-file` path is fresh. | Read the matching entry in `expectations`. |
| `fail`, reason `expectation_unmet` | An `--expect-*` condition did not hold. | Read each `detail`. See the rows below. |
| `inconclusive`, reason `no_expectations` | The run had no `--expect-*` condition. | Choose expectations and rerun. Never report this as success. |
| Expectation `detail` is `missing` | The file does not exist. The app never wrote it. | Check the path, then read the log for what the app did. |
| Expectation `detail` starts with `stale`, or says `text not found in fresh content (appended bytes)` | Evidence from an earlier run. The app did not write it this time. | Treat it as a failure to produce evidence. |
| Install succeeded, no fresh files, error lines in the log | The app failed or stalled before it wrote its evidence. | Read `log_summary.errors` and `log_summary.tty`. |
| Install succeeded, the log shows missing modules or unimplemented imports | An emulator limitation or missing firmware. | Not an app defect until proven on hardware. Consider the firmware section of [install.md](install.md). |
| A network-dependent expectation is unmet | The app could not reach its server. | Check the seeded server address and that the host service runs. |
| Warning `emulator_exited_early` | The emulator ended by itself with status 0 before the timeout. | Expectations are still evaluated. Check whether the app is meant to exit. |

## Limits

- Emulator results never prove device behavior. Say so in every report.
- Software rendering on headless Linux is slow and changes timing.
- Controller and touch input are unavailable.
- No screenshot on macOS or on a Linux host with its own display.
- A user who runs a personal Vita3K during a run can trigger `isolation_violated`.
