---
name: review
description: Generate a code review of the current branch compared to main using two independently named reviewer subagents
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, Agent
---

# Code Review Skill

Generate a thorough code review of the current branch compared to the base branch, using two independent reviewer subagents in parallel. Reviews are written to `./reviews/<change-name>/<reviewer-slug>/`.

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

- Run `git branch --show-current` to get the branch name. Sanitize it for use in paths: replace `/` with `-`.
- Run `date +%Y-%m-%d` to get the review date.
- Build `<change-name>` as `<sanitized-branch>-<YYYY-MM-DD>`.
- Run `git diff $BASE_BRANCH...HEAD` to get the full diff.
- Run `git diff $BASE_BRANCH...HEAD --name-only` to get the list of changed files.
- Read each changed file in full to understand the complete context (not just the diff hunks).
- Run `git log $BASE_BRANCH..HEAD --oneline` to understand the commit history.

### 2. Name reviewers and create output directories

Choose two distinct reviewer display names and slugs for this run. The names should describe complementary review stances suited to the change, not the underlying model/vendor and not ordinal labels.

- Good names are stance-based and specific, such as a correctness-focused reviewer and an architecture-focused reviewer.
- Do not use `opus`, `opus2`, `chatgpt`, `reviewer-1`, `reviewer-2`, or similar model/ordinal names.
- Slugify each display name as lowercase hyphen-case (`[^a-z0-9-]` replaced with `-`, trimmed, no duplicate hyphens).
- If the two slugs collide, rename one before continuing.

```
./reviews/<change-name>/<reviewer-slug-a>/
./reviews/<change-name>/<reviewer-slug-b>/
```

Write `./reviews/<change-name>/manifest.json`:

```json
{
  "schema_version": "review-v1",
  "branch": "<branch>",
  "base_ref": "<BASE_BRANCH>",
  "head_sha": "<git rev-parse HEAD>",
  "pass": null,
  "reviewers": [
    {"slug": "<reviewer-slug-a>", "display_name": "<agent-chosen display name>", "role": "<one-sentence stance>"},
    {"slug": "<reviewer-slug-b>", "display_name": "<different agent-chosen display name>", "role": "<one-sentence stance>"}
  ]
}
```

### 3. Launch parallel reviews

Launch BOTH reviews simultaneously in a single message with two Agent tool calls.

#### 3a. First reviewer

Launch an Agent with `model: opus` containing:

- The assigned reviewer display name, role, and slug from `manifest.json`
- The full diff
- The full content of each changed file
- The output directory path: `./reviews/<change-name>/<reviewer-slug-a>/`
- The review file format specification (section 3c below)

The agent must write the 5 review files using the Write tool.

#### 3b. Second independent reviewer

Launch a second Agent with `model: opus` — same structure as 3a but with a different framing:

- Add this at the top: "You are a second independent code reviewer. Do not mirror the first reviewer — bring your own judgment. Focus on aspects that are easy to overlook: subtle logic errors, missing edge cases, implicit assumptions, and long-term maintainability."
- The assigned reviewer display name, role, and slug from `manifest.json`
- The full diff
- The full content of each changed file
- The output directory path: `./reviews/<change-name>/<reviewer-slug-b>/`
- The review file format specification (section 3c below)

The agent must write the 5 review files using the Write tool. The reviewer name in `00-overview.md` must match the assigned display name.

#### 3c. Review file format (shared by both reviewers)

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
   - Each reviewer's display name and verdict
   - A count of action items by priority from each reviewer
   - Suggest running `/fix-review` to address findings from both reviewers
