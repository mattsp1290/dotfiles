---
name: learning-loop
description: Collaborative learn-by-doing feature development — Claude implements on an isolated branch in a fresh /tmp clone (your repo is untouched until you apply), teaches at decision points with Insight and Decision-point markers, then guides you through reviewing and applying what you want.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /learning-loop — Collaborative feature development in a safe clone

Build a feature together. Claude does all the mechanical work on an isolated `learning/*` branch in a fresh git clone under `/tmp/learning-session/` — nothing is visible in your repository until you explicitly fetch and merge. Along the way, `Insight:` notes surface non-obvious patterns and `Decision point:` prompts invite your input at meaningful technical forks.

**What "isolated" means precisely:** a fresh clone shares no git objects with your repo. The `learning/*` branch and all its commits live entirely in `/tmp` until you run the apply step. Your working tree, current branch, and `git log` are completely untouched.

## Arguments
$ARGUMENTS

Accepted forms:
- `<task description>` — describe the feature or bug in natural language
- `--beads <id>` — work on a specific beads task (`bd show <id>` for title and description)
- `--apply [slug]` — review and apply an existing session; omit slug to list sessions for this repo
- `--cleanup` — remove all `/tmp/learning-session/` clones for this repo
- `-n <number>` — cap the number of iterations (default: unlimited)

---

## Audience

The user is a senior software engineer. Optimize for deeper learning at the right moments, not beginner exposition throughout.

---

## Step 0 — Session setup

```bash
# --beads <id>: RAW_SLUG=$(bd show <id> --json | jq -r .title)
# Otherwise:    RAW_SLUG is the task description argument

SLUG=$(printf '%s' "$RAW_SLUG" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//' \
  | cut -c1-40)
[[ -z "$SLUG" ]] && SLUG="task-$(date +%Y%m%d-%H%M%S)"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_HASH=$(printf '%s' "$PROJECT_ROOT" | shasum | cut -c1-6)
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

SESSION_ID="${REPO_HASH}-${SLUG}"
CLONE_DIR="/tmp/learning-session/${SESSION_ID}"
BRANCH="learning/${SESSION_ID}"
STATE_FILE="/tmp/learning-session/${SESSION_ID}.env"   # sibling to clone dir, never inside it
```

Check whether a session already exists or needs to be created:

```bash
IN_GIT=0
git rev-parse --show-toplevel >/dev/null 2>&1 && IN_GIT=1

if [[ $IN_GIT -eq 1 ]]; then
  mkdir -p /tmp/learning-session

  if [[ -d "$CLONE_DIR/.git" ]]; then
    # Session dir exists — check if branch is still in the clone
    if (cd "$CLONE_DIR" && git show-ref --verify --quiet "refs/heads/$BRANCH"); then
      echo "Resuming existing session: $CLONE_DIR"
      cd "$CLONE_DIR" && git checkout "$BRANCH"
    else
      echo "Session directory exists but branch is gone — starting fresh."
      rm -rf "$CLONE_DIR"
      git clone "$PROJECT_ROOT" "$CLONE_DIR"
      cd "$CLONE_DIR" && git checkout -b "$BRANCH"
    fi
  else
    git clone "$PROJECT_ROOT" "$CLONE_DIR"
    cd "$CLONE_DIR" && git checkout -b "$BRANCH"
  fi
else
  # Non-git: mirror working directory
  mkdir -p "$CLONE_DIR"
  rsync -a --exclude='.git' "$PROJECT_ROOT/" "$CLONE_DIR/"
fi
```

Write the state file (sibling to the clone dir — never inside it, so it cannot be committed):

```bash
mkdir -p /tmp/learning-session
cat > "$STATE_FILE" <<ENVEOF
PROJECT_ROOT="$PROJECT_ROOT"
BASE_BRANCH="$BASE_BRANCH"
SLUG="$SLUG"
SESSION_ID="$SESSION_ID"
CLONE_DIR="$CLONE_DIR"
BRANCH="$BRANCH"
IN_GIT="$IN_GIT"
ENVEOF
```

**Print the session ID prominently** — the agent must use this exact path in every subsequent Bash block:

```
SESSION: /tmp/learning-session/<SESSION_ID>.env
```

**The clone at `$CLONE_DIR` is your entire workspace.** It is a full copy of the project. `cd` there and read, grep, glob, and edit files exclusively within `$CLONE_DIR`. Never read or touch `$PROJECT_ROOT` paths after this point.

**At the top of every subsequent Bash block**, source state and set cwd:
```bash
source /tmp/learning-session/<SESSION_ID>.env && cd "$CLONE_DIR"
```

**Note:** the clone branches from the committed HEAD of `$BASE_BRANCH`. Any uncommitted changes in your working tree will not be present in the clone. If the task depends on uncommitted work, stash it in the original, then apply the stash in `$CLONE_DIR` before starting.

---

## Step 1 — ORIENT

```bash
source /tmp/learning-session/<SESSION_ID>.env && cd "$CLONE_DIR"
```

Read the relevant codebase areas. Form a plan.

Present:
1. A one-paragraph summary of the approach and why
2. The files you plan to touch, with a one-line reason for each
3. An `Insight:` if there is a non-obvious architectural constraint or pattern shaping the whole implementation

Ask **at most three clarifying questions** — only when the answer materially affects architecture, correctness, rollout risk, or the user's specific learning goal. Do not ask about preferences; make a reasonable assumption and state it. If no questions are needed, proceed directly.

---

## Step 2 — Iteration loop: ASSESS → BUILD → VERIFY → COMMIT → SHOW

Repeat until the objective is complete (or `-n` cap is reached). Track iteration number N (start at 1, increment each loop). Every Bash block in this loop starts with:

```bash
source /tmp/learning-session/<SESSION_ID>.env && cd "$CLONE_DIR"
```

### ASSESS

Identify the next focused, testable increment. State in one sentence what it achieves and why it is the right next step.

`Insight:` — Add only if the increment touches something non-obvious: a hidden invariant, a surprising API contract, a meaningful performance or concurrency tradeoff, a security boundary, or a migration/rollout risk. Do not add insights for straightforward changes.

`Decision point:` — If the user's input could meaningfully change the design (not just style or preference), pause. Present two or three named options with brief tradeoffs. If the user does not respond and progress can continue, pick the most defensible option and proceed, noting the choice.

### BUILD

Implement the increment. All file paths are under `$CLONE_DIR`.

- Do all mechanical and boilerplate work yourself. Do not assign the user chores: renaming, updating imports, writing obvious tests, applying repetitive edits.
- `TODO(human):` — Reserve for a deliberate, high-signal design exercise requiring the user's judgment. When used, write a stub that **compiles and has a skipped/pending test** so VERIFY passes. Not more than one per iteration. If none is warranted, write none.

### VERIFY

```bash
source /tmp/learning-session/<SESSION_ID>.env && cd "$CLONE_DIR"
# Auto-detect and run:
# Go (go.mod):             go test ./... && go build ./...
# Node (package.json):     pnpm-lock.yaml→pnpm test, yarn.lock→yarn test, else npm test
# Python (pyproject.toml): pytest
# Rust (Cargo.toml):       cargo test && cargo build
# Make (Makefile):         make test
# None detected: report and ask the user what "verified" means here
```

On failure: one remediation pass inside BUILD, then re-verify. If still failing, surface the error, explain what you tried, and ask how to proceed rather than spinning.

### COMMIT

After a passing VERIFY:

```bash
source /tmp/learning-session/<SESSION_ID>.env && cd "$CLONE_DIR"
git add -A
git commit -m "learning-loop: $SLUG - increment $N"
```

### SHOW

Present a compact summary of this increment:
- Files changed and what each does (one sentence each)
- Any `Insight:` for decisions made implicitly during BUILD
- Any `TODO(human):` exercise with its acceptance criteria

Then: "Ready for the next increment, or is there something here you'd like to dig into first?"

---

## Step 3 — Completion and apply

When the objective is fully implemented:

**Takeaways summary**: what was built, how it was verified, and one or two deeper patterns or tradeoffs worth remembering from this work.

**Review changes** — fetch the branch from the clone and diff it against base:

```bash
source /tmp/learning-session/<SESSION_ID>.env
cd "$PROJECT_ROOT"

# Temporarily add the clone as a local remote to fetch from
git remote add learning-clone "$CLONE_DIR" 2>/dev/null \
  || git remote set-url learning-clone "$CLONE_DIR"
git fetch learning-clone "$BRANCH"

git diff "$BASE_BRANCH"...FETCH_HEAD          # full diff (three-dot: only branch additions)
git log "$BASE_BRANCH"..FETCH_HEAD --oneline  # commit list
```

**Apply options** — always run from `$PROJECT_ROOT`:

```bash
source /tmp/learning-session/<SESSION_ID>.env
cd "$PROJECT_ROOT"
# (assumes learning-clone remote and FETCH_HEAD from the review step above)

# Option A — merge (keeps all increment commits)
git merge FETCH_HEAD

# Option B — squash into one commit
git merge --squash FETCH_HEAD && git commit

# Option C — cherry-pick specific commits
#   First note the SHAs from the clone: cd "$CLONE_DIR" && git log --oneline "$BRANCH"
#   Then from PROJECT_ROOT:
git fetch learning-clone <sha>  # fetch the specific object
git cherry-pick <sha>

# Option D — grab specific files only
git checkout FETCH_HEAD -- path/to/file.go
```

**Cleanup after applying:**

```bash
source /tmp/learning-session/<SESSION_ID>.env
cd "$PROJECT_ROOT"
git remote remove learning-clone 2>/dev/null
rm -rf "$CLONE_DIR"
rm -f "$STATE_FILE"
```

---

## Non-git fallback: apply step

Review what changed, then apply via rsync:

```bash
source /tmp/learning-session/<SESSION_ID>.env

# Review
diff -rq "$PROJECT_ROOT" "$CLONE_DIR"

# Dry run
rsync -av --dry-run --exclude='.git' "$CLONE_DIR/" "$PROJECT_ROOT/"

# Apply (after reviewing the dry run output)
rsync -av --exclude='.git' "$CLONE_DIR/" "$PROJECT_ROOT/"
```

---

## --apply flag

When invoked as `/learning-loop --apply` or `/learning-loop --apply <slug>`:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_HASH=$(printf '%s' "$PROJECT_ROOT" | shasum | cut -c1-6)

# List available sessions for this repo
ls /tmp/learning-session/${REPO_HASH}-*.env 2>/dev/null | sed "s|.*${REPO_HASH}-||; s|\.env$||"
```

If `<slug>` is provided, reconstruct `SESSION_ID="${REPO_HASH}-<slug>"`, then `source /tmp/learning-session/${SESSION_ID}.env` to recover `BASE_BRANCH` and `CLONE_DIR`. If the state file is missing, ask the user which branch to diff against.

Walk through the fetch, review, and apply options from Step 3. Offer cleanup after.

---

## --cleanup flag

When invoked as `/learning-loop --cleanup`:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_HASH=$(printf '%s' "$PROJECT_ROOT" | shasum | cut -c1-6)

for env_file in /tmp/learning-session/${REPO_HASH}-*.env; do
  [[ -f "$env_file" ]] || continue
  source "$env_file"
  rm -rf "$CLONE_DIR" \
    && echo "Removed clone: $SESSION_ID" \
    || echo "Clone already gone: $SESSION_ID"
  rm -f "$env_file" && echo "Removed state: $env_file"
done

# Also remove any dangling learning-clone remote if still present
git remote remove learning-clone 2>/dev/null && echo "Removed learning-clone remote"
```

Scoped to this repo's hash — never touches another project's sessions.

---

## Response shape (throughout the session)

- **Progress updates**: concise. One sentence per step unless something unusual happened.
- **`Insight:`** — non-obvious pattern, design tradeoff, or verification strategy. One sentence, on its own line. Use sparingly.
- **`Decision point:`** — when the user's input can shape the design. Present named options with tradeoffs. Never ask about style or preference.
- **`TODO(human):`** — high-signal design exercise requiring user judgment. Must include a compiling stub and a skipped test. Clear acceptance criteria. Never mechanical chores.
- **Final response**: what was built, how it was verified, one or two deeper takeaways.

---

## Edge cases

| Case | Handling |
|---|---|
| Session dir exists, branch present in clone | Resume silently |
| Session dir exists, branch gone from clone | Warn and restart (rm -rf + fresh clone) |
| Not in a git repo | rsync mirror; VERIFY is collaborative; apply via rsync |
| Test suite not detected | Ask the user what "verified" means before VERIFY |
| VERIFY still failing after one remediation pass | Surface error, explain attempts, ask how to proceed |
| `Decision point:` ignored by user | Pick most defensible option, note the choice, proceed |
| `-n` cap reached | Summarize remaining work, give apply instructions for what is done |
| `TODO(human):` at VERIFY | Stub must compile; write skipped test; do not block VERIFY |
| `--apply` with no matching session | List sessions: `ls /tmp/learning-session/${REPO_HASH}-*.env` |
| Cherry-pick SHA from clone | `git fetch learning-clone <sha>` first, then cherry-pick |
| Cross-repo same slug | Scoped by repo hash in SESSION_ID — no collision |
| Uncommitted changes in working tree | Note: clone branches from committed HEAD; stash and apply to clone if needed |
| Dangling learning-clone remote after crash | `--cleanup` removes it; also safe to `git remote remove learning-clone` manually |

---

Begin working now.
