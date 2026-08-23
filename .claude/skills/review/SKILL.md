---
name: review
description: Generate a code review of the current branch compared to main with web research on best practices
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, WebSearch, WebFetch, Agent
---

# Code Review Skill

Generate a thorough code review of the current branch compared to `main`, using two independently named reviewer subagents in parallel. Research on best practices is fetched once and shared by both reviewers.

Supports focused review passes via `--pass <focus>` to narrow the review to a specific concern area.

## Arguments

Parse `$ARGUMENTS` for optional flags:

- `--pass <focus>`: Narrow the review to a specific focus area. Valid values:
  - `correctness` — Logic bugs, edge cases, wrong return values, type mismatches, API contract violations, incorrect state mutations
  - `tests` — Missing test coverage, tautological tests, brittle tests, missing edge/negative cases, test quality
  - `security` — Injection vulnerabilities, unvalidated input, secrets handling, missing authorization, OWASP Top 10, path traversal, SSRF

If `--pass` is absent, perform a full review (the default behavior covering all areas).

If an unrecognized `--pass` value is provided, stop and tell the user: "Unknown pass: {value}. Valid passes are: correctness, tests, security."

Store the parsed value as PASS (empty string = full review).

**Pass-specific reviewer framing** (used in steps 5a and 5b):

| Pass | Reviewer instruction |
|---|---|
| `correctness` | "REVIEW FOCUS: This is a focused 'correctness' pass. Focus exclusively on whether this code does what it claims to do. Ignore style, tests, and security — those are handled in separate passes. Only report issues directly relevant to correctness." |
| `tests` | "REVIEW FOCUS: This is a focused 'tests' pass. Focus exclusively on test quality and coverage. Ignore style and production code correctness — those are handled in separate passes. Only report issues directly relevant to testing." |
| `security` | "REVIEW FOCUS: This is a focused 'security' pass. Focus exclusively on security vulnerabilities. Assume an adversarial caller. Ignore style, tests, and general correctness — those are handled in separate passes. Only report issues directly relevant to security." |

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

- Run `git diff main...HEAD` to get the full diff. Save this to a shell variable or temp file — both reviewers will need it.
- Run `git diff main...HEAD --name-only` to get the list of changed files.
- Read each changed file in full to understand the complete context (not just the diff hunks).
- Run `git log main..HEAD --oneline` to understand the commit history.

### 3. Research best practices (cache-aware)

#### 3a. Identify needed topics

Based on the diff and changed files, identify topic phrases that need research.

**If PASS is set** (focused review), narrow research to 1-3 topics directly relevant to the pass:
- `correctness`: error handling patterns, type system best practices, edge case patterns for the language/framework
- `tests`: testing best practices, coverage patterns, test framework idioms for the language
- `security`: OWASP Top 10, language-specific security vulnerabilities, input validation patterns

**If PASS is empty** (full review), identify 2-5 topics. Consider:

- Language-specific best practices (e.g., `typescript strict mode`, `python async`)
- Framework patterns (e.g., `react hooks`, `nextjs server components`)
- Security patterns (e.g., `owasp injection`, `shell script security`)
- Infrastructure/config (e.g., `dockerfile security`, `github actions secrets`)
- Data access (e.g., `postgres indexing`, `redis caching patterns`)

#### 3b. Check the research cache

1. Check if `$HOME/.claude/research/` exists. If it does not, all topics are cache misses — skip to 3c.
2. If it exists, list all `.md` files and read the front-matter of each to get the `tags` array.
3. For each needed topic, determine if it is a cache hit or miss:
   - A **cache hit** requires at least one tag from the file to match a keyword in the topic phrase (substring match in either direction).
   - If ambiguous, treat as a **miss** — over-fetching is cheaper than under-fetching.
4. Log the result: "Cache hit: {filename}" or "Cache miss: {topic}".

#### 3c. Fetch missing topics

For each cache miss:
1. Do 1-2 targeted web searches for that topic.
2. Synthesize findings into the research file format below.
3. Save to `$HOME/.claude/research/{descriptive-kebab-name}.md`.

**Research file format:**

```
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

Read the full content of all relevant research files (both cache hits and newly written). You will include this research context in the prompts for both reviewers in step 5.

Also note the list of relevant research file paths — reviewers may need these paths to read the files themselves.

### 4. Name reviewers and create output directories

Determine the branch name and today's date (`YYYY-MM-DD`). Sanitize the branch name (replace `/` with `-`).

Choose two distinct reviewer display names and slugs for this run. The names should describe complementary review stances suited to the change, not the underlying model/vendor and not ordinal labels.

- Good names are stance-based and specific, such as a correctness-focused reviewer and an architecture-focused reviewer.
- Do not use `opus`, `opus2`, `chatgpt`, `reviewer-1`, `reviewer-2`, or similar model/ordinal names.
- Slugify each display name as lowercase hyphen-case (`[^a-z0-9-]` replaced with `-`, trimmed, no duplicate hyphens).
- If the two slugs collide, rename one before continuing.

**If PASS is set** (focused review):
- `./reviews/{sanitized-branch-name}-{YYYY-MM-DD}-{PASS}/{reviewer-slug-a}/`
- `./reviews/{sanitized-branch-name}-{YYYY-MM-DD}-{PASS}/{reviewer-slug-b}/`

**If PASS is empty** (full review):
- `./reviews/{sanitized-branch-name}-{YYYY-MM-DD}/{reviewer-slug-a}/`
- `./reviews/{sanitized-branch-name}-{YYYY-MM-DD}/{reviewer-slug-b}/`

Write `manifest.json` in the review root:

```json
{
  "schema_version": "review-v1",
  "branch": "{branch-name}",
  "base_ref": "main",
  "head_sha": "{git rev-parse HEAD}",
  "pass": "{PASS or null}",
  "reviewers": [
    {"slug": "{reviewer-slug-a}", "display_name": "{agent-chosen display name}", "role": "{one-sentence stance}"},
    {"slug": "{reviewer-slug-b}", "display_name": "{different agent-chosen display name}", "role": "{one-sentence stance}"}
  ]
}
```

### 5. Launch parallel reviews

Launch BOTH reviews simultaneously in a single message with two tool calls. This is the critical parallelization step.

#### 5a. First reviewer (Agent tool)

Launch an Agent with `model: opus` containing:

- **If PASS is set**: the pass-specific reviewer framing from the Arguments section (prepend it at the top of the agent prompt)
- The assigned reviewer display name, role, and slug from `manifest.json`
- The full diff
- The full content of each changed file
- The full content of all relevant research files
- The output directory path (pass-aware path from step 4)
- The review file format specification (section 5c below)
- **If PASS is set**: add this constraint: "For a focused pass, `01-critical-and-important.md` and `02-suggestions.md` must ONLY contain issues relevant to the '{PASS}' focus area. `00-overview.md` should note this is a focused '{PASS}' pass, not a full review."

The agent prompt must instruct it to write the 5 review files directly using the Write tool.

#### 5b. Second independent reviewer (Agent tool)

Launch a second Agent with `model: opus` — same structure as 5a but with a different perspective framing and writing to the second reviewer output directory:

- **If PASS is set**: the pass-specific reviewer framing from the Arguments section (prepend it at the top of the agent prompt)
- Add this framing at the top: "You are a second independent code reviewer. Do not mirror the first reviewer — bring your own judgment. Focus on aspects that are easy to overlook: subtle logic errors, missing edge cases, implicit assumptions, and long-term maintainability."
- The assigned reviewer display name, role, and slug from `manifest.json`
- The full diff
- The full content of each changed file
- The full content of all relevant research files
- The output directory path: the second reviewer directory (pass-aware path from step 4)
- The review file format specification (section 5c below)
- **If PASS is set**: add this constraint: "For a focused pass, `01-critical-and-important.md` and `02-suggestions.md` must ONLY contain issues relevant to the '{PASS}' focus area. `00-overview.md` should note this is a focused '{PASS}' pass, not a full review."

The agent prompt must instruct it to write the 5 review files directly using the Write tool. The reviewer name in `00-overview.md` must match the assigned display name.

#### 5c. Review file format (shared by both reviewers)

Both reviewers must produce these 5 files in their respective output directories:

**`00-overview.md`**
- Branch name, date, reviewer display name, reviewer slug, and reviewer role
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
- Reference to the research if applicable

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

### 6. Verify and finish

After both reviews complete:

1. Verify that both output directories contain the expected 5 files. If either is missing files, note which are missing.
2. Read `00-overview.md` from each reviewer to get their verdicts.
3. Tell the user:
   - **If PASS is set**: "Review pass: {PASS}"
   - **If PASS is empty**: "Review type: full"
   - Where the reviews were written (both directory paths)
   - Each reviewer's display name and verdict
   - A count of action items by priority from each reviewer
   - Which research topics were cache hits vs. freshly fetched
   - Suggest running `/fix-review` to address findings from both reviewers
