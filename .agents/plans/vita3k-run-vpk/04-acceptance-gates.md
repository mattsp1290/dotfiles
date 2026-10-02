# 04 — Acceptance gates (WP5, WP6)

Covers **WP5** (Linux end-to-end acceptance) and **WP6** (macOS gate G2). Terms are defined in [00-overview.md](00-overview.md).

Stub tests never satisfy any criterion in this file (D11).

## WP5 — Linux end-to-end acceptance

Goal: prove S1–S4, the aarch64 Linux part of S5, and S8 with the real emulator on this host through the skill's own commands. Prerequisites: WP3 and WP4 complete, G1 decided as go, the bevypoc fixture VPK from WP1 available.

### Change surface

| Path | Action |
| --- | --- |
| `.agents/plans/vita3k-run-vpk/A1-linux.md` | **new**. Acceptance record. |
| `.agents/skills/vita3k-run-vpk/references/*.md` | Corrections found during acceptance only. |

### Procedure

Run every command through the linked skill path (`~/.agents/skills/vita3k-run-vpk/`), not the repository path, so the links from F4 are exercised. Record each command, exit code, and the relevant JSON fields.

Run every step as the normal user.

1. **Doctor, not installed (S5).** Run `doctor` with `VITA3K_AGENT_HOME` set to an empty temporary directory. Expected: exit 3, `ready: false`, a problem entry whose `fix` names the install reference.
2. **Install from the reference (S5).** In that same empty instance, follow `references/install.md` exactly as written, with no extra knowledge. Run `doctor` again. Expected: exit 0, `ready: true`. Correct the reference when a step is missing or wrong, then repeat from an empty instance. This proves the instance-scoped steps. The host packages are already present from WP1, so their install commands are marked `not run` unless the user ran them.
3. **Pass (S1, S3, S4).** Run:

   ```text
   run <bevypoc.vpk> --expect-file-contains ux0:data/bevypoc/build.txt=<source SHA> --stop-when-satisfied
   ```

   Expected: exit 0, verdict `pass`, `stages.installed` true, `fs_diff.created` lists the file, no emulator or Xvfb process remains. `stages.eboot_matches` is true when G1 observed identical bytes (A7). Otherwise it is false with warning `eboot_differs`.
4. **Freshness (S2).** Run the same command again without `--clean`. Expected: verdict `pass`, and the file appears under `fs_diff.modified`, because bevypoc rewrites it on each launch. Then seed `ux0:data/bevypoc/server.txt` in one run, and in the next run, without `--seed`, pass `--expect-file ux0:data/bevypoc/server.txt`. Expected: verdict `fail`. The file exists from the earlier run and the app does not write it.
5. **Fail (S4).** Run with `--expect-file ux0:data/bevypoc/never-written.txt`. Expected: exit 1, verdict `fail`, the expectation entry is unsatisfied.
6. **Inconclusive (S3).** Run with no expectation. Expected: exit 4, verdict `inconclusive`, `fs_diff` and `log_summary` populated.
7. **Log channel.** When G1 confirmed A3, run with `--expect-log 'bevypoc source commit: <source SHA>'`. Expected: `pass`. When G1 refuted A3, record that app stderr is not available and confirm that `references/evidence.md` says so.
8. **Reject.** Take a real line from the log of step 6 and run with `--reject-log` set to it. When G1 confirmed A3, use the app's own error line for the absent `server.txt`. When G1 refuted A3, use a Vita3K-originated line, for example the install line from F12. Expected: verdict `fail`.

   Then run with that same `--reject-log`, the `build.txt` expectation, and `--stop-when-satisfied`. Record the verdict and whether warning `stopped_early` appears. This shows on the real fixture what an early stop observes.
9. **Screenshot.** When the G1 screenshot decision is `keep`: confirm `paths.screenshot` exists and view it. Expected: the frame shows the app output. When the decision is `drop`: confirm the field is `null` and the documents do not promise a screenshot.
10. **Isolation.** Confirm `~/.config/Vita3K`, `~/.cache/Vita3K`, and `~/.local/share/Vita3K` do not exist, or are unchanged when they existed before WP1. Confirm no run returned `isolation_violated`.
11. **Corrupt VPK.** Run with a zip file that lacks `sce_sys/param.sfo`. Expected: exit 2.

    **Orphan recovery.** Start a pass run, send `SIGKILL` to the script while Vita3K runs, then start a new run. Expected: warning `orphan_cleaned`, a correct verdict, and no leftover Vita3K or Xvfb process.
12. **Agent dry run (S8).** Run this step twice: once in a fresh Claude Code session and once in a fresh Codex session. Both CLIs are installed on this host (`claude`, `codex`). Give each session only this prompt: use the `vita3k-run-vpk` skill to run the bevypoc VPK at `<path>` and report whether it booted. Expected: the agent finds the skill, runs `doctor`, derives the `build.txt` expectation, runs `run`, and reports the verdict with the emulator-versus-device caveat. Record any place where an agent had to guess, and fix the documents. Run the two sessions one after the other, because the instance allows one run at a time. When one CLI cannot start a session, record that agent's part of S8 as unproven and report it.

### `A1-linux.md` content

Date, host, Vita3K version string and binary SHA-256, fixture VPK SHA-256 and source SHA, one row per step with command, exit code, verdict, and observed evidence, plus every document correction made.

### Acceptance criteria

1. Steps 1–11 produce the expected results.
2. Step 12 completes without the agent reading this plan.
3. `A1-linux.md` exists with the content above.
4. `references/install.md` and `references/evidence.md` state the verified Vita3K version and date.

### Optional steps, when the VPK is available

- Run a vitaGL-based Nim VPK (F24) with no expectation and record the result in `A1-linux.md`. Update the Nim rows in `references/evidence.md` from `not exercised` to the observed behavior. This addresses R4.
- Run a vitair VPK with `--expect-file-contains ux0:data/vitair/startup.log=<source SHA>`, twice in a row. Record both results and whether firmware was needed (F23). Update the vitair row.

These steps do not block WP5. The user decided that the Nim run is optional.

## WP6 — macOS gate G2

Goal: prove S6. Prerequisites: WP3 and WP4 complete. WP6 does not depend on WP5.

G2 must run on a Mac. No Mac is reachable from this Linux host (R6). The gate owner is the user, who either runs it or starts an agent session on the Mac. The implementer on Linux stops after WP5, reports G2 as open, and hands over this section.

### Change surface

| Path | Action |
| --- | --- |
| `.agents/plans/vita3k-run-vpk/G2.md` | **new**. Gate record. |
| `.agents/skills/vita3k-run-vpk/references/install.md` | Replace `unverified until gate G2` markers with the G2 date, or correct the steps. |
| `.agents/skills/vita3k-run-vpk/scripts/vita3k_vpk.py` | Only fixes that G2 proves necessary, each with a test. |

### Procedure

1. Run the skill tests: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .agents/skills/vita3k-run-vpk/tests`. Use the system `python3` and record its version. Expected: exit 0. Xvfb tests skip. The helper in `tests/test_run.py` builds the portable layout for the stub, so no test depends on `XDG_*` handling on macOS.
2. Run `doctor` with an empty instance. Expected: exit 3 with a problem entry that names the macOS install section.
3. Follow the macOS section of `references/install.md` exactly, from an empty instance. Record each command. Run `doctor`. Expected: exit 0 and `ready: true`. This proves the macOS part of S5.
4. Verify the portable layout (A6). After one `run`, confirm that `emulator/portable/config.yml`, `emulator/portable/vita3k.log`, and `emulator/portable/fs/ux0/` exist, and that `~/Library/Application Support/Vita3K` was not created or changed.
5. Verify that the seeded config suppresses the welcome, update, and firmware dialogs on macOS. Expected: the app boots with no click.
6. Run WP5 steps 3, 5, 6, and 11 with a bevypoc VPK built on the Mac. Expected: the same verdicts and exit codes.
7. Confirm `paths.screenshot` is `null` and the emulator window closes after the run. Record how the `--version` probe behaves on macOS: its duration, whether a window or Dock icon appears, and whether it exits by itself. When it does not exit within 20 seconds, the script's timeout must kill it and `doctor` must still return.
8. Confirm the stop sequence leaves no `Vita3K` process.

### Gate decision

- **Pass**: steps 1–8 produce the expected results. Replace each `unverified until gate G2` marker in `references/install.md` with the G2 date.
- **Fail with fix**: a step fails and a script or document change makes it pass. Add a test for each script change. Rerun the Linux test suite on the Linux host before merging the change.
- **Fail without fix**: the portable layout or unattended boot does not work on macOS. Stop and report to the user with the observations. `SKILL.md` and `references/install.md` then state that macOS is unsupported, with the reason. The user decides whether to accept that or to request a follow-up.

### `G2.md` content

Date, Mac model and macOS version, Vita3K version string and DMG name, Python version, one row per step with the observed result, and the gate decision.

## Regression gate for both work packages

After any script or document change made during WP5 or WP6:

- the full test command exits 0 on the host where the change was made;
- `tests/test_docs.py` passes;
- the changed behavior is recorded in the matching gate record.
