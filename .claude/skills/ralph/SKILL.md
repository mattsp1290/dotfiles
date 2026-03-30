---
name: ralph
description: Autonomous development loop — defaults to autopilot mode, working through the entire task graph
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# /ralph -- Autonomous development loop

Work autonomously using the Ralph iteration protocol: ASSESS → EXECUTE → VERIFY → CHECKPOINT → EVALUATE.

## Arguments
$ARGUMENTS

### Mode Selection

Parse arguments to determine mode:
- **No arguments** or no special flags → **Autopilot** mode: Work through the entire task graph
- `--goal "<description>"` → **Goal** mode: Work toward the stated goal
- `--single` → **Single Task** mode: Work on the next Beads task only
- `-n <number>` or `--max-iterations <number>` → Suggested iteration limit

## Step 1: Project Context

```bash
# Current branch
git branch --show-current

# Working tree status
git status --short

# Most recent commit
git log --oneline -1
```

## Step 2: Current Objective

### Autopilot Mode (default)

Work through the entire task graph autonomously.

```bash
bv --robot-triage
```

Process tasks in priority order. After completing each task:
1. Mark it closed: `bd update <id> --status closed`
2. Check for newly unblocked tasks
3. Continue with the next highest priority task

### Goal Mode

Goal: **<the goal from arguments>**

Work iteratively toward this goal. Each iteration should make concrete progress.
Break down the goal into logical steps and execute them one at a time.

### Single Task Mode

Check if Beads is initialized (`.beads/` directory exists):

```bash
# Try intelligent triage first
bv --robot-triage

# Or fall back to
bd ready
```

If no beads found: "No beads task graph found. Work on immediate project needs or run `bd init` to initialize Beads."

Focus on completing the highest priority task.

## Step 3: Completion Requirements (CRITICAL)

Both conditions must be met for completion:

### 1. Verification signals must pass

Auto-detect the appropriate test/build commands:

- **Go** (if `go.mod` exists): `go test ./... && go build ./...`
- **Node.js** (if `package.json` exists):
  - If `yarn.lock` exists: `yarn test`
  - If `pnpm-lock.yaml` exists: `pnpm test`
  - Otherwise: `npm test`
- **Python** (if `pyproject.toml` or `setup.py` exists): `pytest`
- **Rust** (if `Cargo.toml` exists): `cargo test && cargo build`
- **Make** (if `Makefile` exists): `make test`
- If none detected: verify manually or add tests

### 2. Explicit completion promise

When the objective is fully complete, output: `<promise>COMPLETE</promise>`

**Completion Criteria Details:**
- Tests must pass (exit code 0)
- Build must succeed (if applicable)
- The `<promise>COMPLETE</promise>` tag signals you are confident the work is done
- Do NOT output the promise tag until tests/build pass
- Do NOT output the promise tag if there is more work to do

## Step 4: Checkpoint Commits

After each successful iteration (tests pass), create a checkpoint commit:

```bash
git add -A && git commit -m "ralph: iteration N - [brief summary]"
```

- Replace N with the iteration number (1, 2, 3, ...)
- Keep summary brief (under 50 chars)
- Only commit when tests pass
- Each commit should represent a stable, working state

## Step 5: Iteration Protocol

Each iteration follows this cycle:

### 1. ASSESS current state
- Review previous iteration results
- Check test status
- Identify what needs to be done next

### 2. EXECUTE one increment
- Make focused, incremental changes
- Keep changes small and testable
- Do not try to do too much at once

### 3. VERIFY the changes
- Run tests/build commands
- Check for errors or regressions
- Fix any issues before proceeding

### 4. CHECKPOINT (if tests pass)
- Commit changes with iteration summary
- This creates a stable restore point

### 5. EVALUATE completion
- Is the objective fully achieved?
- If yes: output `<promise>COMPLETE</promise>`
- If no: continue to next iteration

**Important**: Do not skip steps. Each iteration must verify before checkpointing.

Begin working now.
