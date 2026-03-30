---
name: fix-review
description: Address feedback from the most recent code review in ./reviews/
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Fix Review Skill

Read the most recent code review from `./reviews/` and implement the fixes.

## Prerequisites

1. **Reviews directory exists.** Check for `./reviews/` with review subdirectories. If none exist, stop and tell the user: "No reviews found in ./reviews/. Run `/review` first to generate a code review."
2. **Find the most recent review.** List directories in `./reviews/` and pick the last one alphabetically (the date suffix makes alphabetical order = chronological order). Tell the user which review you're working from.
3. **Note available research.** Check if `.claude/research/` exists. If it does, list the filenames — you will consult these during step 4 rather than doing live web searches.

## Steps

### 1. Read all review files

Read all markdown files from the review directory:
- `00-overview.md` — understand what the changes are about
- `01-critical-and-important.md` — understand the serious issues
- `02-suggestions.md` — understand the nice-to-have improvements
- `03-positive-notes.md` — understand what to preserve (do NOT change these patterns)
- `04-action-items.md` — this is your primary work source

### 2. Validate current state

For each action item, check:
- Does the referenced file still exist? If not, mark as "already resolved / file removed".
- Has the referenced code changed since the review? If the specific lines don't match, note this and adapt.
- Are there uncommitted changes? If so, warn the user that there are uncommitted changes that could be affected.

### 3. Present the plan

Show the user a summary of what you plan to do, organized by priority:

```
## Fix Plan for {review-directory}

### Critical ({count})
- Item description...

### Important ({count})
- Item description...

### Suggestions ({count})
- Item description...

### Already Resolved ({count})
- Item description... (file removed / code already changed)
```

Then ask the user which items to address:
- **All items** (Recommended) — fix everything
- **Critical only** — only fix critical issues
- **Critical + Important** — skip suggestions
- **Let me pick** — user specifies which items to include/exclude

### 4. Implement fixes

Work through the selected items in priority order (critical first, then important, then suggestions).

For each fix:
- Read the current state of the file
- Apply the fix using Edit (preferred) or Write (for new files only)
- Be careful to preserve patterns called out as positive in `03-positive-notes.md`
- If two action items conflict with each other, ask the user which to prefer before proceeding
- If a fix requires context you don't have:
  1. Check `.claude/research/` for a file whose tags match the topic
  2. If found, read it and use the Key Rules and Common Pitfalls sections
  3. Only fall back to a live web search if no cached research is relevant

### 5. Summarize

After implementing all selected fixes, tell the user:
- How many items were fixed, by priority
- Any items that were skipped and why
- Any items that need manual attention
- Suggest reviewing the changes with `git diff` and committing if satisfied
