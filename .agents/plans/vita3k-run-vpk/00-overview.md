# 00 — Overview: `vita3k-run-vpk` skill

Status: macOS gate passed, Linux acceptance open. WP1 is complete: gate G1 passed on 2026-10-02 and its record is [G1.md](G1.md). WP2, WP3, WP4, and WP6 are complete: the skill exists under `.agents/skills/vita3k-run-vpk/`, and gate G2 passed on 2026-10-02 on a Mac, with its record in [G2.md](G2.md). WP5 is the only open work package. It needs the Linux gate host. The plan is not done until WP5 passes.

G1 corrected several findings and assumptions below. Corrected items are marked. Where this plan and [G1.md](G1.md) differ, G1.md is right.

## Application context

```json
{
  "application_context": {
    "has_active_users": false,
    "backward_compatibility_required": false,
    "feature_flags": "not-applicable",
    "confirmation_digest": "ea95692fd434a844a218ee31b2702b07cc090ecae97d5c1befb2b452c5fcd544",
    "confirmed_at": "2026-10-02T18:41:54Z"
  }
}
```

The skill is new. No existing skill, script, or stored data must keep its current behavior. No rollout flag, migration, or compatibility shim is planned. Rollback is deletion of the new skill directory.

## Change type and affected areas

- Change type: new agent skill (documentation plus a Python helper script and its tests).
- Affected area: `.agents/skills/vita3k-run-vpk/` (**new**), under the existing parent `.agents/skills/`.
- Unaffected: `.claude/` (no Claude-specific adapter is needed), `scripts/setup-agent-tools.sh` (it already links every child of `.agents/skills/`), all other skills.

## Requested outcome

An agent (Claude Code or Codex) can take a built PS Vita `.vpk`, run it in the [Vita3K](https://github.com/Vita3K/Vita3K) emulator, and then examine Vita3K's emulated filesystem and log for signs of success or failure. When Vita3K is not installed, the skill gives the agent instructions to install it.

User decisions recorded on 2026-10-02:

| Decision | Answer |
| --- | --- |
| Hosts in the first version | Headless aarch64 Linux and macOS |
| Evidence sources | Emulated filesystem and Vita3K log. A screenshot on headless Linux if the gate shows it is meaningful. No screenshot elsewhere. |
| Input | An already-built VPK. Building stays with each project. (Stated default, not objected to.) |
| Emulator state | A dedicated Vita3K instance that never touches a personal Vita3K install. (Stated default, not objected to.) |
| Nim acceptance | A Nim or vitaGL VPK run is optional. It is not required for done. |

## Success criteria

1. S1 — On this headless aarch64 Linux host, one command installs and boots a real VPK in Vita3K with no human interaction and stops the emulator afterwards.
2. S2 — The command reports which files were created or changed under `ux0:` outside `ux0:app` during that run, and never counts a file left by an earlier run as evidence. Writes under `ux0:app` are visible only through an explicit expectation.
3. S3 — The command prints one JSON result with a verdict of `pass`, `fail`, `inconclusive`, or `environment_error`. An app-level `pass` requires at least one caller-supplied expectation. An emulator crash after installation yields `fail` without any expectation.
4. S4 — With bevypoc as the fixture: a run that expects `ux0:data/bevypoc/build.txt` to contain the VPK's embedded source SHA returns `pass`. A run that expects a file the app never writes returns `fail`.
5. S5 — When Vita3K is absent, `doctor` reports it. Following the skill's install reference from an empty instance makes `doctor` report ready on aarch64 Linux (proven by WP5) and on macOS (proven by G2). The reference also documents x86_64 Linux, marked unverified. x86_64 is outside the success criteria.
6. S6 — The same `run` and `doctor` commands work on macOS, verified on a Mac by gate G2.
7. S7 — Skill unit and integration tests pass without Vita3K installed.
8. S8 — Both Claude Code and Codex discover and use the skill once its directory is linked into each agent's skills directory.

Not covered by any criterion: Nim and vitaGL app behavior in Vita3K. The skill documents Nim projects, and no Nim VPK is run as a required step. The user confirmed this on 2026-10-02.

## Scope

- A `doctor` command: detect host, emulator binary, instance paths, firmware state, and headless prerequisites.
- A `run` command: install and boot one VPK, wait, stop, collect evidence, evaluate caller expectations.
- Evidence: emulated-filesystem diff, Vita3K log summary, and a screenshot on headless Linux.
- References: Vita3K installation per host, and how to read the evidence for Rust (`cargo-vita`) and Nim (VitaSDK script) projects.

## Non-goals

- Building VPKs, installing VitaSDK, or changing any consumer repository.
- Physical-hardware testing. Emulator evidence never proves device behavior.
- Scripted controller or touch input.
- Windows hosts.
- Running as root, for example inside a container (D12).
- Automatic firmware download.
- Committed per-project expectation files. See deferred work in [05-execution-handoff.md](05-execution-handoff.md).
- Screenshots on macOS or on Linux hosts that already have a display.

## Constraints

- The helper script uses the Python standard library only and runs on Python 3.9 or newer. macOS command-line tools ship Python 3.9. This host has Python 3.12.3.
- `.agents/README.md` portability rules apply: relative paths inside the skill, no tool-specific names outside an adapter file, external CLIs named in the skill description.
- The skill must work for both agents. `AGENTS.md` requires shared behavior to live under `.agents/` first.
- Implementation happens on the feature branch `feat/vita3k-run-vpk-skill`, which holds this plan. Pushing to `main` needs explicit user approval.

## Repository-grounded findings

Dotfiles repository:

- F1 — Skills live in `.agents/skills/<name>/` with `SKILL.md` (YAML frontmatter `name`, `description`), optional `agents/openai.yaml`, `references/`, `scripts/`, and `tests/`. Reference: `.agents/skills/select-next-milestone/`.
- F2 — `agents/openai.yaml` holds `interface.display_name`, `interface.short_description`, and `interface.default_prompt`. Reference: `.agents/skills/select-next-milestone/agents/openai.yaml`.
- F3 — Skill tests use `unittest` and import scripts through `sys.path`. `python3 -m unittest discover -s .agents/skills/select-next-milestone/tests` ran 26 tests with result OK on 2026-10-02.
- F4 — `link_children` in `scripts/setup-agent-tools.sh` creates one symlink per child of `.agents/skills/` in `~/.agents/skills`, `~/.claude/skills`, and `~/.codex/skills`. The functions `link_shared_agent_config`, `link_claude_agent_config`, and `link_codex_agent_config` do the linking. `setup_agent_tools` calls them and also installs Claude Code and Codex when absent. They read the agent root from `DOTFILES_AGENT_ROOT`, default `$HOME/git/dotfiles/.agents`. A new skill directory is not linked until they run again or the links are created by hand.
- F5 — The repository has no root `.gitignore`. `.agents/skills/select-next-milestone/scripts/__pycache__/` is untracked noise that predates this plan. It is not plan work.
- F6 — `.claude/skills/` in this repository holds only older skills. Newer shared skills (`select-next-milestone`, `review-gauntlet`) exist only under `.agents/skills/`.

This host (observed 2026-10-02):

- F7 — aarch64, Ubuntu 24.04.4, no `DISPLAY`, no Wayland session, NVIDIA GB10 GPU.
- F8 — Present: `Xvfb`, `xvfb-run`, `xwd`, `xdpyinfo`, `fusermount`, `fusermount3`, `unzip`, `gh`, Python 3.12.3, Mesa 25.2.8 with `libgl1-mesa-dri` and `mesa-vulkan-drivers`, Vulkan ICD files `lvp_icd.json` (lavapipe) and `nvidia_icd.json` under `/usr/share/vulkan/icd.d/`.
- F9 — Absent before WP1: Vita3K (no binary, no data directory), VitaSDK (`VITASDK` unset, `/usr/local/vitasdk` missing), `cargo-vita`, the Rust toolchain `nightly-2026-04-08` that bevypoc and vitair pin, `nim`, `nimble`, `libfuse2`, ImageMagick, `vulkaninfo`. The current user is not root (uid 1000). WP1 changed this: VitaSDK, the Rust toolchain, `cargo-vita`, `libfuse2t64`, and Vita3K build 4111 are now installed. [05-execution-handoff.md](05-execution-handoff.md) lists the host state.

Vita3K (source at commit `a366df69bd66bedaa245e40902d1992038f7ccb7`, 2026-10-02, and the `continuous` release):

- F10 — The `continuous` release publishes `Vita3K-aarch64.AppImage`, `Vita3K-x86_64.AppImage`, `ubuntu-aarch64-latest.zip`, `ubuntu-latest.zip`, `macos-arm64-latest.dmg`, and `macos-latest.dmg`. The tag is rolling. Versioned pins exist in a second repository: `Vita3K/Vita3K-builds` publishes one release per build number with the same asset names (corrected by G1). The GitHub release API exposes a `digest` (`sha256:…`) for each asset. Linux builds from 4112 on need glibc 2.43, because upstream CI moved to Ubuntu 26.04 on 2026-10-02. This host has glibc 2.39, and build 4111 is the newest build that starts here.
- F11 — `vita3k/main.cpp` always constructs a `QApplication` and shows `MainWindow`. No windowless mode is visible in the source. Every invocation, including `--version` and `--firmware`, needs a Qt platform. A `--console` flag exists (`vita3k/config/src/config.cpp`). In `main.cpp` it only changes log initialisation and skips SDL initialisation, and the window is still created. G1 observed it: `--console -- <vpk>` installs the VPK, prints no log lines to stdout, and does not boot the app. The skill does not use it.
- F12 — A positional `.vpk` argument installs the archive. `main.cpp` logs `Installing archive from CLI: <path>` and `Content installed, will auto-boot: <TITLE_ID>`. Corrected by G1: the path must follow a `--` separator, and the app does not boot in that launch. A second launch with `-r <TITLE_ID>` boots the installed app. A likely cause, from reading the source and not observed: `main.cpp` sets `run_app_path` on its local configuration after `app::init` has moved the configuration into the emulator state, and `MainWindow` reads the emulator state.
- F13 — CLI installation passes no reinstall callback. `install_archive_content` in `vita3k/interface.cpp` then removes `ux0/app/<TITLE_ID>` and reinstalls. Files under `ux0/data/` survive reinstalls.
- F14 — Four modal dialogs can block an unattended launch. Three are controlled by `config.yml` keys in `vita3k/config/include/config/config.h`: the welcome dialog (`show-welcome`, default `true`), the update prompt (`check-for-updates-mode`, default prompt; `0` is off), and the missing-firmware warning in `confirm_missing_firmware_warning` (`warn-missing-firmware`, default `true`). The fourth is `prompt_admin_privileges_warning_if_needed` in `vita3k/gui-qt/src/main_window.cpp`. It appears when the process runs as root or with differing real and effective user IDs. Its suppressing setting `warnAdminPrivileges` is stored in the `gui-configs` settings, not in `config.yml`.
- F15 — Linux paths in `vita3k/app/src/app_init.cpp`: config at `$XDG_CONFIG_HOME/Vita3K/config.yml`, log at `$XDG_CACHE_HOME/Vita3K/vita3k.log`, emulated filesystem at `$XDG_DATA_HOME/Vita3K/Vita3K/`. Each falls back to `~/.config`, `~/.cache`, `~/.local/share`.
- F16 — macOS paths: when a `portable/` directory exists beside `Vita3K.app`, config and log are in `portable/` and the emulated filesystem is `portable/fs/`. Otherwise Vita3K uses `~/Library/Application Support/Vita3K/Vita3K/`.
- F17 — The `pref-path` key in `config.yml` overrides the emulated filesystem location outside portable mode.
- F18 — Log line pattern is `[%H:%M:%S.%e] |%L| [%!]: %v` (`vita3k/util/src/logging.cpp`). `%L` is one of `T D I W E C`. The log also goes to stdout. A duplicate filter suppresses identical messages repeated within two seconds. Logging is asynchronous. The file sink is opened with truncation on every start and is flushed on every message only on Android, so `vita3k.log` can lag behind the stdout copy on desktop hosts.
- F19 — Writes to a Vita TTY device are logged as `*** TTY: <text>` at trace level (`vita3k/io/src/io.cpp`). Default `log-level` is `0` (trace).
- F20 — `get_firmware_state` in `vita3k/app/src/app.cpp` treats content in `vs0/` as main firmware and content in `sa0/` as the font package.
- F21 — Vita3K's quickstart page links Sony's system-software page for the main firmware and states that it cannot provide a URL for the font package.

Consumer projects:

- F22 — bevypoc (`birbparty/bevypoc`, Rust, `cargo-vita`): title ID `BEVYPOC01`. On launch it writes its 40-character source SHA to `ux0:data/bevypoc/build.txt` and prints it to stderr. It reads `ux0:data/bevypoc/server.txt`. `scripts/build-vpk.sh` writes `target/armv7-sony-vita-newlibeabihf/release/bevypoc.vpk` and refuses a dirty tree.
- F23 — vitair (Rust, `cargo-vita`): title ID `VITAIR001`. `startup_checkpoint` in `crates/vitair-app/src/lib.rs` appends `<SOURCE_SHA> <message>` lines to `ux0:data/vitair/startup.log`. The app also lists `ux0:` directories on screen. Its README tells the user to install Vita firmware in Vita3K first and launches Vita3K on macOS with the VPK path. The package sets `vita_make_fself_flags = []` for `ux0:` root access. Its plan `vita-dev-loop` states that simulator results never count as proof of device behavior.
- F24 — Nim projects build with VitaSDK shell scripts, not `cargo-vita`. `birbparty/clckr` `scripts/build_vita.sh` defaults to title ID `CLCKR0001` and needs `nim`, VitaSDK, and a raylib4Vita build. Its `examples/vita_spike.nim` writes breadcrumbs to `ux0:data/clckr_vita_spike.txt` and exits by itself when START is pressed. `birbparty/topdown` `scripts/build_vita.sh` uses title ID `TOPD00001` and states that `127.0.0.1` reaches the host only inside a same-machine Vita3K. Both link vitaGL.
- F25 — No `birbparty` repository publishes a VPK as a release asset. VitaSDK publishes `vitasdk-aarch64-linux-gnu` and `arm64-apple-darwin` builds, so a VPK can be built on either target host.

## Key decisions

- D1 — Skill name and path: `.agents/skills/vita3k-run-vpk/` (**new**). One helper script `scripts/vita3k_vpk.py` (**new**) with subcommands `doctor` and `run`.
- D2 — Run-only input. The script takes a VPK path. Rejected: building inside the skill. Build systems differ per project (F22, F24), and both example Rust scripts enforce clean-tree rules that the skill must not work around.
- D3 — Dedicated instance at `${VITA3K_AGENT_HOME:-$HOME/.vita3k-agent}`. On Linux the script sets `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` for the emulator process (F15), so isolation does not depend on where the binary lives. On macOS the script requires a `portable/` directory beside the instance's own copy of `Vita3K.app` (F16). Rejected: sharing the user's Vita3K data, because `--clean` and config seeding would alter personal state.
- D4 — Freshness rule. File evidence counts only when the file is new or its modification time or content hash changed between the pre-run and post-run snapshots. For a file that grew by appending, content expectations match only the appended part. Reasons: F13, and vitair's append-only `startup.log` (F23).
- D5 — Verdict model. Caller expectations decide `pass`. A failed expectation, a reject match, or an emulator crash after installation decides `fail`. A run without expectations and without a crash returns `inconclusive` with the evidence. The script never infers app success from the absence of errors. Reason: the projects signal success in different ways (F22–F24). Log severity alone never decides the verdict, because Vita3K's error vocabulary for homebrew is unobserved.
- D16 — Two launches per run, from G1: an install launch (`-- <vpk>`), stopped once the install is complete, then a boot launch (`-r <TITLE_ID>`). Rejected: unzipping the VPK into `ux0/app/` from the script. The emulator's own installer is the behavior a user gets, and it costs about one second.
- D17 — Headless Linux uses software OpenGL (G1 profile P2). Software Vulkan boots the app and leaves the game window black in the screenshot.
- D6 — The script owns the X display on headless Linux. It starts `Xvfb` with `-displayfd`, so it knows the display number for `xwd`. Rejected: `xvfb-run`, which hides the display number.
- D7 — Screenshot only when the script owns the Xvfb display. G1 showed a meaningful frame with software OpenGL, so the screenshot is kept. This follows the user's answer.
- D8 — Installation is documented, not automated. `doctor` detects a missing emulator and points to `references/install.md`. Reason: the request asks for instructions. The install reference names a pinned build number from `Vita3K/Vita3K-builds` (F10) and verifies the asset digest.
- D9 — Firmware is optional and manual. The script seeds `warn-missing-firmware: false`. `doctor` reports firmware state. The agent never downloads firmware from an unofficial source (F21).
- D10 — Python standard library only, with `unittest`. Reason: F1, F3, and no package manager is defined for skills.
- D11 — Tests run against a stub emulator selected through `VITA3K_BIN`. Real-emulator behavior is proven only by gates G1, G2, and the acceptance run. Stub tests never count as proof of emulator behavior.
- D12 — The script refuses to run as root or with differing real and effective user IDs. It returns `environment_error` with reason `privileged_user`. Reason: the fourth dialog in F14 cannot be cleared through `config.yml`. Rejected: seeding the `gui-configs` settings file, whose format is a Qt implementation detail.
- D13 — Captured emulator stdout is the default authoritative log source. `vita3k.log` is copied as secondary evidence and used for the isolation check. Reason: F18. G1 confirmed it. The install stage needs the installed `eboot.bin` and the install launch's `installed successfully!` line. The script reads that line while the emulator still runs, so a log tail lost at the stop cannot produce a false `install_failed`.
- D14 — Gate results become script constants and reference text. The shipped skill never reads or links to `.agents/plans/`. Reason: plan directories are planning records and can be moved or pruned.
- D15 — The script copies the VPK to `<run_dir>/<TITLE_ID>.vpk` and passes that copy to Vita3K. Reason: `main.cpp` installs only paths ending in `.vpk` or `.zip`, and the copy fixes the exact bytes that were tested.

## Change model

```text
Before: agent builds VPK → no way to execute it on this host → human tests on Mac or device

After:
  agent builds VPK (project's own script)
        │
        ▼
  vita3k_vpk.py doctor ──not ready──► references/install.md ──► doctor again
        │ ready
        ▼
  vita3k_vpk.py run <vpk> [--seed] [--clean] [--expect-*] [--reject-log]
        │
        ├─ copy VPK into run dir, seed config.yml     instance: $VITA3K_AGENT_HOME
        ├─ Xvfb (headless Linux only) → Vita3K -- <vpk> (install) → stop
        ├─ snapshot ux0 (before)
        ├─ Vita3K -r <TITLE_ID> (boot) → wait → screenshot → stop
        ├─ snapshot ux0 (after) → diff
        └─ result.json + run directory (log copy, fs diff, evidence copies, screenshot)
        │
        ▼
  agent reads verdict + evidence using references/evidence.md
```

## Risks

- R1 — Resolved by G1. Vita3K boots under Xvfb on this host with software OpenGL. Heavier apps than bevypoc may run slowly under software rendering (R7).
- R2 — The AppImage may not run without `libfuse2` (F9). The fallback is `--appimage-extract`. G1 ran the direct form with `libfuse2t64` installed. The extracted form is untested.
- R9 — The pinned Linux build 4111 ages. Hosts with glibc older than 2.43 cannot run newer builds, so emulator fixes after 2026-10-02 do not reach this host. Ways out, none planned: a host upgrade to Ubuntu 26.04, a container with a newer glibc, or a source build.
- R3 — The rolling release (F10) can change CLI flags, config keys, log text, or paths. Mitigation: the script records the emulator version string and binary SHA-256 in every result, and it verifies isolation after each run.
- R4 — vitaGL-based Nim apps (F24) may need firmware modules that the firmware-free instance lacks. This is unverified. The evidence reference must tell the agent how to recognise a missing-module failure and classify it as an environment limitation.
- R5 — Buffered, asynchronous file logging (F18) leaves `vita3k.log` far behind during the run. G1 measured it: the file was empty while stdout had about 40 lines. D13 addresses this.
- R6 — macOS behavior is derived from source only. No Mac is reachable from this host. Gate G2 must run on a Mac.
- R7 — Software rendering is slow. Default timeouts come from G1 measurements.
- R8 — Log lines produced just before the stop can be lost (A9). A `--reject-log` condition that did not match is weaker evidence than a file expectation. The evidence reference states this.

## Assumptions

Each assumption was unverified when the plan was written. G1 results: A1, A3, A7, A8, and A9 are true. A2, A4, and A5 are false, with working alternatives in [G1.md](G1.md). G2 result: A6 is true.

- A1 — A minimal `config.yml` containing only the seeded keys is accepted and suppresses the three config-controlled dialogs of F14 (G1).
- A2 — `Vita3K <vpk>` with no other arguments installs and boots under Xvfb (G1).
- A3 — App stdout and stderr reach the log as `*** TTY:` lines (G1). bevypoc's `eprintln!` output is the probe.
- A4 — `SIGTERM` stops Vita3K and leaves a usable log (G1).
- A5 — `Vita3K --version` exits without a window under `QT_QPA_PLATFORM=offscreen` (G1).
- A6 — The macOS portable layout matches F16 at runtime, and a Gatekeeper quarantine removal lets the downloaded app start (G2).
- A7 — The installed `ux0/app/<TITLE_ID>/eboot.bin` is byte-identical to the `eboot.bin` in a homebrew VPK. G1 observed equal SHA-256 values for bevypoc.
- A8 — Emulator stdout contains no ANSI color codes when it is not a terminal (G1). The script strips them in either case.
- A9 — Each log message reaches a redirected stdout within about one second. G1 observed this at its one-second polling resolution. Messages still queued in the asynchronous logger when the emulator is killed can be lost in both sources.

## Unresolved decisions

None. G1 resolved the decisions that were open:

| Decision | Result |
| --- | --- |
| Renderer profile for headless Linux | Software OpenGL (D17) |
| Authoritative log source | Captured stdout, plain redirect (D13 confirmed) |
| Whether `eboot_matches` gates the install stage | Yes (A7 true) |
| Keep or drop the screenshot | Keep |
| Default `--timeout` | 60 seconds |

## Stop/go gates

- G1 — Headless Linux feasibility. Defined in [01-fixture-and-headless-gate.md](01-fixture-and-headless-gate.md). **Passed 2026-10-02.** Record: [G1.md](G1.md).
- G2 — macOS acceptance. Defined in [04-acceptance-gates.md](04-acceptance-gates.md). **Passed 2026-10-02** on an Apple silicon Mac. Record: [G2.md](G2.md). The Intel build was not run.

## External requests

None. The skill consumes VPK files that other repositories already produce and needs no change in any of them.

## Document map

| File | Purpose |
| --- | --- |
| [00-overview.md](00-overview.md) | Context, findings, decisions, risks, gates. |
| [01-fixture-and-headless-gate.md](01-fixture-and-headless-gate.md) | WP1: obtain a fixture VPK, install Vita3K in the instance, run gate G1. Complete. |
| [G1.md](G1.md) | G1 gate record: the working launch recipe, check results, deviations, and script constants. |
| [G2.md](G2.md) | G2 gate record: the macOS run of the skill with the real emulator, and how macOS differs from G1. |
| [02-runner-script.md](02-runner-script.md) | WP2 and WP3: the `vita3k_vpk.py` contract, host-independent core, launch lifecycle, tests. |
| [03-skill-documents.md](03-skill-documents.md) | WP4: `SKILL.md`, references, `agents/openai.yaml`. |
| [04-acceptance-gates.md](04-acceptance-gates.md) | WP5 and WP6: Linux end-to-end acceptance and macOS gate G2. |
| [05-execution-handoff.md](05-execution-handoff.md) | Ordered work packages, verification commands, definition of done, deferred work. |
