---
name: pr-ready
description: Run automated multi-pass review and fix loop to prepare a branch for PR merge
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Skill, Agent
---

# PR Ready Skill

Automated multi-pass review pipeline that thoroughly prepares a branch for PR merge. Uses intelligent triage to determine which review passes are needed, then runs them sequentially — each with dual-reviewer feedback (Opus + ChatGPT) and automatic fixes — then verifies and pushes.

Estimated runtime: 5-45 minutes depending on triage results.

## Arguments

Parse `$ARGUMENTS` for optional flags:

- `--all-passes`: Skip triage, run all 5 passes unconditionally.
- `--quick`: Skip triage, run only a single full review pass.

If neither flag is provided, run the triage step to determine which passes are needed.

## Prerequisites

Before starting, validate:

1. **Not on main branch.** Run `git branch --show-current`. If on `main`, stop and tell the user: "You're on the main branch. Switch to a feature branch first."
2. **Changes exist vs main.** Run `git diff main...HEAD --stat`. If empty, stop and tell the user: "No changes found compared to main."
3. **Check for uncommitted changes.** Run `git status --porcelain`. If there are uncommitted changes, warn the user: "There are uncommitted changes. These will be mixed with review fixes. Commit or stash them first?" Wait for confirmation before proceeding.

If any check fails, do not proceed.

## Triage — Determine Which Passes to Run

Skip this section if `--all-passes` or `--quick` was provided.

Triage uses two layers: deterministic hard triggers (fast, reliable) and a triple-agent assessment (nuanced judgment). The goal is to skip passes that add no value for the specific PR, without missing real issues.

### Layer 1 — Deterministic Hard Triggers

Gather context by running these commands:
- `git diff main...HEAD --stat` (file-level summary)
- `git diff main...HEAD --name-only` (changed file list)
- `git log main..HEAD --oneline` (commit messages)
- `git diff main...HEAD --shortstat` (total lines added/removed)

Apply these rules to build a set of **forced passes** (these run regardless of agent recommendations):

| Signal | Forced pass |
|--------|-------------|
| Any changed file matches `auth`, `login`, `session`, `token`, `secret`, `credential`, `password`, `permission`, `rbac`, `acl`, `.env` | **security** |
| Any changed file matches `migrate`, `schema`, `sql`, `alembic`, `prisma` | **correctness** + **security** |
| Total lines changed > 500 OR files changed > 20 | **all passes** (equivalent to `--all-passes`) |
| All changed files are docs-only (`.md`, `.txt`, `.rst`, `LICENSE`, `README`) | **final full review only** (skip all focused passes) |
| All changed files are generated/lockfiles (`package-lock.json`, `go.sum`, `yarn.lock`, `Cargo.lock`, `*.pb.go`, `*_generated.*`) | **final full review only** |
| Commit messages contain only `ralph: iteration` or `scaffold` or `init` | No forced passes (defer to agents) |

### Layer 2 — Triple-Agent Assessment

Launch THREE agents **in parallel** (single message, three Agent tool calls) to independently assess which remaining (non-forced) passes are needed.

All three agents receive the same context:
- The output of `git diff main...HEAD --stat`
- The output of `git log main..HEAD --oneline`
- The list of changed files
- The set of passes already forced by Layer 1
- Instructions to recommend only the non-forced passes

#### Agent 1 — Sonnet (fast, pattern-based)

Launch with `model: sonnet`:

```
Analyze this PR to determine which review passes are needed. You are one of three triage agents — your role is fast pattern matching.

[Include: diff stats, commit messages, changed file list, forced passes from Layer 1]

For each pass NOT already forced, recommend yes or no with a one-sentence reason:
- baseline (full holistic review)
- correctness (logic bugs, edge cases, wrong behavior)
- tests (test coverage and quality)
- security (vulnerabilities, input validation, secrets)

Consider:
- File types: are these source files, configs, tests, or boilerplate?
- Commit messages: do they suggest scaffolding, iteration, or complex feature work?
- Scope: how many files and lines are involved?

Output EXACTLY this format:
TRIAGE:
- baseline: yes/no (reason)
- correctness: yes/no (reason)
- tests: yes/no (reason)
- security: yes/no (reason)
CONFIDENCE: high/medium/low
```

#### Agent 2 — Opus (deep, judgment-based)

Launch with `model: opus`:

```
Analyze this PR to determine which review passes are needed. You are one of three triage agents — your role is deep semantic judgment.

[Include: diff stats, commit messages, changed file list, PLUS the full diff content, forced passes from Layer 1]

For each pass NOT already forced, recommend yes or no with a one-sentence reason:
- baseline (full holistic review)
- correctness (logic bugs, edge cases, wrong behavior)
- tests (test coverage and quality)
- security (vulnerabilities, input validation, secrets)

Consider:
- Semantic complexity: is this new logic or boilerplate/scaffolding?
- Cross-file coupling: do changes in one file affect behavior in another?
- Error handling: are there new error paths that need validation?
- State mutations: are there changes to shared state or data flow?

Output EXACTLY this format:
TRIAGE:
- baseline: yes/no (reason)
- correctness: yes/no (reason)
- tests: yes/no (reason)
- security: yes/no (reason)
CONFIDENCE: high/medium/low
```

#### Agent 3 — GPT (independent perspective via OpenCode)

Run via the OpenCode wrapper script with readonly permissions:

```bash
bash $HOME/.claude/skills/opencode/opencode_run.sh \
  --task-name "pr-ready-triage" \
  --model "openai/gpt-5.4" \
  "<GPT_TRIAGE_PROMPT>"
```

The GPT prompt must include:
- The full diff (inline in the prompt, since GPT has readonly permissions)
- The changed file list and commit messages
- The forced passes from Layer 1
- The same output format as the other agents

Use `--timeout 120` on the wrapper script. Use the default Bash tool timeout — GPT triage should complete in under 2 minutes.

### Merge Logic

Combine the three agents' recommendations with the Layer 1 forced passes:

1. **Forced passes** from Layer 1 always run — non-negotiable.
2. **2-of-3 majority**: For each non-forced pass, if 2 or more agents recommend it, include it.
3. **Security exception**: If even 1 agent recommends the security pass, include it (err on the side of caution for security).
4. **Low confidence override**: If any agent reports `low` confidence, include all passes that agent recommended (trust the uncertainty signal).
5. **Final full review** always runs — non-negotiable.

### Present Triage Results

Show the user a concise summary before proceeding:

```
## Triage Results

Hard triggers: {list any forced passes and why}

| Pass | Sonnet | Opus | GPT | Decision |
|------|--------|------|-----|----------|
| Baseline | yes/no | yes/no | yes/no | RUN / SKIP |
| Correctness | yes/no | yes/no | yes/no | RUN / SKIP |
| Tests | yes/no | yes/no | yes/no | RUN / SKIP |
| Security | yes/no | yes/no | yes/no | RUN / SKIP |
| Final | — | — | — | ALWAYS RUN |

Planned passes: {list}
Estimated time: {rough estimate based on pass count}
```

Auto-proceed after displaying. Do NOT ask for confirmation unless:
- All three agents reported `low` confidence (ask: "Triage confidence is low across all agents. Run all passes to be safe?")
- The triage would skip ALL focused passes (ask: "Triage suggests only a final full review. Proceed, or run all passes?")

## Pipeline

Run the passes selected by triage (or all passes if `--all-passes`, or only final if `--quick`). Each pass follows the same cycle: review, check for issues, fix, commit.

Number the planned passes sequentially (e.g., if triage selected baseline + security + final, they are passes 1/3, 2/3, 3/3). Use the total planned count, not the fixed 5.

For each planned pass, follow this cycle:

### Pass Cycle (repeat for each planned pass)

1. **Announce**: Tell the user "**Starting pass {N}/{total}: {pass-name}**"
2. **Review**: Invoke the appropriate skill:
   - Baseline: `Skill(skill: "review")`
   - Correctness: `Skill(skill: "review", args: "--pass correctness")`
   - Tests: `Skill(skill: "review", args: "--pass tests")`
   - Security: `Skill(skill: "review", args: "--pass security")`
   - Final: `Skill(skill: "review")`
3. **Check for action items**:
   - Read `04-action-items.md` from both the `opus/` and `chatgpt/` subdirectories of the most recent review in `./reviews/`
   - Count lines matching `- [ ]` (unchecked items)
   - If zero items in both files: print "Pass {N} ({pass-name}): no action items found. Skipping fixes." and proceed to next pass.
4. **Fix**: Invoke `Skill(skill: "fix-review", args: "--auto")`
   - For the security pass: note that `/fix-review --auto` will flag security-sensitive files as "needs-manual". Report any such items to the user.
5. **Check for changes**: Run `git diff HEAD`. If empty, print "Pass {N} ({pass-name}): fix-review made no changes. Skipping commit." and proceed to next pass.
6. **Commit**:
   ```
   git add -A
   git commit -m "fix({pass-name}): address {pass-name} review findings"
   ```

### Default pass order (when all are selected)

1. Baseline (full holistic review)
2. Correctness
3. Tests
4. Security
5. Final (full holistic review — always last, always runs)

## Verification Gate

After all planned passes complete, run a verification gate before pushing:

1. **Detect project type** by checking for common files:
   - `Makefile` → run `make test` (if a `test` target exists)
   - `go.mod` → run `go test ./...`
   - `package.json` → run `npm test` or `yarn test`
   - `Cargo.toml` → run `cargo test`
   - `pytest.ini` / `setup.py` / `pyproject.toml` → run `pytest`
   - If none match, skip the test step and note: "No test runner detected."

2. **Run linter** if available:
   - `golangci-lint` / `eslint` / `ruff` / `clippy` — run if the tool is installed
   - If no linter detected, skip silently.

3. **Report results**:
   - If tests pass: "Verification passed."
   - If tests fail: warn the user — "Tests failed. Review the failures before pushing. Continue with push anyway?" Wait for confirmation.

## Push

Push all commits at once:

```
git push
```

If the push fails (no upstream, auth error, etc.), tell the user: "Push failed: {error}. Your commits are safe locally. Set upstream with `git push -u origin {branch}` or resolve the error."

## Post-Loop Summary

After everything completes, present a summary:

```
## PR Ready Summary

Triage: {which passes were selected and why, or "--all-passes" / "--quick"}

| Pass | Issues Found | Issues Fixed | Commit |
|------|-------------|-------------|--------|
| {pass-name} | {N} | {N} | {sha} or "no changes" |
| ... | ... | ... | ... |
| Final | {N} | {N} | {sha} or "no changes" |

Passes skipped by triage: {list, or "none"}
Verification: {passed/failed/skipped}
Push: {success/failed}

{If any items were flagged as needs-manual, list them here}
```

Show `git log --oneline -7` to display the commits created.

If all passes completed successfully, suggest: "Your branch is PR-ready. Run `gh pr create` to open a pull request."

## Error Handling

- **Review or fix-review failure**: If any pass's `/review` or `/fix-review` invocation fails, log the error, skip that pass, and continue to the next. Do not abort the entire pipeline.
- **Commit failure**: If `git commit` fails (e.g., nothing to commit), skip silently and continue.
- **Push failure**: Report the error to the user. Commits are safe locally.
- **All passes skipped**: If every pass found zero issues, tell the user: "All review passes found no issues. Your code looks good — consider opening a PR directly."
