# GitHub Human Review and Feedback

Read this reference after a PR exists and on every goal continuation while it remains active.

## Ask and wait

After ready PR creation, report its real URL/number, one-sentence result, changed-file and human/generated line summary, passed validation commands, internal-review dispositions, and any exception approval. State:

```text
Waiting for your review or merge. I will not start the next PR until this one merges.
```

Persist `awaiting-human-review`, release the executor lease, and start a read-only monitor. Snapshot the PR and all three feedback streams immediately, then every five minutes until their canonical fingerprint changes. The monitor owns this fixed cadence; the human must not need to prompt the goal after reviewing, commenting, or merging.

Use the script's `--snapshot-only` mode for the final authoritative pre-wait snapshot and capture its emitted `fingerprint`. If it emits `terminal: true`, continue processing immediately instead of waiting. Otherwise pass that exact digest as `--expected-fingerprint` when launching the monitor; this closes the race where feedback or a merge lands between the final snapshot and monitor startup.

Launch `scripts/monitor_pr.py` relative to this skill directory in a yielded/background-capable execution session:

```text
python3 <skill-dir>/scripts/monitor_pr.py \
  --repo <owner/repo> \
  --pr-number <number> \
  --monitor-lock <git-common-dir>/plan-pr-loop/runs/<stable-plan-id>/monitor-pr-<number> \
  --expected-fingerprint <fingerprint-from-snapshot-only>
```

Keep its default 300-second interval in ordinary runs. The script acquires an exclusive per-PR monitor directory, compares the first read with the supplied fingerprint, immediately wakes for an already-terminal PR, polls the PR plus all three streams, exits on any fingerprint change, retries provider failures up to three ticks, and rejects overlapping monitors. Keep the yielded execution session active instead of ending the goal turn. On `monitor-change`, reacquire the executor lease and recollect the authoritative full snapshot; the monitor output deliberately contains digests rather than feedback bodies. Use `--interval-seconds` and `--max-ticks` only for disposable automated evaluation.

The monitor holds an exclusive OS file lock for its full lifetime and records diagnostic PID/target metadata. On `monitor-overlap`, do not start another loop. On `monitor-stale`, the lifetime lock is no longer held; still prove that no yielded continuation owns it, digest that evidence, then restart once with `--stale-monitor-recovery-evidence-digest <digest>`. The script rejects recovery while the lifetime lock is held or when the recorded repository/PR differs. Never remove the monitor directory by hand or infer staleness from age alone.

Do not hold the executor lease while the monitor sleeps or performs read-only GitHub queries. On a changed fingerprint, stop the monitor, acquire a fresh executor lease and fencing token, then recollect the full authoritative snapshot before any mutation. Process the event, release the lease, and restart the five-minute monitor if the PR still awaits human action or merge. Use one monitor per current PR, stop stale monitors when the PR or goal changes, and never overlap polling loops.

Build the fingerprint from canonicalized PR metadata plus complete normalized identities from the conversation-comment, submitted-review, and inline-review streams. A timestamp-only, state, body-edit, requested-reviewer, checks, base/head, or merge change must wake the agent. Provider or network failure is not “no change”: retry the read-only snapshot on the next five-minute tick and surface a persistent failure after three consecutive attempts.

## Authoritative snapshot

Use `gh pr view --json` for PR metadata and `gh api --paginate` for all three feedback streams:

1. `/repos/{owner}/{repo}/issues/{number}/comments` — conversation comments.
2. `/repos/{owner}/{repo}/pulls/{number}/reviews` — submitted reviews.
3. `/repos/{owner}/{repo}/pulls/{number}/comments` — inline review comments.

Capture PR state, `mergedAt`, base/head names, `baseRefOid`, `headRefOid`, mergeability, merge-state status, review decision, requested reviewers, checks, and URL. For feedback, transiently capture body/author/URL/context but persist only IDs, timestamps, state, body digest, disposition, and outbound-operation evidence.

Do not rely on `gh pr view --comments`; it does not cover every feedback type.

## Stream identity

- Conversation and inline comments: `(id, updated_at, body_digest)`.
- Submitted reviews: `(id, submitted_at, state, body_digest)`, including dismissal/state changes.

Never ignore inbound feedback by login; the human can use the same account as automation. Suppress only an exact returned outbound remote ID. A hidden marker may reconcile a pending outbox only when actor, operation kind, PR, and creation window also match. A human comment quoting a marker is still feedback.

Keep bot feedback separate. A bot approval is not the human gate. Never treat a `COMMENTED` review as approval, and treat requested changes as active until addressed or superseded.

## Classification

| Feedback | Action |
|---|---|
| In-scope code/test request | Implement, validate, commit, push, reply with SHA/evidence, re-request review. |
| Question | Reply; do not create an empty commit. |
| Valid out-of-scope suggestion | Explain boundary and ask whether to revise remaining queue; do not create an issue. |
| Ambiguous/conflicting request | Ask before editing. |
| Security, migration, public API, generated-exception expansion | Invalidate contract/approval and get explicit approval. |
| Non-actionable acknowledgment/approval | Record and wait for merge. |

## Feedback edit/push sequence

1. Snapshot PR state and fetch the feature branch.
2. Fast-forward linear human commits, validate them, and stop on divergence.
3. Record feedback IDs and intended bounded fix in the PR contract.
4. Implement, test, run allowed full validation, and stage explicit paths.
5. Commit and capture the real SHA.
6. Immediately before push, snapshot PR state/head. If already merged, do not push; enter merge-race recovery.
7. Push normally. Snapshot state/head immediately afterward.
8. If merge won the race, do not claim the new SHA merged. Verify the base, preserve the orphaned commit, and ask whether to open a follow-up or map it into a later entry.
9. Otherwise verify remote/local head equality, reply through outbox with real SHA/evidence, reconcile current/timeline review state, and re-request review.
10. Take another complete feedback snapshot before yielding so comments created during the edit are not lost.

When step 7 succeeds but the human merges that exact pushed SHA before the fresh internal-review gate or review re-request finishes, do not demand an impossible open-PR re-request or redo review solely to close state. Confirm that the PR's merged head contains the fix SHA, verify the updated base, reply to the feedback when GitHub still permits it, and obtain an explicit contemporaneous human disposition to accept this already-merged exception. Persist that disposition as a `merged-feedback-race` approval bound to the current contract, merge SHA, verification digest, and feedback identity. This is a terminal recovery path only: while the PR is open, the fresh `$review`/`$fix-review`/thermo gate and review re-request remain required.

Do not resolve a thread before its code or answer exists. Leave final thread resolution to repository convention when unknown.

Persist an explicit normalized class and follow its helper-enforced path:

- `code-change`: `seen -> in-progress -> code-pushed -> replied -> disposed`; bind the intended-fix/expected-head evidence, real final pushed commit and validation, a resolved comment-reply outbox targeting this exact `<stream>:<item-id>`, and normally a resolved review-request outbox bound to the same feedback identity and final head. The already-merged exception above replaces only the review-request evidence with its contract-bound approval and verified merge evidence.
- `question`: `seen -> replied -> disposed`; bind a resolved reply outbox targeting this exact `<stream>:<item-id>` and do not invent a code commit.
- `non-actionable`: `seen -> disposed` with a concrete disposition.

Every newly observed or edited identity must begin at `seen`. An edited feedback identity restarts there. Never mark actionable feedback disposed before the code or answer exists and both class-required remote operations are terminal. Normally terminal means `resolved`; when an attempted write remains ambiguous and the human explicitly chooses not to retry after reconciliation, the exact bound `cancelled-human-resolved` outbox also satisfies that operation. A pending or `cancelled-before-attempt` operation never does.

Compute the durable feedback-identity digest over stream, repository ID, current queue-entry ID, PR number, and the normalized identity fields: comments use `(id, updated_at, body_digest, classification)` and reviews use `(id, submitted_at, state, body_digest, classification)`. Bind every reply and feedback-driven review-request outbox to the same repository/entry/PR, canonical `<stream>:<item-id>`, and digest. Revalidate all of them in `outbox-authorize`; an edited same-ID item or a different target must create new operations and can never reuse old reply/request evidence.

For a review re-request, normalize and persist the exact reviewer or team as the outbox `target` plus the reviewed base/final pushed head. Bind a single fixed item with `feedback_target`/`feedback_identity_digest`. When one commit addresses several items for the same reviewer and review cycle, create one request with canonical sorted `feedback_targets` and aligned `feedback_identity_digests`; every included item may reference that one operation. Never send one request per comment for the same reviewed head/target. Run `outbox-authorize` immediately before the POST. Recovery accepts only matching requested-reviewer state, a matching timeline event, or a newer review by that same target. Activity from another reviewer is not proof that this request succeeded.

## Checks and terminal states

CI and human review are separate gates. Record pending checks. Fix in-scope failures, but stop after one evidence-backed retry for infrastructure-only failures, credentials, or scope expansion. Never report skipped checks as passed and never merge.

On `MERGED`:

1. Collect a final feedback snapshot.
2. If unseen actionable code feedback exists, ask whether an existing later ordinary queue contract covers it; do not silently complete coverage. On explicit confirmation, persist the exact later entry ID/current contract digest and the human-disposition digest, then dispose the feedback as `mapped-later` without pretending it was fixed on the merged PR. If no existing contract covers it, stop for plan/scope reconciliation.
3. Record merge metadata and coverage IDs.
4. Fast-forward the base and verify the merged result.
5. Mark the immutable entry merged only after verification.

On closed-unmerged, stop for reopen/supersede/queue/abort disposition. On conflict or unmergeable state, use only the repository's accepted non-rewriting update policy, rerun all gates, and re-request review.

Source guidance:

- [GitHub Docs — Resolving reviews](https://docs.github.com/en/pull-requests/concepts/resolving-reviews)
- [GitHub Docs — Pull request reviews](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews)
- [GitHub REST — Review requests](https://docs.github.com/en/rest/pulls/review-requests)
- [GitHub REST — Review comments](https://docs.github.com/en/rest/pulls/comments)
