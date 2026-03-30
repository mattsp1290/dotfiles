---
name: big-change
description: Interactive planner for significant codebase changes — auto-detects change type and affected areas, produces a task plan in docs/prompts/
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep
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

## Final Output

After saving, tell the user:

- The file path where it was saved
- A brief summary of the change plan (auto-detected change type, description, number of affected areas)
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
