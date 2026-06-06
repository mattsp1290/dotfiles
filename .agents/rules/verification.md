# Verification

Never mark work done on compile-success alone. "It builds" is not "it works."
The defects that slip through are exactly the ones a compile can't see:
first-run-only behavior, device-only rendering, smoke-test failures, broken
links, runtime panics on the happy path.

## The bar for "done"

Before declaring a task complete, empirically confirm — and report — the
relevant subset of:

- **Build** passes (all targets, not just the one you touched).
- **Tests** pass — run them, don't assume. If tests exist and you didn't run
  them, the task is not verified.
- **Lint / vet / type-check** is clean for the changed surface.
- **Runtime behavior** actually does the thing: run the app/command and observe
  the result, not just the exit code. Use `/verify` or `/run` where they fit.
- **On-device / on-hardware** when the target is embedded or platform-specific
  (devkitARM, emulator, physical device) — platform defects don't reproduce on
  the host.
- **Links / external refs** resolve, when the change adds them.

## Reporting

Report results honestly and specifically:

- If a gate fails, say so with the output. Do not proceed as if clean.
- If a step was skipped, say it was skipped and why — don't imply coverage you
  didn't run.
- Only state "done/verified" for what you actually exercised. No hedging when
  it genuinely passed; no false confidence when it didn't.

## Shell hygiene that protects verification

- Run chained remote/verification steps as **separate, individually-checked
  commands** (or `set -e`). A compound `a && b && push` can mask a mid-step
  failure and report success on an unverified result.
- After a push, confirm it landed: `git status` must show up to date with
  origin before you call it pushed (see [[git-conventions]]).

This is the exit gate of the [[review-workflow]] pipeline: implement → fix →
**verify** → commit.
