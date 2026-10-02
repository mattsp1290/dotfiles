# 03 — Skill documents (WP4)

Covers **WP4**. Terms are defined in [00-overview.md](00-overview.md). The script contract is defined in [02-runner-script.md](02-runner-script.md).

## Goal

An agent that has never seen this plan can run a VPK and judge the result by reading the skill alone. Prerequisite: WP3 complete, so every documented command exists and every documented behavior was observed.

## Change surface

All paths are **new** under `.agents/skills/vita3k-run-vpk/`.

| Path | Content |
| --- | --- |
| `SKILL.md` | Frontmatter and the agent workflow. |
| `agents/openai.yaml` | Codex interface metadata. Pattern: F2. |
| `references/install.md` | Vita3K installation per host, instance layout, firmware. |
| `references/evidence.md` | How to choose expectations and read the result. |

No file under `.claude/` changes (F6, and `AGENTS.md` rule: update `.claude/` only for a Claude-specific adapter).

## `SKILL.md`

Frontmatter:

- `name: vita3k-run-vpk`
- `description`: one paragraph that states what the skill does, when to use it, when not to use it, and the external requirements. Required content: runs a built PS Vita VPK in Vita3K and inspects the emulated filesystem and log; use after building a VPK to check boot and runtime behavior; do not use to build a VPK or to claim physical-device behavior; requires Python 3 and Vita3K, with install instructions included.

Body sections, in order:

1. **Workflow.** Numbered steps:
   1. Resolve this skill's directory from the loaded `SKILL.md`.
   2. Locate the VPK. Build it with the project's own script when it is missing or older than the source. Never bypass a project's clean-tree check.
   3. Run `doctor`. When `ready` is false, read `references/install.md`, perform the steps, and run `doctor` again.
   4. Derive expectations from the project before running. Read `references/evidence.md`.
   5. Run `run` with the expectations, `--seed` for input files, and `--clean` for evidence that must not carry over.
   6. Read the JSON result. For `fail` and `inconclusive`, read the files under `paths.run_dir`.
   7. Report the verdict, the VPK SHA-256, the emulator version, and the evidence that supports the verdict.
2. **Commands.** The two command lines, the option table, the exit-code table, and the environment variables `VITA3K_AGENT_HOME` and `VITA3K_BIN` from [02-runner-script.md](02-runner-script.md). Keep the tables identical to the implemented script. State the default timeout and that a run without `--stop-when-satisfied` lasts the full timeout. State that log expectations read the boot launch only. Do not document the test seams `VITA3K_VPK_HOST` and `VITA3K_VPK_INSTALL_TIMEOUT`.
3. **Invariants.**
   - A `pass` needs at least one expectation. Never report success from an `inconclusive` run.
   - Emulator evidence never proves physical-device behavior. State this in every report.
   - `environment_error` is not an app failure. Fix the environment or report the blocker.
   - Never run the skill as root. The script refuses.
   - An early stop proves only the part of the run before the stop. Use the full timeout when a late failure matters.
   - A `--reject-log` condition that did not match is not proof of absence. Log lines written just before the stop can be lost. Prefer file expectations.
   - Never download firmware or an emulator build from an unofficial source.
   - Never modify, stash, or commit in the VPK's repository as part of this skill.
   - One run at a time per instance.
4. **Reporting.** The report must name: verdict, reason, expectations with their results, fresh files, notable log lines, screenshot path when present, and each skipped step.

Write for both agents. Do not name Claude-only or Codex-only tools in `SKILL.md` (`.agents/README.md` portability rules). Use relative links to the references.

## `agents/openai.yaml`

Three keys under `interface`, following `.agents/skills/select-next-milestone/agents/openai.yaml`:

- `display_name`: `Vita3K Run VPK`
- `short_description`: at most 60 characters, for example `Run a Vita VPK in Vita3K and inspect evidence`.
- `default_prompt`: one sentence that uses `$vita3k-run-vpk` and asks to run the current project's VPK and report the verdict.

## `references/install.md`

Sections:

1. **Instance layout.** The `VITA3K_AGENT_HOME` tree per host, from [02-runner-script.md](02-runner-script.md). State that the skill never uses a personal Vita3K install.
2. **Linux aarch64 and x86_64.** Host packages are preconditions that need `sudo`. The agent asks the user to install a missing one and does not install it. The exact instance-scoped commands that G1 proved: create `emulator/`, download `Vita3K-aarch64.AppImage` from a numbered release of `Vita3K/Vita3K-builds` (F10), verify its SHA-256 against the release asset `digest` from the GitHub API, and make it executable. State the glibc rule: builds from 4112 on need glibc 2.43 (Ubuntu 26.04 or newer). On a host with an older glibc, use build 4111. Give the check command `ldd --version` and the failure text `version 'GLIBC_2.43' not found`. On a host with glibc 2.43 or newer, the newest build is expected to work and is marked `not run`. Describe `--appimage-extract` as the untested fallback for a host without `libfuse2t64`. List the required host packages from the G1 observations, with Ubuntu 24.04 package names. The list from G1 is `xvfb`, `x11-apps` for `xwd`, `libgl1-mesa-dri` for software OpenGL, and `libfuse2t64` for the direct AppImage form. G1 needed no other package on this host. Whether the AppImage runs without `libfuse2t64` is untested. Mark the whole x86_64 path `unverified`: the asset name comes from the release listing and no x86_64 host ran it.
3. **Headless Linux.** The renderer profile that G1 chose: software OpenGL through Mesa. State that software Vulkan boots the app and leaves the game window black in screenshots, and that the NVIDIA profiles were not tried.
4. **macOS.** Download `macos-arm64-latest.dmg` or `macos-latest.dmg`, copy `Vita3K.app` into `emulator/`, create `emulator/portable/`, and remove the quarantine attribute. Mark every macOS step `unverified until gate G2` until [04-acceptance-gates.md](04-acceptance-gates.md) G2 passes. After G2, replace the marker with the G2 date.
5. **Firmware (optional).** State when it is needed: an app fails with missing system modules or fonts. State that the two `os0:kd/*.skprx` error lines appear in every firmware-free run and are harmless. State the source: Sony's system-software page linked from Vita3K's quickstart (F21). State the command: the emulator's `--firmware <file.pup>` option, run with the same isolation environment as `run`. State that the font package has no documented official URL and needs the user. The agent asks the user for firmware files. It does not search for them.
6. **Updating and removing.** Replace the file under `emulator/` to update. Delete `VITA3K_AGENT_HOME` to remove everything.
7. **Verification.** `doctor` must print `"ready": true`.

The references restate gate results in their own words. They never link to or name a file under `.agents/plans/` (D14).

Every command in `references/install.md` must have been executed during WP1, WP5, or G2. Mark any command that was not executed as `not run`, with the reason.

## `references/evidence.md`

Sections:

1. **Evidence channels.** Emulated filesystem diff, log summary, screenshot. For each: where it is in the result, what it proves, and what it cannot prove. State that `fs_diff` covers `ux0:` outside `ux0:app`, that a write under `ux0:app` needs an explicit expectation, and that other devices such as `ur0:` are not examined.
2. **Choosing expectations.** Procedure: search the project for `ux0:` writes and for log or stderr output at startup. Prefer a file whose content identifies the build (for example a source SHA). Add `--reject-log` for the project's own error strings. When the app leaves no file and no log line, state that only `inconclusive` is possible and propose that the project add a startup breadcrumb. Do not add the breadcrumb as part of this skill.
3. **Project patterns.** A table grounded in F22–F24:

   | Project type | Build output | Typical evidence |
   | --- | --- | --- |
   | Rust with `cargo-vita` (bevypoc) | `target/armv7-sony-vita-newlibeabihf/release/<bin>.vpk` | `ux0:data/bevypoc/build.txt` contains the source SHA. `server.txt` is seeded with `--seed`. Without it the log repeats `*** TTY: SpacetimeDB unavailable: ` and the screen shows `ERR`. Exercised in G1. |
   | Rust with `cargo-vita` (vitair) | same layout, `vitair-app.vpk` | `ux0:data/vitair/startup.log` gains lines of the form `<source SHA> <message>`. The file is append-only, so the expectation matches appended lines only. The on-screen `ux0:` listing needs the screenshot. |
   | Nim with VitaSDK script (clckr spike) | path set by the project's `scripts/build_vita.sh` | Breadcrumb file `ux0:data/clckr_vita_spike.txt`. The last line names the last step reached. |
   | Nim with network client (topdown) | same | Host `127.0.0.1` reaches a server on the same machine only inside the emulator. |

   Mark the vitair row and the Nim rows `not exercised` until a VPK of that project was run through the skill. The vitair row also states that vitair's README requires firmware in Vita3K.
4. **Reading the log.** Line format (F18), level letters, the duplicate filter, and these facts from G1:
   - app stdout and stderr appear as `*** TTY: <text>` lines, and one print call becomes several lines, so a regex must target one fragment (for bevypoc: the SHA line, not `bevypoc source commit: <sha>`);
   - boot markers: `App session phase: Launching -> Running` and `Game started: <title> (<TITLE_ID>)`;
   - every file access is logged, including `Missing file at "<host path>" (target path: ux0:...)`, which shows what the app tried to read;
   - error-level lines occur in healthy runs: the two `os0:kd/*.skprx` lines without firmware, and one `Missing file at` line for every file that the app probes and does not find. Never use the mere presence of `|E|` lines as a failure signal;
   - the Qt and Mesa lines without a timestamp are noise;
   - `vita3k.log` is often short or empty, and `emulator-stdout.log` is the log to read.
5. **Failure classes.** A table with one row per class, its signature in the result, and the next action:
   - `environment_error` codes from [02-runner-script.md](02-runner-script.md);
   - verdict `fail` with reason `emulator_crashed`: in the boot launch the emulator ended by itself with a non-zero status, for example 139 for a segmentation fault. Read the log tail and the exit code. The cause can be the app or the emulator;
   - `interrupted`: the script was signalled. Rerun;
   - `install_failed`: read the install log tail in the result. A `GLIBC_… not found` line means the Vita3K build is too new for the host;
   - install succeeded, no fresh files, error lines in the log: the app failed or stalled before writing its evidence;
   - install succeeded, log shows missing modules or unimplemented imports: emulator limitation or missing firmware (R4), not an app defect until proven on hardware;
   - expectation file exists but is not fresh, or the expected text is only in the old part of an appended file: stale evidence from an earlier run;
   - `isolation_violated`: a personal Vita3K ran during the run, or the emulator ignored the isolation settings. Rerun with the personal Vita3K closed. If it repeats, treat it as an emulator change (R3) and stop;
   - network-dependent expectation unmet: check the seeded server address and that the host service runs.
   Use only log strings that were observed in a real run. Do not invent signatures.
6. **Limits.** Emulator results never prove device behavior. Software rendering affects timing. Controller and touch input are unavailable.

## Acceptance criteria

1. `SKILL.md` frontmatter parses as YAML and has exactly the keys `name` and `description`. Check with the method used for the other skills: `python3 -c` with a small frontmatter split, or the repository's existing tooling if one exists at implementation time.
2. Every relative link in `SKILL.md` and both references resolves to an existing file.
3. Every command, option, exit code, and JSON field named in the documents exists in `scripts/vita3k_vpk.py`. Add a test `tests/test_docs.py` (**new**) that extracts each `--option` token from `SKILL.md` and asserts that `build_parser()` accepts it, that each exit code in the table matches the `EXIT_*` constants, that no file under the skill contains the text `agents/plans` (the test builds that search string from two parts, so the test file itself does not match), and that every macOS step in `references/install.md` carries either the `unverified until gate G2` marker or a verification date.
4. `grep -rn "Claude\|Codex" .agents/skills/vita3k-run-vpk/SKILL.md .agents/skills/vita3k-run-vpk/references` returns no tool-specific instruction. `agents/openai.yaml` is the only adapter file.
5. No document contains an absolute path of this host. Paths use `$VITA3K_AGENT_HOME`, `$HOME`, or skill-relative form.
6. `~/.agents/skills/vita3k-run-vpk`, `~/.claude/skills/vita3k-run-vpk`, and `~/.codex/skills/vita3k-run-vpk` are symlinks to the new skill directory. Create exactly these three links with `ln -snf <checkout>/.agents/skills/vita3k-run-vpk <target>`. This is what `link_children` does for one child (F4), without relinking commands, hooks, and rules, and without the tool installs in `setup_agent_tools`. The link functions default to `$HOME/git/dotfiles/.agents` (`DOTFILES_AGENT_ROOT`), so they do not see a skill that exists only in another worktree. When `<checkout>` is a temporary worktree, re-point the three links to `$HOME/git/dotfiles/.agents/skills/vita3k-run-vpk` after the branch is merged, and state this in the final report. Together with WP5 step 12 this proves S8.

## Risks and exclusions

- Documentation can drift from the rolling Vita3K release (R3). Each reference states the Vita3K version string and date it was verified against.
- Excluded: a README index entry. No skill index exists in this repository (F1, F6).
- Excluded: a Claude command file under `.agents/commands/`. The skill is invoked by name.
