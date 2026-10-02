# 01 — Fixture VPK and headless Linux gate (WP1, gate G1)

Covers **WP1**. Terms, findings (F*), decisions (D*), and assumptions (A*) are defined in [00-overview.md](00-overview.md).

## Goal

Prove, by hand, that Vita3K can install and boot a real VPK on this headless aarch64 Linux host with no human interaction. Record the exact working recipe. WP3 implements that recipe and nothing else.

Prerequisite state: none for checks 1–7 and 9–14. Check 8 needs the `xwd_to_png` function and its test from WP2. WP1 itself writes no skill code. A converter defect found in check 8 is fixed as WP2 work, and check 8 resumes after the fix.

## Why this comes first

The Vita3K source shows no windowless mode (F11). This host has no display and no Vita3K (F7, F9). Every launch detail in WP3 depends on facts that only a real run can establish (A1–A5, A7–A9).

## Change surface

| Path | Action |
| --- | --- |
| `.agents/plans/vita3k-run-vpk/G1.md` | **new**. Gate record. Parent directory exists. Precedent: vitair's `docs/hardware-gates/H1.md`. |
| `$VITA3K_AGENT_HOME` (default `$HOME/.vita3k-agent`) | Created on the host. Not in the repository. |

No file under `.agents/skills/` changes in WP1.

## Step 1 — Obtain a fixture VPK

The fixture is bevypoc (F22). It writes a file under `ux0:` at launch and prints to stderr, so it probes both evidence channels.

Use the first source that works. Record the source in `G1.md`.

1. Build on this host. This needs four host installs that are absent today (F9): VitaSDK from the `vitasdk-aarch64-linux-gnu` build (F25), the Rust toolchain `nightly-2026-04-08` with `rust-src` and `rustfmt`, the `wasm32-unknown-unknown` target for that toolchain, and `cargo-vita 0.2.2`. The bevypoc README gives the commands. Then run bevypoc's `./scripts/build-vpk.sh` from a clean checkout. These are host setup actions outside this repository. Name all four in one request and get the user's approval before installing any of them. Record the installed versions in `G1.md`.
2. Copy a VPK that was built on another machine. Ask the user for the file.

Requirements for the fixture:

- Record the VPK path, its SHA-256, and the source SHA that `build-vpk.sh` printed.
- Do not modify the bevypoc repository. Do not work around its clean-tree check.

If neither source is available, stop. The gate owner is the user. The unblock action is to supply a bevypoc VPK or approve the four host installs.

## Step 2 — Install Vita3K into the instance

1. Create `$VITA3K_AGENT_HOME/emulator/`.
2. Download `Vita3K-aarch64.AppImage` from the `continuous` release of `Vita3K/Vita3K` (F10) into that directory. Example: `gh release download continuous -R Vita3K/Vita3K -p 'Vita3K-aarch64.AppImage' -D "$VITA3K_AGENT_HOME/emulator"`.
3. Compute the file's SHA-256. Compare it with the `digest` field of that asset from `gh api repos/Vita3K/Vita3K/releases/tags/continuous` (F10). Stop on a mismatch. Record the SHA-256 and download time.
4. Make it executable. Try to run it directly (step 3 below supplies the display). If the AppImage runtime fails because FUSE is unavailable (R2), run `./Vita3K-aarch64.AppImage --appimage-extract` inside `emulator/` and use `emulator/squashfs-root/AppRun` instead.
5. Record which form runs. Record every missing-library or FUSE error exactly, and the Ubuntu package that resolves it. `references/install.md` takes its package list from these observations.
6. Do not install a host package yourself. Installing one needs `sudo`. Stop, name the package and the error it resolves, and ask the user to install it. Prefer a path that needs no new package, such as the extracted AppImage.

## Step 3 — Establish the launch recipe

Set the isolation environment for every emulator invocation (D3):

```text
XDG_CONFIG_HOME=$VITA3K_AGENT_HOME/xdg/config
XDG_CACHE_HOME=$VITA3K_AGENT_HOME/xdg/cache
XDG_DATA_HOME=$VITA3K_AGENT_HOME/xdg/data
```

Expected resulting paths (F15):

| Item | Path |
| --- | --- |
| Config | `$VITA3K_AGENT_HOME/xdg/config/Vita3K/config.yml` |
| Log | `$VITA3K_AGENT_HOME/xdg/cache/Vita3K/vita3k.log` |
| Emulated filesystem | `$VITA3K_AGENT_HOME/xdg/data/Vita3K/Vita3K/` |

Run every check as the normal user. Do not run Vita3K as root (D12, F14).

Checks, in order. Record the observed result of each one in `G1.md`.

1. **Version probe (A5).** Run the binary with `--version` and `QT_QPA_PLATFORM=offscreen`. Record the exit status, the printed version string, and whether the process exits by itself. If it fails, repeat under Xvfb and record that instead.
2. **Config seed (A1).** Write a `config.yml` at the config path that contains exactly these keys (F14, F19):

   ```yaml
   show-welcome: false
   warn-missing-firmware: false
   check-for-updates: false
   check-for-updates-mode: 0
   log-level: 0
   ```

   If Vita3K rejects or ignores the minimal file, let Vita3K generate a full default file first (any invocation writes one when the file is absent), then change only those keys. Record which method works. Record whether Vita3K rewrites the file on exit.
3. **Display.** Start `Xvfb` with `-displayfd`, one `1280x800x24` screen, and `-nolisten tcp`. Export the resulting `DISPLAY`.
4. **Renderer matrix (R1).** For each profile, launch `<binary> <fixture.vpk>` and wait up to 180 seconds. Stop at the first profile that passes check 5.

   | Profile | Vita3K setting | Extra environment |
   | --- | --- | --- |
   | P1 | `backend-renderer: Vulkan` | `VK_DRIVER_FILES` and `VK_ICD_FILENAMES` set to `/usr/share/vulkan/icd.d/lvp_icd.json` |
   | P2 | `backend-renderer: OpenGL` | `LIBGL_ALWAYS_SOFTWARE=1`, `__GLX_VENDOR_LIBRARY_NAME=mesa` |
   | P3 | `backend-renderer: Vulkan` | none (NVIDIA ICD) |
   | P4 | `backend-renderer: OpenGL` | none |

5. **Boot proof.** A profile passes when all of these hold:
   - the log contains `Content installed, will auto-boot: BEVYPOC01` (F12);
   - `ux0/app/BEVYPOC01/eboot.bin` exists under the emulated filesystem and was written by this run;
   - `ux0/data/bevypoc/build.txt` exists and contains the fixture's 40-character source SHA;
   - no modal dialog blocked the run. Judge this from the screenshot in check 8.
   Also record whether the installed `eboot.bin` has the same SHA-256 as `eboot.bin` inside the VPK (A7). A difference does not fail the profile.
6. **Timing (R7).** Record seconds from launch to the install log line and to the appearance of `build.txt`.
7. **Log channels (A3, A8, R5, D13).** Capture emulator stdout to a file during the run. Record:
   - whether `bevypoc source commit: <sha>` appears as a `*** TTY:` line or in any other form;
   - the exact log lines that mark app boot, if any stable marker exists;
   - whether the install line from F12 is visible in each source while the emulator still runs, and how many seconds after launch;
   - the lag of each source (A9): the seconds between the appearance of `build.txt` and the appearance of the nearest following log line in the stdout capture and in `vita3k.log`;
   - whether `vita3k.log` and the stdout capture have the same final lines after the stop in check 9, and the timestamp of the last line in each compared with the stop time;
   - whether the stdout capture contains ANSI escape sequences.
   When the stdout capture lags by more than 2 seconds, repeat the run with the emulator's stdout attached to a pseudo-terminal (Python `pty.openpty`) and record whether the lag disappears. WP3 then uses the pseudo-terminal.
   Save a sanitized excerpt of the real log for the WP3 parser fixture: at most 200 lines, with `$HOME` replaced in every path.
8. **Screenshot (D7).** Run `xwd -root -silent -display "$DISPLAY" -out <file>` just before stopping. Keep the raw dump. Convert it to PNG with the `xwd_to_png` function from WP2 ([02-runner-script.md](02-runner-script.md)) and view the PNG. This check therefore needs that one WP2 function. Record whether the frame shows the app's rendered output (bevypoc draws `...`, a green number, or `ERR` on red), only emulator chrome, or a blank frame. A garbled image is a converter defect. Fix it under WP2 with a test, then repeat this check.
9. **Stop (A4).** Send `SIGTERM` to the emulator's process group. Record the seconds until exit and whether `SIGKILL` was needed. Confirm no emulator or Xvfb process remains.
10. **App exit behavior.** Record what Vita3K does when the app keeps running until timeout. bevypoc does not exit by itself, so this is the only case the fixture can show. What Vita3K does when an app exits by itself (F24, the clckr spike) stays unobserved. The script covers both outcomes: an emulator exit with status 0 adds a warning, and a non-zero exit or a fatal signal is a crash. Neither outcome blocks WP3.
11. **Isolation check.** Confirm that `~/.config/Vita3K`, `~/.cache/Vita3K`, and `~/.local/share/Vita3K` still do not exist after all runs.
12. **Reinstall and stale evidence (F13).** Run the passing profile a second time without deleting `ux0/data/bevypoc/`. Record whether `build.txt` has a new modification time. Then delete `ux0/app/BEVYPOC01/` and run again. Record that the install recreates it. WP3 relies on this.
13. **Process identity and leftovers.** While the emulator runs, record the process tree under the launched process group, with `ps -o pid,pgid,lstart,command`. After a `SIGKILL` of the whole group, record whether an AppImage FUSE mount remains (`mount | grep -i vita3k`) and the command that removes it. This check applies to the direct AppImage form only.
14. **`--console` (F11).** Launch once with `--console <fixture.vpk>`. Record whether a window appears in the screenshot, whether the app boots, and whether `build.txt` is written. This check is informational. It changes WP3 only if console mode boots the app without a window.

## `G1.md` content

The gate record must contain:

- date, host description, Vita3K version string, binary SHA-256, binary form (AppImage or extracted);
- fixture VPK SHA-256, source SHA, and source of the fixture;
- one row per check above with the observed result;
- the chosen renderer profile with its exact configuration and environment;
- the chosen config-seeding method;
- the authoritative log source: the stdout capture (D13), unless it proved incomplete and `vita3k.log` proved complete;
- the A7 result: whether `eboot_matches` gates the install stage;
- the host packages that the emulator needed, with Ubuntu package names;
- the measured stop time and the kill grace period: twice the measured time, minimum 5 seconds;
- the stdout capture method: plain redirect or pseudo-terminal;
- the stale-mount cleanup command, or `none`;
- the screenshot decision: `keep` when the frame shows app output, otherwise `drop`;
- recommended default `--timeout`: twice the measured time to `build.txt`, rounded up to the next 30 seconds, minimum 60;
- every deviation from this document and every assumption (A1–A5, A7–A9) that proved false.

Do not copy secrets or personal paths into `G1.md`. Use `$VITA3K_AGENT_HOME` and `$HOME` in paths.

## Gate decision

- **Go**: at least one renderer profile passes check 5, and the stop in check 9 leaves no process behind. Continue with WP3.
- **No-go**: no profile passes. Stop. Report the per-profile failure output to the user. The decision owner is the user. Options to present: a real X server on the NVIDIA GPU, a different host, or macOS-only support.
- **Partial**: the app boots but writes no `build.txt`. Treat as no-go until the cause is known, because the emulated-filesystem channel is the skill's primary evidence.

A false assumption that has a working alternative (for example A5 false, Xvfb works) is not a no-go. Record the alternative. WP3 implements the recorded behavior.

## Acceptance criteria

1. `.agents/plans/vita3k-run-vpk/G1.md` exists and contains every item listed above.
2. The gate decision is stated as go or no-go with the evidence.
3. `git status` in the bevypoc checkout shows no change caused by this work.
4. No Vita3K path outside `$VITA3K_AGENT_HOME` was created (check 11).

## Risks and exclusions

- The fixture needs no network for the pass condition. `build.txt` is written before the first network read (F22).
- Excluded: Nim or vitaGL fixtures. No Nim VPK is available on this host (F25). R4 stays open and is listed as deferred acceptance.
- Excluded: firmware installation. G1 runs without firmware. If bevypoc fails to boot only because firmware is missing, record that and ask the user for a firmware file before deciding the gate.
