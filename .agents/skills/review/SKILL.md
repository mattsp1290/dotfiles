---
name: review
description: Generate a code review of the current branch compared to main using two independent Opus subagents
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, Agent
---

# Code Review Skill

Generate a thorough code review of the current branch compared to the base branch, using two independent Claude Opus subagents in parallel. Reviews are written to `./.agents/reviews/<change-name>/`.

## Base Branch Resolution

Before any diff commands, determine the base branch:

```bash
BASE_BRANCH="main"
if [[ -f ".ralph" ]]; then
  _cfg=$(grep -oP '(?<=^main_branch=).*' .ralph 2>/dev/null | head -1)
  [[ -n "$_cfg" ]] && BASE_BRANCH="$_cfg"
fi
```

If `.ralph` is absent, `BASE_BRANCH` defaults to `"main"`. Use `$BASE_BRANCH` everywhere `main` appears below.

## Prerequisites

Before starting, validate:

1. **Not on base branch.** Run `git branch --show-current`. If on `$BASE_BRANCH`, stop and tell the user: "You're on the base branch ($BASE_BRANCH). Switch to a feature branch with changes to review."
2. **Changes exist vs base.** Run `git diff $BASE_BRANCH...HEAD --stat`. If empty, stop and tell the user: "No changes found compared to $BASE_BRANCH. Make some commits first."

If either check fails, do not proceed.

## Steps

### 1. Gather the diff and context

- Run `git branch --show-current` to get the branch name. Sanitize it for use in paths: replace `/` with `-`. This is the `<change-name>`.
- Run `git diff $BASE_BRANCH...HEAD` to get the full diff.
- Run `git diff $BASE_BRANCH...HEAD --name-only` to get the list of changed files.
- Read each changed file in full to understand the complete context (not just the diff hunks).
- Run `git log $BASE_BRANCH..HEAD --oneline` to understand the commit history.

### 2. Create output directories

```
./.agents/reviews/<change-name>/opus/
./.agents/reviews/<change-name>/opus2/
```

### 3. Launch parallel reviews

Launch BOTH reviews simultaneously in a single message with two Agent tool calls.

#### 3a. Opus Review (first reviewer)

Launch an Agent with `model: opus` containing:

- The full diff
- The full content of each changed file
- The output directory path: `./.agents/reviews/<change-name>/opus/`
- The review file format specification (section 3c below)

The agent must write the 5 review files using the Write tool.

#### 3b. Opus 2 Review (second independent reviewer)

Launch a second Agent with `model: opus` — same structure as 3a but with a different framing:

- Add this at the top: "You are a second independent code reviewer. Do not mirror the first reviewer — bring your own judgment. Focus on aspects that are easy to overlook: subtle logic errors, missing edge cases, implicit assumptions, and long-term maintainability."
- The full diff
- The full content of each changed file
- The output directory path: `./.agents/reviews/<change-name>/opus2/`
- The review file format specification (section 3c below)

The agent must write the 5 review files using the Write tool. The reviewer name in `00-overview.md` must be "Claude Opus (2nd reviewer)".

#### 3c. Review file format (shared by both reviewers)

Both reviewers must produce these 5 files in their respective output directories:

**`00-overview.md`**
- Branch name, date, reviewer name (either "Claude Opus" or "Claude Opus (2nd reviewer)")
- One-paragraph summary of what the changes do
- Overall verdict: one of `APPROVE`, `REQUEST_CHANGES`, or `NEEDS_DISCUSSION`
- Stats: files changed, lines added/removed, commits

**`01-critical-and-important.md`**
Issues that must or should be fixed before merging:
- **Critical**: Security vulnerabilities, data loss risks, crashes, broken functionality
- **Important**: Missing error handling, race conditions, logic errors, performance problems, missing validation at system boundaries

For each issue:
- Severity (Critical / Important)
- File path and line number(s)
- Description of the problem
- Suggested fix with a code snippet

If no issues found, say so explicitly.

**`02-suggestions.md`**
Nice-to-have improvements that don't block merging:
- Code style and readability, naming improvements, simplification opportunities
- Minor DRY violations, documentation suggestions (only where logic is non-obvious)

For each suggestion: file path, line number(s), what to change and why, suggested code snippet.

**`03-positive-notes.md`**
Good patterns and practices found in the changes that should be preserved. Be specific — reference exact code.

**`04-action-items.md`**
A prioritized checklist synthesizing items from `01-critical-and-important.md` and `02-suggestions.md`:

```
## Action Items

### Critical
- [ ] [File:line] Brief description of fix needed

### Important
- [ ] [File:line] Brief description of fix needed

### Suggestions
- [ ] [File:line] Brief description of improvement
```

Each item should be self-contained enough that `/fix-review` can act on it without re-reading the other files.

### 4. Verify and finish

After both reviews complete:

1. Verify that both output directories contain the expected 5 files. If either is missing files, note which are missing.
2. Read `00-overview.md` from each reviewer to get their verdicts.
3. Tell the user:
   - Where the reviews were written (both directory paths)
   - Each reviewer's verdict (Opus 1 and Opus 2)
   - A count of action items by priority from each reviewer
   - Suggest running `/fix-review` to address findings from both reviewers
