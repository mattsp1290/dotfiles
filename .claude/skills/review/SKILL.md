---
name: review
description: Generate a code review of the current branch compared to main with web research on best practices
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, WebSearch, WebFetch, Agent
---

# Code Review Skill

Generate a thorough code review of the current branch compared to `main`, with web research on best practices relevant to the changes.

## Prerequisites

Before starting, validate:

1. **Not on main branch.** Run `git branch --show-current`. If on `main`, stop and tell the user: "You're on the main branch. Switch to a feature branch with changes to review."
2. **Changes exist vs main.** Run `git diff main...HEAD --stat`. If empty, stop and tell the user: "No changes found compared to main. Make some commits first."

If either check fails, do not proceed.

## Steps

### 1. Gather the diff and changed files

- Run `git diff main...HEAD` to get the full diff.
- Run `git diff main...HEAD --name-only` to get the list of changed files.
- Read each changed file in full to understand the complete context (not just the diff hunks).
- Run `git log main..HEAD --oneline` to understand the commit history.

### 2. Research best practices

Based on the specific changes found (languages, frameworks, patterns used), do web research on relevant best practices. For example:
- If the changes involve React components, search for current React best practices
- If there are security-sensitive changes (auth, input handling, etc.), search for OWASP guidelines
- If there are infrastructure/config changes, search for relevant best practices

Do 2-4 targeted web searches based on what the actual changes involve. Do not do generic searches.

### 3. Write the review documents

Determine the branch name and today's date (`YYYY-MM-DD`). Create the output directory at `./reviews/{branch-name}-{YYYY-MM-DD}/`.

Write the following files. Each file should be written as actionable guidance for another Claude Code agent that will implement fixes. Be specific — reference exact file paths, line numbers, and code snippets.

#### `00-overview.md`

- Branch name, date, reviewer (Claude Code)
- One-paragraph summary of what the changes do
- Overall verdict: one of `APPROVE`, `REQUEST_CHANGES`, or `NEEDS_DISCUSSION`
- Stats: files changed, lines added/removed, commits

#### `01-critical-and-important.md`

Issues that must or should be fixed before merging:

- **Critical**: Security vulnerabilities, data loss risks, crashes, broken functionality
- **Important**: Missing error handling, race conditions, logic errors, performance problems, missing validation at system boundaries

For each issue:
- Severity (Critical / Important)
- File path and line number(s)
- Description of the problem
- Suggested fix with a code snippet
- Reference to the best practice research if applicable

If no issues found, say so explicitly.

#### `02-suggestions.md`

Nice-to-have improvements that don't block merging:

- Code style and readability
- Naming improvements
- Simplification opportunities
- Minor DRY violations
- Documentation suggestions (only where logic is non-obvious)

For each suggestion:
- File path and line number(s)
- What to change and why
- Suggested code snippet

#### `03-positive-notes.md`

Good patterns and practices found in the changes that should be preserved:

- Well-structured code
- Good error handling patterns
- Effective use of language/framework features
- Clear naming
- Good test coverage

Be specific — reference the exact code so `/fix-review` knows what NOT to change.

#### `04-action-items.md`

A prioritized checklist synthesizing items from `01-critical-and-important.md` and `02-suggestions.md`. Format:

```markdown
## Action Items

### Critical
- [ ] [File:line] Brief description of fix needed

### Important
- [ ] [File:line] Brief description of fix needed

### Suggestions
- [ ] [File:line] Brief description of improvement
```

Each item should be self-contained enough that `/fix-review` can act on it without re-reading the other files (though it will).

### 4. Finish

After writing all files, tell the user:
- Where the review was written (the directory path)
- The overall verdict
- A count of items by priority
- Suggest running `/fix-review` to address the findings
