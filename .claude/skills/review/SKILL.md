---
name: review
description: Generate a code review of the current branch compared to main with web research on best practices
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, WebSearch, WebFetch, Agent
---

# Code Review Skill

Generate a thorough code review of the current branch compared to `main`, with research on best practices relevant to the changes.

## Prerequisites

Before starting, validate:

1. **Not on main branch.** Run `git branch --show-current`. If on `main`, stop and tell the user: "You're on the main branch. Switch to a feature branch with changes to review."
2. **Changes exist vs main.** Run `git diff main...HEAD --stat`. If empty, stop and tell the user: "No changes found compared to main. Make some commits first."

If either check fails, do not proceed.

## Steps

### 1. Clean up previous reviews for this branch

- Run `git branch --show-current` to get the branch name.
- Sanitize the branch name for use in paths: replace `/` with `-`.
- If `./reviews/` exists, delete any directories matching `./reviews/{sanitized-branch-name}-*` using `rm -rf`.
- Do NOT delete review directories for other branches.
- If no matching directories exist, skip silently.

### 2. Gather the diff and changed files

- Run `git diff main...HEAD` to get the full diff.
- Run `git diff main...HEAD --name-only` to get the list of changed files.
- Read each changed file in full to understand the complete context (not just the diff hunks).
- Run `git log main..HEAD --oneline` to understand the commit history.

### 3. Research best practices (cache-aware)

#### 3a. Identify needed topics

Based on the diff and changed files, identify 2-5 topic phrases that need research. Consider:

- Language-specific best practices (e.g., `typescript strict mode`, `python async`)
- Framework patterns (e.g., `react hooks`, `nextjs server components`)
- Security patterns (e.g., `owasp injection`, `shell script security`)
- Infrastructure/config (e.g., `dockerfile security`, `github actions secrets`)
- Data access (e.g., `postgres indexing`, `redis caching patterns`)

#### 3b. Check the research cache

1. Check if `.claude/research/` exists. If it does not, all topics are cache misses — skip to 3c.
2. If it exists, list all `.md` files and read the front-matter of each to get the `tags` array.
3. For each needed topic, determine if it is a cache hit or miss:
   - A **cache hit** requires at least one tag from the file to match a keyword in the topic phrase (substring match in either direction).
   - If ambiguous, treat as a **miss** — over-fetching is cheaper than under-fetching.
4. Log the result: "Cache hit: {filename}" or "Cache miss: {topic}".

#### 3c. Fetch missing topics

For each cache miss:
1. Do 1-2 targeted web searches for that topic.
2. Synthesize findings into the research file format below.
3. Save to `.claude/research/{descriptive-kebab-name}.md`.

**Research file format:**

```markdown
---
topic: Human Readable Topic Name
tags: [keyword1, keyword2, keyword3]
last-researched: YYYY-MM-DD
sources:
  - https://example.com/source1
  - https://example.com/source2
---

# Topic Name

## Key Rules
- Bullet list of actionable best-practice rules

## Common Pitfalls
- Failure modes and anti-patterns to watch for

## Relevant to Code Review
- What to specifically look for when reviewing code
```

Keep each file under ~300 lines. Curated summaries, not raw dumps.

#### 3d. Load all relevant research

Read the full content of all relevant research files (both cache hits and newly written). Use this research context in step 4 when writing the review.

### 4. Write the review documents

Determine the branch name and today's date (`YYYY-MM-DD`). Sanitize the branch name (replace `/` with `-`). Create the output directory at `./reviews/{sanitized-branch-name}-{YYYY-MM-DD}/`.

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
- Reference to the research if applicable

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

### 5. Finish

After writing all files, tell the user:
- Where the review was written (the directory path)
- The overall verdict
- A count of items by priority
- Which research topics were cache hits vs. freshly fetched
- Suggest running `/fix-review` to address the findings
