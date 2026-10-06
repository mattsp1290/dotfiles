---
name: vita3k-run-vpk
description: Run a built PS Vita VPK in the Vita3K emulator and inspect the emulated filesystem and the emulator log for evidence of success or failure. Use after building a VPK to check that it installs, boots, and shows the runtime behavior the project expects. Do not use it to build a VPK or to claim physical-device behavior. Requires Python 3.9 or newer and Vita3K; install instructions for Vita3K are included.
---

# Vita3K Run VPK

Run one built `.vpk` in a dedicated Vita3K instance and judge the result from evidence: files the app wrote under `ux0:`, the emulator log, and a screenshot on headless Linux. The helper script decides nothing by guesswork. You state what success looks like, and it reports whether that happened.

The instance is one directory, `$VITA3K_AGENT_HOME` (default `$HOME/.vita3k-agent`). It holds the skill's own copy of the emulator with its config, log, and emulated filesystem. A file is **fresh** when the boot launch of this run created or changed it.

## Workflow

1. Resolve this skill's directory from the loaded `SKILL.md`. The script is `scripts/vita3k_vpk.py` in that directory.
2. Locate the VPK. Build it with the project's own build script when it is missing or older than the source. Build output is expected. Never bypass a project's clean-tree check.
3. Run `doctor`. When `ready` is false, read each entry of `problems`, follow the section of [references/install.md](references/install.md) that its `fix` names, and run `doctor` again.
4. Derive expectations from the project before running. Read [references/evidence.md](references/evidence.md).
5. Run `run` with the expectations. Add `--seed` for input files the app reads and `--clean` for evidence that must not carry over from an earlier run.
6. Read the JSON result. `pass`: go to the report. `fail` or `inconclusive`: read the files under `paths.run_dir` and the matching row of the failure classes in [references/evidence.md](references/evidence.md). `environment_error`: take the next action of its row, then rerun. Never report an `environment_error` as an app failure.
7. Report the verdict, the VPK SHA-256, the emulator version, and the evidence that supports the verdict.

## Commands

```text
python3 <skill-dir>/scripts/vita3k_vpk.py doctor [--display auto|xvfb|host]
python3 <skill-dir>/scripts/vita3k_vpk.py run <vpk> [options]
```

Both commands print exactly one JSON document on stdout. Diagnostics go to stderr. A usage error prints its message to stderr and leaves stdout empty.

`doctor` prints `ready` (true or false), `emulator` (`path`, `version`, `sha256`), `firmware`, `headless`, and `problems`. Each entry of `problems` has `code`, `detail`, and `fix`. `fix` names the section of `references/install.md` to follow, or the action to take.

| `doctor` problem | Clears `ready` | Meaning |
| --- | --- | --- |
| `emulator_missing` | yes | No Vita3K in the instance, and on Linux none on `PATH`. Install it. |
| `isolation_unavailable` | yes | macOS: the emulator is not the instance's own app bundle with `portable/` beside it. |
| `version_probe_failed` | yes | The emulator did not start. `detail` holds its last output lines. |
| `xvfb_missing` | yes | A host without a display needs `Xvfb`. Ask the user to install it. |
| `privileged_user` | yes | Run as a normal user. |
| `interrupted` | yes | The script was signalled during the version probe. Run `doctor` again. |
| `xwd_missing` | no | Runs work and produce no screenshot. |
| `firmware_missing` | no | Optional. Most homebrew boots without firmware. |
| `instance_busy` | no | A run holds the instance, so the version probe was skipped. Wait, then run `doctor` again. Install nothing for it. |

Each `run` makes two emulator launches: one installs the VPK, the next boots the installed title. `--timeout`, the expectations, and the log summary refer to the boot launch.

### `run` options

| Option | Meaning |
| --- | --- |
| `--timeout SECS` | Maximum run time of the boot launch. Default 60. |
| `--stop-when-satisfied` | Stop once every `--expect-*` condition has held for the settle period. Needs at least one `--expect-*` option. |
| `--settle SECS` | Settle period for `--stop-when-satisfied`. Default 5. |
| `--seed HOST_FILE=ux0:PATH` | Copy a host file into the emulated filesystem before the launches. Splits at the last `=ux0:`. A seeded file is input: it counts as fresh only when the app changes it. Repeatable. |
| `--clean ux0:PATH` | Delete a file or directory in the emulated filesystem before the launches. `--clean` runs before `--seed`. Only `ux0:data/<name>...` and the VPK's own `ux0:user/00/savedata/<TITLE_ID>...` are accepted. `<TITLE_ID>` is `vpk.title_id` in any earlier result. Repeatable. |
| `--expect-file ux0:PATH` | The file must be fresh after the run. Repeatable. |
| `--expect-file-contains ux0:PATH=TEXT` | The file must be fresh and its fresh content must contain `TEXT`, a plain substring. Splits at the first `=`. Repeatable. |
| `--expect-log REGEX` | At least one log line must match the Python regular expression. Repeatable. |
| `--reject-log REGEX` | No log line may match. Repeatable. |
| `--reject-file ux0:PATH` | The file must not be fresh after the run. Repeatable. |
| `--display auto\|xvfb\|host` | `auto` uses the host display on macOS and when `DISPLAY` or `WAYLAND_DISPLAY` is set. Otherwise the script starts its own `Xvfb`. On macOS the emulator opens a window, so it needs a logged-in desktop session. `doctor` takes the same option. |
| `--no-screenshot` | Skip the screenshot even when the script owns the display. |

A run without `--stop-when-satisfied` lasts the full timeout, unless the emulator exits first. Log expectations read the boot launch only, one line at a time. The install launch's output is never matched.

Choosing `--timeout`: start with the default. With `--stop-when-satisfied` a healthy run ends as soon as its expectations have held for the settle period, so a larger timeout costs nothing. When a run fails with `expectation_unmet` and `stages.seconds_running` reached the timeout, rerun once with three to four times the timeout before calling it an app failure. Software rendering on headless Linux is slow.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | `doctor`: ready. `run`: verdict `pass`. |
| 1 | `run`: verdict `fail`. |
| 2 | Usage error: bad arguments, unreadable VPK, rejected path. |
| 3 | `run`: verdict `environment_error`. `doctor`: not ready. |
| 4 | `run`: verdict `inconclusive`. |

### Environment variables

| Variable | Meaning |
| --- | --- |
| `VITA3K_AGENT_HOME` | Instance root. Default `$HOME/.vita3k-agent`. |
| `VITA3K_BIN` | Emulator executable. Overrides discovery. Without it the script looks in the instance's `emulator/` directory, and on Linux, as a last resort, for `Vita3K` on `PATH`. |

## Invariants

- A `pass` needs at least one `--expect-*` condition. With `--reject-*` conditions alone, a match gives `fail` and no match gives `inconclusive`. Never report success from an `inconclusive` run.
- Emulator evidence never proves physical-device behavior. State this in every report.
- `environment_error` is not an app failure. Fix the environment or report the blocker.
- Never run the skill as root. The script refuses.
- An early stop proves only the part of the run before the stop. Use the full timeout when a late failure matters.
- A `--reject-log` condition that did not match is not proof of absence. Log lines written just before the stop can be lost. Prefer file expectations.
- Never download firmware or an emulator build from an unofficial source.
- Never edit source files, stash, reset, or commit in the VPK's repository as part of this skill. Build output that the project's own build script writes is expected.
- One run at a time per instance.
- The skill keeps all emulator data in its own instance. Never point it at a personal Vita3K install or its data.

## Reporting

Every report names:

- the verdict and the reason (`verdict`, `reason`);
- each expectation with its result (`expectations`: `target`, `satisfied`, `detail`);
- the fresh files (`fs_diff.created` and `fs_diff.modified`);
- notable log lines (`log_summary.tty` and `log_summary.errors`);
- the screenshot path when `paths.screenshot` is set;
- the VPK SHA-256 and the emulator version (`vpk.sha256`, `emulator.version`);
- each step that was skipped, with the reason;
- the caveat that emulator evidence does not prove behavior on a physical device.
