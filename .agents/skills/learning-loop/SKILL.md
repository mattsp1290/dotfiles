---
name: learning-loop
description: Collaborative learn-by-doing feature development — Claude implements on an isolated branch in a fresh /tmp clone (your working tree and branch history are untouched until you apply), teaches at decision points with Insight and Decision-point markers, then guides you through reviewing and applying what you want.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /learning-loop — Collaborative feature development in a safe clone

Build a feature together. Claude does all the mechanical work on an isolated `learning/*` branch in a fresh git clone under `/tmp/learning-session/` — nothing is visible in your repository until you explicitly fetch and merge. Along the way, `Insight:` notes surface non-obvious patterns and `Decision point:` prompts invite your input at meaningful technical forks.

**What "isolated" means precisely:** a fresh clone shares no git objects with your repo. The `learning/*` branch and all its commits live entirely in `/tmp` until you run the apply step. Your working tree and branch history are completely untouched. The one exception: the *review-before-apply* sub-step adds a temporary `learning-clone` remote to `.git/config`; cleanup removes it.

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
REPO_HASH=$(printf '%s' "$PROJECT_ROOT" | { shasum 2>/dev/null || sha1sum; } | cut -c1-6)
[[ -z "$REPO_HASH" ]] && { echo "ERROR: no sha1 tool found"; exit 1; }
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
BASE_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")

SESSION_ID="${REPO_HASH}-${SLUG}"
CLONE_DIR="/tmp/learning-session/${SESSION_ID}"
BRANCH="learning/${SESSION_ID}"
STATE_FILE="/tmp/learning-session/${SESSION_ID}.env"   # sibling to clone dir, never inside it

# On resume, carry forward learning mode so ORIENT doesn't re-ask.
LEARNING_MODE=""; PROJECT_LANGUAGE=""; SOURCE_LANGUAGE=""
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
```

Check whether a session already exists or needs to be created:

```bash
IN_GIT=0
git rev-parse --show-toplevel >/dev/null 2>&1 && IN_GIT=1

if [[ $IN_GIT -eq 1 ]]; then
  mkdir -p /tmp/learning-session

  if [[ -d "$CLONE_DIR/.git" ]]; then
    if (cd "$CLONE_DIR" && git show-ref --verify --quiet "refs/heads/$BRANCH"); then
      echo "Resuming existing session: $CLONE_DIR (mode: ${LEARNING_MODE:-unset})"
      echo "Note: the clone is a snapshot of the base at session start; any new commits on $BASE_BRANCH in the original repo are not reflected here."
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
  mkdir -p "$CLONE_DIR"
  rsync -a --exclude='.git' "$PROJECT_ROOT/" "$CLONE_DIR/"
fi
```

Write the state file (sibling to the clone dir — never inside it, so `git add -A` cannot stage it):

```bash
mkdir -p /tmp/learning-session
cat > "$STATE_FILE" <<ENVEOF
PROJECT_ROOT="$PROJECT_ROOT"
BASE_BRANCH="$BASE_BRANCH"
BASE_SHA="$BASE_SHA"
SLUG="$SLUG"
SESSION_ID="$SESSION_ID"
CLONE_DIR="$CLONE_DIR"
BRANCH="$BRANCH"
IN_GIT="$IN_GIT"
LEARNING_MODE="$LEARNING_MODE"
PROJECT_LANGUAGE="$PROJECT_LANGUAGE"
SOURCE_LANGUAGE="$SOURCE_LANGUAGE"
ENVEOF

cp "$STATE_FILE" /tmp/learning-session/current.env
```

**Every subsequent Bash block sources state with this exact literal command:**
```bash
source /tmp/learning-session/current.env && cd "$CLONE_DIR"
```

No substitution needed — `current.env` always points to the active session.

**The clone at `$CLONE_DIR` is your entire workspace.** It is a full copy of the project. `cd` there and read, grep, glob, and edit files exclusively within `$CLONE_DIR`. Never read or touch `$PROJECT_ROOT` paths after this point.

**Note:** the clone branches from the committed HEAD of `$BASE_BRANCH`. Any uncommitted changes in your working tree will not be present in the clone. If the task depends on uncommitted work, stash it in the original, then apply the stash in `$CLONE_DIR` before starting.

---

## Step 1 — ORIENT

```bash
source /tmp/learning-session/current.env && cd "$CLONE_DIR"
```

Read the relevant codebase areas. Form a plan.

**Detect `PROJECT_LANGUAGE`** from the files the task will touch (preferred) or from root manifests if the touched files don't make it clear. Precedence: `go.mod`→Go, `Cargo.toml`→Rust, `*.nimble`→Nim, `pyproject.toml`/`setup.py`→Python, `package.json`→JavaScript/TypeScript, `Makefile`→(use what the task touches). If genuinely ambiguous, use "this project" as the language label.

Present:
1. A one-paragraph summary of the approach and why
2. The files you plan to touch, with a one-line reason for each
3. An `Insight:` if there is a non-obvious architectural constraint or pattern shaping the whole implementation

**Learning mode question** — ask this in the same turn as any clarifying questions (one round-trip total, not two). Append it as the final item after any clarifying questions, or as the only question if no clarifying questions are needed:

> What would you like to focus on learning in this session? Pick one or two — Ship-focused cannot be combined with others.
>
> 1. **Idiomatic `<PROJECT_LANGUAGE>`** — learn where this language's idioms diverge from your instincts
> 2. **Ship-focused** — implement end to end; I'll teach only at genuine forks
> 3. *(optional, include only if the task genuinely forces a non-trivial design decision with no default-correct answer — e.g., a public API surface multiple callers depend on, or a hot path where algorithmic choice is load-bearing. Do NOT add this for CRUD endpoints, config plumbing, or standard test coverage. If uncertain, omit it.)*

Ask at most two clarifying questions on architecture, correctness, or rollout risk. Do not ask about preferences — assume and state. Learning mode counts as one question in the budget.

**After the user responds**, update the state file with the selected mode(s) and source language. If Idiomatic mode is selected and the user's source language is not clear from context (prior code, filenames, conversation), ask one short follow-up: "What's your primary language background? I'll focus on where `<PROJECT_LANGUAGE>` diverges from `<source>` habits." Then write:

```bash
source /tmp/learning-session/current.env

# Set from user's response:
LEARNING_MODE="<user's choice: idiom | ship | api-design | testing | performance | architecture>"
PROJECT_LANGUAGE="<detected above>"
SOURCE_LANGUAGE="<inferred or stated by user; empty if not idiom mode>"

cat >> "$STATE_FILE" <<ENVEOF
LEARNING_MODE="$LEARNING_MODE"
PROJECT_LANGUAGE="$PROJECT_LANGUAGE"
SOURCE_LANGUAGE="$SOURCE_LANGUAGE"
ENVEOF
cp "$STATE_FILE" /tmp/learning-session/current.env
```

**On resume** (LEARNING_MODE already set from Step 0): skip the mode question. Emit one line: "Resuming in `<LEARNING_MODE>` mode — say 'change mode' to re-pick." If the user says "change mode," re-present the menu and update the state file.

If `LEARNING_MODE` is not set on resume of an older session (state file pre-dates this field), silently default to `idiom`.

Begin Step 2 immediately after the user responds (or after the source-language follow-up if needed). No further waiting.

---

## Mode behaviors

All modes are sparing with markers — the difference is *what earns a marker*, not how many appear.

| Mode | `TODO(human):` focuses on | `Insight:` / `Decision point:` leans toward |
|---|---|---|
| `idiom` | Idiomatic constructs where `PROJECT_LANGUAGE`'s approach diverges from `SOURCE_LANGUAGE` instincts (judgment call required — see discriminator below) | Language-specific patterns; where `SOURCE_LANGUAGE` intuitions mislead in `PROJECT_LANGUAGE` |
| `api-design` | Public-surface choices with long-lived consequence: naming, signatures, error types, versioning | API design tradeoffs affecting callers; backward-compatibility implications |
| `testing` | Test-case and property selection; boundary identification; choosing example-based vs property-based | Coverage seams; test architecture tradeoffs; what to stub vs integrate |
| `performance` | Algorithmic choices at hot paths; explicit tradeoff between clarity and throughput | Concurrency and allocation surprises; when optimization is premature vs necessary |
| `architecture` | Structural decisions: component boundaries, dependency direction, contract design | Long-lived architectural tradeoffs; coupling and cohesion |
| `ship` | Never used — no `TODO(human):`. Every increment is fully implemented and verified, leaving nothing for the user to complete. | Only for genuinely surprising things. `Decision point:` only when architecturally load-bearing. |

**Combining modes** — up to two non-`ship` modes may be selected. When two modes are active, an increment earns a `TODO(human):` only if it hits both topical areas simultaneously (not one or the other). This keeps markers rare.

**Idiom mode: exercise discriminator**

A good idiom exercise forces a *judgment call* at a point where the user's `SOURCE_LANGUAGE` instinct produces non-idiomatic `PROJECT_LANGUAGE` code. A bad one has a single mechanically-correct translation.

Example — Go, for a Java/Python developer:
- ✓ **Good**: "Design the error handling for this multi-step operation." The fork is real: sentinel errors vs `fmt.Errorf("...: %w", err)` wrapping vs a custom error type implementing `error`. Java/Python instinct reaches for exceptions — which Go doesn't have — so the exercise lands on the divergence and requires judgment about call-site needs.
- ✗ **Bad**: "Iterate over this slice" or "convert this class into a struct." Mechanical, single correct answer, no instinct to unlearn.

**Rule**: if there is one mechanically-correct translation, implement it yourself — it is not an idiom exercise.

When `SOURCE_LANGUAGE` is known, make the framing explicit in SHOW: "In `<source>`, you'd typically write X. In idiomatic `<target>`, the approach is Y because Z."

---

## Step 2 — Iteration loop: ASSESS → BUILD → VERIFY → COMMIT → SHOW

Repeat until the objective is complete (or `-n` cap is reached). Track iteration number N (start at 1, increment each loop). After COMMIT, if N equals the cap, stop and go to Step 3. Every Bash block in this loop starts with:

```bash
source /tmp/learning-session/current.env && cd "$CLONE_DIR"
```

Apply the mode behaviors from the **Mode behaviors** section above for all marker decisions in this loop.

### ASSESS

Identify the next focused, testable increment. State in one sentence what it achieves and why it is the right next step.

`Insight:` — Add only if the increment touches something non-obvious per the active mode's focus (see Mode behaviors). Do not add for straightforward changes.

`Decision point:` — If the user's input could meaningfully change the design (not just style or preference), pause per the active mode's focus. Present two or three named options with brief tradeoffs. If the user does not respond and progress can continue, pick the most defensible option and proceed, noting the choice.

### BUILD

Implement the increment. All file paths are under `$CLONE_DIR`.

- Do all mechanical and boilerplate work yourself. Do not assign the user chores: renaming, updating imports, writing obvious tests, applying repetitive edits.
- Match the idioms, error-handling style, and naming conventions of the surrounding code.
- `TODO(human):` — Reserve for a deliberate, high-signal design exercise per the active mode (see Mode behaviors). When used, write a stub that **compiles and has a skipped/pending test** so VERIFY passes. Not more than one per iteration. If none is warranted, write none.

### VERIFY

```bash
source /tmp/learning-session/current.env && cd "$CLONE_DIR"
# Auto-detect and run:
# Go (go.mod):             go test ./... && go build ./...
# Node (package.json):     pnpm-lock.yaml→pnpm test, yarn.lock→yarn test, else npm test
# Python (pyproject.toml): pytest
# Rust (Cargo.toml):       cargo test && cargo build
# Make (Makefile):         make test
# None detected: ask the user what "verified" means for this change before proceeding
```

On failure: one remediation pass inside BUILD, then re-verify. If still failing, surface the error, explain what you tried, and ask how to proceed rather than spinning.

### COMMIT

After a passing VERIFY:

```bash
source /tmp/learning-session/current.env && cd "$CLONE_DIR"
git add -A
git commit -m "learning-loop: $SLUG - increment $N"
```

### SHOW

Present a compact summary of this increment:
- Files changed and what each does (one sentence each)
- Any `Insight:` for decisions made implicitly during BUILD
- Any `TODO(human):` exercise with its acceptance criteria

In idiom mode, add one line in SHOW for any patterns implemented: "In `<source>`, you'd write X. Idiomatic `<target>` uses Y because Z." Only when there's a genuine divergence worth naming.

Then: "Ready for the next increment, or is there something here you'd like to dig into first?"

---

## Step 3 — Completion and apply

When the objective is fully implemented:

**Takeaways summary**: what was built, how it was verified, and one or two deeper patterns or tradeoffs worth remembering from this work.

**Review changes** — add the clone as a temporary remote and fetch the branch. `BASE_SHA` (recorded at session start) is used as the diff base:

```bash
source /tmp/learning-session/current.env
cd "$PROJECT_ROOT"

git remote add learning-clone "$CLONE_DIR" 2>/dev/null \
  || git remote set-url learning-clone "$CLONE_DIR"
git fetch learning-clone "$BRANCH"

git diff "$BASE_SHA"...learning-clone/"$BRANCH"          # full diff (three-dot: only branch additions)
git log "$BASE_SHA"..learning-clone/"$BRANCH" --oneline  # commit list
```

**Apply options** — run the review/fetch block above first, then choose:

```bash
source /tmp/learning-session/current.env
cd "$PROJECT_ROOT"
# (learning-clone remote and learning-clone/$BRANCH tracking ref from the review step)

# Option A — merge (keeps all increment commits)
git merge learning-clone/"$BRANCH"

# Option B — squash into one commit
git merge --squash learning-clone/"$BRANCH" && git commit

# Option C — cherry-pick specific commits
#   Find SHAs: cd "$CLONE_DIR" && git log --oneline "$BRANCH"
#   Objects already present after the fetch above — cherry-pick directly:
git cherry-pick <sha>

# Option D — grab specific files only
git checkout learning-clone/"$BRANCH" -- path/to/file.go
```

**Cleanup after applying:**

```bash
source /tmp/learning-session/current.env
cd "$PROJECT_ROOT"
git remote remove learning-clone 2>/dev/null
rm -rf "$CLONE_DIR"
rm -f "$STATE_FILE"
rm -f /tmp/learning-session/current.env
```

---

## Non-git fallback: apply step

```bash
source /tmp/learning-session/current.env

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
REPO_HASH=$(printf '%s' "$PROJECT_ROOT" | { shasum 2>/dev/null || sha1sum; } | cut -c1-6)

ls /tmp/learning-session/${REPO_HASH}-*.env 2>/dev/null | sed "s|.*${REPO_HASH}-||; s|\.env$||"
```

If `<slug>` is provided, reconstruct `SESSION_ID="${REPO_HASH}-<slug>"`, then `source /tmp/learning-session/${SESSION_ID}.env` to recover `BASE_SHA`, `BASE_BRANCH`, and `CLONE_DIR`. If the state file is missing, ask the user which commit/branch to diff against.

Run the review/fetch block from Step 3 first, then walk through the apply options. Offer cleanup after.

---

## --cleanup flag

When invoked as `/learning-loop --cleanup`:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_HASH=$(printf '%s' "$PROJECT_ROOT" | { shasum 2>/dev/null || sha1sum; } | cut -c1-6)

cd "$PROJECT_ROOT" 2>/dev/null

for env_file in /tmp/learning-session/${REPO_HASH}-*.env; do
  [[ -f "$env_file" ]] || continue
  CLONE_DIR=""; SESSION_ID=""
  source "$env_file"
  [[ -n "$CLONE_DIR" ]] && rm -rf "$CLONE_DIR" \
    && echo "Removed clone: $SESSION_ID" \
    || echo "Clone path missing or empty — skipping: $env_file"
  rm -f "$env_file" && echo "Removed state: $env_file"
done

git remote remove learning-clone 2>/dev/null && echo "Removed learning-clone remote"
rm -f /tmp/learning-session/current.env && echo "Cleared active-session pointer"
```

---

## Response shape (throughout the session)

- **Progress updates**: concise. One sentence per step unless something unusual happened.
- **`Insight:`** — non-obvious pattern per the active mode's focus. One sentence, on its own line. Use sparingly.
- **`Decision point:`** — when the user's input can shape the design per the active mode. Named options with tradeoffs. Never ask about style or preference.
- **`TODO(human):`** — high-signal exercise per the active mode (see Mode behaviors). Must include a compiling stub and a skipped test. Clear acceptance criteria. Never mechanical chores.
- **Final response**: what was built, how it was verified, one or two deeper takeaways.

---

## Edge cases

| Case | Handling |
|---|---|
| Session dir exists, branch present in clone | Resume silently; emit "Resuming in `<mode>` mode — say 'change mode' to re-pick." |
| Session dir exists, branch gone from clone | Warn and restart (rm -rf + fresh clone) |
| LEARNING_MODE not set on resume (older session) | Default to `idiom` silently |
| User says "change mode" on resume | Re-present the menu; update state file and re-copy to current.env |
| Idiomatic mode, source language unknown | Ask one follow-up in the same ORIENT turn |
| PROJECT_LANGUAGE detection ambiguous (polyglot repo) | Use language of the files the task touches; if still ambiguous, use generic label "this project" |
| Not in a git repo | rsync mirror; no test suite auto-detected — ask what "verified" means before proceeding |
| Test suite not detected | Ask the user what "verified" means before VERIFY |
| VERIFY still failing after one remediation pass | Surface error, explain attempts, ask how to proceed |
| `Decision point:` ignored by user | Pick most defensible option, note the choice, proceed |
| `-n` cap reached | Summarize remaining work, give apply instructions for what is done |
| `TODO(human):` at VERIFY | Stub must compile; write skipped test; do not block VERIFY |
| Ship-focused mode | No `TODO(human):` — every increment fully implemented; no stub needed |
| `--apply` with no matching session | List sessions: `ls /tmp/learning-session/${REPO_HASH}-*.env` |
| Detached HEAD in original repo | BASE_SHA (not BASE_BRANCH) is used as diff base — safe |
| Cross-repo same slug | Scoped by repo hash in SESSION_ID — no collision |
| Uncommitted changes in working tree | Clone branches from committed HEAD; stash and apply to clone if needed |
| Dangling learning-clone remote after crash | `--cleanup` removes it; also safe to `git remote remove learning-clone` manually |
| `current.env` left from prior session | Overwritten at Step 0; `--cleanup` removes it |

---

Begin working now.
