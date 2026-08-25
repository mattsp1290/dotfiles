# Review Protocol

The first two reviews are independent attempts to improve the plan. The third review tries to break the revised plan.

## Shared reviewer contract

Give each reviewer this context:

- the user's request verbatim;
- the repository root;
- the plan directory;
- permission to inspect relevant repository files and history;
- a prohibition on editing files or implementing the change.

Do not put secret values in reviewer prompts or findings. Refer to secret variable names and redacted examples only.

Require evidence-backed findings. Each finding must include:

1. Severity: `Critical`, `Important`, or `Minor`.
2. Plan location.
3. Repository evidence or the missing evidence that requires a gate.
4. Failure mode for the implementing agent.
5. A concrete correction to the plan.

Ask reviewers to omit compliments, summaries, and style preferences. A reviewer with no material findings must say `No material findings`.

Every reviewer must also map the user's explicit outcomes, constraints, non-goals, and compatibility promises to plan locations and acceptance criteria. Verify that the structured application context matches the user's answers and is applied consistently to compatibility, rollout, migration, rollback, and behavior-changing work packages. Flag each omitted requirement, changed constraint, unstated scope expansion, and success criterion that does not prove the requested outcome. Never infer or rewrite an application-context answer; identify the exact question that must return to the user.

## Initial reviewer A: implementation completeness

Ask this reviewer to trace the proposed work as an implementer. Focus on missing files or symbols, incomplete control/data flow, hidden dependencies, migration and compatibility gaps, lifecycle/error handling, execution order, and underspecified acceptance criteria.

## Initial reviewer B: architecture and verification

Ask this reviewer to challenge architectural fit and test strategy. Focus on consistency with repository patterns, public API boundaries, security and performance implications where relevant, rollback or recovery, test-layer coverage, false confidence in mocks, and whether success criteria prove user-visible behavior.

Do not tell either reviewer which role the other reviewer has. Do not share their responses until both have completed.

## Calling-agent disposition

Judge each finding independently. Agreement between reviewers is useful evidence, but it is not a vote. Verify claims in the repository before accepting them when verification is practical.

Accept a finding when it makes the plan more correct, grounded, complete, safely ordered, or verifiable without changing user intent. Reject findings that are unsupported, already covered, cosmetic, outside scope, or based on an incompatible redesign.

Apply accepted findings directly to the affected documents. Update the overview, document map, handoff order, and cross-references when a change affects them. Do not add review-response or changelog sections to the plan unless the user requested an audit trail.

## Adversarial reviewer

After the initial findings are applied, launch a fresh subagent with this stance:

> Assume a competent coding agent follows this plan exactly and the change still fails in production or cannot be completed. Find the strongest ways that can happen.

Give this reviewer only the verbatim request, repository root, current revised plan directory, and shared reviewer contract. Do not provide earlier reviews, accepted or rejected findings, the calling agent's conclusions, suspected defects, or proposed corrections.

Ask it to attack:

- unverified assumptions presented as facts;
- contradictions between plan files;
- missing dependency, sequencing, ownership, or cleanup steps;
- partial failure, rollback, recovery, concurrency, and compatibility gaps;
- tests that pass while the required behavior remains broken;
- vague acceptance criteria and scope boundaries that invite drift;
- stale or invented paths, symbols, commands, or APIs.

Require the shared finding format. The adversarial reviewer must rank its strongest failure paths first and avoid repeating issues already fixed.
