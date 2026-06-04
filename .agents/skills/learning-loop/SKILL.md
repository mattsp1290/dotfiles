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

# On resume, carry forward session context so ORIENT doesn't re-ask.
LEARNING_MODE=""; PROJECT_LANGUAGE=""; SOURCE_LANGUAGE=""; PRIMARY_ENTRYPOINT=""
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
PRIMARY_ENTRYPOINT="$PRIMARY_ENTRYPOINT"
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

**Detect architecture signals** in the files the task will touch:
- **New outbound dependency**: the task *adds* a first-time call to a remote service this code didn't previously depend on, or moves logic that was previously in-process across the network boundary. A pre-existing call to a service already depended on is NOT a trigger.
- **Multiple main entrypoints**: the repo has more than one distinct executable entry (`cmd/*/main.go`, multiple `bin` entries in `package.json`, separate Procfile processes / docker-compose services pointing to different executables). Do NOT use Python `__main__` files as a proxy — they are often library utilities, not entrypoints.

Present:
1. A one-paragraph summary of the approach and why
2. The files you plan to touch, with a one-line reason for each
3. An `Insight:` if there is a non-obvious architectural constraint or pattern shaping the whole implementation

**Learning mode question** — ask in the same turn as any clarifying questions (one round-trip total, not two). Append it as the final item, or as the only question if none are needed:

> What would you like to focus on learning in this session? Pick one or two — Ship-focused cannot be combined with others.
>
> 1. **Idiomatic `<PROJECT_LANGUAGE>`** — learn where this language's idioms diverge from your instincts
> 2. **Ship-focused** — implement end to end; I'll teach only at genuine forks
> 3. **Architecture** *(include this option only when an architecture signal fired above — new outbound dependency OR multiple main entrypoints with shared code touched. Do NOT include merely because existing network calls appear in the touched files. If uncertain, omit it.)* — understand caller/callee contracts and what crosses process and network boundaries
> 4. *(Other task-derived option: api-design / testing / performance — include only when no architecture signal fired AND the task forces a non-trivial design decision with no default-correct answer in one of these areas. Do NOT add for CRUD endpoints, config plumbing, or standard test coverage. If uncertain, omit. At most one of option 3 or option 4 — not both.)*

Ask **at most two clarifying questions** on architecture, correctness, or rollout risk. Do not ask about preferences — assume and state. The mode question counts as one question in the budget. Do not ask the multi-entrypoint question here — it is deferred to the first ASSESS where a contract fork makes the answer relevant (see Mode behaviors).

**After the user responds**, update the state file:

```bash
source /tmp/learning-session/current.env

LEARNING_MODE="<user's choice: idiom | ship | api-design | testing | performance | architecture>"
PROJECT_LANGUAGE="<detected above>"
SOURCE_LANGUAGE="<inferred or stated by user; empty if not idiom mode>"
# PRIMARY_ENTRYPOINT is populated lazily during architecture-mode ASSESS, not here.

cat >> "$STATE_FILE" <<ENVEOF
LEARNING_MODE="$LEARNING_MODE"
PROJECT_LANGUAGE="$PROJECT_LANGUAGE"
SOURCE_LANGUAGE="$SOURCE_LANGUAGE"
ENVEOF
cp "$STATE_FILE" /tmp/learning-session/current.env
```

If Idiomatic mode is selected and the user's source language is not clear from context, ask one short follow-up in the same turn: "What's your primary language background? I'll focus on where `<PROJECT_LANGUAGE>` diverges from `<source>` habits."

**On resume** (LEARNING_MODE already set from Step 0): skip the mode question. Emit one line: "Resuming in `<LEARNING_MODE>` mode — say 'change mode' to re-pick." If the user says "change mode," re-present the menu and update the state file.

If `LEARNING_MODE` is not set on resume of an older session (state file pre-dates this field), silently default to `idiom`.

Begin Step 2 immediately after the user responds. No further waiting.

---

## Mode behaviors

All modes are sparing with markers — the difference is *what earns a marker*, not how many appear.

| Mode | `TODO(human):` focuses on | `Insight:` / `Decision point:` leans toward |
|---|---|---|
| `idiom` | Idiomatic constructs where `PROJECT_LANGUAGE`'s approach diverges from `SOURCE_LANGUAGE` instincts (judgment call required — see idiom discriminator below) | Language-specific patterns; where `SOURCE_LANGUAGE` intuitions mislead in `PROJECT_LANGUAGE` |
| `api-design` | Public-surface choices with long-lived consequence: naming, signatures, error types, versioning | API design tradeoffs affecting callers; backward-compatibility implications |
| `testing` | Test-case and property selection; boundary identification; choosing example-based vs property-based | Coverage seams; test architecture tradeoffs; what to stub vs integrate |
| `performance` | Algorithmic choices at hot paths; explicit tradeoff between clarity and throughput | Concurrency and allocation surprises; when optimization is premature vs necessary |
| `architecture` | Contract decisions at boundaries with no default-correct answer: *semantic* failure contract for a new outbound call (is this operation idempotent? what does the caller observe on timeout vs hard failure vs partial success?); caller/callee interface when multiple consumers exist and optimizing for one harms another. **Claude implements all mechanical wiring** (timeout config, retry logic, client setup, circuit breaker plumbing) — the TODO(human) is the semantic decision only. | Who calls this code and from what execution context (HTTP handler? background worker? CLI? library consumer?); for new network boundaries: the failure modes the caller must now reckon with, the remote service and protocol; whether a new dependency creates a coupling or layering concern |
| `ship` | Never used — no `TODO(human):`. Every increment is fully implemented and verified, leaving nothing for the user to complete. | Only for genuinely surprising things. `Decision point:` only when architecturally load-bearing. |

**Combining modes** — up to two non-`ship` modes may be selected. Each axis earns a marker when *its own criterion* is met — don't suppress an architecture marker just because an idiom exercise didn't also fire, and vice versa. When both axes fire on the same increment, merge them into one unified `TODO(human):` rather than two separate ones. Don't manufacture combined exercises that force-join both axes; the natural joint exercises are described in the architecture discriminator below.

---

### Idiom mode: exercise discriminator

A good idiom exercise forces a *judgment call* at a point where the user's `SOURCE_LANGUAGE` instinct produces non-idiomatic `PROJECT_LANGUAGE` code. A bad one has a single mechanically-correct translation.

Example — Go, for a Java/Python developer:
- ✓ **Good**: "Design the error handling for this multi-step operation." The fork is real: sentinel errors vs `fmt.Errorf("...: %w", err)` wrapping vs a custom error type implementing `error`. Java/Python instinct reaches for exceptions — which Go doesn't have — so the exercise lands on the divergence and requires judgment about call-site needs.
- ✗ **Bad**: "Iterate over this slice" or "convert this class into a struct." Mechanical, single correct answer, no instinct to unlearn.

**Rule**: if there is one mechanically-correct translation, implement it yourself — it is not an idiom exercise.

When `SOURCE_LANGUAGE` is known, make the framing explicit in SHOW: "In `<source>`, you'd typically write X. In idiomatic `<target>`, the approach is Y because Z."

---

### Architecture mode: exercise discriminator

A good architecture exercise forces a contract or boundary decision with **no default-correct answer** and a **nameable long-lived cost if chosen wrong**. A bad one is mechanical wiring with a single correct outcome.

- ✓ **Good**: "This function is called by both the synchronous API handler and the async batch worker. The batch caller holds a DB transaction and calls this in a tight loop; the HTTP caller calls it once per request without a transaction. Design the interface so neither caller's ownership assumptions bleed into the other — name what leaks if you optimize for only one." Real fork, durable consequence.
- ✗ **Bad**: "Wire up the HTTP call to the users service" or "add retry middleware" or "configure the timeout." Mechanical, single correct answer — Claude does this.

**Rule**: if the structural choice has one defensible answer given the constraints, implement it yourself — it is not an architecture exercise.

**Multi-entrypoint — ask lazily**: when `architecture` mode is active and an increment touches shared code across entry points, raise a `Decision point:` at that ASSESS: *"This code has multiple consumers (`cmd/api`, `cmd/worker`, ...). Is one the primary consumer, or is this intentionally designed to serve all equally?"* — "serves multiple consumers equally" is a first-class answer. When given, leave `PRIMARY_ENTRYPOINT` empty and focus `TODO(human):` on multi-consumer contract design (the richer lesson). When a primary is named, update the state file:
```bash
source /tmp/learning-session/current.env
PRIMARY_ENTRYPOINT="cmd/api"   # whatever the user named
cat >> "$STATE_FILE" <<ENVEOF
PRIMARY_ENTRYPOINT="$PRIMARY_ENTRYPOINT"
ENVEOF
cp "$STATE_FILE" /tmp/learning-session/current.env
```
When `PRIMARY_ENTRYPOINT` is empty in architecture mode, frame using "the callers of this code" generically rather than a named entry point.

**Idiom + architecture joint exercises**: the reliable natural hook is error-type design at a boundary — the boundary's failure modes expressed through the language's error idiom (e.g., Rust `enum` + `thiserror` for each remote failure mode; Go custom error types that callers can `errors.As` against). This is genuinely both: idiomatic error representation AND naming the boundary's failure modes as a contract. If the architectural fork is purely structural with no language-idiom surface (e.g., "should this be one service or two"), emit it as an architecture-only `TODO(human):` rather than manufacturing a forced idiom angle.

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

`Decision point:` — If the user's input could meaningfully change the design per the active mode's focus, pause. Present two or three named options with brief tradeoffs. If the user does not respond and progress can continue, pick the most defensible option and proceed, noting the choice.

In architecture mode: if this is the first increment that touches shared code across multiple entry points and `PRIMARY_ENTRYPOINT` is unset, raise the multi-entrypoint `Decision point:` described in Mode behaviors before building.

### BUILD

Implement the increment. All file paths are under `$CLONE_DIR`.

- Do all mechanical and boilerplate work yourself. Do not assign the user chores: renaming, updating imports, writing obvious tests, applying repetitive edits.
- Match the idioms, error-handling style, and naming conventions of the surrounding code.
- In architecture mode: implement all mechanical wiring (timeouts, retries, client setup, circuit breaker plumbing) yourself. The TODO(human) is the semantic/contract decision only.
- `TODO(human):` — Reserve for a deliberate, high-signal exercise per the active mode (see Mode behaviors and discriminators). When used, write a stub that **compiles and has a skipped/pending test** so VERIFY passes. Not more than one per iteration. If none is warranted, write none.

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

In idiom mode, add one line in SHOW for any patterns implemented where there is a genuine divergence: "In `<source>`, you'd write X. Idiomatic `<target>` uses Y because Z."

In architecture mode, add one line in SHOW when a new network boundary was crossed: "This call goes to `<remote service>` via `<protocol>`. Failure modes the caller inherits: `<list>`."

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

diff -rq "$PROJECT_ROOT" "$CLONE_DIR"
rsync -av --dry-run --exclude='.git' "$CLONE_DIR/" "$PROJECT_ROOT/"
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
- **`TODO(human):`** — high-signal exercise per the active mode (see Mode behaviors and discriminators). Must include a compiling stub and a skipped test. Clear acceptance criteria. Never mechanical chores.
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
| Architecture signal detected in ORIENT | Surface Architecture as the task-derived menu option (slot 3) |
| No architecture signal detected | Apply strict gate for task-derived slot: api-design / testing / performance only if task forces a non-trivial design decision |
| Architecture mode — multi-entrypoint first seen | Raise a Decision point at that ASSESS (not in ORIENT); "serves multiple consumers equally" is a valid answer |
| "Serves multiple consumers equally" given | Leave PRIMARY_ENTRYPOINT empty; focus TODO(human) on multi-consumer contract design |
| PRIMARY_ENTRYPOINT empty in architecture mode | Frame as "the callers of this code" generically |
| Idiom + architecture selected | Each axis earns its own marker on its criterion; natural joint exercise is error-type design at the boundary |
| PROJECT_LANGUAGE detection ambiguous (polyglot repo) | Use language of the files the task touches; if still ambiguous, use "this project" |
| Not in a git repo | rsync mirror; ask what "verified" means before VERIFY |
| Test suite not detected | Ask the user what "verified" means before VERIFY |
| VERIFY still failing after one remediation pass | Surface error, explain attempts, ask how to proceed |
| `Decision point:` ignored by user | Pick most defensible option, note the choice, proceed |
| `-n` cap reached | Summarize remaining work, give apply instructions for what is done |
| `TODO(human):` at VERIFY | Stub must compile; write skipped test; do not block VERIFY |
| Ship-focused mode | No `TODO(human):`; no stub needed |
| `--apply` with no matching session | List sessions: `ls /tmp/learning-session/${REPO_HASH}-*.env` |
| Detached HEAD in original repo | BASE_SHA (not BASE_BRANCH) is used as diff base — safe |
| Cross-repo same slug | Scoped by repo hash in SESSION_ID — no collision |
| Uncommitted changes in working tree | Clone branches from committed HEAD; stash and apply to clone if needed |
| Dangling learning-clone remote after crash | `--cleanup` removes it; also safe to `git remote remove learning-clone` manually |
| `current.env` left from prior session | Overwritten at Step 0; `--cleanup` removes it |

---

Begin working now.
