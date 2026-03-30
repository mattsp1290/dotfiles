---
name: new-project
description: Interactive planner that walks through questions and produces a project task plan in docs/prompts/
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep
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

## Final Output

After saving, tell the user:

- The file path where it was saved
- A brief summary of the project plan
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
