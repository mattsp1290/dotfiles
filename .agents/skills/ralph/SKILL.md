---
name: ralph
description: Autonomous development loop — each iteration on its own branch, gated by /review + /fix-review, merged to main
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# /ralph -- Autonomous development loop with per-iteration review + merge

Work autonomously using the Ralph iteration protocol. Each iteration is a short-lived branch off `$RALPH_MAIN_BRANCH`, gated by `/review` and `/fix-review`, optionally augmented by a Gemini UI/UX pass via `/opencode`, then merged back with `--no-ff`.

## Arguments
$ARGUMENTS

### Mode Selection

Parse arguments:
- **No arguments** → **Autopilot** mode: work through the entire task graph
- `--goal "<description>"` → **Goal** mode: work toward the stated goal
- `--single` → **Single Task** mode: work on the next Beads task only
- `-n <number>` / `--max-iterations <number>` → hard cap on iterations
- `--ui` → force the Gemini UI/UX pass for this session (required in goal mode; overrides label detection in other modes)

### Authorization notice

**Invoking `/ralph` constitutes explicit user authorization for this skill to push to `origin/$RALPH_MAIN_BRANCH`** per the merge step below. This authorization is scoped to `/ralph` only — it does not grant any other command permission to push the main branch.

### Unsupported environments

`/ralph` does **not** support:
- Concurrent `/ralph` sessions in the same repo (no lock; do not run two at once)
- Submodules / git worktrees
- Branches protected against direct push (use a PR flow instead)

---

## Step 0 — Resolve main branch

Read the project-level ralph config to determine which branch acts as `main`. Run this before any other step:

```bash
# Default to "main"; override via .ralph in the repo root
RALPH_MAIN_BRANCH="main"
if [[ -f ".ralph" ]]; then
  _cfg=$(grep -oP '(?<=^main_branch=).*' .ralph 2>/dev/null | head -1)
  [[ -n "$_cfg" ]] && RALPH_MAIN_BRANCH="$_cfg"
fi
echo "Using main branch: $RALPH_MAIN_BRANCH"
```

`.ralph` format (project root, optionally tracked in git):
```
main_branch=my-feature-base
```

If `.ralph` is absent or `main_branch` is not set, `RALPH_MAIN_BRANCH` stays `"main"`.

---

## Step 1 — Preflight (hard fail on any check)

Every check below must pass before any branching happens. Any failure → abort with an actionable message; do not attempt to "fix it up."

```bash
# 1. Git context
git rev-parse --show-toplevel >/dev/null                          # inside a repo
git remote get-url origin >/dev/null                              # origin exists

# origin/RALPH_MAIN_BRANCH may not exist yet for local-only branches — warn but don't abort
if git ls-remote --exit-code origin "refs/heads/$RALPH_MAIN_BRANCH" >/dev/null 2>&1; then
  echo "✓ origin/$RALPH_MAIN_BRANCH exists"
else
  echo "⚠ origin/$RALPH_MAIN_BRANCH does not exist yet (local-only branch)"
fi

# 2. Current branch must be RALPH_MAIN_BRANCH (no magic checkout)
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" != "$RALPH_MAIN_BRANCH" ]]; then
  echo "ralph must be invoked from $RALPH_MAIN_BRANCH (currently on $CURRENT). Run: git checkout $RALPH_MAIN_BRANCH" >&2
  exit 1
fi

# 3. Entire worktree clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit, stash, or discard changes before running /ralph." >&2
  exit 1
fi

# 4. If remote branch exists, ensure local can fast-forward to it
git rev-parse --verify "$RALPH_MAIN_BRANCH" >/dev/null
if git rev-parse --verify "origin/$RALPH_MAIN_BRANCH" >/dev/null 2>&1; then
  git pull --ff-only "origin" "$RALPH_MAIN_BRANCH" || {
    echo "$RALPH_MAIN_BRANCH diverged from origin/$RALPH_MAIN_BRANCH. Reconcile manually before /ralph." >&2
    exit 1
  }
fi

# 5. No unmerged ralph iteration branches (local OR remote)
LOCAL_LEFTOVER=$(git for-each-ref --format='%(refname:short)' 'refs/heads/ralph/iteration-*')
REMOTE_LEFTOVER=$(git ls-remote --heads origin 'ralph/iteration-*' | awk '{print $2}' | sed 's|refs/heads/||')
if [[ -n "$LOCAL_LEFTOVER" || -n "$REMOTE_LEFTOVER" ]]; then
  echo "Unmerged ralph iteration branch exists." >&2
  [[ -n "$LOCAL_LEFTOVER"  ]] && echo "  local:  $LOCAL_LEFTOVER"  >&2
  [[ -n "$REMOTE_LEFTOVER" ]] && echo "  remote: $REMOTE_LEFTOVER" >&2
  echo "Clean up manually before rerunning." >&2
  exit 1
fi

# 6. .agents/reviews/ must not be tracked in git
if git ls-files .agents/reviews/ 2>/dev/null | grep -q .; then
  echo ".agents/reviews/ is tracked in git. Run:" >&2
  echo "  git rm -r --cached .agents/reviews/ && echo .agents/reviews/ >> .gitignore && git commit -m 'gitignore .agents/reviews/'" >&2
  exit 1
fi

# 7. Idempotently exclude .agents/reviews/ for this session
grep -qxF '.agents/reviews/' .git/info/exclude || echo '.agents/reviews/' >> .git/info/exclude
```

---

## Step 2 — Iteration setup

Run at the start of every iteration.

### Iteration number `N`

Sourced from merge commits on `$RALPH_MAIN_BRANCH` so it is durable across branch deletion, fresh clones, and shared work:

```bash
N=$(git log "$RALPH_MAIN_BRANCH" --format='%s' \
    | grep -oE '^ralph: iteration [0-9]+ merge' \
    | awk '{print $3}' | sort -n | tail -1)
N=$(( ${N:-0} + 1 ))
```

### Slug

Source in priority order:
1. **Autopilot / single-task mode**: title of the current Beads task (`bd show "$TASK_ID" --json | jq -r .title`)
2. **Goal mode**: the `--goal` argument
3. **Fallback**: `iter-$(date +%Y%m%d-%H%M%S)`

Sanitize:
```bash
SLUG=$(printf '%s' "$RAW_SLUG_SOURCE" \
       | tr '[:upper:]' '[:lower:]' \
       | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//' \
       | cut -c1-40)
[[ -z "$SLUG" ]] && SLUG="iter-$(date +%Y%m%d-%H%M%S)"

BRANCH="ralph/iteration-${N}-${SLUG}"
git checkout -b "$BRANCH"
```

### UI label detection

```bash
TASK_HAS_UI_LABEL=0

if [[ "${RALPH_FORCE_UI:-0}" == "1" ]]; then
  # --ui flag was passed
  TASK_HAS_UI_LABEL=1
elif [[ -n "${TASK_ID:-}" ]]; then
  # Autopilot / single mode with a beads task
  bd show "$TASK_ID" --json 2>/dev/null \
    | jq -r '.labels[]?' 2>/dev/null \
    | grep -qx ui && TASK_HAS_UI_LABEL=1
fi
```

In `--goal` mode with no `--ui` flag: `TASK_HAS_UI_LABEL` stays `0`.

---

## Step 3 — Work loop (inner ASSESS / EXECUTE / VERIFY cycle)

This is the existing ralph inner loop. Run it until the objective is locally complete and the auto-detected test suite passes on the iteration branch.

### Objective source

- **Autopilot**: `bv --robot-triage` then process tasks in priority order. After each task: `bd update <id> --status closed`, check for newly unblocked tasks, continue. One iteration = one task (or one task cluster).
- **Goal mode**: work toward the stated goal, breaking it into logical sub-steps.
- **Single Task**: work the one highest-priority ready beads task.

If beads is not initialized: fall back to goal-less behavior. No UI detection, slug uses timestamp.

### Inner cycle

1. **ASSESS** — review previous iteration results, check test status, identify next increment
2. **EXECUTE** — make one focused, testable change
3. **VERIFY** — run the auto-detected test/build suite:
   - **Go** (`go.mod`): `go test ./... && go build ./...`
   - **Node** (`package.json`): `yarn test` / `pnpm test` / `npm test` (pick via lockfile)
   - **Python** (`pyproject.toml` / `setup.py`): `pytest`
   - **Rust** (`Cargo.toml`): `cargo test && cargo build`
   - **Make** (`Makefile`): `make test`
   - None detected: verify manually, or add tests before continuing
4. **CHECKPOINT** — when tests pass, `git add -A && git commit -m "ralph: iteration ${N} checkpoint - <brief>"`. The pre-commit hook at `.claude/hooks/pre-commit-tests.sh` re-runs tests.
5. Repeat until the objective is done on this branch.

Checkpoint commits are preserved through the `--no-ff` merge to `$RALPH_MAIN_BRANCH`.

---

## Step 4 — Empty-iteration short-circuit

Tree-diff (NOT a commit count — a branch can commit and revert and still be net-empty):

```bash
if git diff --quiet "$RALPH_MAIN_BRANCH"...HEAD; then
  git checkout "$RALPH_MAIN_BRANCH"
  git branch -D "$BRANCH"
  # Go to Step 11 (evaluate / loop)
fi
```

---

## Step 5 — `/review`

Invoke the `/review` skill. It diffs `$RALPH_MAIN_BRANCH...HEAD` on the current branch and writes two independent Opus reviews into `./.agents/reviews/{sanitized-branch}/{opus,opus2}/`. No arguments required.

The `/review` skill also reads `.ralph` to determine the base branch — pass it the same config if needed.

Review artifacts are excluded by `.git/info/exclude` from Step 1.

---

## Step 6 — `/fix-review`

Invoke the `/fix-review` skill. It reads `./.agents/reviews/{branch}/{opus,opus2}/04-action-items.md` and applies prioritized fixes via Edit.

Then re-run the auto-detected test suite:

```bash
# <run the same test command from Step 3>

# If anything changed and tests pass, commit
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "ralph: iteration ${N} - review fixes"
fi
```

If tests fail after `/fix-review`: one inner ASSESS/EXECUTE/VERIFY remediation pass. Still failing → **abort this iteration** without merging. Leave the iteration branch in place (local + origin once Step 8 runs, or local only if Step 8 hasn't happened yet) for manual inspection, and halt the session. Local `$RALPH_MAIN_BRANCH` is still clean.

---

## Step 7 — UI/UX pass via Gemini (conditional on `TASK_HAS_UI_LABEL == 1`)

Run Gemini via the opencode wrapper and persist its output:

```bash
REVIEW_DIR="./.agents/reviews/$(echo "$BRANCH" | tr '/' '-')"
mkdir -p "$REVIEW_DIR"

bash "$HOME/.claude/skills/opencode/opencode_run.sh" \
  --task-name "ralph-ui-${N}" \
  --model "google/gemini-3-pro-preview" \
  --permissions full \
  "$(cat <<'PROMPT'
You are reviewing the UI/UX changes on the current git branch vs the base branch.
Focus exclusively on: visual hierarchy, accessibility (ARIA, contrast, keyboard nav),
responsive layout, interaction affordances, and design system consistency.

Run `git diff $RALPH_MAIN_BRANCH...HEAD` to see the changes. Produce a markdown report with three sections:
- Critical UI/UX issues (must fix)
- Suggested improvements
- Positive patterns worth preserving

Output the report to stdout. Do not modify files.
PROMPT
)" > "$REVIEW_DIR/gemini-ui.md"
```

Then Claude (ralph) reads `$REVIEW_DIR/gemini-ui.md` and applies the "Critical" fixes (and any obviously correct "Suggested" ones) using Edit/Write. Keeping Claude in the loop for the actual edits avoids handing write access to Gemini-via-opencode and keeps `/fix-review` untouched.

Run tests again. If anything changed and tests pass, commit:

```bash
git add -A
git commit -m "ralph: iteration ${N} - gemini ui fixes"
```

`gemini-ui.md` lives under `.agents/reviews/` and is already excluded from git by Step 1.

---

## Step 8 — Push the iteration branch

```bash
git push -u origin "$BRANCH"
```

Any failure here → abort iteration, leave branch locally, report, halt session. Never `--force`.

---

## Step 9 — Merge to `$RALPH_MAIN_BRANCH` (bounded retry, explicit failure handling)

```bash
for attempt in 1 2 3; do
  git checkout "$RALPH_MAIN_BRANCH"

  # Pull from remote only if the remote branch exists
  if git rev-parse --verify "origin/$RALPH_MAIN_BRANCH" >/dev/null 2>&1; then
    git pull --ff-only origin "$RALPH_MAIN_BRANCH"
  fi

  if ! git merge --no-ff "$BRANCH" -m "ralph: iteration ${N} merge - ${SLUG}"; then
    # Conflict — do not retry. Unwind and halt.
    git merge --abort
    echo "iteration ${N} conflicts with $RALPH_MAIN_BRANCH. Manual resolution required." >&2
    echo "Iteration branch left at origin/${BRANCH}." >&2
    exit 1
  fi

  # Push — set upstream on first push if remote branch doesn't exist yet
  if git rev-parse --verify "origin/$RALPH_MAIN_BRANCH" >/dev/null 2>&1; then
    PUSH_CMD="git push origin $RALPH_MAIN_BRANCH"
  else
    PUSH_CMD="git push -u origin $RALPH_MAIN_BRANCH"
  fi

  if $PUSH_CMD; then
    break   # success
  fi

  # Push rejected — discard local merge so branch stays ff-able, then retry
  git reset --hard "origin/$RALPH_MAIN_BRANCH" 2>/dev/null || git reset --hard HEAD~1

  if [[ $attempt -eq 3 ]]; then
    echo "Failed to push $RALPH_MAIN_BRANCH after 3 attempts. Iteration branch left at origin/${BRANCH}." >&2
    echo "Local $RALPH_MAIN_BRANCH is clean." >&2
    exit 1
  fi
done
```

Two critical invariants of this block:
1. **Merge conflict is never retried** — `git merge --abort` restores the branch, iteration branch is preserved for manual resolution.
2. **Every push-failure path resets local branch** so it is never left ahead of origin with an unpublished merge commit.

If the repo is protected against direct pushes, the push will fail every attempt and the retry loop exits cleanly. Use a PR flow instead of `/ralph` in those repos.

---

## Step 10 — Post-merge cleanup

```bash
git branch -d "$BRANCH"
git push origin --delete "$BRANCH"
```

---

## Step 11 — Evaluate and loop

- If the objective is fully complete, emit `<promise>COMPLETE</promise>` and exit.
- Otherwise return to **Step 2** — the preflight has already been satisfied and `$RALPH_MAIN_BRANCH` is clean at HEAD of `origin/$RALPH_MAIN_BRANCH`, so just re-enter iteration setup.
- Respect `-n` / `--max-iterations` if specified — hard cap, even if more work remains.

---

## Commit structure per iteration

With `--no-ff` preserving the iteration branch, `$RALPH_MAIN_BRANCH` ends up with:

1. N work-loop checkpoint commits (one per successful VERIFY)
2. `ralph: iteration N - review fixes` (only if `/fix-review` changed anything)
3. `ralph: iteration N - gemini ui fixes` (only if the Gemini pass ran and applied changes)
4. Merge commit: `ralph: iteration N merge - slug` ← this is the anchor Step 2 parses for `N`

---

## Edge cases (all handled above)

| Case | Handling |
|---|---|
| No `origin` / unreachable | Preflight abort |
| `origin/$RALPH_MAIN_BRANCH` absent | Warned (not aborted) — first push creates it |
| Not invoked from `$RALPH_MAIN_BRANCH` | Preflight abort, no implicit checkout |
| Dirty worktree anywhere | Preflight abort |
| `$RALPH_MAIN_BRANCH` diverged from remote | Preflight abort (only if remote branch exists) |
| Unmerged `ralph/iteration-*` branch (local OR remote) | Preflight abort |
| `.agents/reviews/` already tracked in git | Preflight abort with remediation |
| Merge conflict against `$RALPH_MAIN_BRANCH` | `merge --abort`, halt, leave branch |
| Push rejected (any cause) | reset to safe state, bounded retry, then halt |
| Beads not initialized | Fall back: no UI label detection, timestamp slug |
| Empty iteration (no net diff vs merge-base) | Delete branch, skip review/merge, loop |
| UI label but no UI files changed | Gemini pass still runs, applies nothing, no-op commit |
| `/review` / `/fix-review` produce no action items | `/fix-review` no-ops gracefully |
| Concurrent `/ralph` sessions in the same repo | Undefined, explicitly unsupported |

---

Begin working now.
