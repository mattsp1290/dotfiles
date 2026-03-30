---
name: web-research-update
description: Refresh all cached research files in .claude/research/ with current web data
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, WebSearch, WebFetch
---

# Web Research Update Skill

Refresh research files cached in `.claude/research/` by re-running web searches and updating each file with current findings.

## Prerequisites

1. **Research directory exists.** Check for `.claude/research/` with at least one `.md` file. If the directory does not exist or is empty, stop and tell the user: "No cached research found in .claude/research/. Run `/review` on a branch first to populate the cache."

## Steps

### 1. Inventory cached research

- List all `.md` files in `.claude/research/`.
- Read the front-matter of each file to extract: `topic`, `tags`, `last-researched`, `sources`.
- Display a table to the user:

  | File | Topic | Last Researched | Age |
  |------|-------|-----------------|-----|
  | react-hooks-best-practices.md | React Hooks Best Practices | 2026-01-15 | 74 days |

- Ask the user: "Update all files, or specific ones? (default: all)"

### 2. Update each selected file

Process files sequentially (not in parallel — respect web search rate limits).

For each file:

1. Read the full current content.
2. Note the existing `sources` URLs and `Key Rules` content as the previous baseline.
3. Run 1-2 web searches for the topic (use the `topic` front-matter field as the search query, supplemented with "best practices" or "security guidelines" as appropriate).
4. Fetch 1-2 of the most authoritative source URLs from the search results.
5. Synthesize updated findings using the same file structure:
   - Update `last-researched` to today's date
   - Update `sources` to reflect the URLs actually used
   - Rewrite `## Key Rules`, `## Common Pitfalls`, `## Relevant to Code Review`
6. Before writing, compare new content to previous content. Note additions, removals, and unchanged items.
7. Write the updated file.
8. Report what changed:
   ```
   Updated: react-hooks-best-practices.md
   - Added: "Prefer useId over Math.random() for stable IDs"
   - Removed: "Avoid useReducer for simple state" (outdated)
   - Unchanged: 4 rules
   ```

### 3. Summarize

After all updates complete, show:
- Count of files updated
- Count of files where content changed vs. stayed the same
- List any topics where advice materially changed (new rules added or old rules removed)
- Suggest running `/review` again on any active branch if research changed significantly
