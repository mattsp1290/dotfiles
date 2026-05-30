# Beads (bd) CLI Conventions

## Core Commands

- `bd init` — Initialize beads in a repo (creates `.beads/` directory)
- `bd create "title" [flags]` — Create a new bead (NOT `bd add`)
- `bd close <id> -r "reason"` — Close a bead (use `-r` not `-m` for the message)
- `bd delete <id> --force` — Delete a bead
- `bd list` — List all beads
- `bd ready` — Show unblocked beads (no pending dependencies)
- `bd show <id>` — Show bead details
- `bd graph` — Show dependency graph

## Creating Beads

```bash
bd create "Short title (under 500 chars)" \
  -d "Longer description with details" \
  -p 0 \           # Priority: 0=critical, 1=high, 2=medium, 3=low
  -l impl \         # Label: analysis, prep, impl, testing, docs, cleanup
  -t task \         # Type: bug, feature, task, epic, chore
  --silent          # Output only the ID (for scripting with variable capture)
```

- Title MUST be under 500 characters. Keep under 100 chars ideally — use `-d` for details.
- Use `--silent` when capturing IDs: `ID=$(bd create "..." --silent)`

### Good vs bad pattern

```bash
# Good — short title, details in -d
bd create "Extend Hugo archetype with tags and sources fields" \
  -d "Update themes/lunus-theme/archetypes/default.md. Add: tags (list), sources (list of {title, url}), relevancy_score (int 1-10). Keep TOML +++ format." \
  -p 0 -l prep --silent

# Bad — everything crammed into the title
bd create "Extend themes/lunus-theme/archetypes/default.md with additional frontmatter fields for synthesized articles: tags (list), sources (list of {title, url} objects), relevancy_score (int 1-10), category ('dev-news' or 'ai-developments'). Keep TOML +++ format matching existing convention." -p 0 -l prep --silent
```

## When generating `bd create` commands

- Title: what (action + target, <100 chars)
- `-d` description: how and why (details, criteria, file paths, constraints)
- Always use `-p` for priority and `-l` for labels
- Use `--silent` when capturing the ID into a variable

## Dependencies

```bash
bd dep add <child> <parent>   # child depends on parent completing first
bd dep remove <child> <parent>
bd dep tree                   # Show dependency tree
bd dep cycles                 # Detect cycles
```

- Convention: `bd dep add CHILD PARENT` — the child is blocked until parent closes
- Never create cycles

## Closing Beads

```bash
bd close <id> -r "reason"     # -r for reason, NOT -m
bd close <id> --force         # Force close pinned issues
```

## ID Format

Beads use the pattern `{project}-{hash}` (e.g., `lunusdotai-a3f2dd`). The prefix is set during `bd init`.

## Scripting Pattern

```bash
TASK_A=$(bd create "First task" -p 0 -l analysis --silent)
TASK_B=$(bd create "Second task" -p 1 -l impl --silent)
bd dep add $TASK_B $TASK_A
```

## Common mistakes

- **`bd add` does not exist** — use `bd create`
- **`-m` does not exist on close** — use `-r` for reason
- **Long titles blow up** — always use `-d` for details
- **Missing `--silent`** — without it, variable capture grabs extra output
