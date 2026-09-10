---
name: select-next-milestone
description: Determine one bounded next product milestone for the current Git repository from live repository evidence, repository-declared vision, and current official comparator research. Use when asked what this repository should build next or when composed as $implementation-plan $select-next-milestone. Do not use to implement an already selected milestone, brainstorm without repository evidence, or create a long-range roadmap.
---

# Select Next Milestone

Select one evidence-backed milestone, resolve its material decisions, and then return or hand off one brief. Rebuild the frontier from current evidence on every fresh candidate-selection run.

## Modes and ownership

- Standalone: return one `ready` or `blocked` milestone brief in conversation. Do not create a plan, request record, tracker item, or implementation change.
- Composed with `$implementation-plan`: complete metadata, research, candidate selection, and decision resolution first. Then give exactly one brief to `$implementation-plan`; that skill owns application-context questions, plan files, cross-repository request artifacts, and required reviews.

## Workflow

1. Resolve the current Git root, read applicable repository guidance, and record the current revision and dirty state. Stop outside a Git worktree.
2. Resolve this skill's directory from the loaded `SKILL.md`, then run `python3 <skill-dir>/scripts/validate_project.py <absolute-git-root>`. If metadata is absent, invalid, unsupported, path-unsafe, or explicitly being edited, read [project-metadata.md](references/project-metadata.md). Do not measure the repository or recommend candidates before valid metadata is re-read.
3. Read [research-playbook.md](references/research-playbook.md). Inspect current repository and configured ecosystem evidence read-only. Refresh every configured comparator from current official sources. If mandatory official coverage is unavailable, identify the affected fields and return an evidence-blocked result before a plan-ready recommendation.
4. Read [frontier-rubric.md](references/frontier-rubric.md). Build the configuration-driven matrix and show two to four bounded candidates when supported, recommendation first. Explain when fewer are defensible.
5. **Stop after displaying fresh candidates and ask one concise selection question.** Never select for the user unless they delegate after seeing the options. Preserve a non-recommended choice and its trade-off.
6. Recheck the metadata digest, repository revision/dirty fingerprint, related-repository revisions, and material comparator freshness after the pause. Any material change invalidates the displayed candidates and any pending selection: rebuild and redisplay the affected matrix/candidates, then ask for a fresh selection before decision resolution, even when the former recommendation still appears viable.
7. Resolve only decisions that materially affect behavior, public interfaces, ownership, persistence, recovery, security, lifecycle, external effects, platform support, or scope. Ask no more than three short questions per interaction.
8. Read [implementation-plan-handoff.md](references/implementation-plan-handoff.md). Return one ready or blocked brief. Recheck evidence identities immediately before composed handoff.

## Invariants

- Keep `Repository fact`, `Local ecosystem fact`, `External fact`, `Inference`, `Proposal`, and `User decision` distinct.
- Mark a capability `implemented` only when an executable path plus a passing meaningful test or observed executed behavior proves it. An unexecuted test file, plan, issue, document, example, mock, or name proves only its own surface.
- Comparator behavior supplies current product lessons, not automatic requirements or permission to copy source, prompts, schemas, package layouts, or undocumented interfaces.
- Treat project records as read-only evidence. Only a selected candidate whose acceptance path requires an unresolved verified contract is dependency-blocked.
- Preserve unrelated worktree changes. Do not inspect secret-bearing files, credentials, private conversations, prompt/session logs, raw reasoning, or sensitive tool payloads.
- Do not modify sibling repositories or perform live external effects from this selection workflow.
