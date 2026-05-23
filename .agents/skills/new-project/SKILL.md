---
name: new-project
description: Interactive planner that walks through questions and produces a project task plan in docs/prompts/
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /new-project -- Interactive New Project Planner

You are helping the user plan a new project using the template below. Your job is to walk through each placeholder section, collect answers interactively, and produce a completed prompt file.

## Setup

1. Use the template provided in the "Template" section below
2. Determine the **project name** from the basename of the current working directory
3. Determine today's **date** in YYYY-MM-DD format

## Collecting Information

You will ask the user **4 questions**, one at a time. Wait for the user's response before moving to the next question. Keep your questions concise.

If the user provided arguments (shown below), use them as the pre-filled **Project Description** — show it to the user for confirmation rather than asking from scratch.

**User arguments:** $ARGUMENTS

### Question 1: Project Description

- If `$ARGUMENTS` is non-empty, show: "I'll use this as the project description: **{$ARGUMENTS}** — want to adjust it, or is that good?"
- If `$ARGUMENTS` is empty, ask: "Describe the project you want to build."

### Question 2: Links to Relevant Documentation

Ask: "Any links to relevant docs, APIs, design docs? (enter 'none' to skip)"

If the user says "none", "no", "n/a", or similar, use `N/A`.

### Question 3: Technical Stack

Ask: "What's the technical stack? (languages, frameworks, databases, etc.)"

### Question 4: Specific Requirements

Ask: "Any specific requirements? (auth, performance targets, accessibility, integrations, etc.) Enter 'none' to skip."

If the user says "none", "no", "n/a", or similar, use `N/A`.

## Generating the Output

Once you have all 4 answers, fill in the template. The template has four sections each containing `{PLEASE FILL THIS OUT}` — replace each one with the matching answer based on section heading:

1. Under `### Links to Relevant Documentation` — replace `{PLEASE FILL THIS OUT}` with the links answer (or N/A)
2. Under `### Project Description` — replace `{PLEASE FILL THIS OUT}` with the project description
3. Under `### Technical Stack` — replace `{PLEASE FILL THIS OUT}` with the technical stack
4. Under `### Specific Requirements` — replace `{PLEASE FILL THIS OUT}` with the specific requirements (or N/A)
5. In the Example Output script section, replace:
   - `{PROJECT_NAME}` with the project name (from cwd basename)
   - `{DATE}` with today's date

## Saving the File

1. Convert the project description to **kebab-case** for the filename (lowercase, spaces/special chars to hyphens, collapse multiple hyphens, trim leading/trailing hyphens, max 60 chars)
2. Create the directory `docs/prompts/` if it doesn't exist (use `mkdir -p`)
3. Save the completed template to `docs/prompts/<kebab-case-name>.md`

## GPT Review Loop

After the plan file is saved, run an opt-out GPT review pass so ChatGPT can catch gaps before the plan is turned into a Beads task graph. The loop iterates up to 3 rounds, applying user-approved edits between rounds.

### Opt-in gate

Ask the user exactly:

```
Run a GPT review pass on this plan? (Y/n)
```

- Blank or `Y`/`y`/`yes` → proceed to step 1 below.
- `n`/`no`/`skip`/`stop`/`done`/`good enough`/`exit` (case-insensitive) → print `Review loop exited by user. Plan file is saved and ready.` and return to the "Final Output" section. Do **not** create any state file, opencode-sessions entry, or temp prompt file.

### Loop state

The loop spans multiple `Bash` invocations and user turns. Each `Bash` call is a fresh shell, so you cannot rely on shell variables across turns. Persist every round-spanning value to `/tmp/plan-review-state-<FRESH_KEY>.json` and re-read it at the start of each round. Re-read it if your own context is ever compressed mid-loop.

**State file schema** (initial values shown):
```json
{
  "schema_version": 1,
  "fresh_key": "<FRESH_KEY>",
  "plan_path": "/abs/path/to/docs/prompts/<kebab>.md",
  "kebab": "<kebab>",
  "skill": "new-project",
  "round": 1,
  "phase": "awaiting_first_gpt",
  "pending_concerns": [],
  "pending_concern_index": 0,
  "last_raw_gpt_response": "",
  "accepted_edits": [],
  "declined_suggestions": [],
  "user_extra_concerns": []
}
```

`phase` progresses through `awaiting_first_gpt` → `processing_concerns` → `awaiting_signoff` → `awaiting_user_concerns` → `done`. Write the file after **every** user decision: y/n per edit, decline reason, user-extra concern, signoff answer. If at any round-start you find the state file absent, truncated, or invalid JSON, print `Plan review state file corrupt or missing; aborting review loop. Plan file is saved and ready.` and exit the phase without recovery attempts.

### Loop steps

1. Read `docs/prompts/<kebab>.md`. If `wc -c` reports `>= 102400` bytes, print `Plan file exceeds 100 KB; skipping GPT review to avoid argument-size limits. Plan file is saved and ready.` and exit the phase.
2. Compute a unique fresh session key using Bash:
   ```bash
   FRESH_KEY="plan-review-<kebab>-$(date +%Y%m%d%H%M%S)-$$-$(printf '%04d' $RANDOM)"
   ```
3. Check for pre-existing `/tmp/plan-review-state-<FRESH_KEY>.json` or `/tmp/opencode-review-prompt-<FRESH_KEY>.txt`. On (extremely unlikely) collision, regenerate the random suffix up to 3 times; after 3 collisions, print the corrupt-state abort message and give up.
4. Initialize the state file with the schema above.
5. Write the **first-turn review prompt** (template at bottom of this phase) to `/tmp/opencode-review-prompt-<FRESH_KEY>.txt`. Inline the full current contents of `docs/prompts/<kebab>.md` verbatim at the designated slot.
6. Invoke the wrapper via `Bash` with an explicit 270000 ms timeout parameter on the Bash tool call itself:
   ```bash
   bash "$HOME/.claude/skills/opencode/opencode_run.sh" \
     --task-name "<FRESH_KEY>" \
     --model "openai/gpt-5.4" \
     --timeout 240 \
     "$(cat /tmp/opencode-review-prompt-<FRESH_KEY>.txt)"
   ```
7. **Detect failure via exit code**:
   - Exit 0 → the response text is in stdout. Proceed to step 8.
   - Non-zero → retry **once** with `--model openai/gpt-5.4-fast` and a **fresh** `FRESH_KEY` (regenerate, re-initialize state, re-write the prompt file, re-invoke). The retry prompt must carry the full accumulated decision history from before the failure (since the new session has no prior context). Orphan the old state/prompt files in `/tmp`; no cleanup. Retries **do not consume rounds** — `ROUND` counts successful GPT turns, not attempts.
   - If the retry also fails non-zero, print:
     - `GPT review skipped due to opencode error. Plan file is saved and ready. Error: <stderr>` if `ROUND == 1` and `accepted_edits` is empty.
     - `GPT review aborted after partial review (round <ROUND>). Accepted edits are still applied to the plan file; declined items and user-extra concerns are preserved in /tmp/plan-review-state-<FRESH_KEY>.json. Error: <stderr>` otherwise.
     Then exit the phase. Never delete or modify the plan file on failure; edits already applied via the `Edit` tool stay applied.
8. Show the response verbatim to the user and print `[Round <ROUND>/3]`. Save the raw text to `last_raw_gpt_response` in the state file.
9. **Classify the response**:
   - Strip whitespace. Take the first non-empty line. Lowercase it. Strip trailing `.?!:,` and whitespace.
   - **APPROVED** if the result equals `approved`. If there is additional content after `APPROVED`, surface it to the user as `[GPT notes]` before the signoff gate, but do not record it in state.
   - Else, scan for a **contiguous numbered list**: the first line matching `^[\t ]{0,2}[0-9]+[.)]\s+\S` begins the block; numbering must be contiguous `1.`, `2.`, `3.`, ... Gaps, duplicates, or out-of-order numbering invalidate the block. Each item's body extends from its own top-level numbered line to the next top-level numbered line (blank lines, indented continuations, and sub-bullets are part of the item). Must have at least one item. Save the parsed list to `pending_concerns` with `origin: "gpt"`.
   - Else, print the **malformed-response prompt**:
     ```
     GPT's response didn't match the expected format. How should we proceed?
     (a) Treat as APPROVED and go to signoff gate
     (b) I'll paste the concerns as a numbered list (1., 2., 3., ...)
     (c) Skip the review loop
     ```
     - `(a)`: treat as APPROVED. `pending_concerns` stays empty.
     - `(b)`: collect a multi-line paste. Each input line is first checked against whole-loop exit phrases (below); on match, exit the loop. Then checked against the literal terminator `END`; on match, stop collecting. Otherwise append to the paste buffer. Parse the buffer with the same contiguous numbered-list rules. On parse failure, re-prompt with this same malformed-response prompt. Successful parses set `origin: "malformed_paste"`.
     - `(c)`: print `User skipped the review loop after malformed response. Plan file is saved and ready.` and exit the phase.
     A malformed round that resolves via `(a)` or successful `(b)` **still counts as round `<ROUND>`'s GPT turn** for the 3-round cap. `(c)` does not increment anything.
10. **Edit proposal loop**. For each concern from `pending_concern_index` forward:
    - Propose one concrete edit. For concerns that need multiple disjoint edits, propose them as one bundled unit (one `y/n` for the whole bundle). For concerns already satisfied by earlier edits or genuinely out of scope, propose a **no-op** ("no change — already satisfied by <prior edit> / out of scope because <reason>").
    - Ask `Apply this edit? (y/n/skip-rest)`.
      - `y`: apply via the `Edit` tool (or record the no-op), append `{concern, change}` to `accepted_edits`, advance the index, persist state.
      - `n`: ask `Why decline this suggestion?`, append `{suggestion, reason}` to `declined_suggestions`, advance the index, persist state.
      - `skip-rest`: mark all remaining concerns declined with reason `user skip-rest`, advance to step 11.
    - **Whole-loop exit precedence** applies to every prompt that takes user input (the y/n/skip-rest question, the decline reason, the signoff gate, the user-extra-concerns paste, the malformed-response paste). If the input (lowercased, trimmed) equals `done`, `good enough`, `exit`, `stop`, or `skip`, save state and print `Review loop exited by user. Plan file is saved and ready.` then exit. A literal `n` at y/n/skip-rest is **not** an exit (it's a decline). Case-insensitive match. If the user genuinely wants a decline reason of `stop`, they type `reason: stop` — strip a leading `reason: ` before the exit-phrase check.
11. **Round-cap gate**: immediately before any potential next GPT invocation, if `ROUND >= 3`, do not run another turn — print `Review loop hit the 3-round cap. To re-review, re-run /big-change (or /new-project) on the same plan and opt into the loop again; a fresh review session will be created.` and exit the phase. This check fires from three call sites: after step 10 finishes, after the user answers `more` at the signoff gate, and after a malformed `(b)` paste.
12. **Continuation round**: increment `ROUND`, persist state, write the **continuation-turn prompt** (template below) to the same `/tmp/opencode-review-prompt-<FRESH_KEY>.txt` (overwriting the prior round). Include the full current contents of `docs/prompts/<kebab>.md` inlined AND the full accumulated `accepted_edits`, `declined_suggestions`, and `user_extra_concerns` across the whole loop. Invoke the wrapper again with the same `FRESH_KEY`; the wrapper's per-PID UUID cache resolves to the same OpenCode session automatically. Go back to step 7.

### Signoff gate (APPROVED path only)

Print exactly:

```
GPT approved on round <ROUND>. Anything else you want to add, or are we done? (done/more)
```

- `done` (or any whole-loop exit phrase) → print `GPT review converged on round <ROUND>. Plan file is final.` and exit successfully.
- `more` → first check the round-cap gate (step 11). If `ROUND >= 3`, exit with the cap message. Otherwise set `phase: "awaiting_user_concerns"`, collect a multi-line input terminated by a line equal to `END` (with exit-phrase precedence on every input line). Each non-empty, non-exit, non-terminator line becomes `{text, round_raised: <ROUND+1>}` appended to `user_extra_concerns`, and also populates `pending_concerns` with `origin: "user_more"`. After collection, go to step 10 to propose edits for the user concerns. If the user accepts zero edits, the next continuation round still increments `ROUND` and is still subject to the cap; the continuation prompt records each user concern as `<concern> — noted but no edit was applied (user declined all proposed edits)`.

### Review prompt templates

Substitute the phrase **new project** for the `[big change | new project]` marker below — this is a render-time substitution specific to this skill.

**First-turn template** (write to `/tmp/opencode-review-prompt-<FRESH_KEY>.txt`):

```
You are critiquing a planning document. Your tools are denied by the enclosing
config — respond with TEXT only. Do not attempt file edits. Do not propose
rewrites of the plan.

The plan below will later drive an autonomous agent to generate a Beads task
graph for a new project. Your job is to catch gaps BEFORE task creation.

Plan contents:
---
<INLINE FULL CURRENT CONTENTS OF docs/prompts/<kebab>.md HERE>
---

Evaluate for:
- Ambiguity or missing constraints
- Unclear or unmeasurable success criteria
- Missing affected areas, stakeholders, or dependencies
- Scope sanity — is this a single coherent change, or should it be split?
  (Soft signal. Do NOT reject large plans on task count alone.)
- Tech-stack or architectural concerns
- Anything a future implementer would have to guess at

Respond with EXACTLY ONE of these two formats — nothing else:

FORMAT A — no concerns:
APPROVED

(The single word APPROVED, on its own line, with no preamble and no text after it.)

FORMAT B — concerns:
1. <first concern, one paragraph>
2. <second concern, one paragraph>
3. ...

(A contiguous numbered list starting at 1., each item on its own line, no
preamble before item 1, no summary after the last item.)

Do not mix formats. Do not add prose outside these two shapes.
```

**Continuation-turn template** (round 2+, overwrite the same temp file):

```
Tools are denied. Respond with TEXT only.

Since your last review, here is the full decision history for this loop
(accumulated across all rounds so far):

Accepted and applied (edits the user accepted from your prior suggestions):
- <bullet per accepted edit: short description of the change>
  [omit entire "Accepted" section if list is empty]

Declined (settled constraints — do NOT raise these again):
- <bullet per declined suggestion: "<original suggestion> — declined because <reason>">
  [omit entire "Declined" section if list is empty]

User-added concerns (not from your prior feedback, but requested by the user):
- <bullet per user concern and the resulting edit>
  [omit entire "User-added" section if list is empty]

Here is the FULL CURRENT plan with all edits applied. Re-review from scratch:
---
<INLINE FULL CURRENT CONTENTS OF docs/prompts/<kebab>.md HERE>
---

Treat every item in the "Declined" list as a settled constraint and do not
re-raise it. Respond with EXACTLY ONE of:

FORMAT A: APPROVED (on its own line, no other text)
FORMAT B: A contiguous numbered list of REMAINING concerns (1., 2., 3., ...)
```

Empty sections are omitted entirely — do not emit `(none)` placeholders.

## Final Output

After saving (and completing the GPT review loop, if run), tell the user:

- The file path where it was saved
- A brief summary of the project plan
- If the review loop ran, a one-line summary of the outcome (converged on round N, capped at 3, skipped on error, user-exited)
- Suggest next step: "You can now run this prompt with Claude to generate your beads task graph."

## Template

# Project Planning with Beads

## Agent Instructions

You are an expert software architect creating a comprehensive task breakdown. This task graph will be executed by AI agents working in parallel, coordinated through MCP Agent Mail with file reservations to prevent conflicts.

<quality_expectations>
Create a thorough, production-ready task graph. Include all necessary setup, implementation, testing, and documentation tasks. Go beyond the basics - consider edge cases, error handling, security considerations, and integration points. Each task should be specific enough for an agent to execute independently without ambiguity.
</quality_expectations>

## Project Information

### Links to Relevant Documentation
{PLEASE FILL THIS OUT}

### Project Description
{PLEASE FILL THIS OUT}

### Technical Stack
{PLEASE FILL THIS OUT}

### Specific Requirements
{PLEASE FILL THIS OUT}

---

## Your Task

Analyze this project and create a comprehensive **Beads task graph** using the `bd` CLI. Beads provides dependency-aware, conflict-free task management for multi-agent execution.

---

<critical_constraint>
Your ONLY output is a bash shell script. Do NOT use `bd add` — the correct command to create a bead is `bd create`. Use `bd dep add` for dependencies. Do not implement anything yourself.
</critical_constraint>

## Output Format

Generate a shell script that creates the full task graph. The script should:

1. **Initialize Beads** (if not already initialized)
2. **Create all beads** with appropriate priorities
3. **Establish dependencies** between beads
4. **Add labels** for phase grouping

### Example Output

```bash
#!/bin/bash
# Project: {PROJECT_NAME}
# Generated: {DATE}

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating project beads..."

# ========================================
# Phase 1: Project Setup & Infrastructure
# ========================================

SETUP_VITE=$(bd create "Initialize project with Vite + React + TypeScript" -p 0 --label setup --silent)

SETUP_LINT=$(bd create "Configure ESLint, Prettier, and TypeScript strict mode" -p 1 --label setup --silent)
bd dep add $SETUP_LINT $SETUP_VITE

SETUP_TAILWIND=$(bd create "Set up Tailwind CSS with design system tokens" -p 1 --label setup --silent)
bd dep add $SETUP_TAILWIND $SETUP_VITE

SETUP_TESTING=$(bd create "Configure testing framework (Vitest + Testing Library)" -p 1 --label setup --silent)
bd dep add $SETUP_TESTING $SETUP_LINT

# ========================================
# Phase 2: Core Architecture
# ========================================

API_CLIENT=$(bd create "Implement API client with error handling and retries" -p 0 --label core --silent)
bd dep add $API_CLIENT $SETUP_VITE

STATE_MGMT=$(bd create "Set up global state management (Zustand/Jotai)" -p 0 --label core --silent)
bd dep add $STATE_MGMT $SETUP_VITE

AUTH_CONTEXT=$(bd create "Create authentication context and hooks" -p 0 --label core --silent)
bd dep add $AUTH_CONTEXT $STATE_MGMT
bd dep add $AUTH_CONTEXT $API_CLIENT

# ... continue for all phases ...

echo ""
echo "Bead graph created! View with:"
echo "  bd ready              # List unblocked tasks"
```

---

## Bead Creation Guidelines

### Priority Levels
- `-p 0` = Critical (blocking other work)
- `-p 1` = High (important but not blocking)
- `-p 2` = Medium (standard work)
- `-p 3` = Low (nice to have)

### Labels (Phase Grouping)
Use `--label` to group beads by phase:
- `setup` - Project initialization
- `core` - Core architecture
- `auth` - Authentication/authorization
- `ui` - UI components
- `feature-{name}` - Feature-specific work
- `testing` - Test coverage
- `docs` - Documentation
- `deploy` - Deployment/CI

### Dependency Rules
1. Never create cycles
2. Every bead should have a clear dependency chain back to setup tasks
3. Use `bd dep add CHILD PARENT` (child depends on parent completing first)
4. Parallel work should share a common ancestor, not depend on each other

### Task Granularity
- Each bead should be completable in **under 750 lines of code**
- Tasks should be atomic enough for one agent to complete without coordination
- If a task requires multiple file areas, consider splitting by file area

---

## File Reservation Planning

For each major work area, note the file patterns that will need exclusive reservation:

```bash
# Example reservation notes (add as bead descriptions)
# Auth work: src/auth/**, tests/auth/**, src/hooks/useAuth*
# API client: src/api/**, src/lib/fetch*, tests/api/**
# UI components: src/components/{ComponentName}/**, tests/components/{ComponentName}/**
```

This helps agents claim appropriate file surfaces when they start work.

---

## Context Documentation

Place any important context in `prompts/docs/` for agents to reference. This includes:
- Architecture decisions
- API documentation
- Design system specs
- External service integration guides

---

## Verification Steps

After generating the script:

1. **Run it**: `chmod +x setup-beads.sh && ./setup-beads.sh`
2. **Check ready work**: `bd ready` should show initial setup tasks

---

## Completeness Checklist

Ensure your task graph includes:

- [ ] All setup and configuration tasks
- [ ] Core architecture and shared utilities
- [ ] Feature implementation tasks (broken into small units)
- [ ] Error handling and edge cases
- [ ] Unit and integration tests for each feature
- [ ] API documentation
- [ ] Security considerations (input validation, auth checks)
- [ ] Performance considerations where relevant
- [ ] CI/CD and deployment tasks
- [ ] Clear dependency chains with no cycles
