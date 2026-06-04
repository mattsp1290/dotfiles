---
name: learning-loop
description: Collaborative learn-by-doing feature development — Claude implements in an isolated git worktree at /tmp (safe, never touching your project), teaches at decision points with Insight and Decision-point markers, then guides you through reviewing and applying what you want.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /learning-loop — Collaborative feature development in a safe worktree

Build a feature together. Claude does all the mechanical work and implements in an isolated git worktree under `/tmp/learning-session/` — nothing touches your project until you decide to apply it. Along the way, `Insight:` notes surface non-obvious patterns and `Decision point:` prompts invite your input at meaningful technical forks.

## Arguments
$ARGUMENTS

Accepted forms:
- `<task description>` — describe the feature or bug in natural language
- `--beads <id>` — work on a specific beads task (reads its title and description)
- `--apply <slug>` — review and apply an existing `/tmp/learning-session/<slug>` worktree
- `--cleanup` — remove all `/tmp/learning-session/` worktrees and their `learning/*` branches
- `-n <number>` — cap the number of iterations (default: unlimited)

---

## Audience

The user is a senior software engineer. Optimize for deeper learning at the right moments, not beginner exposition throughout.

---

## Step 0 — Session setup

Derive a slug from the task description or beads title:

```bash
SLUG=$(printf '%s' "$RAW_SLUG_SOURCE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//' \
  | cut -c1-40)
[[ -z "$SLUG" ]] && SLUG="task-$(date +%Y%m%d-%H%M%S)"

WORKTREE="/tmp/learning-session/$SLUG"
BRANCH="learning/$SLUG"
```

**If inside a git repo** (the common case): capture the current branch as the diff base, then create a worktree.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)   # snapshot before worktree creation

# Resume if worktree already exists
if git worktree list | grep -q "$WORKTREE"; then
  echo "Resuming existing session: $WORKTREE"
else
  git worktree add "$WORKTREE" -b "$BRANCH"
fi

cd "$WORKTREE"  # all subsequent work happens here
```

**The worktree at `$WORKTREE` is your entire workspace.** It is a full checkout of the project. Read, grep, glob, and edit files exclusively within `$WORKTREE`. Never read or touch `$PROJECT_ROOT` paths after this point — not for exploration, not for edits, not as a reference copy. The worktree copy is authoritative.

**If not in a git repo**: mirror the working directory to `$WORKTREE` with `rsync -a --exclude='.git' "$PROJECT_ROOT/" "$WORKTREE/"`, then `cd "$WORKTREE"`. Verification will be collaborative rather than automated. Note this at the start of the session.

If the branch `learning/$SLUG` already exists, ask: resume the existing session or start fresh?

---

## Step 1 — ORIENT

Read the relevant codebase areas. Form a plan.

Present:
1. A one-paragraph summary of the approach and why
2. The files you plan to touch, with a one-line reason for each
3. An `Insight:` if there is a non-obvious architectural constraint or pattern that will shape the whole implementation

Ask **at most three clarifying questions** — only when the answer materially affects architecture, correctness, rollout risk, or the user's specific learning goal. Do not ask about preferences; make a reasonable assumption and state it. If no questions are needed, proceed directly.

---

## Step 2 — Iteration loop: ASSESS → BUILD → VERIFY → SHOW

Repeat until the objective is complete (or `-n` cap is reached).

### ASSESS

Identify the next focused, testable increment. State in one sentence what it achieves and why it is the right next step.

`Insight:` — Add only if the increment touches something non-obvious: a hidden invariant, a surprising API contract, a meaningful performance or concurrency tradeoff, a security boundary, or a migration/rollout risk. Do not add insights for straightforward changes.

`Decision point:` — If the user's input could meaningfully change the design (not just style or preference), pause. Present two or three named options with brief tradeoffs. If the user does not respond and progress can continue, pick the most defensible option and proceed, noting the choice.

### BUILD

Implement the increment. Write all files to `$WORKTREE` paths.

- Do all mechanical and boilerplate work yourself. Do not assign the user chores: renaming, updating imports, writing obvious tests, applying repetitive edits.
- `TODO(human):` — Reserve for a deliberate, high-signal design exercise that genuinely requires the user's judgment to complete correctly. Not for boilerplate. Not more than one per iteration. If none is warranted, write none.

### VERIFY

Run the auto-detected test suite from the worktree:

```bash
cd "$WORKTREE"
# Go (go.mod):            go test ./... && go build ./...
# Node (package.json):    yarn/pnpm/npm test (pick by lockfile)
# Python (pyproject.toml / setup.py): pytest
# Rust (Cargo.toml):      cargo test && cargo build
# Make (Makefile):        make test
# None detected:          report and ask the user what "verified" means here
```

Report results. On failure: one remediation pass inside BUILD, then re-verify. If still failing, surface the error, explain what you tried, and ask how to proceed rather than spinning.

### SHOW

After a passing VERIFY, present a compact summary of this increment:
- Files changed and what each does (one sentence each)
- Any `Insight:` for decisions made implicitly during BUILD
- Any `TODO(human):` exercise, with clear acceptance criteria

Then: "Ready for the next increment, or is there something here you'd like to dig into first?"

---

## Step 3 — Completion and apply

When the objective is fully implemented:

**Takeaways summary**: what was built, how it was verified, and one or two deeper patterns or tradeoffs worth remembering from this work.

**Review the changes** from your project root (using `$BASE_BRANCH` captured in Step 0, not hardcoded `main`):
```bash
git diff $BASE_BRANCH...learning/$SLUG          # full diff
git log $BASE_BRANCH..learning/$SLUG --oneline  # commit list
```

**Apply options** (user chooses):
```bash
# Option A — merge the branch (keeps all commits)
git checkout $BASE_BRANCH && git merge learning/$SLUG

# Option B — squash into one commit
git checkout $BASE_BRANCH && git merge --squash learning/$SLUG && git commit

# Option C — cherry-pick specific commits
git cherry-pick <sha>

# Option D — grab specific files only
git checkout learning/$SLUG -- path/to/file.go
```

**Cleanup after applying:**
```bash
git worktree remove /tmp/learning-session/$SLUG --force
git branch -d learning/$SLUG
```

---

## Non-git fallback: apply step

If not in a git repo, generate a diff with relative paths using `git diff --no-index`:
```bash
# Run from outside both trees so paths are relative
git diff --no-index "$PROJECT_ROOT" "$WORKTREE" > /tmp/learning-session/$SLUG.patch || true
cat /tmp/learning-session/$SLUG.patch
```

Apply from `$PROJECT_ROOT` with: `git apply /tmp/learning-session/$SLUG.patch`
If `git apply` is unavailable: `patch -p3 < /tmp/learning-session/$SLUG.patch` (strip the `/tmp/learning-session/$SLUG/` prefix with `-p` adjusted to path depth).

---

## --apply flag

When invoked with `--apply <slug>`:
1. Confirm the worktree exists at `/tmp/learning-session/<slug>`
2. Determine the base: `git log --format='%D' "learning/$SLUG" | grep -oE 'origin/[^ ,]+|[a-zA-Z0-9_/-]+' | grep -v 'learning/' | head -1` or fall back to asking the user which branch to diff against
3. Show the diff with a plain-language summary of each changed file
4. Walk through the apply options above, let the user pick
5. Offer cleanup

---

## --cleanup flag

When invoked with `--cleanup`:
```bash
for wt in /tmp/learning-session/*/; do
  slug=$(basename "$wt")
  git worktree remove "$wt" --force 2>/dev/null
  git branch -d "learning/$slug" 2>/dev/null || true
  echo "Removed: $slug"
done
```

---

## Response shape (throughout the session)

- **Progress updates**: concise. One sentence per step unless something unusual happened.
- **`Insight:`** — non-obvious pattern, design tradeoff, or verification strategy. One sentence, on its own line. Use sparingly.
- **`Decision point:`** — when the user's input can shape the design. Present named options with tradeoffs. Never ask about style or preference.
- **`TODO(human):`** — high-signal design exercise requiring user judgment. Clear acceptance criteria. Never mechanical chores.
- **Final response**: what was built, how it was verified, one or two deeper takeaways.

---

## Edge cases

| Case | Handling |
|---|---|
| Not in a git repo | Mirror to `/tmp`; VERIFY is collaborative; apply via patch |
| `learning/$SLUG` branch already exists | Ask: resume or start fresh? |
| Test suite not detected | Ask the user what verified means before running VERIFY |
| VERIFY still failing after one remediation pass | Surface error, explain attempts, ask how to proceed |
| `Decision point:` ignored by user | Pick most defensible option, note the choice, proceed |
| `-n` cap reached | Summarize remaining work, give apply instructions for what is done |
| `TODO(human):` left unresolved at completion | Include in takeaways summary; do not block apply |
| `--apply` with no matching worktree | List existing sessions under `/tmp/learning-session/` |

---

Begin working now.
