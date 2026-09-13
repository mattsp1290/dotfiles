---
name: bead-swarm
description: Autonomous Beans task-graph execution loop for Codex. Use when the user invokes `/goal /bead-swarm`, asks to work through ready Beans tasks, or wants a Ralph-like multi-agent loop that selects independent ready beans, delegates implementation to subagents, validates, runs two independent reviews, merges a clean iteration, and repeats until the task graph is complete or human intervention is required.
user-invocable: true
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# /bead-swarm -- Beans-first multi-agent work loop

Run a Ralph-like autonomous development loop over Beans. The parent Codex agent supervises; each iteration is delegated to one orchestrator subagent, which may spawn worker and reviewer subagents for one safe batch of ready beans. The orchestrator must finish one iteration and return control to the parent so the parent can inspect git and Beans state before continuing.

## Codex Subagent Requirement

This skill prefers Codex multi-agent tools. Use Codex subagent tooling, such as `spawn_agent`, `wait_agent`, `send_input`, and `close_agent`, when those tools are available. Do not assume Claude-only `Agent` or `Skill` tools exist.

If Codex subagent tools are unavailable, quota-limited, or fail after the parent has established a valid work loop, the parent may continue in degraded mode only when the iteration can be made safe without parallel implementation:

- Select at most one implementation bead for the degraded iteration.
- Do not attempt worker parallelism.
- Run the same validation, review gate, metadata, merge, and Beans closure protocol.
- Use the fallback review path and clearly separate the review passes.
- Record `execution_mode`, `review_mode`, `review_assurance`, and `degraded_reason` in iteration metadata, immutable history, and the parent summary.

Stop instead of entering degraded mode when the selected work requires true parallel agents, independent reviewer subagents are required by the user, acceptance criteria are broad or unclear, or the parent cannot produce durable review artifacts.

When invoking existing skills such as `review` or `fix-review`, use whatever Codex skill invocation mechanism is available in the session. If no skill invocation tool exists, read that skill's `SKILL.md` and perform its workflow directly.

## Invocation Contract

`/goal /bead-swarm` is the intended invocation. Treat the `/goal` wrapper as the durable objective: keep relaunching clean iterations until there are no ready beans left, a real blocker needs the human, or git state is not safely recoverable.

Invoking this skill authorizes, within the repository and selected Beans only:

- Creating `bead-swarm/iteration-*` branches.
- Spawning orchestrator, implementation, and review subagents.
- Committing generated changes on the iteration branch.
- Pushing the iteration branch.
- Merging the iteration branch into the configured main branch with the Ralph no-fast-forward protocol.
- Pushing the configured main branch and deleting the iteration branch.
- Closing Beans only after the implementation is present on the configured main branch.

This does not authorize force-pushes, destructive resets of user work, bypassing branch protection, running concurrent autonomous loops, or sweeping unrelated dirty files into commits.

## Arguments

Parse any user text after the skill name:

- No arguments: process ready beans in conservative batches until complete.
- Bead IDs: restrict the next batch to those beans, but only if they are ready and mutually safe.
- `use <branch> as the main branch` or `--main-branch <branch>`: use `<branch>` as `BEANS_SWARM_MAIN_BRANCH` for this run. This explicit override takes precedence over `.ralph`.
- `--single`: run one bead only, then stop after the parent post-iteration check.
- `--max-workers N`: cap implementation workers for one batch. Default: `3`.
- `--no-push`: run implementation, validation, and review, but do not push, merge, or close beans. Stop on the iteration branch with a clean local checkpoint and report the exact resume command.

## Parent Supervisor Loop

The parent agent owns the outer loop. Do not let one long-running orchestrator work through the whole graph without returning.

### 1. Resolve Main Branch

Resolve `BEANS_SWARM_MAIN_BRANCH` with this precedence:

1. Explicit user argument: `use <branch> as the main branch` or `--main-branch <branch>`.
2. Active iteration metadata, only when resuming from a `bead-swarm/iteration-*` branch and `.agents/bead-swarm/iteration.json` names the current branch.
3. `.ralph` `main_branch`, exactly as `/ralph` resolves `RALPH_MAIN_BRANCH`.
4. `main`.

Validate the resolved branch with `git check-ref-format --branch "$BEANS_SWARM_MAIN_BRANCH"`. Record both the branch and the source of the decision in the parent log, orchestrator prompt, and `.agents/bead-swarm/iteration.json`.

Local-only main branches are allowed only when the branch came from an explicit user override. If `origin/BEANS_SWARM_MAIN_BRANCH` exists, normal fast-forward checks apply. If the remote branch does not exist and the branch was explicitly overridden, the end-of-iteration push may create `origin/BEANS_SWARM_MAIN_BRANCH`; report that in the summary. Do not silently treat a local-only `.ralph` branch as safe to publish.

```bash
BEANS_SWARM_MAIN_BRANCH="main"
BEANS_SWARM_MAIN_BRANCH_SOURCE="default"
if [[ -f ".ralph" ]]; then
  _cfg=$(awk -F= '$1 == "main_branch" {print $2; exit}' .ralph 2>/dev/null)
  if [[ -n "$_cfg" ]]; then
    BEANS_SWARM_MAIN_BRANCH="$_cfg"
    BEANS_SWARM_MAIN_BRANCH_SOURCE=".ralph"
  fi
fi
```

### 2. Acquire A Local Loop Lock

Create an untracked repo-local lock before spawning an orchestrator. In Codex,
do not rely on a shell `trap` or shell PID for cleanup because the parent loop
spans multiple tool calls. Record an opaque owner token in the parent notes and
release the lock explicitly during parent final cleanup or recovery.

```bash
LOCK_DIR="$(git rev-parse --git-dir)/bead-swarm.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another bead-swarm session appears to be running: $LOCK_DIR" >&2
  exit 1
fi
OWNER_ID="$(uuidgen 2>/dev/null || openssl rand -hex 16 2>/dev/null || printf '%s-%s' "$(date -u +%s)" "$RANDOM")"
BEANS_SWARM_LOCK_OWNER="codex:$(date -u +%Y%m%dT%H%M%SZ):$OWNER_ID"
printf '%s\n' "$BEANS_SWARM_LOCK_OWNER" > "$LOCK_DIR/owner"
```

At final completion, blocked stop, or recovery handoff, remove only the lock whose
`owner` matches the owner token created by this parent. If the owner does not
match, stop and report the competing owner.

If a stale lock exists and there are no `bead-swarm/iteration-*` branches, no
`bead-swarm/recovery-*` branches, and no remote autonomous branches, remove it
only when the owner token is from this parent or you can prove the owning
session is gone. An opaque owner token is not a PID; absence of a matching process
is not enough proof by itself. Otherwise stop and ask for human confirmation.

If a stale lock exists while the current branch is already `bead-swarm/iteration-*`,
verify no matching owner process/session is running, remove only the stale lock,
and continue to **Resume Existing Iteration**. A stale lock must not prevent
recovery of an interrupted iteration branch.

### 3. Preflight Or Resume

Run these checks before each new orchestrator:

- Inside a git repo.
- `origin` exists unless `--no-push` is set.
- Review artifact policy is understood for this repo. Some repos keep review
  artifacts untracked under `reviews/`; others commit durable artifacts under
  `.agents/reviews/`. Follow the repo's existing convention and do not require
  `.agents/reviews/` to be excluded when it is already tracked. Before running a
  review workflow, know the exact artifact root it will write. If that root is
  local-only, ensure it is ignored by the repo's tracked `.gitignore` or local
  `.git/info/exclude`; if it is durable, include it in the path allowlist.
- Any `.agents/bead-swarm/iteration.json` found on the main branch is advisory history only. Treat it as active metadata only when the current branch is `bead-swarm/iteration-*` and its `branch` field matches the current branch.
- No concurrent autonomous branch exists locally or remotely:
  - `ralph/iteration-*`
  - `bead-swarm/iteration-*`
  - `bead-swarm/recovery-*`

Exception: if the current branch itself is `bead-swarm/iteration-*`, do not start a new iteration. Enter **Resume Existing Iteration** below.

For normal new iterations:

- Current branch must be `BEANS_SWARM_MAIN_BRANCH`.
- Worktree must be clean.
- Local branch can fast-forward from `origin/BEANS_SWARM_MAIN_BRANCH` when that remote branch exists.
- If `origin/BEANS_SWARM_MAIN_BRANCH` does not exist, continue only when the branch came from an explicit user main-branch override or `--no-push` is set.

If the main branch is dirty, classify the dirty paths before doing anything else:

- selected-bead or interrupted iteration work: enter **Resume Existing Iteration**
  or recovery, do not start a new iteration;
- referenced plan/setup docs that must be committed before implementation:
  either commit them deliberately under their own bead/checkpoint or stop for
  human confirmation;
- unrelated user drift: stop and report exact paths;
- legitimate work outside the selected ready beans: create or use a separate bead
  and checkpoint it before continuing.

This classification never weakens the clean-main invariant: a normal new
iteration still starts only from a clean `BEANS_SWARM_MAIN_BRANCH`.

### Serialized Beans Operations

All `bn` commands must run serially. Do not run `bn` commands through parallel tool wrappers, and do not let workers or reviewers run `bn` commands unless the orchestrator explicitly delegates one serialized operation and waits for it to finish. This avoids hub-lock failures.

The parent must not run any `bn` command while an orchestrator may still be
claiming, closing, or pushing Beans state. During heartbeat checks, inspect git
state only; wait for the orchestrator's final summary before parent-side `bn`
queries.

If a serial `bn` command exits 4, another process holds the hub lock. Wait a
short bounded interval and retry once; then report a real concurrent-session
conflict. Do not work around the lock with raw hub commands.

If synchronization fails, record the exact failure, run `bn status`, then use `bn sync` or `bn doctor`. Continue only after serial `bn ready` and any required `bn show <id>` commands succeed. Do not invent raw hub commands or branch names.

### 4. Query Ready Work

- Prefer `bn ready --json`.
- Inspect each candidate with `bn show <id>` when needed.
- If `bn status` fails, stop after reporting the failure and suggesting `bn sync`
  or `bn doctor`. This skill is Beans-first, unlike `/ralph`.
- Treat `bn` CLI output as authoritative; Beans state is hub-backed.
- Do not select `issue_type: epic` as an implementation bead. Use epics only for
  completion auditing: inspect children and acceptance criteria, close only when
  actually satisfied, and use notes/defer/human flags for manual remainder.

If there are no ready beans:

- Run `bn list --json` or `bn blocked` if available to identify open blocked work.
- If no open actionable work remains and git is clean on `BEANS_SWARM_MAIN_BRANCH`, report completion and, when the goal tool is available, mark the goal complete.
- If open work remains but all of it is blocked/deferred/hooked, report the blocking beans and stop for human input.

### 5. Spawn One Orchestrator

Spawn one orchestrator subagent for one iteration. Pass:

- This skill path.
- Resolved `BEANS_SWARM_MAIN_BRANCH`.
- Requested bead IDs or filters.
- `--max-workers`.
- Whether `--single` or `--no-push` was set.
- A directive to return a structured summary and not continue into another iteration.

After the orchestrator exits, inspect:

- `git branch --show-current`
- `git status --porcelain`
- `bn ready --json`

While the orchestrator is running, wait in bounded intervals. If it runs longer than 5 minutes without completion, the parent may inspect git state read-only and send one status request asking for:

- current phase
- current branch
- clean/dirty state
- last validation or git command
- blocker, or `none`

Do not run any `bn` commands during heartbeat checks. Move to recovery only when branch state and lack of orchestrator response indicate a real stall.

Decide:

- Clean on `BEANS_SWARM_MAIN_BRANCH` and ready beans remain: spawn the next orchestrator unless `--single` was set.
- Clean on `BEANS_SWARM_MAIN_BRANCH` and `bn ready` returns only epics: inspect
  child statuses and acceptance criteria. Do not select the epic for
  implementation. Close it only if all criteria are proven; otherwise record why
  it remains open and use defer/human-needed notes for manual remainder.
- Clean on `BEANS_SWARM_MAIN_BRANCH` and no ready/open actionable beans remain: complete.
- Clean on `BEANS_SWARM_MAIN_BRANCH` but only blocked work remains: stop as blocked with exact bead IDs and reasons.
- Clean on an iteration branch because `--no-push` was set: stop intentionally and report the branch, pending beans, and next command.
- Dirty or unexpectedly on an iteration branch: run the recovery protocol.

## Resume Existing Iteration

Use this path when `/goal /bead-swarm` starts while the current branch is `bead-swarm/iteration-*`.

1. Inspect `git status --porcelain`, `git log --oneline "$BEANS_SWARM_MAIN_BRANCH"..HEAD`, and selected Beans from branch notes or commit messages.
2. Reconstruct iteration metadata from `.agents/bead-swarm/iteration.json` on the branch. If that file is missing, derive `N` and `SLUG` from the branch name, then inspect Beans state and commit history to rebuild `BEANS_DONE_PENDING_CLOSE`, `BEANS_BLOCKED`, and `BEANS_PARTIAL`. If the bead set cannot be reconstructed with confidence, stop for human inspection instead of guessing.
3. If the branch has uncommitted changes, run the relevant validation if practical, stage only related paths, and commit `bead-swarm: interrupted checkpoint`.
4. If the branch has a net diff against `BEANS_SWARM_MAIN_BRANCH`, run validation and the review gate. Fix critical and important findings before merging.
5. Continue at **Ralph End-Of-Iteration Protocol**. Do not create a second iteration branch.
6. If the branch has no net diff, check out `BEANS_SWARM_MAIN_BRANCH`, delete the empty branch, set any claimed selected beans back to open or blocked with notes, and return `BEANS_SWARM_ITERATION_STATUS: complete-empty`.

## Orchestrator Iteration

The orchestrator handles exactly one batch. It may spawn worker subagents, but it must own selection, integration, validation, review, and the final decision.

### 1. Select And Claim A Safe Batch

Start from ready beans only. A bead is eligible when it is open, unblocked, not deferred, not hooked, not already in progress by another actor, and within any explicit bead-ID filter from the user.

Prefer a batch of independent beans that can be implemented simultaneously. Reject parallelism and run a smaller batch when:

- Two beans likely touch the same files or subsystem.
- One bead changes schemas, generated code, public APIs, auth, migrations, build tooling, or shared config that another bead depends on.
- Acceptance criteria are unclear.
- A bead appears too broad for a bounded worker.

Use at most `--max-workers`; default `3`. If no safe parallel set exists, select the single highest-priority ready bead.

Claim selected beans before creating an iteration branch:

```bash
bn update <id> --claim
bn update <id> --note "bead-swarm: selected for next iteration"
```

If claiming a bead fails, drop it from the batch and continue with other safe candidates. If all claims fail, do not create a branch; stop as blocked and return a structured summary.

### 2. Set Up The Iteration Branch

Create the branch only after at least one bead is claimed.

```bash
N=$(git log "$BEANS_SWARM_MAIN_BRANCH" --format='%s' \
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

Create branch-local active metadata for resume before implementation starts. Use
the file-editing tool available in the session to write
`.agents/bead-swarm/iteration.json` with this shape:

```json
{
  "iteration": 1,
  "branch": "bead-swarm/iteration-1-example",
  "slug": "example",
  "main_branch": "main",
  "main_branch_source": "explicit-user-argument|iteration-metadata|.ralph|default",
  "selected_beans": ["repo-abc123"],
  "beans_done_pending_close": [],
  "beans_blocked": [],
  "beans_partial": []
}
```

Then commit the metadata file:

```bash
git add -- .agents/bead-swarm/iteration.json
git commit -m "bead-swarm: iteration ${N} metadata"
```

Active `iteration.json` is for iteration branches only. Before a non-empty
iteration branch is merged, replace it with immutable history metadata, for
example `.agents/bead-swarm/history/iteration-${N}.json`, or update/remove the
active file so main never shows stale `beans_done_pending_close` state. On the
main branch, any remaining `.agents/bead-swarm/iteration.json` is advisory only
and must not be treated as active unless its branch matches the current
`bead-swarm/iteration-*` branch.

If branch creation or metadata commit fails after claims, immediately release the claimed beans before stopping. Beans mutations already commit and push their hub state:

```bash
bn update <id> --status open --assignee "" --note "bead-swarm failed before iteration branch setup; released for future work" 2>/dev/null \
  || bn update <id> --status open --note "bead-swarm failed before iteration branch setup; release assignee manually if needed"
```

Do not leave unrelated changes on main.

### 3. Delegate Implementation

Launch implementation workers in parallel only when their write scopes are disjoint and the Codex environment gives workers isolated workspaces or patch artifacts that can be integrated. If workers would share the live worktree, serialize implementation instead of running parallel edits.

Each worker prompt must include:

- The bead ID, title, description, labels, dependencies, and acceptance criteria.
- The exact owned files or subsystem.
- A warning that other workers may edit the repo and that they must not revert or overwrite others' changes.
- Instructions to implement only their bead, add or update focused tests where appropriate, run the most relevant local validation they can, and return changed paths plus validation results.
- A prohibition on committing, pushing, merging, closing beans, or broad refactors.

Integrate worker changes one at a time. Before accepting each patch, inspect `git diff --stat` and changed paths. Reject or trim unrelated files, caches, generated artifacts not required by the bead, and edits outside the worker's ownership.

When a worker reports a genuine blocker, update the bead:

```bash
bn update <id> --status blocked --note "Blocked in bead-swarm iteration ${N}: <reason>"
```

Continue with other selected beans only if their changes remain safe.

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

After each validation gate, clean generated artifacts that are known outputs of
the gate before inspecting or staging git state. For Nim projects, this commonly
means untracked executables such as `tests/<compiled-test-name>` created by
`nimble test`. Remove only untracked expected outputs from the project's test
list or `.gitignore`; do not broadly delete every executable under `tests/`.

Commit only after the integrated batch validates. Stage by reviewed path allowlist, not by `git add -A`:

```bash
git status --short
git add -- <implemented-paths> <test-paths>
git commit -m "bead-swarm: iteration ${N} checkpoint - ${SLUG}"
```

### 5. Run Two Independent Reviews

Review the complete iteration diff against `BEANS_SWARM_MAIN_BRANCH`.

Preferred path:

1. Run the existing `review` skill workflow. It must produce two independently named reviewer directories under the repo's review-artifact convention, such as `./reviews/<change-name>/<reviewer-slug>/` or tracked `.agents/reviews/<change-name>/<reviewer-slug>/`, with reviewer slugs recorded when the review workflow supports a manifest. If the review skill's current output root differs from the repo's old convention, either update the ignore/allowlist before running it or explicitly pass/use the convention supported by that skill.
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
- If nested reviewer subagents are unavailable inside the orchestrator, perform two clearly separated manual review passes and record the degraded assurance in the summary and immutable history.
- Store fallback artifacts under stable paths that match the repo's convention,
  such as `./reviews/bead-swarm-iteration-${N}-${SLUG}/{reviewer-slug}/04-action-items.md`
  or `.agents/reviews/bead-swarm-iteration-${N}-${SLUG}/{reviewer-slug}/04-action-items.md`,
  using the same agent-chosen reviewer slug convention as the review skill.
- Each review artifact must contain a verdict line: `VERDICT: APPROVE`, `VERDICT: REQUEST_CHANGES`, or `VERDICT: NEEDS_DISCUSSION`.
- Treat any `REQUEST_CHANGES`, `NEEDS_DISCUSSION`, critical, or important finding as blocking until fixed or explicitly justified.
- After fixing review findings, re-run validation and either re-review or write a `fixes.md` artifact explaining which findings were fixed or why they were non-issues.
- Never label a fallback or degraded review as normal approval unless a second independent review pass actually ran after the fixes. Use `findings_fixed_re_reviewed: false` when fixes were verified by validation and artifact review but not independently re-reviewed.

If validation still fails after one focused remediation pass, stop without merging and leave the iteration branch for manual inspection. The orchestrator may ignore suggestions only when it records why they are non-blocking.

### 6. Prepare Bead Outcomes

Do not close beans yet. Prepare a local list:

- `BEANS_DONE_PENDING_CLOSE`: selected beans whose acceptance criteria are satisfied and validated.
- `BEANS_BLOCKED`: selected beans that remain blocked, with reasons already appended to the bead.
- `BEANS_PARTIAL`: selected beans with partial implementation, notes appended, no closure, and a deliberate status transition.

Never close a bead whose code did not make it into the final diff.

For every partial bead, choose one of these before merge:

- Revert its partial code and release it back to ready:
  ```bash
  bn update <id> --status open --assignee "" --note "Partial bead-swarm work was reverted; ready for future iteration" 2>/dev/null \
    || bn update <id> --status open --note "Partial bead-swarm work was reverted; release assignee manually if needed"
  ```
- Keep a validated incremental change, append exact remaining acceptance criteria, and set the bead back to `open` unless it is truly blocked:
  ```bash
  bn update <id> --status open --assignee "" --note "Validated partial increment merged in iteration ${N}; remaining: <criteria>" 2>/dev/null \
    || bn update <id> --status open --note "Validated partial increment merged in iteration ${N}; release assignee manually if needed; remaining: <criteria>"
  ```
- Set it to `blocked` with a concrete blocker if more progress requires human or external input.

Update `.agents/bead-swarm/iteration.json` with final pending/blocked/partial
lists, then finalize it into immutable history before merge. The final history
record must include selected beans, done beans, blocked beans, partial beans,
validation, review verdicts, review mode, degraded-execution status, review
artifact paths, whether those artifacts are local-only, and the merge target. If
review artifacts are local-only, embed enough verdict and blocker-summary data in
the committed history record that the record is useful without the ignored files.
Commit metadata by path allowlist before the end-of-iteration protocol.

Use this stable history schema:

```json
{
  "schema_version": "bead-swarm-history-v1",
  "iteration": 1,
  "branch": "bead-swarm/iteration-1-example",
  "slug": "example",
  "main_branch": "main",
  "main_branch_source": "explicit-user-argument|iteration-metadata|.ralph|default",
  "execution_mode": "orchestrator-subagent|parent-degraded",
  "degraded_reason": null,
  "selected_beans": ["repo-abc123"],
  "beans_done": ["repo-abc123"],
  "beans_blocked": [],
  "beans_partial": [],
  "merge_target": "main",
  "validation": ["<command and result>"],
  "review_mode": "review-skill|reviewer-subagents|manual-separated-passes",
  "review_assurance": "normal|degraded",
  "findings_fixed_re_reviewed": true,
  "review_artifacts_local_only": true,
  "review_blocker_summary": [],
  "reviews": [
    {"reviewer": "<slug>", "verdict": "APPROVE", "artifact": "<path>"}
  ],
  "status": "complete"
}
```

If `--no-push` is set, stop here with a clean committed iteration branch. Leave completed beans open with notes such as:

```bash
bn update <id> --note "Implemented on ${BRANCH}; not closed because --no-push skipped merge to ${BEANS_SWARM_MAIN_BRANCH}."
```

That note is committed and pushed by Beans automatically.

### Already-Satisfied Beans

If a selected bead's acceptance criteria are already satisfied by code on `BEANS_SWARM_MAIN_BRANCH`, the orchestrator may run an already-satisfied iteration instead of making code changes. This path is allowed only when the orchestrator records concrete proof in `.agents/bead-swarm/iteration.json`, such as the relevant files, commits, and validation commands.

Requirements:

- Run validation that directly covers the bead's acceptance criteria.
- Run the review gate against the evidence and any metadata-only diff.
- Merge a metadata-only iteration branch, then close the bead after the merge lands on `BEANS_SWARM_MAIN_BRANCH`.
- Report `BEANS_SWARM_ITERATION_STATUS: complete-existing` or `complete` with `already satisfied by <commit>`.

Never close a bead merely because no code change seems necessary; evidence and validation are mandatory.

## Ralph End-Of-Iteration Protocol

After validation and review approval, finish the iteration like `/ralph`, substituting `BEANS_SWARM_MAIN_BRANCH` and `bead-swarm/iteration-*`.

1. Empty-diff short-circuit:
   ```bash
   if git diff --quiet "$BEANS_SWARM_MAIN_BRANCH"...HEAD; then
     git checkout "$BEANS_SWARM_MAIN_BRANCH"
     git branch -D "$BRANCH"
     echo "BEANS_SWARM_ITERATION_STATUS: complete-empty"
     exit 0
   fi
   ```
   Return the structured summary even for empty iterations. Do not close a selected bead on this empty-diff path. Use **Already-Satisfied Beans** when a bead should close because existing main-branch work already satisfies it.
2. Finalize metadata for merge:
   - Write immutable final metadata to `.agents/bead-swarm/history/iteration-${N}.json`
     or the repo's equivalent history path.
   - Remove `.agents/bead-swarm/iteration.json` from the iteration branch, or
     replace it with a clearly inactive/advisory pointer that cannot imply pending
     bead closure on `BEANS_SWARM_MAIN_BRANCH`.
   - Commit this metadata finalization by path allowlist.
   - Re-run `git status --short` and clean untracked generated validation
     artifacts before pushing.
3. Push the iteration branch:
   ```bash
   git push -u origin "$BRANCH"
   ```
4. Merge with bounded retry:
   - Check out `BEANS_SWARM_MAIN_BRANCH`.
   - Pull fast-forward from origin when `origin/BEANS_SWARM_MAIN_BRANCH` exists.
   - Record `PRE_MERGE_SHA=$(git rev-parse HEAD)` after the fast-forward pull.
   - Merge with `git merge --no-ff "$BRANCH" -m "bead-swarm: iteration ${N} merge - ${SLUG}"`.
   - Re-run the validation gate on the merged main branch before pushing.
   - If validation fails, reset only the local merge commit with `git reset --hard "$PRE_MERGE_SHA"`, check out the iteration branch, and stop for human inspection.
   - On conflict, `git merge --abort`, leave the iteration branch pushed, and stop for human resolution.
   - Push `BEANS_SWARM_MAIN_BRANCH`.
   - If push is rejected, discard only the local merge commit by resetting back to `origin/BEANS_SWARM_MAIN_BRANCH`, pull, and retry up to three times. Never force-push.
5. After the merge commit is pushed, close completed beans:
   ```bash
   bn close <id> -r "Implemented and validated in bead-swarm iteration ${N}; merged to ${BEANS_SWARM_MAIN_BRANCH}"
   ```
6. Verify each close succeeded with `bn show <id>` or `bn list --json`. If any close fails, do not delete the iteration branch. Append failure notes where possible, report `BEANS_SWARM_ITERATION_STATUS: failed-bead-close`, and stop so the next session can repair Beans state without losing the code branch.
7. Beans closes commit and push their hub state automatically:
   ```bash
   bn status
   bn doctor
   ```
   If a close fails, keep the iteration branch, report the exact failure, and stop.
8. Cleanup after successful code push and bead-state push:
   ```bash
   git branch -d "$BRANCH"
   git push origin --delete "$BRANCH"
   ```
9. Return a structured summary to the parent:
   ```text
   BEANS_SWARM_ITERATION_STATUS: complete|complete-existing|complete-empty|blocked|dirty|failed|failed-bead-close|no-push
   ITERATION: <N>
   BRANCH: <branch>
   EXECUTION_MODE: orchestrator-subagent|parent-degraded
   DEGRADED_REASON: <none or reason>
   BEANS_DONE: <ids closed after merge>
   BEANS_PENDING: <ids left open and why>
   BEANS_BLOCKED: <ids and reasons>
   VALIDATION: <commands and pass/fail>
   REVIEW_MODE: review-skill|reviewer-subagents|manual-separated-passes
   REVIEW_ASSURANCE: normal|degraded
   FINDINGS_FIXED_RE_REVIEWED: true|false
   REVIEWS: <verdicts and artifact paths>
   NEXT_READY_COUNT: <count if checked>
   ```

Generated test binaries, such as `tests/<compiled-test-name>`, must not be staged or committed.

## Recovery Protocol

Use this only after an orchestrator returns with dirty git state or the parent detects that an interrupted run left the repo off the main branch unexpectedly.

1. Inspect `git branch --show-current`, `git status --porcelain`, `git log --oneline -5`, and the selected beans' current state.
2. If on a `bead-swarm/iteration-*` branch with generated changes:
   - Prefer **Resume Existing Iteration**.
   - If the branch cannot be safely resumed now, run relevant validation if practical and commit a local checkpoint by reviewed path allowlist:
     ```bash
     git status --short
     git add -- <related-paths>
     git commit -m "bead-swarm: interrupted checkpoint"
     ```
   - Append notes to in-progress beans explaining the checkpoint branch and remaining work.
   - Stop and tell the user the next `/goal /bead-swarm` session should start from this branch to resume the iteration.
3. If on `BEANS_SWARM_MAIN_BRANCH` with dirty files that clearly came from the current bead-swarm run:
   - Create a recovery branch:
     ```bash
     git checkout -b "bead-swarm/recovery-$(date +%Y%m%d-%H%M%S)"
     git add -- <related-paths>
     git commit -m "bead-swarm: recovery checkpoint"
     ```
   - Update affected beans with recovery notes.
   - Stop for human inspection.
4. If dirty files predate the run or are unrelated, do not commit them. Stop and report the exact files that require human cleanup.

## Completion Rules

Complete only when all are true:

- Git is clean.
- Current branch is `BEANS_SWARM_MAIN_BRANCH`.
- No unmerged `ralph/iteration-*`, `bead-swarm/iteration-*`, or `bead-swarm/recovery-*` branches remain.
- `bn ready` returns no actionable non-epic work.
- Any ready epics have been audited against their children and acceptance criteria;
  completed epics are closed, and epics with manual/deferred remainder have notes
  and are deferred or marked human-needed rather than left as unexplained ready
  work.
- Any remaining open beans are blocked, deferred, hooked, or explicitly out of scope, and those reasons are recorded.
- Generated validation artifacts are removed or ignored, and `git status` is clean.
- The parent releases only its own `.git/bead-swarm.lock` owner token, or reports
  why the lock is intentionally retained for recovery.

Stop as blocked when a human decision, external credential, merge conflict, branch protection failure, unclear acceptance criteria, or unrelated dirty work prevents safe progress.
