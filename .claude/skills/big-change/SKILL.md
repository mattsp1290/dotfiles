---
name: big-change
description: Interactive planner for significant codebase changes — auto-detects change type and affected areas, produces a task plan in docs/prompts/
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /big-change -- Interactive Big Change Planner

You are helping the user plan a significant codebase change using the template below. Your job is to walk through each placeholder section, collect answers interactively, and produce a completed prompt file.

## Setup

1. Use the template provided in the "Template" section below
2. Determine the **project name** from the basename of the current working directory
3. Determine today's **date** in YYYY-MM-DD format

## Collecting Information

You will ask the user **4 questions**, one at a time. Wait for the user's response before moving to the next question. Keep your questions concise.

If the user provided arguments (shown below), use them as the pre-filled **Description** — show it to the user for confirmation rather than asking from scratch.

**User arguments:** $ARGUMENTS

### Question 1: Description

- If `$ARGUMENTS` is non-empty, show: "I'll use this as the description: **{$ARGUMENTS}** — want to adjust it, or is that good?"
- If `$ARGUMENTS` is empty, ask: "What is the goal of this change? Describe what you want to accomplish."

### Question 2: Links to Relevant Documentation

Ask: "Any links to relevant docs, RFCs, or design docs? (enter 'none' to skip)"

If the user says "none", "no", "n/a", or similar, use `N/A`.

### Question 3: Success Criteria

Ask: "How will you know this change is complete and working? What are the success criteria?"

### Question 4: Constraints

Ask: "Any constraints? (backwards compatibility, deployment considerations, feature flags, etc.) Enter 'none' to skip."

If the user says "none", "no", "n/a", or similar, use `N/A`.

## Auto-Detecting Change Context

After collecting the 4 answers above, automatically determine Change Type and Affected Areas before generating output. Report findings to the user.

### Change Type Detection

Analyze the user's description and the codebase to classify the change type:

1. Run `git log --oneline -10` to understand recent activity
2. Apply classification heuristics based on the description:
   - **MIGRATION**: description mentions "migrate", "upgrade", "move from", "replace X with Y", "port"
   - **SECURITY**: description mentions "vulnerability", "CVE", "XSS", "injection", "auth bypass", "permission", "sanitiz"
   - **PERFORMANCE**: description mentions "slow", "performance", "latency", "throughput", "optimize", "benchmark", "cache"
   - **REFACTOR**: description mentions "refactor", "restructure", "decouple", "extract", "split", "clean up", "simplify"
   - **NEW_FEATURE**: description mentions building/adding something new and no existing code matches the feature area
   - **OTHER**: none of the above
3. Report to user: "Based on your description and the codebase, I'm classifying this as **{TYPE}**."

### Affected Areas Detection

1. Extract key nouns/concepts from the description
2. Use Glob and Grep to find relevant directories and files
3. Check `docs/specs/` and `docs/adr/` for architectural context
4. Compile a list of affected directories/modules
5. Report to user: "I've identified these affected areas: {list}"

## Generating the Output

Once you have all 4 user answers plus the 2 auto-detected values, fill in the template. The template has six sections each containing `{PLEASE FILL THIS OUT}` — replace each one with the matching answer based on section heading:

1. Under `### Change Type` — replace `{PLEASE FILL THIS OUT}` with the auto-detected change type
2. Under `### Description` — replace `{PLEASE FILL THIS OUT}` with the description
3. Under `### Links to Relevant Documentation` — replace `{PLEASE FILL THIS OUT}` with the links answer (or N/A)
4. Under `### Affected Areas` — replace `{PLEASE FILL THIS OUT}` with the auto-detected affected areas
5. Under `### Success Criteria` — replace `{PLEASE FILL THIS OUT}` with the success criteria
6. Under `### Constraints` — replace `{PLEASE FILL THIS OUT}` with the constraints (or N/A)
7. In the Example Output script section, replace:
   - `{PROJECT_NAME}` with the project name (from cwd basename)
   - `{DATE}` with today's date

## Saving the File

1. Convert the description to **kebab-case** for the filename (lowercase, spaces/special chars to hyphens, collapse multiple hyphens, trim leading/trailing hyphens, max 60 chars)
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
  "skill": "big-change",
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

Substitute the phrase **big change** for the `[big change | new project]` marker below — this is a render-time substitution specific to this skill.

**First-turn template** (write to `/tmp/opencode-review-prompt-<FRESH_KEY>.txt`):

```
You are critiquing a planning document. Your tools are denied by the enclosing
config — respond with TEXT only. Do not attempt file edits. Do not propose
rewrites of the plan.

The plan below will later drive an autonomous agent to generate a Beads task
graph for a big change. Your job is to catch gaps BEFORE task creation.

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
- A brief summary of the change plan (auto-detected change type, description, number of affected areas)
- If the review loop ran, a one-line summary of the outcome (converged on round N, capped at 3, skipped on error, user-exited)
- Suggest next step: "You can now run this prompt with Claude to generate your beads task graph."

## Template

# Big Change Planning with Beads

## Agent Instructions

You are an expert software architect creating a comprehensive task breakdown for a change to an existing codebase. This task graph will be executed by AI agents working in parallel, coordinated through MCP Agent Mail with file reservations to prevent conflicts.

<quality_expectations>
Create a thorough, production-ready task graph. Include all necessary analysis, preparation, implementation, testing, and documentation tasks. Go beyond the basics — consider edge cases, error handling, security considerations, backwards compatibility, and integration points. Each task should be specific enough for an agent to execute independently without ambiguity.
</quality_expectations>

<critical_constraint>
You must NOT implement any of the changes yourself. Your ONLY output is a bash shell script containing `bd create` and `bd dep add` commands. Do NOT use `bd add` — the correct command is `bd create`. Do not write code. Do not create files other than the shell script. Do not modify existing files. Read and analyze the codebase, then produce the script.
</critical_constraint>

## Change Information

### Change Type
{PLEASE FILL THIS OUT}

### Description
{PLEASE FILL THIS OUT}

### Links to Relevant Documentation
{PLEASE FILL THIS OUT}

### Affected Areas
{PLEASE FILL THIS OUT}

### Success Criteria
{PLEASE FILL THIS OUT}

### Constraints
{PLEASE FILL THIS OUT}

---

## Your Task

Analyze this codebase change and create a comprehensive **Beads task graph** using the `bd` CLI. Beads provides dependency-aware, conflict-free task management for multi-agent execution.

Before creating the task graph, you MUST first analyze the affected areas of the codebase:

1. Check `docs/specs/` and `docs/adr/` for existing architectural decisions
2. Examine the directory/module structure of the affected areas listed above
3. Identify key interfaces, APIs, and integration points that must be preserved
4. Note existing test patterns and coverage in the affected areas
5. Assess risk areas where changes could break existing functionality

Use your analysis to make each bead specific — reference actual file paths, module names, and patterns you observed.

Then generate a shell script that creates the complete task graph.

**IMPORTANT: Your ONLY deliverable is a bash shell script with `bd create` commands. Not an implementation plan. Not a design document. Not a code review. A runnable `.sh` script.**

---

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
# Change: Refactor auth middleware for compliance
# Generated: {DATE}

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating change beads..."

# ========================================
# Phase 1: Analysis & Preparation
# ========================================

ANALYZE_CURRENT=$(bd create "Analyze current auth middleware implementation in src/auth/ — document all session token storage patterns and consumer dependencies" -p 0 --label analysis --silent)

IDENTIFY_DEPS=$(bd create "Map all modules importing from src/auth/ and catalog their usage patterns" -p 0 --label analysis --silent)

CHAR_TESTS=$(bd create "Add characterization tests capturing current auth middleware behavior before refactoring" -p 0 --label prep --silent)
bd dep add $CHAR_TESTS $ANALYZE_CURRENT

# ========================================
# Phase 2: Core Implementation
# ========================================

IMPL_NEW_STORAGE=$(bd create "Implement compliant session token storage in src/auth/session.ts replacing in-memory store" -p 0 --label impl --silent)
bd dep add $IMPL_NEW_STORAGE $CHAR_TESTS
bd dep add $IMPL_NEW_STORAGE $IDENTIFY_DEPS

IMPL_MIGRATION=$(bd create "Create migration script for existing session data to new storage format" -p 1 --label impl --silent)
bd dep add $IMPL_MIGRATION $IMPL_NEW_STORAGE

UPDATE_CONSUMERS=$(bd create "Update all consumer modules to use new auth middleware API surface" -p 1 --label impl --silent)
bd dep add $UPDATE_CONSUMERS $IMPL_NEW_STORAGE

# ========================================
# Phase 3: Testing & Validation
# ========================================

UNIT_TESTS=$(bd create "Add unit tests for new session storage implementation" -p 1 --label testing --silent)
bd dep add $UNIT_TESTS $IMPL_NEW_STORAGE

INTEGRATION_TESTS=$(bd create "Add integration tests for auth flow end-to-end with new middleware" -p 1 --label testing --silent)
bd dep add $INTEGRATION_TESTS $UPDATE_CONSUMERS

REGRESSION_CHECK=$(bd create "Run full regression suite and verify characterization tests still pass" -p 0 --label testing --silent)
bd dep add $REGRESSION_CHECK $INTEGRATION_TESTS
bd dep add $REGRESSION_CHECK $UNIT_TESTS

# ========================================
# Phase 4: Cleanup & Documentation
# ========================================

UPDATE_DOCS=$(bd create "Update auth middleware documentation and API reference" -p 2 --label docs --silent)
bd dep add $UPDATE_DOCS $REGRESSION_CHECK

CLEANUP=$(bd create "Remove deprecated session storage code and update changelog" -p 3 --label cleanup --silent)
bd dep add $CLEANUP $REGRESSION_CHECK

echo ""
echo "Bead graph created! View with:"
echo "  bd ready              # List unblocked tasks"
```

---

## Bead Creation Guidelines

### Priority Levels
- `-p 0` = Critical (blocking other work, or high-risk changes needing early validation)
- `-p 1` = High (important implementation work)
- `-p 2` = Medium (standard work)
- `-p 3` = Low (cleanup, nice-to-haves)

### Labels (Phase Grouping)
Use `--label` to group beads by phase:
- `analysis` - Understanding current state
- `prep` - Preparation work (characterization tests, feature flags, scaffolding)
- `impl` - Core implementation
- `testing` - Test coverage
- `migration` - Data/code migration
- `docs` - Documentation updates
- `cleanup` - Post-rollout cleanup

### Dependency Rules
1. Never create cycles
2. Analysis tasks should complete before implementation begins
3. Characterization tests should exist before changing code
4. Use `bd dep add CHILD PARENT` (child depends on parent completing first)
5. Parallel work should share a common ancestor, not depend on each other

### Task Granularity
- Each bead should be completable in **under 750 lines of code changed**
- Tasks should be atomic enough for one agent to complete without coordination
- If a task requires multiple file areas, consider splitting by file area

---

## Change-Specific Considerations

### For New Features
- Start with analysis of similar existing features
- Consider feature flag for gradual rollout
- Plan for A/B testing if relevant
- Include documentation and changelog updates

### For Refactors
- Add characterization tests first (capture current behavior)
- Consider strangler fig pattern for large changes
- Plan incremental migration path
- Ensure no behavior changes unless intentional

### For Migrations
- Create rollback plan as an explicit task
- Plan data validation checkpoints
- Consider dual-write period if applicable
- Include monitoring/alerting tasks

### For Performance Changes
- Add benchmarks before and after
- Include load testing tasks
- Plan gradual rollout with monitoring
- Have rollback criteria defined

---

## File Reservation Planning

For each major work area, note the file patterns that will need exclusive reservation:

```bash
# Example reservation notes (add as bead descriptions)
# CAUTION: These files have many consumers
# Auth refactor: src/auth/**, tests/auth/** (coordinate with API team)
# Shared utils: src/lib/utils.ts (high contention - keep changes minimal)
```

This helps agents claim appropriate file surfaces when they start work.

---

## Verification Steps

After generating the script:

1. **Run it**: `chmod +x setup-beads.sh && ./setup-beads.sh`
2. **Check ready work**: `bd ready` should show initial analysis/prep tasks

---

## Completeness Checklist

Ensure your task graph includes:

- [ ] Analysis of current implementation in affected areas
- [ ] Characterization tests for existing behavior
- [ ] Feature flag or gradual rollout mechanism (if applicable)
- [ ] Core implementation broken into small units
- [ ] Unit tests for new/changed code
- [ ] Integration tests for affected workflows
- [ ] Regression testing plan
- [ ] Documentation updates
- [ ] Migration scripts (if data changes)
- [ ] Rollback plan
- [ ] Cleanup tasks for post-rollout
- [ ] Clear dependency chains with no cycles
