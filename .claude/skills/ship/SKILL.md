---
name: ship
description: >-
  Run the full review-fix-verify-push pipeline on the current branch:
  invokes /review for dual-AI feedback, applies Critical and Important
  findings via /fix-review --auto, runs CI-discovered build/test/lint
  as a verification gate, commits selectively (excluding settings.local.json
  and unrelated drift), pushes to origin, and creates a draft PR if one
  does not already exist. Use when ready to ship a feature branch for
  review. Reports the actual commit SHA via git rev-parse and the actual
  PR URL via gh — never fabricates either.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, AskUserQuestion, Skill
---

# Ship Skill

End-to-end pipeline that takes a feature branch from "ready for review" to "pushed with a draft PR open and a green verification gate." Composes the existing `/review` and `/fix-review` skills rather than duplicating their logic; adds a CI-discovered verification gate, selective commit, push, and PR creation on top.

## Arguments

Parse `$ARGUMENTS` for optional flags:

- `--skip-review`: Skip Phase 2. Use when `/review` was already run for this branch and you want fix-review + verify + ship only.
- `--no-pr`: Skip Phase 6's PR creation step (push only).
- `--skip-fix`: Skip Phase 3 (use after manual fixes when only verify + commit + push remain).

If absent, run the full pipeline.

## Prerequisites

The pipeline aborts early if any of these fail:

1. **Working directory matches repo root.** Run `pwd` and `git rev-parse --show-toplevel`. If they disagree, abort: "Run /ship from the repo root."
2. **Not on a default branch.** Run `git rev-parse --abbrev-ref HEAD`. If it equals `main`, `master`, `develop`, or `trunk`, abort: "/ship doesn't operate on default branches. Switch to a feature branch."
3. **Origin remote exists.** Run `git remote get-url origin`. If missing, abort: "No origin remote — push target unknown."

## Phases

Each phase has explicit entry/exit criteria. If a phase's exit criteria are not met, the skill aborts with a structured failure report — it does NOT proceed to the next phase.

### Phase 1 — Pre-flight

**Entry:** prerequisites passed.

**Actions:**
1. Capture the branch name: `BRANCH=$(git rev-parse --abbrev-ref HEAD)`.
2. Capture the upstream base ref: `BASE=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||')` — fall back to `main` if unset.
3. Capture initial dirty state: `git status --porcelain` → save as PRE_STATUS for later selective-staging diff.
4. Fetch origin to ensure base ref is current: `git fetch origin`.

**Exit:** `BRANCH`, `BASE`, and `PRE_STATUS` captured; origin fetched.

### Phase 2 — Review (delegated to /review)

**Entry:** Phase 1 complete and `--skip-review` not set.

**Actions:**
1. Invoke the `review` skill via the Skill tool — equivalent to running `/review`. `/review` writes a dual-reviewer artifact tree to `./reviews/<sanitized-branch>-<YYYY-MM-DD>/{opus,chatgpt}/`.
2. After `/review` returns, locate the freshest review directory: `ls -1d ./reviews/${BRANCH//\//-}-* 2>/dev/null | sort | tail -n1`.
3. Verify both `opus/04-action-items.md` and `chatgpt/04-action-items.md` exist and are non-empty.

**Skip:** if `--skip-review` was passed, locate the freshest existing review directory using the same `ls` command. If none exists, abort: "/ship --skip-review needs an existing review under ./reviews/. Run without the flag, or run /review first."

**Exit:** review artifact directory exists with both reviewers' action-items files.

### Phase 3 — Fix (delegated to /fix-review)

**Entry:** Phase 2 produced a usable review artifact, and `--skip-fix` not set.

**Actions:**
1. Invoke the `fix-review` skill via the Skill tool with the `--auto` argument — equivalent to running `/fix-review --auto`. Auto mode applies all selected items but flags auth/secrets/credentials/permissions/config files as **needs-manual** rather than auto-editing them.
2. Capture fix-review's structured summary line: `<!-- auto-summary fixed:N skipped:N needs-manual:N -->`.
3. If `needs-manual:N` where `N > 0`, abort: "/ship aborted: fix-review flagged sensitive files for manual review. Address them, then re-run with `/ship --skip-fix`."
4. Run `git diff --stat` to confirm changes were applied.

**Skip:** if `--skip-fix` was passed, proceed directly to Phase 4 with whatever changes are already in the working tree.

**Exit:** fix-review completed with `needs-manual:0`, OR fix-review reported nothing to fix, OR `--skip-fix` was set.

### Phase 4 — Verify (CI-discovered)

**Entry:** Phase 3 complete (or skipped).

**Actions:**

#### 4a. Discover what CI runs

Read CI configuration to learn what the project actually runs (this beats hardcoded fallback tables):

1. Glob `.github/workflows/*.yml` and `.github/workflows/*.yaml`.
2. For each workflow file, extract:
   - Build/compile commands.
   - Test commands with feature flags or build tags (e.g., `cargo test --features foo,bar`, `go test -tags=integration`).
   - Lint and format commands.
   - **Codegen-sync** steps: any pattern like `<gen-command> && git diff --exit-code`. Record the gen-command for Phase 4d.
   - Docs build commands (e.g., `make site`, `mkdocs build`).
3. Read `Makefile` (if present). Cross-reference targets used in CI — those are the ones that matter.
4. Read repo-root `CLAUDE.md` (if present) for project-defined quality gates.

Store discovered commands as `VERIFY_CMDS`. They take priority over fallbacks.

#### 4b. Fall back per language if CI config absent

If `VERIFY_CMDS` is empty, detect language from manifest files and use these fallbacks (a multi-language repo runs all matching tables):

| Language | Manifest | Build | Test | Lint | Format | Vet/Types |
|----------|----------|-------|------|------|--------|-----------|
| Go | `go.mod` | `go build ./...` | `go test ./...` | `golangci-lint run` | `gofmt -l .` | `go vet ./...` |
| Rust | `Cargo.toml` | `cargo build` | `cargo test` | `cargo clippy -- --deny warnings` | `cargo fmt --check` | — |
| Python | `pyproject.toml` / `setup.py` | — | `pytest -q` | `ruff check` | `ruff format --check` | `ty check` |
| Node/TS | `package.json` | per project | per project | `oxlint` | `oxfmt --check` | `tsc --noEmit` |

#### 4c. Run the verification gate

Run discovered/fallback commands sequentially in this order: build → test → lint → format → vet/types.

On the first non-zero exit:
1. Read the failure output and attempt **one** targeted auto-fix pass — formatter for format failures (`gofmt -w .`, `cargo fmt`, `ruff format`); nothing for build/test/lint failures (those need human judgment).
2. Re-run only the failed command. If still failing, abort: "/ship verification gate failed at: `<command>`. Output: `<last 30 lines>`."

If a tool is not installed (binary not on PATH), skip with a note rather than aborting. Skipped commands are reported as "skipped (tool not installed)" in the final report — never as "passed."

#### 4d. Codegen sync

For every codegen-sync command discovered in 4a, run it then `git diff --exit-code`. If diff is non-empty, the generated files are stale. Stage the regenerated diff into the working tree (it will be picked up in Phase 5).

**Exit:** every executed verification command exited 0; codegen is in sync.

### Phase 5 — Commit (selective)

**Entry:** Phase 4 green.

**Actions:**
1. Run `git status --porcelain` to enumerate all modified/untracked files.
2. Build the **stage list** by including only files whose state changed since `PRE_STATUS` (i.e., files modified by /fix-review in Phase 3 or codegen sync in Phase 4d). Files in `PRE_STATUS` that weren't touched during this run are pre-existing drift — exclude them.
3. **Always exclude** these patterns regardless of state:
   - `.claude/settings.local.json`
   - `*.md5`
   - `frontend/dist/`, `frontend/wailsjs/`, generated frontend assets
   - `*.lock` files that were not intentionally regenerated by the verification gate
4. Stage selected files explicitly by path with `git add --` (NOT `git add -A` or `git add .`).
5. Show the user the staged diff summary via `git diff --staged --stat` and the list of excluded files.
6. Compose the commit message:

   ```
   fix: address review findings on <BRANCH>

   Findings addressed (review: <review-dir>):
   - Critical: <fixed-count> fixed
   - Important: <fixed-count> fixed
   - Suggestions: <fixed-count> fixed
   - Dismissed: <count> with reasoning

   Verified:
   - <command> ✓
   - <command> ✓
   ```

7. `git commit -m "<message>"`. **Never** use `--no-verify` or `--no-gpg-sign`. If the commit hook fails, fix the underlying issue and create a NEW commit (do not amend — the commit didn't happen, so amend would modify the previous commit).
8. **Verify the commit landed:** `SHA=$(git rev-parse HEAD)`. This is the only authoritative source for the SHA in any subsequent reporting.

**Exit:** new commit exists; `SHA` captured from `git rev-parse HEAD`.

### Phase 6 — Push and PR

**Entry:** Phase 5 produced a commit.

**Actions:**
1. `git push origin HEAD` (regular push). If push is rejected (remote diverged), do NOT force-push automatically — abort and use `AskUserQuestion` to ask the user how to proceed (rebase, merge, force-push with-lease, or cancel).
2. Detect existing PR for this branch:
   ```bash
   PR_JSON=$(gh pr view --json url,number,state 2>/dev/null) || PR_JSON=""
   ```
3. **If `PR_JSON` is empty AND `--no-pr` not set:**
   - Run `gh pr create --draft --fill`. Capture stdout — gh prints the PR URL on the last line.
   - Parse the actual URL/number from stdout. Never compose URLs from owner/repo/branch.
4. **If `PR_JSON` is non-empty:**
   - Post a comment summarizing the ship: `gh pr comment <number> --body "<summary>"`. Body uses the structured findings table from /review's `04-action-items.md`.
5. Report final state to the user:
   - **Branch:** `$BRANCH`
   - **Commit SHA:** `$SHA` (from `git rev-parse HEAD`)
   - **PR:** actual URL from `gh` stdout (or "no PR — pushed only" if `--no-pr` was set)
   - **Verification:** list of commands that actually executed and passed in Phase 4

**Exit:** branch pushed; PR exists or was just created; final report shown with ground-truthed values.

## Anti-hallucination guarantees

These rules are non-negotiable:

- **SHAs:** the only valid source is `git rev-parse HEAD` AFTER the commit completes. Never report a SHA from message buffers, plans, memory, or guesses.
- **PR URLs and numbers:** the only valid source is the JSON output of `gh pr view --json` or the stdout of `gh pr create`. Never compose URLs from `owner/repo/branch` patterns.
- **Verification commands run:** only commands that actually executed and exited 0 may be reported as "passed." Skipped commands (tool not installed) are reported as skipped. Never claim a command passed if it didn't run.
- **Failure mode:** any phase failure aborts the skill and surfaces the exact failing command + its last 30 lines of output. The skill never silently continues past a failed gate.

## Failure recovery

If the skill aborts mid-pipeline, resume with the matching flags below — none of the earlier phases need to re-run.

| Aborted at | Resume with |
|------------|-------------|
| Phase 2 (review) | `/ship` (or `/review` directly to debug) |
| Phase 3 (fix-review) | Address `needs-manual` items by hand, then `/ship --skip-review --skip-fix` |
| Phase 4 (verify) | Fix the failing command manually, then `/ship --skip-review --skip-fix` |
| Phase 5 (commit) | Fix commit-hook issue, then `/ship --skip-review --skip-fix` |
| Phase 6 (push) | Resolve remote conflict (rebase/merge/force-with-lease), then `/ship --skip-review --skip-fix --no-pr` |

## Out of scope

- Squashing commits before push — the skill preserves review history as a separate commit.
- Merging or auto-merging the PR — that's an explicit human gate.
- Stacked PRs — use the `pr-splitter:split-pr` skill for that.
- Force-push — the skill never force-pushes without an explicit `AskUserQuestion` confirmation.
- Signing fixups for unsigned upstream commits — use the `fix-signing` skill before invoking `/ship` if the branch has unsigned commits.
