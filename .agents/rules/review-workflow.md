# Review Workflow

The default path for any non-trivial change is **plan → review → implement →
fix → verify → commit**, not plan → implement → commit. Review is a quality
gate, not a formality — it routinely catches real defects before they ship
(casing bugs, nonexistent schema fields, wrong variable names), including bugs
inside a reviewer's *own* suggested code.

## When to run a review pass

- **Always** before committing a multi-file change, a refactor, or anything
  touching auth, schemas, public APIs, or serialization boundaries.
- After implementing a plan or applying a fix, before declaring it done.
- Skip only for trivial, mechanical edits (a typo, a rename the compiler
  verifies, a one-line config bump).

## How

Prefer the existing skills over ad-hoc review:

1. `/review` — runs two independent reviewers in parallel against the branch
   diff. Use this as the standing dual-agent gate.
2. Reconcile conflicting findings yourself — do not rubber-stamp. When two
   reviewers disagree, prefer the stricter severity and verify the claim
   against source before acting on it (see [[plan-grounding]]).
3. `/fix-review` (or `/fix-review --auto`) — apply the agreed findings.
4. Re-verify after fixes (see [[verification]]) before commit.

For a second non-Claude perspective when the user asks, route through
`/opencode review` (see [[opencode-routing]]).

## Reconciliation discipline

- A finding is not actionable until its referenced symbol/API is confirmed to
  exist. Reviewers hallucinate APIs too.
- Apply valid findings; for each rejected finding, state the one-line reason.
- If a fix is non-trivial, it earns its own review pass — don't let fixes ride
  in unreviewed on the back of the original change.

Delegate the parallel review work to subagents per [[subagents]] (review of
changes is a Sonnet/RedOwl task), and keep yourself as the integration and
quality gate.
