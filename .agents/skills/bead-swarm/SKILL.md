---
name: bead-swarm
description: Autonomous Beads task-graph execution loop for Codex. Use when the user invokes `/goal /bead-swarm`, asks to work through ready Beads tasks, or wants a Ralph-like multi-agent loop that selects independent ready beads, delegates implementation to subagents, validates, runs two independent reviews, merges a clean iteration, and repeats until the task graph is complete or human intervention is required.
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# /bead-swarm -- Beads-first multi-agent work loop

Run a Ralph-like autonomous development loop over Beads. The parent Codex agent supervises; each iteration is delegated to one orchestrator subagent, which may spawn worker and reviewer subagents for one safe batch of ready beads. The orchestrator must finish one iteration and return control to the parent so the parent can inspect git and Beads state before continuing.

## Codex Subagent Requirement

This skill requires Codex multi-agent tools. Use Codex subagent tooling, such as `spawn_agent`, `wait_agent`, `send_input`, and `close_agent`, when those tools are available. Do not assume Claude-only `Agent` or `Skill` tools exist. If Codex subagent tools are not available, stop and report that `/bead-swarm` cannot run because the requested parent-orchestrator-worker topology is unavailable.

When invoking existing skills such as `review` or `fix-review`, use whatever Codex skill invocation mechanism is available in the session. If no skill invocation tool exists, read that skill's `SKILL.md` and perform its workflow directly.

## Invocation Contract

`/goal /bead-swarm` is the intended invocation. Treat the `/goal` wrapper as the durable objective: keep relaunching clean iterations until there are no ready beads left, a real blocker needs the human, or git state is not safely recoverable.

Invoking this skill authorizes, within the repository and selected Beads only:

- Creating `bead-swarm/iteration-*` branches.
- Spawning orchestrator, implementation, and review subagents.
- Committing generated changes on the iteration branch.
- Pushing the iteration branch.
- Merging the iteration branch into the configured main branch with the Ralph no-fast-forward protocol.
- Pushing the configured main branch and deleting the iteration branch.
- Closing Beads only after the implementation is present on the configured main branch.

This does not authorize force-pushes, destructive resets of user work, bypassing branch protection, running concurrent autonomous loops, or sweeping unrelated dirty files into commits.

## Arguments

Parse any user text after the skill name:

- No arguments: process ready beads in conservative batches until complete.
- Bead IDs: restrict the next batch to those beads, but only if they are ready and mutually safe.
- `use <branch> as the main branch` or `--main-branch <branch>`: use `<branch>` as `BEAD_SWARM_MAIN_BRANCH` for this run. This explicit override takes precedence over `.ralph`.
- `--single`: run one bead only, then stop after the parent post-iteration check.
- `--max-workers N`: cap implementation workers for one batch. Default: `3`.
- `--no-push`: run implementation, validation, and review, but do not push, merge, or close beads. Stop on the iteration branch with a clean local checkpoint and report the exact resume command.

## Parent Supervisor Loop

The parent agent owns the outer loop. Do not let one long-running orchestrator work through the whole graph without returning.

### 1. Resolve Main Branch

Resolve `BEAD_SWARM_MAIN_BRANCH` with this precedence:

1. Explicit user argument: `use <branch> as the main branch` or `--main-branch <branch>`.
2. Active iteration metadata, only when resuming from a `bead-swarm/iteration-*` branch and `.agents/bead-swarm/iteration.json` names the current branch.
3. `.ralph` `main_branch`, exactly as `/ralph` resolves `RALPH_MAIN_BRANCH`.
4. `main`.

Validate the resolved branch with `git check-ref-format --branch "$BEAD_SWARM_MAIN_BRANCH"`. Record both the branch and the source of the decision in the parent log, orchestrator prompt, and `.agents/bead-swarm/iteration.json`.

Local-only main branches are allowed only when the branch came from an explicit user override. If `origin/BEAD_SWARM_MAIN_BRANCH` exists, normal fast-forward checks apply. If the remote branch does not exist and the branch was explicitly overridden, the end-of-iteration push may create `origin/BEAD_SWARM_MAIN_BRANCH`; report that in the summary. Do not silently treat a local-only `.ralph` branch as safe to publish.

```bash
BEAD_SWARM_MAIN_BRANCH="main"
BEAD_SWARM_MAIN_BRANCH_SOURCE="default"
if [[ -f ".ralph" ]]; then
  _cfg=$(awk -F= '$1 == "main_branch" {print $2; exit}' .ralph 2>/dev/null)
  if [[ -n "$_cfg" ]]; then
    BEAD_SWARM_MAIN_BRANCH="$_cfg"
    BEAD_SWARM_MAIN_BRANCH_SOURCE=".ralph"
  fi
fi
```

### 2. Acquire A Local Loop Lock

Create an untracked repo-local lock before spawning an orchestrator:

```bash
LOCK_DIR="$(git rev-parse --git-dir)/bead-swarm.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another bead-swarm session appears to be running: $LOCK_DIR" >&2
  exit 1
fi
printf '%s\n' "$$" > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT
```

If a stale lock exists and there are no `bead-swarm/iteration-*` branches and no running process matching its PID, remove it and retry once. Do not remove a lock while another autonomous session may still be active.

If a stale lock exists while the current branch is already `bead-swarm/iteration-*`, verify the PID is not running, remove only the stale lock, and continue to **Resume Existing Iteration**. A stale lock must not prevent recovery of an interrupted iteration branch.

### 3. Preflight Or Resume

Run these checks before each new orchestrator:

- Inside a git repo.
- `origin` exists unless `--no-push` is set.
- `.agents/reviews/` is untracked and excluded in `.git/info/exclude`.
- Any `.agents/bead-swarm/iteration.json` found on the main branch is advisory history only. Treat it as active metadata only when the current branch is `bead-swarm/iteration-*` and its `branch` field matches the current branch.
- No concurrent autonomous branch exists locally or remotely:
  - `ralph/iteration-*`
  - `bead-swarm/iteration-*`
  - `bead-swarm/recovery-*`

Exception: if the current branch itself is `bead-swarm/iteration-*`, do not start a new iteration. Enter **Resume Existing Iteration** below.

For normal new iterations:

- Current branch must be `BEAD_SWARM_MAIN_BRANCH`.
- Worktree must be clean.
- Local branch can fast-forward from `origin/BEAD_SWARM_MAIN_BRANCH` when that remote branch exists.
- If `origin/BEAD_SWARM_MAIN_BRANCH` does not exist, continue only when the branch came from an explicit user main-branch override or `--no-push` is set.

### Serialized Beads Operations

All `bd` commands must run serially. Do not run `bd` commands through parallel tool wrappers, and do not let workers or reviewers run `bd` commands unless the orchestrator explicitly delegates one serialized operation and waits for it to finish. This avoids embedded-Dolt exclusive-lock failures.

If `bd dolt pull` fails because embedded mode cannot infer a branch, record the exact failure. Continue only after serial `bd ready` and any required `bd show <id>` commands succeed. Do not invent raw Dolt commands or branch names unless the repository documents them.

### 4. Query Ready Work

- Prefer `bd ready --json --limit 20`.
- If JSON is unavailable, use `bd ready --plain --limit 20` and inspect each candidate with `bd show <id>`.
- If Beads is unavailable or uninitialized, stop. This skill is Beads-first, unlike `/ralph`.

If there are no ready beads:

- Run `bd list --json` or `bd blocked` if available to identify open blocked work.
- If no open actionable work remains and git is clean on `BEAD_SWARM_MAIN_BRANCH`, report completion and, when the goal tool is available, mark the goal complete.
- If open work remains but all of it is blocked/deferred/hooked, report the blocking beads and stop for human input.

### 5. Spawn One Orchestrator

Spawn one orchestrator subagent for one iteration. Pass:

- This skill path.
- Resolved `BEAD_SWARM_MAIN_BRANCH`.
- Requested bead IDs or filters.
- `--max-workers`.
- Whether `--single` or `--no-push` was set.
- A directive to return a structured summary and not continue into another iteration.

After the orchestrator exits, inspect:

- `git branch --show-current`
- `git status --porcelain`
- `bd ready --json --limit 20` or fallback ready output

While the orchestrator is running, wait in bounded intervals. If it runs longer than 5 minutes without completion, the parent may inspect git state read-only and send one status request asking for:

- current phase
- current branch
- clean/dirty state
- last validation or git command
- blocker, or `none`

Do not run parallel `bd` commands during heartbeat checks. Move to recovery only when branch state and lack of orchestrator response indicate a real stall.

Decide:

- Clean on `BEAD_SWARM_MAIN_BRANCH` and ready beads remain: spawn the next orchestrator unless `--single` was set.
- Clean on `BEAD_SWARM_MAIN_BRANCH` and no ready/open actionable beads remain: complete.
- Clean on `BEAD_SWARM_MAIN_BRANCH` but only blocked work remains: stop as blocked with exact bead IDs and reasons.
- Clean on an iteration branch because `--no-push` was set: stop intentionally and report the branch, pending beads, and next command.
- Dirty or unexpectedly on an iteration branch: run the recovery protocol.

## Resume Existing Iteration

Use this path when `/goal /bead-swarm` starts while the current branch is `bead-swarm/iteration-*`.

1. Inspect `git status --porcelain`, `git log --oneline "$BEAD_SWARM_MAIN_BRANCH"..HEAD`, and selected Beads from branch notes or commit messages.
2. Reconstruct iteration metadata from `.agents/bead-swarm/iteration.json` on the branch. If that file is missing, derive `N` and `SLUG` from the branch name, then inspect Beads state and commit history to rebuild `BEADS_DONE_PENDING_CLOSE`, `BEADS_BLOCKED`, and `BEADS_PARTIAL`. If the bead set cannot be reconstructed with confidence, stop for human inspection instead of guessing.
3. If the branch has uncommitted changes, run the relevant validation if practical, stage only related paths, and commit `bead-swarm: interrupted checkpoint`.
4. If the branch has a net diff against `BEAD_SWARM_MAIN_BRANCH`, run validation and the review gate. Fix critical and important findings before merging.
5. Continue at **Ralph End-Of-Iteration Protocol**. Do not create a second iteration branch.
6. If the branch has no net diff, check out `BEAD_SWARM_MAIN_BRANCH`, delete the empty branch, set any claimed selected beads back to open or blocked with notes, and return `BEAD_SWARM_ITERATION_STATUS: complete-empty`.

## Orchestrator Iteration

The orchestrator handles exactly one batch. It may spawn worker subagents, but it must own selection, integration, validation, review, and the final decision.

### 1. Select And Claim A Safe Batch

Start from ready beads only. A bead is eligible when it is open, unblocked, not deferred, not hooked, not already in progress by another actor, and within any explicit bead-ID filter from the user.

Prefer a batch of independent beads that can be implemented simultaneously. Reject parallelism and run a smaller batch when:

- Two beads likely touch the same files or subsystem.
- One bead changes schemas, generated code, public APIs, auth, migrations, build tooling, or shared config that another bead depends on.
- Acceptance criteria are unclear.
- A bead appears too broad for a bounded worker.

Use at most `--max-workers`; default `3`. If no safe parallel set exists, select the single highest-priority ready bead.

Claim selected beads before creating an iteration branch:

```bash
bd update <id> --claim
bd update <id> --append-notes "bead-swarm: selected for next iteration"
```

If claiming a bead fails, drop it from the batch and continue with other safe candidates. If all claims fail, do not create a branch; stop as blocked and return a structured summary.

### 2. Set Up The Iteration Branch

Create the branch only after at least one bead is claimed.

```bash
N=$(git log "$BEAD_SWARM_MAIN_BRANCH" --format='%s' \
    | grep -oE '^bead-swarm: iteration [0-9]+ merge' \
    | awk '{print $3}' | sort -n | tail -1)
N=$(( ${N:-0} + 1 ))

RAW_SLUG_SOURCE="<selected bead titles>"
SLUG=$(printf '%s' "$RAW_SLUG_SOURCE" \
       | tr '[:upper:]' '[:lower:]' \
       | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//' \
       | cut -c1-40)
[[ -z "$SLUG" ]] && SLUG="iter-$(date +%Y%m%d-%H%M%S)"

BRANCH="bead-swarm/iteration-${N}-${SLUG}"
git checkout -b "$BRANCH"
```

If Beads claim state produced tracked changes, commit only those Beads paths on the iteration branch:

```bash
git status --short
# Stage only Beads state paths, not unrelated files.
git add -- <beads-state-paths>
git commit -m "bead-swarm: iteration ${N} claim beads"
```

Create branch-local metadata for resume before implementation starts. Use the file-editing tool available in the session to write `.agents/bead-swarm/iteration.json` with this shape:

```json
{
  "iteration": 1,
  "branch": "bead-swarm/iteration-1-example",
  "slug": "example",
  "main_branch": "main",
  "main_branch_source": "explicit|iteration-metadata|.ralph|default",
  "selected_beads": ["repo-abc123"],
  "beads_done_pending_close": [],
  "beads_blocked": [],
  "beads_partial": []
}
```

Then commit the metadata file:

```bash
git add -- .agents/bead-swarm/iteration.json
git commit -m "bead-swarm: iteration ${N} metadata"
```

Skip the claim-state commit when Beads state is external or there are no tracked claim changes. If branch creation or metadata commit fails after claims, immediately release the claimed beads before stopping:

```bash
bd update <id> --status open --assignee "" --append-notes "bead-swarm failed before iteration branch setup; released for future work" 2>/dev/null \
  || bd update <id> --status open --append-notes "bead-swarm failed before iteration branch setup; release assignee manually if needed"
```

If tracked Beads claim changes are left on `BEAD_SWARM_MAIN_BRANCH`, commit only those Beads paths to a recovery branch or stop with exact cleanup instructions. Do not leave dirty main.

### 3. Delegate Implementation

Launch implementation workers in parallel only when their write scopes are disjoint and the Codex environment gives workers isolated workspaces or patch artifacts that can be integrated. If workers would share the live worktree, serialize implementation instead of running parallel edits.

Each worker prompt must include:

- The bead ID, title, description, labels, dependencies, and acceptance criteria.
- The exact owned files or subsystem.
- A warning that other workers may edit the repo and that they must not revert or overwrite others' changes.
- Instructions to implement only their bead, add or update focused tests where appropriate, run the most relevant local validation they can, and return changed paths plus validation results.
- A prohibition on committing, pushing, merging, closing beads, or broad refactors.

Integrate worker changes one at a time. Before accepting each patch, inspect `git diff --stat` and changed paths. Reject or trim unrelated files, caches, generated artifacts not required by the bead, and edits outside the worker's ownership.

When a worker reports a genuine blocker, update the bead:

```bash
bd update <id> --status blocked --append-notes "Blocked in bead-swarm iteration ${N}: <reason>"
```

Continue with other selected beads only if their changes remain safe.

### 4. Validate The Integrated Batch

Run targeted tests first, then the smallest full-project gate that matches the repo. Prefer project-specific commands over generic defaults.

Detection order:

- `justfile`: `just test`; run `just lint` if present.
- `Makefile`: `make test`; run `make lint` if present.
- Go: `go test ./... && go build ./...`
- Node: choose by lockfile: `pnpm test`, `yarn test`, or `npm test`; run the matching `lint` script if defined.
- Python: `pytest`; run `ruff check .` if configured or installed and obviously applicable.
- Rust: `cargo test && cargo build`; run `cargo clippy` if configured.
- Existing CI scripts in `.github/workflows/`: mirror the relevant local command when practical.

If no automated gate exists, perform a manual verification that is specific to the changed behavior and note the gap. Do not mark a bead complete on compile success alone when tests exist.

Commit only after the integrated batch validates. Stage by reviewed path allowlist, not by `git add -A`:

```bash
git status --short
git add -- <implemented-paths> <test-paths>
git commit -m "bead-swarm: iteration ${N} checkpoint - ${SLUG}"
```

### 5. Run Two Independent Reviews

Review the complete iteration diff against `BEAD_SWARM_MAIN_BRANCH`.

Preferred path:

1. Run the existing `review` skill workflow. It must produce two independent review trees under `.agents/reviews/<change-name>/`.
2. Verify both reviewer directories contain the expected review files.
3. Read both action-item files and verdicts.
4. If either reviewer reports critical or important findings, run `fix-review --auto` or manually follow the `fix-review` skill workflow.
5. Re-read both reviewers' action items and the `fix-review --auto` summary. Every critical and important item must be fixed, explicitly marked already resolved, or recorded as a justified non-issue. Any `needs-manual` item is blocking until manually resolved or explicitly justified.
6. Re-run validation.
7. Commit review fixes by reviewed path allowlist:
   ```bash
   git status --short
   git add -- <review-fix-paths>
   git commit -m "bead-swarm: iteration ${N} - review fixes"
   ```

Fallback path when the `review` skill cannot run after a valid orchestrator exists:

- Spawn two read-only reviewer subagents in parallel with the full diff, changed file list, relevant changed file contents, and instructions to return findings ordered by severity with file and line references plus `APPROVE`, `REQUEST_CHANGES`, or `NEEDS_DISCUSSION`.
- If nested reviewer subagents are unavailable inside the orchestrator, perform two clearly separated manual review passes and record the degraded assurance in the summary.
- Store fallback artifacts under stable paths such as `.agents/reviews/bead-swarm-iteration-${N}-${SLUG}/review-a.md` and `review-b.md`.
- Each review artifact must contain a verdict line: `VERDICT: APPROVE`, `VERDICT: REQUEST_CHANGES`, or `VERDICT: NEEDS_DISCUSSION`.
- Treat any `REQUEST_CHANGES`, `NEEDS_DISCUSSION`, critical, or important finding as blocking until fixed or explicitly justified.
- After fixing review findings, re-run validation and either re-review or write a `fixes.md` artifact explaining which findings were fixed or why they were non-issues.

If validation still fails after one focused remediation pass, stop without merging and leave the iteration branch for manual inspection. The orchestrator may ignore suggestions only when it records why they are non-blocking.

### 6. Prepare Bead Outcomes

Do not close beads yet. Prepare a local list:

- `BEADS_DONE_PENDING_CLOSE`: selected beads whose acceptance criteria are satisfied and validated.
- `BEADS_BLOCKED`: selected beads that remain blocked, with reasons already appended to the bead.
- `BEADS_PARTIAL`: selected beads with partial implementation, notes appended, no closure, and a deliberate status transition.

Never close a bead whose code did not make it into the final diff.

For every partial bead, choose one of these before merge:

- Revert its partial code and release it back to ready:
  ```bash
  bd update <id> --status open --assignee "" --append-notes "Partial bead-swarm work was reverted; ready for future iteration" 2>/dev/null \
    || bd update <id> --status open --append-notes "Partial bead-swarm work was reverted; release assignee manually if needed"
  ```
- Keep a validated incremental change, append exact remaining acceptance criteria, and set the bead back to `open` unless it is truly blocked:
  ```bash
  bd update <id> --status open --assignee "" --append-notes "Validated partial increment merged in iteration ${N}; remaining: <criteria>" 2>/dev/null \
    || bd update <id> --status open --append-notes "Validated partial increment merged in iteration ${N}; release assignee manually if needed; remaining: <criteria>"
  ```
- Set it to `blocked` with a concrete blocker if more progress requires human or external input.

Update `.agents/bead-swarm/iteration.json` with final pending/blocked/partial lists and commit that metadata by path allowlist before the end-of-iteration protocol.

If `--no-push` is set, stop here with a clean committed iteration branch. Leave completed beads open with notes such as:

```bash
bd update <id> --append-notes "Implemented on ${BRANCH}; not closed because --no-push skipped merge to ${BEAD_SWARM_MAIN_BRANCH}."
```

If that note changes tracked Beads state, commit only Beads paths on the iteration branch.

### Already-Satisfied Beads

If a selected bead's acceptance criteria are already satisfied by code on `BEAD_SWARM_MAIN_BRANCH`, the orchestrator may run an already-satisfied iteration instead of making code changes. This path is allowed only when the orchestrator records concrete proof in `.agents/bead-swarm/iteration.json`, such as the relevant files, commits, and validation commands.

Requirements:

- Run validation that directly covers the bead's acceptance criteria.
- Run the review gate against the evidence and any metadata-only diff.
- Merge a metadata-only iteration branch, then close the bead after the merge lands on `BEAD_SWARM_MAIN_BRANCH`.
- Report `BEAD_SWARM_ITERATION_STATUS: complete-existing` or `complete` with `already satisfied by <commit>`.

Never close a bead merely because no code change seems necessary; evidence and validation are mandatory.

## Ralph End-Of-Iteration Protocol

After validation and review approval, finish the iteration like `/ralph`, substituting `BEAD_SWARM_MAIN_BRANCH` and `bead-swarm/iteration-*`.

1. Empty-diff short-circuit:
   ```bash
   if git diff --quiet "$BEAD_SWARM_MAIN_BRANCH"...HEAD; then
     git checkout "$BEAD_SWARM_MAIN_BRANCH"
     git branch -D "$BRANCH"
     echo "BEAD_SWARM_ITERATION_STATUS: complete-empty"
     exit 0
   fi
   ```
   Return the structured summary even for empty iterations. Do not close a selected bead on this empty-diff path. Use **Already-Satisfied Beads** when a bead should close because existing main-branch work already satisfies it.
2. Push the iteration branch:
   ```bash
   git push -u origin "$BRANCH"
   ```
3. Merge with bounded retry:
   - Check out `BEAD_SWARM_MAIN_BRANCH`.
   - Pull fast-forward from origin when `origin/BEAD_SWARM_MAIN_BRANCH` exists.
   - Record `PRE_MERGE_SHA=$(git rev-parse HEAD)` after the fast-forward pull.
   - Merge with `git merge --no-ff "$BRANCH" -m "bead-swarm: iteration ${N} merge - ${SLUG}"`.
   - Re-run the validation gate on the merged main branch before pushing.
   - If validation fails, reset only the local merge commit with `git reset --hard "$PRE_MERGE_SHA"`, check out the iteration branch, and stop for human inspection.
   - On conflict, `git merge --abort`, leave the iteration branch pushed, and stop for human resolution.
   - Push `BEAD_SWARM_MAIN_BRANCH`.
   - If push is rejected, discard only the local merge commit by resetting back to `origin/BEAD_SWARM_MAIN_BRANCH`, pull, and retry up to three times. Never force-push.
4. After the merge commit is pushed, close completed beads:
   ```bash
   bd close <id> -r "Implemented and validated in bead-swarm iteration ${N}; merged to ${BEAD_SWARM_MAIN_BRANCH}"
   ```
5. Verify each close succeeded with `bd show <id>` or `bd list --json`. If any close fails, do not delete the iteration branch. Append failure notes where possible, report `BEAD_SWARM_ITERATION_STATUS: failed-bead-close`, and stop so the next session can repair Beads state without losing the code branch.
6. If Beads closure changes tracked files, commit and push only those Beads paths on `BEAD_SWARM_MAIN_BRANCH`:
   ```bash
   git status --short
   git add -- <beads-state-paths>
   git commit -m "bead-swarm: iteration ${N} bead status updates"
   git push origin "$BEAD_SWARM_MAIN_BRANCH"
   ```
   If this push fails, keep the iteration branch and local bead-status commit, report the exact failure, and stop. Do not report completion until Beads state is pushed or explicitly confirmed external.
7. Cleanup after successful code push and bead-state push:
   ```bash
   git branch -d "$BRANCH"
   git push origin --delete "$BRANCH"
   ```
8. Return a structured summary to the parent:
   ```text
   BEAD_SWARM_ITERATION_STATUS: complete|complete-existing|complete-empty|blocked|dirty|failed|failed-bead-close|no-push
   ITERATION: <N>
   BRANCH: <branch>
   BEADS_DONE: <ids closed after merge>
   BEADS_PENDING: <ids left open and why>
   BEADS_BLOCKED: <ids and reasons>
   VALIDATION: <commands and pass/fail>
   REVIEWS: <verdicts and artifact paths>
   NEXT_READY_COUNT: <count if checked>
   ```

Generated test binaries, such as `tests/<compiled-test-name>`, must not be staged or committed.

## Recovery Protocol

Use this only after an orchestrator returns with dirty git state or the parent detects that an interrupted run left the repo off the main branch unexpectedly.

1. Inspect `git branch --show-current`, `git status --porcelain`, `git log --oneline -5`, and the selected beads' current state.
2. If on a `bead-swarm/iteration-*` branch with generated changes:
   - Prefer **Resume Existing Iteration**.
   - If the branch cannot be safely resumed now, run relevant validation if practical and commit a local checkpoint by reviewed path allowlist:
     ```bash
     git status --short
     git add -- <related-paths>
     git commit -m "bead-swarm: interrupted checkpoint"
     ```
   - Append notes to in-progress beads explaining the checkpoint branch and remaining work.
   - Stop and tell the user the next `/goal /bead-swarm` session should start from this branch to resume the iteration.
3. If on `BEAD_SWARM_MAIN_BRANCH` with dirty files that clearly came from the current bead-swarm run:
   - Create a recovery branch:
     ```bash
     git checkout -b "bead-swarm/recovery-$(date +%Y%m%d-%H%M%S)"
     git add -- <related-paths>
     git commit -m "bead-swarm: recovery checkpoint"
     ```
   - Update affected beads with recovery notes.
   - Stop for human inspection.
4. If dirty files predate the run or are unrelated, do not commit them. Stop and report the exact files that require human cleanup.

## Completion Rules

Complete only when all are true:

- Git is clean.
- Current branch is `BEAD_SWARM_MAIN_BRANCH`.
- No unmerged `ralph/iteration-*`, `bead-swarm/iteration-*`, or `bead-swarm/recovery-*` branches remain.
- `bd ready` returns no actionable work.
- Any remaining open beads are blocked, deferred, hooked, or explicitly out of scope, and those reasons are recorded.

Stop as blocked when a human decision, external credential, merge conflict, branch protection failure, unclear acceptance criteria, or unrelated dirty work prevents safe progress.
