# Resolved milestone brief

Use after selection, material-decision resolution, and evidence-identity revalidation. Keep the brief in conversation; it is not a second plan artifact.

Include:

- `status`: `ready` or `blocked`; each blocker has kind `decision`, `upstream_dependency`, or `evidence`, an owner, affected acceptance path, and exact unblock action;
- metadata project ID, tagged repository identity, and SHA-256 used for research;
- selected candidate, the user's decision, and accepted trade-off;
- product vision, comparator scope, affected lenses, and acceptance journey;
- repository HEAD/worktree fingerprint, related-repository revisions, and evidence classifications, revalidated after the final displayed candidates and selection;
- current and target flows;
- functional behavior, affected non-functional requirements, boundaries, ownership, external dependencies, and exclusions;
- security, lifecycle, persistence, and recovery decisions only where affected;
- exact tests and observable acceptance criteria;
- official source titles, publishers, direct URLs, revisions/releases/update dates, and access dates;
- unresolved decisions or dependencies with owner and exact unblock evidence.

A brief is `ready` only when every material decision and required public dependency is resolved and current evidence supports planning. Otherwise retain the selected milestone as `blocked`; do not invent an answer or workaround.

## Standalone

Return the brief in conversation and direct the user to invoke `$implementation-plan` with the already resolved milestone. Create no plan, request record, tracker item, or implementation code.

## Composed with implementation-plan

Give exactly one brief to `$implementation-plan`. Preserve still-applicable explicit user decisions. Let that skill ask its required active-users, backward-compatibility, and feature-flag questions, choose one normal plan name, use its normal multi-file format, decide whether any authorized cross-repository request artifact is needed, and run its required reviews.

Treat review completion as evidence, not intent. Before describing a composed plan as reviewed, verify that `$implementation-plan` captured two distinct completed initial reviewer results and one fresh completed adversarial reviewer result after revisions. Never wait on an empty reviewer set. If reviewer creation is unavailable or fails after that skill's allowed retry, preserve the plan and report the exact incomplete review stage under `$implementation-plan`'s existing failure contract.

Do not create an interim roadmap, hidden handoff file, duplicate plan format, or plan before selection. A decision/evidence-blocked brief may become a clearly blocked plan under `$implementation-plan` when that skill permits it. An unresolved required upstream dependency follows `$implementation-plan` ownership and authorization rules; this skill itself remains read-only for project records and sibling repositories.
