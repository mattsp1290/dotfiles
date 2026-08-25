# Lifecycle, State, and Internal Review

Read this reference before any mutation and again after compaction or interruption.

## State location

Anchor below `git rev-parse --git-common-dir`:

```text
<git-common-dir>/plan-pr-loop/
├── lock/
│   ├── owner.json
│   ├── fence.json
│   └── executor/lease.json
└── runs/<stable-plan-id>/
    ├── state.json
    ├── review-backups/
    └── reviews/
```

## Canonical identities

Compute identifiers byte-for-byte as follows. SHA-256 inputs are UTF-8 and use the shown NUL separators.

1. Read `git remote get-url origin`.
2. For GitHub SSH or HTTPS forms, remove credentials, query, fragment, and a trailing `.git`; lowercase host, owner, and repository; emit `github.com/<owner>/<repo>`. Reject any other host during ordinary execution.
3. For the eval-only local-origin exception, resolve the origin to its canonical real path and emit `file:<absolute-posix-realpath>`.
4. Repository ID is the lowercase hex SHA-256 of `plan-pr-loop-repo-v1\0<normalized-origin>`.
5. Express the canonical plan directory as a repository-relative POSIX path. Stable plan ID is the lowercase hex SHA-256 of `plan-pr-loop-plan-v1\0<repository-id>\0<relative-plan-path>`. It deliberately excludes file contents.
6. Order numbered Markdown plan files by integer prefix, rejecting duplicate prefixes. Begin the plan-content hash with `plan-pr-loop-content-v1\0`; for each file, append `<repo-relative-posix-path>\0<lowercase-sha256-of-raw-file-bytes>\0`. The resulting lowercase hex digest is the plan digest.

Store both the stable ID and ordered content digest. An edited plan therefore finds the same run and requires reconciliation rather than silently starting another run.

## Helper protocol

Run `python3 scripts/pr_loop_state.py <command>`. This is the stable entry point; its sibling modules separate pure model/validation rules, atomic state storage, leases, and feedback/outbox handling. Lock commands use `--lock`. Every mutating state command uses both `--state` and `--lock` plus the exact owner token, executor ID, and live fencing token; the helper verifies `lease.json` while holding the repository mutex before it performs the state CAS. Pass structured command data with `--input-json` or stdin.

Required lock commands:

- `lock-init`: atomically claim or verify the repository owner lock.
- `lock-release`: remove the owner lock only after the exact owner proves no executor lease remains and the bound run state is complete. Retain it for recovery or abort disposition.
- `lock-update-plan`: after explicit plan-change reconciliation, update the owner digest while holding the exact executor lease.
- `lease-acquire`: atomically acquire the single executor and return the next fencing token.
- `lease-release`: require exact owner, executor, and fencing token.
- `lease-takeover`: repair an abandoned/incomplete executor directory only after the skill proves no live continuation owns it and records explicit takeover evidence (plus the prior executor ID when a lease file exists).

Required state commands:

- `init`, `validate`, `bind-lease`, `transition`
- `record-plan`, `record-requirements`, `record-application-context`, `record-queue`, `record-coverage`, `record-pr`
- `record-review-isolation`, `record-review-gate`, `record-acceptance`
- `feedback-check`, `feedback-record`
- `outbox-begin`, `outbox-authorize`, `outbox-resolve`
- `approval-check`, `approval-record`

Every mutating state command uses expected revision, expected phase when applicable, the current fencing token, `--lock`, `--owner-token`, and `--executor-id`. Exit codes: `0` success, `2` input/schema, `3` CAS/owner/lease/fencing conflict, `4` illegal transition, `5` I/O, `64` unknown command. Treat nonzero as a stop; never infer partial success.

Lock arguments:

| Command | Required arguments |
|---|---|
| `lock-init` | `--lock`, `--owner-token`, `--repository-id`, `--stable-plan-id`, `--plan-digest`; add `--goal-id` when available. |
| `lease-acquire` | `--lock`, `--owner-token`, `--executor-id`. |
| `lease-release` | `--lock`, `--owner-token`, `--executor-id`, `--fencing-token`. |
| `lease-takeover` | `--lock`, `--owner-token`, new `--executor-id`; JSON includes `takeover_evidence_digest` and, for an intact old lease, `prior_executor_id`. |
| `lock-update-plan` | Same exact lease identity plus `--plan-digest`. |
| `lock-release` | `--lock`, `--state`, `--owner-token`; call only after lease release and helper-verified completion. Retain the owner lock for abort/recovery disposition. |

State input contracts:

| Command | JSON object |
|---|---|
| `init` | `plan` and `repository`, plus the validated user-confirmed `application_context` loaded from `00-overview.md`; optional `requirements`, `queue`, and `coverage`; pass the acquired `--fencing-token`. |
| `validate` | Empty. |
| `bind-lease` | Empty; pass expected revision/phase and the newly acquired fencing token. |
| `transition` | `to_phase`, `reason`. |
| `record-plan` | Full `plan` with unchanged stable ID/path, `reason`, and human approval-evidence digest when contents changed. |
| `record-requirements` | Full requirement inventory and `reason`; dependency IDs must form a DAG; changed inventory requires human approval-evidence digest. |
| `record-application-context` | Exact active-user, compatibility, feature-flag, confirmation-digest, and time fields loaded from the plan. |
| `record-queue` | Full `queue`, `reason`. |
| `record-coverage` | `requirement_id`, status, and an evidence digest for terminal status. |
| `record-pr` | `current` patch containing only authoritative IDs, refs, SHAs, PR metadata, or review artifact path. |
| `record-review-isolation` | Next isolation phase plus the source/backup/archive paths and immutable base/head/manifest evidence required for that phase. |
| `record-review-gate` | Entry/contract/base/head, two independent reviewer-artifact digests, C+I disposition digest, thermo artifact and disposition digests, post-fix validation digest, final fix commit SHA, and equal verified remote-head SHA. |
| `record-acceptance` | Passed status, final base SHA, and acceptance evidence digest. |
| `feedback-check` / `feedback-record` | `stream`, normalized `item` with explicit `code-change`, `question`, or `non-actionable` classification; never include a durable body. |
| `outbox-begin` | `operation` with stable ID and kind-specific identity: PR create includes base/head refs, expected base/head OIDs, marker, and input digest; replies include PR, canonical `<stream>:<item-id>` target, full normalized feedback-identity digest, marker, and input digest; review requests include PR, exact reviewer/team target, expected base/head OIDs, and—when feedback-driven—the same feedback target/identity digest. |
| `outbox-authorize` | `operation_id`; call immediately before the first provider-write attempt. It revalidates repository/PR/feedback identity and the exact review gate, then moves `pending` to `authorized`. After interruption, reconcile an `authorized` operation; never authorize or execute it again. |
| `outbox-resolve` | `operation_id` and resolution evidence. Cancellation is either proved `cancelled-before-attempt`, or `cancelled-human-resolved` with attempted=true plus human-disposition and reconciliation-snapshot digests. |
| `approval-check` | `entry_id`, `contract_digest`. |
| `approval-record` | Approval ID, entry ID, contract/summary digests, approver, and approval time. A `merged-feedback-race` approval also requires exact merge SHA, verification digest, and feedback-identity digest. |

Before state initialization, parse the single `application_context` JSON block in `00-overview.md`. Recompute its confirmation digest using the formula defined by `$implementation-plan`; reject a mismatch, an invalid enum/type, contradictory plan prose, or `not-applicable` when either boolean is true. Record that application context and the requirement inventory before the queue. The helper computes each PR-contract digest from immutable entry fields, requirement content digests, and the application-context digest. It rejects incomplete PR contracts, unknown dependencies, dependency cycles, unknown mappings, illegal entry-status changes, multiple active entries, incomplete prerequisites, removal/core edits, terminal reopening, and started-entry reordering. After preflight, a new entry must split a still-queued persisted parent, preserve symmetric lineage, and conserve that parent's requirements; reconcile genuinely new approved scope by returning through preflight with new human evidence. A split retains the parent as `superseded` with complete lineage. Before leaving preflight, every in-scope requirement must be mapped or proved satisfied by base. Completion additionally requires structured terminal PR/base evidence, matching computed coverage, class-valid disposed feedback, evidenced terminal outboxes, and passed final acceptance evidence. Each merged entry requires a complete fresh review gate unless the narrow merged-feedback race exception in the GitHub-feedback reference is bound to the exact contract and verified merge.

## Eval-only preflight adapter

For a forward evaluation explicitly launched from this skill's `evals/` tree, do not apply `$preflight`'s ordinary non-GitHub fallback verbatim. First prove the working repository, local bare `origin`, and bundled fake `gh` all resolve inside the same disposable temporary root. Then reproduce the relevant readiness checks with the fake `gh` and run an ordinary `git push --dry-run` against that local origin. Do not pass `--no-verify`; hook bypass remains forbidden. This adapter never applies to a real plan run.

## Legal phases

```text
preflight -> queued -> implementing -> internal-review -> publishing
publishing -> awaiting-human-review -> addressing-feedback
awaiting-human-review -> awaiting-merge
addressing-feedback -> awaiting-human-review | awaiting-merge
awaiting-merge -> queued | complete
any active phase -> human-required | recovery-required
human-required | recovery-required -> a reconciled prior/next phase
```

Record the reason for every transition. Git and GitHub remain authoritative.

## Resume reconciliation

On every continuation:

1. Verify lock owner; acquire a fresh executor lease; bind its fencing token by state revision.
2. Re-read and digest the plan. Stop on changed content until its effect on queued/current work is resolved. Return through `preflight`, obtain and digest explicit human reconciliation for implementation-impacting changes, and update requirements as needed. If `application_context` changed, require a newly user-confirmed block produced during plan revision; never ask the initial context questions here. Then use `record-plan` and `lock-update-plan`; never create a new run for edited contents.
3. Inspect branch, worktree, local/remote heads, target base OID, PR state, pending outbox, and review artifact restoration state.
4. Fast-forward only linear human commits. Stop on divergence.
5. Continue exactly one safe phase. If remote success is ambiguous, reconcile or enter `human-required`; do not retry blindly.
6. Release the executor lease before yielding.

Never reclaim a lease based only on age. Prove no continuation owns it and inspect state/outbox before explicit takeover.

## Internal `$review` adapter

Load the current installed `$review` skill and preserve its base resolution, prerequisites, review stances, `review-v1` manifest, five-file reviewer contract, and final verification. Adapt only unsupported launcher primitives:

1. Fetch the target base. Require the local named base and `origin/<base>` to resolve to the same immutable OID.
2. Isolate live `reviews/`: move existing untracked contents into the run backup after recording recovery state; create an empty live directory.
3. Choose two distinct stance-based reviewer names/slugs. Write the manifest before launch. Include standard `review-v1` fields plus `base_oid` and the reviewed `<base-oid>...HEAD` range.
4. Launch two independent supported Codex subagents in parallel. Give each its stance, repository root, immutable base OID, HEAD, changed paths, output directory, and the installed `$review` five-file format. Tell the second not to mirror the first.
5. Require both directories and all five nonempty files. Verify overview name/verdict and action-item headings. Missing/ambiguous output fails review.
6. Persist the artifact path. Restore prior `reviews/` only after the Critical-and-Important fix phase; archive current artifacts under run state without deleting evidence.

Drive every filesystem move with `record-review-isolation`: `none -> backup-intent -> backed-up -> reviewing -> archive-intent -> archived -> restore-intent -> restored`. When no prior directory exists, `none -> reviewing` is allowed. Persist unique source/backup/archive paths before their moves and bind the review to base OID, head OID, and manifest digest. On resume, reconcile recorded intent with observed paths before invoking `$fix-review`; never guess from lexicographic order.

## `$fix-review` composition

Before edits, parse both `01-critical-and-important.md` and `04-action-items.md`. Stop for human judgment on conflicts, unclear safe fixes, auth/secrets/credentials/permissions, security-sensitive config, destructive operations, migrations, or authorization expansion.

Load and follow the current installed `$fix-review` skill. The original `$plan-pr-loop` request permanently answers its selection step as `Critical + Important`; do not prompt again and do not use `--auto`. Follow its remaining validation and implementation instructions. Leave Suggestions unchanged unless a blocking fix cannot be correct without one. Record each blocking item as fixed, already resolved, or human-required.

## Thermo-nuclear composition

After every `$review` plus `$fix-review` pass, load and run the installed `$thermo-nuclear-code-quality-review` skill against the same immutable `<base-oid>...HEAD` range. Save its recommendations and a disposition for each beside the archived review artifact. Implement every actionable recommendation, including structural simplifications, then rerun the allowed validation set. A recommendation may not silently broaden behavior, compatibility policy, feature-flag policy, paths, or authorization; return to human judgment when it would. Commit and normally push the combined fixes before creating or re-requesting a PR. If the base moves and the dual review/fix pass repeats, this gate repeats too.

After the final push, verify the remote head equals the local head and call `record-review-gate` with the exact PR-contract, base, and final head plus both reviewer-artifact digests, the C+I disposition digest, thermo artifact/recommendation-disposition digests, validation evidence, and fix/final commit SHA. The helper rejects `internal-review -> publishing`, PR-create intents, and review-request intents without that exact gate. Changing the reviewed base or local/remote head invalidates it and requires the complete review/fix/thermo sequence again.

The only terminal exception is when a human merges the exact already-pushed feedback-fix SHA before the invalidated gate can be rebuilt. Bind a `merged-feedback-race` approval to the current entry contract, human disposition digest, merge SHA, and verified terminal evidence. This exception never authorizes a large or otherwise exceptional PR and never applies while the PR is still open.

## Base freshness

Bind every internal review artifact to an immutable base OID. Fetch immediately before review and PR creation. If the base moved, reconcile through documented repository policy without force/rebase of published history, rerun validation, and repeat `$review`, `$fix-review`, and the thermo-nuclear gate. While a PR is open, compare every `baseRefOid` snapshot to the reviewed OID and repeat the full gate after movement.

## Remote outbox

Persist an outbox intent before PR creation, replies, or review requests. Each operation has stable ID, kind, PR/repository identity, inputs/digests, intent time, and status.

- PR creation: require the intent's expected base OID and head SHA, and embed `<!-- plan-pr-loop:op=<id> -->`. Recover first by marker and repository/head/base, independent of current head SHA. Immediately query `baseRefOid` after create/recovery and compare it with the expected OID before publication. Never create a duplicate when a matching marker or head/base PR exists in any relevant state.
- Replies: use the marker when Markdown is supported and record the returned remote ID. Suppress only the returned ID as authoritative.
- Review requests: bind `target` to normalized reviewer/team identity and expected base/head to the current complete review gate. Bind one feedback item singularly, or bind a canonical target/digest list when the same commit addresses several items in one review cycle; issue only one re-request per reviewer/head. Reconcile exact-target requested-reviewer state, exact-target timeline events, and exact-target submitted reviews after intent time. Another reviewer's newer review does not satisfy the request. If success remains ambiguous, require human disposition instead of notifying twice.

Call `outbox-authorize` immediately before every PR-create, reply, or review-request POST; authorization changes the intent from `pending` to `authorized`, so an interrupted attempt cannot be authorized twice. Reconcile an authorized operation before any further provider write. Record ambiguity with attempted=true and a snapshot digest, then reconcile that same operation only to `resolved` or `cancelled-human-resolved`. Never turn an ambiguous intent into a pre-attempt cancellation. Use `cancelled-before-attempt` only for a still-pending, never-authorized intent with evidence that no provider call occurred. If a call may have reached GitHub, obtain the human's disposition, capture a provider reconciliation snapshot, and persist both digests as `cancelled-human-resolved`; otherwise leave it ambiguous and stop.

## Validation command safety

Automatically run only local, reversible, non-secret checks with a bounded working-copy target. Require separate exact approval for deployment, credentialed network write, non-disposable migration, destructive cleanup, or an unclear target. Report skipped/manual gates as such; never call them passed.

Before staging or pushing, verify the recorded feature branch, explicit path allowlist, real local SHA, no plan/state/lock/review artifacts, and no unrelated work. Never use `git add .`, `git add -A`, force push, hook bypass, or default-branch push.
