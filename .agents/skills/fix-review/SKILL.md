---
name: fix-review
description: Address feedback from a selected code review in ./reviews/, with legacy alphabetical discovery as the default
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Fix Review Skill

Read a selected code review from `./reviews/` and implement the fixes. By
default, use the legacy alphabetical discovery rule; callers can instead
supply an exact directory. Supports the current `review-v1` schema with
agent-chosen reviewer directories, plus legacy single-reviewer and
fixed-directory layouts.

## Arguments

Parse `$ARGUMENTS` for optional flags:

- `--auto`: Run in fully automatic mode. When set:
  - Skip the user prompt in Step 3 (select ALL items automatically)
  - Handle conflicts automatically (prefer stricter severity; when tied, prefer the first reviewer listed in `manifest.json` or the first reviewer directory alphabetically)
  - **Security guardrail**: Flag (but do NOT auto-fix) changes to files involving auth, secrets, credentials, permissions, or config. Log these as "needs-manual" in the summary.
  - After implementing fixes, output a structured summary (see Step 5)
- `--review-dir <path>`: Use this exact review directory instead of selecting
  one by alphabetical order. The path must be an immediate child of
  `./reviews/` or `./.agents/reviews/`. When it contains a `review-v1`
  manifest, require `branch` to match the current branch and `head_sha` to
  match the current `HEAD`; stop on a mismatch rather than applying stale or
  cross-branch feedback.

If `--auto` is absent, behavior is identical to the default interactive mode.

## Prerequisites

1. **Reviews directory exists.** Check for `./reviews/` first, then fall back to `./.agents/reviews/` for legacy artifacts. If neither exist with review subdirectories, stop and tell the user: "No reviews found. Run `/review` first to generate a code review."
2. **Select the review.** If `--review-dir` was provided, canonicalize the path,
   verify it is an immediate child of one of the supported review roots, and
   use it exactly. Otherwise, list directories in the reviews directory and
   pick the last one alphabetically (legacy behavior). Tell the user which
   review you're working from and whether it was explicit or discovered.
   For an explicit `review-v1` directory, validate its manifest `branch` and
   `head_sha` against `git branch --show-current` and `git rev-parse HEAD`.
3. **Detect review structure.** Determine the format in this priority order:
   - If `manifest.json` exists with a `reviewers` array → **review-v1**. Read reviewer directories in manifest order.
   - Otherwise, find all immediate subdirectories containing `04-action-items.md`. If two or more exist → **multi-reviewer directory format**. Read them alphabetically.
   - If the directory contains legacy `opus/` with `opus2/` or `chatgpt/` → **legacy dual-reviewer format**. Read those directories in that order.
   - Otherwise → **single-reviewer legacy format**, read from the directory directly.
4. **Note available research.** Check if `$HOME/.claude/research/` exists. If it does, list the filenames — you will consult these during step 4 rather than doing live web searches.

## Steps

### 1. Read all review files

#### Multi-reviewer format

Read all markdown files from each reviewer directory discovered in the prerequisite step:

- `00-overview.md`, `01-critical-and-important.md`, `02-suggestions.md`, `03-positive-notes.md`, `04-action-items.md`

For each reviewer, derive a label from `manifest.json` `display_name` when available; otherwise use the directory name.

When processing multi-reviewer reviews:
- **Merge action items**: combine action items from all reviewers, deduplicating items that flag the same file:line with the same issue. When multiple reviewers flag the same issue, note it as "flagged by multiple reviewers" (higher confidence).
- **Union positive notes**: preserve patterns called out as positive by any reviewer.
- **Prefer the stricter severity**: if one reviewer says Critical and the other says Important for the same issue, treat it as Critical.

#### Legacy single-reviewer format

Read all markdown files directly from the review directory:
- `00-overview.md`, `01-critical-and-important.md`, `02-suggestions.md`, `03-positive-notes.md`, `04-action-items.md`

### 2. Validate current state

For each action item (from all reviewers if multi-reviewer format), check:
- Does the referenced file still exist? If not, mark as "already resolved / file removed".
- Has the referenced code changed since the review? If the specific lines don't match, note this and adapt.
- Are there uncommitted changes? If so:
  - **If `--auto`**: log a warning ("Uncommitted changes detected, proceeding in auto mode") but continue. Prior passes in a `/pr-ready` pipeline may have left uncommitted changes.
  - **Otherwise**: warn the user that there are uncommitted changes that could be affected.

### 3. Present the plan

Show the user a summary of what you plan to do, organized by priority:

```
## Fix Plan for {review-directory}

### Reviewers: {list reviewer display names or directory names}

### Critical ({count}) {note if any flagged by multiple reviewers}
- Item description... [{reviewer}] / [{reviewer}] / [Multiple reviewers]

### Important ({count})
- Item description... [{reviewer}] / [{reviewer}] / [Multiple reviewers]

### Suggestions ({count})
- Item description... [{reviewer}] / [{reviewer}] / [Multiple reviewers]

### Already Resolved ({count})
- Item description... (file removed / code already changed)
```

**If `--auto`**: Print the plan summary (same format above), then print: "**Auto mode**: proceeding with ALL items automatically." Proceed directly to Step 4 with all items selected. Do not ask the user.

**Otherwise**, ask the user which items to address:
- **All items** (Recommended) — fix everything
- **Critical only** — only fix critical issues
- **Critical + Important** — skip suggestions
- **Multiple-reviewer items only** — only fix issues flagged by multiple reviewers (highest confidence)
- **Let me pick** — user specifies which items to include/exclude

### 4. Implement fixes

Work through the selected items in priority order (critical first, then important, then suggestions). Items flagged by multiple reviewers should be prioritized within their severity level.

For each fix:
- Read the current state of the file
- **If `--auto`** and the file involves auth, secrets, credentials, permissions, or config (check the file path and content for patterns like `auth`, `secret`, `credential`, `password`, `token`, `apikey`, `permission`, `.env`): do NOT auto-fix. Mark the item as "needs-manual" and continue to the next item.
- Apply the fix using Edit (preferred) or Write (for new files only)
- Be careful to preserve patterns called out as positive in `03-positive-notes.md` from any reviewer
- If two action items conflict with each other (from the same or different reviewers):
  - **If `--auto`**: prefer the stricter interpretation (Critical over Important; if same severity, prefer the first reviewer listed in `manifest.json` or the first reviewer directory alphabetically). Log the conflict and the choice made.
  - **Otherwise**: ask the user which to prefer before proceeding
- If a fix requires context you don't have:
  1. Check `$HOME/.claude/research/` for a file whose tags match the topic
  2. If found, read it and use the Key Rules and Common Pitfalls sections
  3. Only fall back to a live web search if no cached research is relevant

### 5. Summarize

After implementing all selected fixes, tell the user:
- How many items were fixed, by priority
- How many were flagged by multiple reviewers vs. one reviewer
- Any items that were skipped and why
- Any items that need manual attention

**If `--auto`**: After the human-readable summary, output a structured block that the caller (e.g., `/pr-ready`) can parse:

```
<!-- auto-summary fixed:{N} skipped:{N} needs-manual:{N} -->
```

**Otherwise**: Suggest reviewing the changes with `git diff` and committing if satisfied.
