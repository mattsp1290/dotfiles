# Plan Grounding

Before writing an implementation plan, verify that every symbol it references
actually exists in the source. The most common cause of multi-pass plan
correction is plans built on hallucinated APIs — a nonexistent schema field, a
misremembered function name, a wrong variable, a type that was renamed. Each one
forces a review-fix cycle that grounding up front would have avoided.

The goal: make review *validation* of a sound plan, not *rework* of a broken
one.

## Before you write the plan

Grep/read the actual source to confirm each of these that the plan will name:

- **Types and structs** — they exist, with the fields you reference.
- **Schema / enum / constant values** — the exact identifier and casing (e.g.
  confirm `RoleReasoning` exists before planning around it; don't assume from a
  pattern).
- **Function / method signatures** — name, arity, and types match.
- **Variable and config names** — spelled and cased as you'll use them.
- **The right seam** — confirm you're targeting the correct local repo/module,
  not a pinned constant or an external endpoint, before planning around it. When
  unsure which seam is canonical, ask the user.

List any referenced identifier you could **not** confirm, and resolve it (find
the real name, or flag the gap) before the plan is considered ready.

## Casing and cross-platform

When a name crosses a serialization or language boundary (JSON field, env var,
exported vs unexported), verify the exact casing on **both** sides — casing
mismatches are a recurring class of bug, including inside reviewers' own
suggestions.

## How this composes

- Use [[subagents]] (Explore/Haiku) to map the real seam and confirm symbols
  before planning — cheap, parallel, and read-only.
- Grounded plans feed the [[review-workflow]]: reviewers then hunt for logic and
  edge-case problems instead of catching basic existence errors.
- The same existence check applies to **review findings** — don't act on a
  reviewer's claim about an API until you've confirmed the API exists.
