# 05 — Execution handoff

Terms are defined in [00-overview.md](00-overview.md). WP1 is complete (2026-10-02, gate G1 passed, record in [G1.md](G1.md)). No skill code exists. Start with WP2.

Host state left by WP1: VitaSDK at `/usr/local/vitasdk`, Rust `nightly-2026-04-08`, `cargo-vita 0.2.2`, `libfuse2t64`, and the instance at `$HOME/.vita3k-agent` with Vita3K build 4111 and bevypoc installed. `$HOME/.vita3k-agent/g1-artifacts/` holds the G1 harness, a working XWD-to-PNG converter (`xwd2png.py`), a real 1280x800 dump (`runs/p2r/screen.xwd`), and real logs (`runs/*/stdout.log`). Use the converter and the logs as the starting point for `xwd_to_png` and for `tests/fixtures/vita3k-sample.log`. Replace `$HOME` in every path before committing a log excerpt.

## Before starting

1. Confirm the repository: `pwd` and `git remote -v` must show the dotfiles repository.
2. Use the existing branch `feat/vita3k-run-vpk-skill`, which holds this plan. Do not commit to `main`.
3. Leave `.agents/skills/select-next-milestone/scripts/__pycache__/` alone. It is unrelated untracked noise (F5).
4. Read `AGENTS.md` and `.agents/README.md`.

## Work packages in dependency order

| WP | Result | Detail | Prerequisites | Changes |
| --- | --- | --- | --- | --- |
| WP1 (done) | Gate G1 decided, recipe recorded | [01](01-fixture-and-headless-gate.md) | Met: the user approved the host installs. | `.agents/plans/vita3k-run-vpk/G1.md` (**new**) |
| WP2 | Host-independent core with unit tests | [02](02-runner-script.md) | None | `scripts/vita3k_vpk.py`, `tests/test_core.py`, `tests/fixtures/xvfb-root.xwd`, `.gitignore` (all **new**) |
| WP3 | `run` and `doctor` work with the stub and follow the G1 recipe | [02](02-runner-script.md) | WP2, G1 go, `G1.md` complete | `scripts/vita3k_vpk.py`, `tests/test_run.py`, `tests/stub_vita3k.py`, `tests/fixtures/vita3k-sample.log` (**new**) |
| WP4 | Skill documents | [03](03-skill-documents.md) | WP3 | `SKILL.md`, `agents/openai.yaml`, `references/install.md`, `references/evidence.md`, `tests/test_docs.py` (all **new**) |
| WP5 | Linux end-to-end acceptance | [04](04-acceptance-gates.md) | WP3, WP4, fixture VPK | `.agents/plans/vita3k-run-vpk/A1-linux.md` (**new**), reference corrections |
| WP6 | macOS gate G2 | [04](04-acceptance-gates.md) | WP3, WP4, a Mac | `.agents/plans/vita3k-run-vpk/G2.md` (**new**), reference updates |

All skill paths are under `.agents/skills/vita3k-run-vpk/` (**new**).

## Ordering and parallelism

- WP1 is done. WP2 has no open prerequisite.
- WP3 and WP4 touch the same contract. Do them sequentially, in one agent.
- WP5 and WP6 are independent of each other. WP6 needs a different host.
- Do not run the skill tests while another agent writes files in the skill directory.
- Only one real emulator run at a time per instance. Do not run WP1 checks and WP5 steps concurrently.

## Verification per work package

| WP | Command or procedure | Pass condition |
| --- | --- | --- |
| WP1 (done) | Checks 1–14 in [01](01-fixture-and-headless-gate.md) | `G1.md` complete, decision go. Met on 2026-10-02. |
| WP2 | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .agents/skills/vita3k-run-vpk/tests -p 'test_core.py'` | Exit 0 |
| WP3 | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .agents/skills/vita3k-run-vpk/tests` | Exit 0, no leftover process, no `__pycache__` in `git status` |
| WP3 | `python3 -m py_compile .agents/skills/vita3k-run-vpk/scripts/vita3k_vpk.py` | Exit 0 |
| WP4 | Acceptance criteria 1–6 in [03](03-skill-documents.md) | All hold |
| WP4 | Create the three skill symlinks with `ln -snf`, as acceptance criterion 6 in [03](03-skill-documents.md) describes | Three skill symlinks resolve to the new skill directory |
| WP5 | Steps 1–12 in [04](04-acceptance-gates.md) | `A1-linux.md` complete |
| WP6 | Steps 1–8 in [04](04-acceptance-gates.md) on a Mac | `G2.md` complete, decision pass |

Run each verification command separately and check its exit status. Do not chain them with `&&` into a push.

## Integration and regression gates

1. Existing skill tests still pass: `python3 -m unittest discover -s .agents/skills/select-next-milestone/tests` exits 0. On 2026-10-02 it ran 26 tests with result OK.
2. `git status --short` shows only files under `.agents/skills/vita3k-run-vpk/` and `.agents/plans/vita3k-run-vpk/`, plus the pre-existing untracked path from F5.
3. `git diff --stat main -- scripts/ .claude/ setup.sh setup-linux.sh` is empty. This plan changes none of them.
4. No Vita3K data exists outside `VITA3K_AGENT_HOME` on the Linux host (WP5 step 10).

## Review and commit

- Follow the repository review workflow before each commit that changes more than one file: run the dual review, apply agreed findings, re-verify.
- Suggested commits: one for WP2, one for WP3, one for WP4, one for the gate and acceptance records with their document corrections.
- Commit messages follow the existing style, for example `feat(agents): add vita3k-run-vpk skill`. The body explains why.
- Push the feature branch and open a pull request. Do not push to `main` without explicit user approval.

## Definition of done

1. S1–S4, the aarch64 Linux part of S5, S7, and S8 are proven by WP5 and the test suite on the Linux host.
2. S6 and the macOS part of S5 are proven by G2 on a Mac. The plan is not done while G2 is open. Until then the work is reported as "Linux complete, macOS gate open". The only other way to close the plan is the user's explicit acceptance of macOS as unsupported after a failed G2.
3. `G1.md`, `A1-linux.md`, and `G2.md` exist with their required content.
4. Every command in `references/install.md` was executed, or is marked `not run` with the reason.
5. The documents state the Vita3K version and date they were verified against.
6. The integration and regression gates hold.
7. The final report lists each gate result, each skipped step with its reason, and the caveat that emulator evidence does not prove device behavior.

## Decision owners

| Decision | Owner | When |
| --- | --- | --- |
| Supply a fixture VPK or approve VitaSDK installation on the Linux host | User | Start of WP1 |
| G1 no-go alternatives | User | End of WP1, only on no-go |
| Supply firmware files, if an app needs them | User | On demand |
| Install a missing host package (needs `sudo`) | User | On demand, WP1 |
| Run G2 on a Mac | User | After WP4 |
| Accept "macOS unsupported" if G2 fails without a fix | User | End of WP6, only on failure |

## Deferred work and follow-ups

- Nim and vitaGL acceptance (R4). Needs a Nim VPK from `birbparty/clckr` or `birbparty/topdown`, which needs `nim`, VitaSDK, and raylib4Vita on the build host. Optional step in WP5, by user decision. Until it runs, no evidence shows that Vita3K boots these apps.
- vitair acceptance. Optional step in WP5. vitair's README requires firmware in Vita3K.
- Running as root, for example in a container. The script refuses (D12).
- x86_64 Linux verification. Documented, not run.
- A committed per-project expectations file, so a repository can declare its own success signals. Deferred until two projects need the same expectations repeatedly.
- Startup breadcrumbs in consumer apps that show results only on screen (vitair). A change in those repositories. Not requested here.
- Scripted controller or touch input.
- Screenshots on macOS or on Linux with a host display.
- A newer Vita3K on this host (R9). Builds after 4111 need glibc 2.43. Options: upgrade the host to Ubuntu 26.04, run the emulator in a container, or build from source.
- The NVIDIA renderer profiles and the extracted AppImage form. Not tried in G1.
- Windows hosts.
- A root `.gitignore` for `__pycache__` across all skills (F5).
