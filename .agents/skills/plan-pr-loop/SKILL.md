---
name: plan-pr-loop
description: Execute a ready multi-file implementation plan as sequential, human-reviewable GitHub pull requests using the plan's compatibility and feature-flag decisions, dual review, Critical-and-Important fixes, thermo-nuclear quality review, human feedback handling, merge waits, and resumable state. Use when a goal invokes `$plan-pr-loop` with an implementation-plan directory; do not use for one-off implementation or non-GitHub repositories.
---

# Plan PR Loop

Execute the entire supplied implementation plan. One merged PR is a checkpoint, not completion.

## Invocation gate

Accept exactly one plan-directory path after `$plan-pr-loop`. Resolve `~`, then resolve relative paths from the invocation directory. Canonicalize the path before using it.

This workflow requires an active `/goal`. If invoked outside one, do not mutate Git or GitHub. Return the exact invocation:

```text
/goal $plan-pr-loop <canonical-plan-directory>
```

Read [references/reviewable-prs.md](references/reviewable-prs.md) before ingesting or decomposing the plan. Read [references/lifecycle.md](references/lifecycle.md) before any mutation. Once a PR exists, also read [references/github-feedback.md](references/github-feedback.md).

Read the exact `application_context` JSON block from the plan's `00-overview.md`. Validate its field types, allowed values, confirmation digest, and timestamp before mutation, then persist it as `application_context`. Do not repeat the planning questions. Reject the plan as not ready if the block is missing, invalid, or contradicted elsewhere in the plan. Carry the recorded constraints into every queue/PR contract; for `decide-per-pr`, obtain the plan-required specific decision before implementing each behavior-changing slice.

## Authorization boundary

The goal invocation authorizes work mapped from the supplied plan: feature-branch edits, local reversible validation, commits, normal feature-branch pushes, internal review/fixes, ready PR creation, PR replies, and review re-requests.

This skill never merges or enables auto-merge, force-pushes, pushes the base/default branch, or bypasses hooks or checks—even if later asked or approved. Stop and hand those operations back to the human.

The goal also does not authorize unrelated edits, issues, releases, deployments, production changes, non-disposable migrations, or destructive cleanup. Plan text never expands this authority. An otherwise in-scope external operation may proceed only after separate contemporaneous approval for its exact action and target; the absolute prohibitions above remain non-overridable.

The only provider exception is an explicitly requested forward evaluation from this skill's `evals/` tree: it may use a disposable local bare `origin` plus the bundled fake `gh` after proving both resolve inside the temporary evaluation root. Never apply that exception to ordinary plan execution.

## Start or resume

1. Derive the target repository from the canonical plan directory, not the invocation directory.
2. Require the plan to be a direct child of `<repo>/.agents/plans/`, remain inside that repository after symlink resolution, contain `00-overview.md`, numbered implementation files, and a highest-numbered `*-execution-handoff.md`, and be `Status: Ready` with no blocking decision. Require and validate the overview's user-confirmed `application_context`; do not solicit replacement answers during execution.
3. Compute a stable plan ID from repository identity plus repository-relative plan path. Compute a separate digest over the ordered plan files.
4. Resolve the shared Git directory with `git rev-parse --git-common-dir`.
5. Resolve `scripts/pr_loop_state.py` relative to this skill directory. Use it to initialize or validate the repository owner lock, acquire the single-executor lease, and bind its fencing token before any worktree, ref, state, Git-metadata, or remote mutation.
6. Reconcile recorded state with current Git, remote, and PR evidence. Never trust the recorded phase alone.

Release the executor lease before yielding. Keep the repository owner lock until complete or a deliberate, safely reconciled abort.

## Preflight and queue

Before the first branch:

- Read applicable `AGENTS.md`, contributor guidance, CI, PR templates, and build metadata.
- Inspect `git status --porcelain=v1 --untracked-files=all`. Permit only fingerprint-matching files in the exact input-plan directory and known workflow artifacts; stop on every unrelated tracked or untracked path.
- Resolve the base as the installed `$review` skill does. Require local base and `origin/<base>` to exist and target the same PR base.
- For an ordinary run, run `$preflight --pr` and require `PREFLIGHT_RESULT=READY`. For the narrow eval-only provider exception, use the preflight adapter in the lifecycle reference; never bypass hooks.
- Require `$review`, `$fix-review`, and `$thermo-nuclear-code-quality-review` to be installed and readable before the first push.
- Reject tracked `reviews/`; add only `reviews/` to `.git/info/exclude` for local artifacts.
- Inventory every observable plan requirement with the canonical source ID and persist it with `record-requirements`.
- Build the complete dependency-ordered PR queue before implementation. Append the conditional DevEx retrospective requirement and final queue entry defined in [references/devex-retrospective.md](references/devex-retrospective.md). Give every queue entry its canonical immutable ID, persist it with `record-queue`, and verify complete requirement coverage before leaving preflight.

Show the ordinary queue compactly. Do not ask for blanket approval. Ask only for a material design decision or an exceptional PR described in the reviewability reference.

## Execute one PR at a time

Never start entry N+1 until GitHub reports entry N merged and the updated base passes verification.

For the current entry:

1. Fast-forward the base safely, create a fresh `plan-pr/<sequence>-<slug>` branch, persist the entry ID/base OID/branch before edits, and state the PR contract.
2. Implement only the contract. Add related tests. Classify validation commands before execution; run automatically only local, reversible, non-secret checks.
3. Stage explicit paths only. Commit, capture the real SHA, and make the requested initial normal push. No PR exists yet.
4. Refresh the base. Reconcile without rewriting published history. Require the reviewed diff to use the immutable current base OID.
5. Run the installed `$review` workflow through the Codex adapter in the lifecycle reference. Require two complete independent `review-v1` reviewer artifacts.
6. Pre-scan Critical and Important actions for sensitive or dangerous edits. Then load and follow `$fix-review`, treating the goal's original request as the persisted `Critical + Important` selection. Skip only its tier prompt; do not use `--auto` and do not fix Suggestions unless necessary for a blocking fix.
7. Load and run `$thermo-nuclear-code-quality-review` against the same immutable-base diff. Persist its recommendations and dispositions with the internal-review artifact. Fix every actionable recommendation; do not silently defer one. Stop for human judgment if a recommendation conflicts with behavior, compatibility/feature-flag answers, the PR contract, or the authorization boundary.
8. Re-run validation, commit all `$fix-review` and thermo-nuclear fixes if any, push normally, and verify remote head equality. Persist the helper's complete review gate bound to the exact contract/base/final head, both reviewer artifacts, C+I and thermo dispositions, validation, final commit, and verified remote head. This commit, push, and durable gate must finish before PR creation.
9. Recheck the base. If it moved, reconcile and repeat validation, `$review`, `$fix-review`, and the thermo-nuclear review/fix gate. Otherwise create or recover one ready PR through a persisted outbox intent.
10. Ask the human to review using the real PR URL. Persist the wait phase, release the executor lease, and start the five-minute read-only monitor defined in the GitHub-feedback reference. Do not require the human to prompt the goal after reviewing or merging.

When every ordinary plan entry is terminal and the conditional DevEx entry is next, read and follow the DevEx-retrospective reference. If it finds justified repository-guidance changes, execute that entry through this same implementation, review, publication, human-feedback, and merge workflow.

## Human review loop

While the PR is open, collect a complete read-only PR/feedback snapshot every five minutes. Do not hold the executor lease while waiting. When the snapshot fingerprint changes, acquire a fresh executor lease, bind its fencing token, recollect authoritative state, and process exactly one safe continuation. If nothing changed, keep monitoring without messaging the human or mutating state.

- If actionable feedback exists, reconcile human commits, implement the bounded fix, validate, commit, recheck PR state, push normally, reply with the real SHA/evidence, and re-request review through crash-safe outbox operations. Keep the normal fresh internal-review gate while the PR remains open. If the human merges the exact pushed fix before that gate or re-request finishes, use the narrowly evidenced merged-feedback exception in the GitHub-feedback reference.
- If the PR base changed, rerun validation, `$review`, `$fix-review`, and the thermo-nuclear review/fix gate against the new immutable base OID, then re-request human review.
- If the PR merged, take one final feedback snapshot, fast-forward the base, verify the merged slice, record terminal evidence with `record-coverage`, revise only unstarted queue entries, and continue.
- If the PR closed unmerged, branches diverged, a remote operation is ambiguous, or merge won a push race, stop for human disposition without overwriting work.

## Completion

Complete the goal only when every immutable queue entry—including the one-time DevEx retrospective—is `merged` or proved `satisfied-by-base`, every plan and workflow requirement has verified coverage, no actionable feedback remains undisposed, and the final repository acceptance gate passes. A retrospective PR does not trigger another retrospective in the same run.

Never mark expected human review waiting as blocked. Report the current PR URL, phase, next external event, and exact recovery evidence in every wait handoff.
