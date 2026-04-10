---
name: fix-review
description: Address feedback from the most recent code review in ./reviews/
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Fix Review Skill

Read the most recent code review from `./reviews/` and implement the fixes. Supports both single-reviewer reviews and dual-reviewer reviews (Opus + ChatGPT).

## Prerequisites

1. **Reviews directory exists.** Check for `./reviews/` with review subdirectories. If none exist, stop and tell the user: "No reviews found in ./reviews/. Run `/review` first to generate a code review."
2. **Find the most recent review.** List directories in `./reviews/` and pick the last one alphabetically (the date suffix makes alphabetical order = chronological order). Tell the user which review you're working from.
3. **Detect review structure.** Check if the most recent review directory contains `opus/` and `chatgpt/` subdirectories (dual-reviewer format) or contains review files directly (legacy single-reviewer format).
   - **Dual-reviewer**: read from both `opus/` and `chatgpt/` subdirectories
   - **Legacy single-reviewer**: read from the directory directly
4. **Note available research.** Check if `$HOME/.claude/research/` exists. If it does, list the filenames — you will consult these during step 4 rather than doing live web searches.

## Steps

### 1. Read all review files

#### Dual-reviewer format (opus/ + chatgpt/ subdirectories)

Read all markdown files from BOTH reviewer directories:

**From `opus/`:**
- `00-overview.md`, `01-critical-and-important.md`, `02-suggestions.md`, `03-positive-notes.md`, `04-action-items.md`

**From `chatgpt/`:**
- `00-overview.md`, `01-critical-and-important.md`, `02-suggestions.md`, `03-positive-notes.md`, `04-action-items.md`

When processing dual reviews:
- **Merge action items**: combine action items from both reviewers, deduplicating items that flag the same file:line with the same issue. When both reviewers flag the same issue, note it as "flagged by both reviewers" (higher confidence).
- **Union positive notes**: preserve patterns called out as positive by EITHER reviewer.
- **Prefer the stricter severity**: if one reviewer says Critical and the other says Important for the same issue, treat it as Critical.

#### Legacy single-reviewer format

Read all markdown files directly from the review directory:
- `00-overview.md`, `01-critical-and-important.md`, `02-suggestions.md`, `03-positive-notes.md`, `04-action-items.md`

### 2. Validate current state

For each action item (from both reviewers if dual format), check:
- Does the referenced file still exist? If not, mark as "already resolved / file removed".
- Has the referenced code changed since the review? If the specific lines don't match, note this and adapt.
- Are there uncommitted changes? If so, warn the user that there are uncommitted changes that could be affected.

### 3. Present the plan

Show the user a summary of what you plan to do, organized by priority:

```
## Fix Plan for {review-directory}

### Reviewers: {list reviewers — e.g., "Opus + ChatGPT" or "Claude Code"}

### Critical ({count}) {note if any flagged by both reviewers}
- Item description... [Opus] / [ChatGPT] / [Both]

### Important ({count})
- Item description... [Opus] / [ChatGPT] / [Both]

### Suggestions ({count})
- Item description... [Opus] / [ChatGPT] / [Both]

### Already Resolved ({count})
- Item description... (file removed / code already changed)
```

Then ask the user which items to address:
- **All items** (Recommended) — fix everything
- **Critical only** — only fix critical issues
- **Critical + Important** — skip suggestions
- **Both-reviewer items only** — only fix issues flagged by both reviewers (highest confidence)
- **Let me pick** — user specifies which items to include/exclude

### 4. Implement fixes

Work through the selected items in priority order (critical first, then important, then suggestions). Items flagged by both reviewers should be prioritized within their severity level.

For each fix:
- Read the current state of the file
- Apply the fix using Edit (preferred) or Write (for new files only)
- Be careful to preserve patterns called out as positive in `03-positive-notes.md` from EITHER reviewer
- If two action items conflict with each other (from the same or different reviewers), ask the user which to prefer before proceeding
- If a fix requires context you don't have:
  1. Check `$HOME/.claude/research/` for a file whose tags match the topic
  2. If found, read it and use the Key Rules and Common Pitfalls sections
  3. Only fall back to a live web search if no cached research is relevant

### 5. Summarize

After implementing all selected fixes, tell the user:
- How many items were fixed, by priority
- How many were flagged by both reviewers vs. one reviewer
- Any items that were skipped and why
- Any items that need manual attention
- Suggest reviewing the changes with `git diff` and committing if satisfied
