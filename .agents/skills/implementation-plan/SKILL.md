---
name: implementation-plan
description: Create a repository-grounded, multi-file implementation plan with explicit operating-context decisions, then improve it through two independent reviews and one adversarial review. Use for changes that need detailed technical planning before implementation. Do not use when the user asks to implement immediately or only needs a short checklist.
---

# Implementation Plan

Create an implementation specification under the current repository. Planning is the deliverable. Do not implement the change unless the user separately asks for implementation.

## Establish the planning target

1. Resolve the repository root with `git rev-parse --show-toplevel` from the invocation directory. If that command fails, stop and ask the user to invoke the skill inside a repository.
2. Read every applicable `AGENTS.md` and the repository's contributor guidance.
3. Derive a short plan name from the requested change. Normalize both derived and user-provided names to lowercase kebab-case. The result must be one non-empty path segment that matches `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
4. Set the only output directory to `<repo-root>/.agents/plans/<plan-name>/`. Resolve the destination before writing and verify that it is a direct child of `<repo-root>/.agents/plans/`. Reject path traversal, nested names, absolute names, and symlink escapes.
5. If that directory contains files, preserve them unless the user explicitly asked to revise that plan. Ask before replacing an existing plan whose relationship to the request is unclear.

## Research before writing

Inspect the code, tests, build configuration, documentation, version-control state, and nearby patterns that materially affect the change. Follow important call paths and interfaces far enough to distinguish repository facts from assumptions.

Never copy secret values from environment files, configuration, logs, command output, or history into the plan or a subagent message. Refer to variable names and redacted examples only. Inspect secret-bearing files only when the task requires it. Treat a discovered live credential as a separate security issue, not as plan evidence.

Resolve reasonable questions from the repository. Infer and report the change type and affected areas from the request and repository; do not make the user classify them. Ask for relevant documentation only when the request and repository do not identify an authoritative source and that omission could change the design. Ask how success will be judged when the requested outcome is not already measurable. Ask about additional constraints only when deployment, migration, rollout, security, performance, or another repository-specific concern materially affects the plan.

## Confirm operating context

Before detailed plan writing, ask the user these questions and wait for explicit answers. Ask them together in one concise message unless a prior answer makes a follow-up clearer.

1. Does the application, service, library, or tool currently have active users or external consumers?
2. Must this change preserve backward compatibility for existing users or consumers, including APIs, stored data, configuration, and established workflows?
3. If either answer is yes, are feature flags appropriate for relevant behavior changes: `appropriate`, `not-appropriate`, or `decide-per-pr`?

Do not infer these answers from repository evidence. If both first answers are no, record feature flags as `not-applicable`. If the user cannot answer either of the first two questions, treat the decision as blocking. If `decide-per-pr` is selected, identify the work packages that can change behavior and require a human decision before each corresponding PR is implemented.

Record the answers in the exact `application_context` structure in [references/plan-format.md](references/plan-format.md). Preserve the user's answers through review; a reviewer finding may trigger a new user question but must never silently alter them. Use the answers to define compatibility, rollout, migration, and rollback requirements throughout the plan.

Classify every remaining question as blocking or non-blocking. Resolve blocking questions before calling the plan implementation-ready. If a blocking decision cannot be resolved, mark the plan `blocked` and record the decision owner and exact unblock action.

Read [references/plan-format.md](references/plan-format.md), then write the complete plan as a numerically ordered series of Markdown files. Use repository-relative paths for repository content. Do not use checkout-specific absolute paths. Identify external locations with documented environment variables or platform-neutral identifiers and state how the implementer resolves them. Do not create implementation artifacts outside the plan directory.

## Review and revise

Read [references/review-protocol.md](references/review-protocol.md). Use subagents for the required reviews. The calling agent owns every plan edit and must not delegate final judgment.

1. After the initial plan is complete, launch two independent reviewer subagents. Launch them concurrently when the harness permits it.
2. Give both reviewers the user request, repository root, and plan directory. Do not give either reviewer the other review, suspected problems, or proposed answers.
3. Tell reviewers to inspect the repository and return findings only. They must not edit the plan or implementation.
4. Evaluate every finding against the request and repository evidence. Apply the findings that improve correctness, completeness, sequencing, testability, or implementability. Reject unsupported, duplicative, scope-expanding, or purely stylistic findings.
5. After those edits are complete, launch a new subagent for an adversarial review. Do not reuse either initial reviewer for this pass. Give it only the verbatim request, repository root, current revised plan directory, and review contract. Withhold the earlier reviews, dispositions, suspected defects, and proposed corrections.
6. Evaluate and apply the adversarial findings with the same standard. Edit the relevant plan sections instead of appending a review transcript.
7. Re-read the full plan after the last edit. Remove contradictions, stale cross-references, duplicate requirements, and obsolete assumptions introduced by revision.

A review is complete only when its designated subagent inspected the required artifacts and returned valid findings or the exact no-findings response. If a reviewer aborts, times out, cannot inspect the repository, or returns unusable output, retry that stage once with a fresh subagent. If the harness cannot create a required subagent or the retry fails, preserve the current plan, stop, and tell the user which review stage did not complete. Do not silently replace independent review with self-review.

## Deliver

Confirm that:

- the plan contains at least an overview, one implementation work file, and an execution handoff;
- a ready plan's overview contains valid, user-confirmed `application_context`, while a blocked plan names any missing context answer and owner;
- all document-map links and references to existing repository files resolve;
- every proposed file or symbol is labeled `new` or `proposed` and names an existing parent path or insertion point;
- dependencies and work packages have an unambiguous order;
- each work package has concrete verification and acceptance criteria;
- facts, assumptions, decisions, open questions, and out-of-scope work are distinct;
- the plan does not claim that implementation work occurred.

Read [references/summary-style.md](references/summary-style.md), then summarize the finished plan for the user. Link the overview and state the first implementation action. If a blocking decision remains, describe the plan as blocked and state the exact unblock action instead.
