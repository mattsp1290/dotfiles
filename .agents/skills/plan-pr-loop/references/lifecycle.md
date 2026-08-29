# Lifecycle, State, and Internal Review

Read this reference before any mutation and again after compaction or interruption.

## State location

Anchor below `git rev-parse --git-common-dir`:

```text
<git-common-dir>/plan-pr-loop/
├── lock/                         # permanent v2 guard, or one unfinished legacy run
├── .coordination.mutex           # short initialization/release transactions only
└── runs/<stable-plan-id>/
    ├── lock/
    │   ├── owner.json
    │   ├── fence.json
    │   └── executor/lease.json
    ├── state.json
    ├── review-backups/
    └── reviews/
```

Each checkout also has a lifetime claim at `<git-dir>/plan-pr-loop-checkout/owner.json`, where `git-dir` is the canonical result of `git rev-parse --git-dir`, not the `.git` path guessed from the worktree. The claim contains a random checkout-incarnation ID mirrored in the plan owner and executor lease. A main checkout and each linked worktree therefore have separate claims even though they share the coordination root and refs.

The plan lock excludes a second executor for the same stable plan. The checkout claim excludes a second plan from the same checkout, including while the first plan waits for human review. Different plans in different checkout incarnations have independent locks, fencing counters, state, monitors, and review archives and may execute concurrently. Hold `.coordination.mutex` only while initializing, adopting, or releasing lifetime claims; never use it as a repository-wide executor lease.

### Legacy singleton compatibility

The old layout used `<git-common-dir>/plan-pr-loop/lock` as the active plan lock. New plan-scoped initialization requires that path to contain the v2 guard. If it contains a legacy owner, every different or new plan stops. The owning legacy plan may resume in place only after its executor has yielded and explicit reconciliation evidence binds it to the current checkout incarnation. It keeps its existing state path and fence counter. When that run reaches helper-verified completion, `lock-release` atomically replaces its owner with the v2 guard while holding the legacy mutex, so older loaded helpers fail closed. Never move live legacy state or reset its fence. An incomplete legacy lock or a missing/mismatched checkout claim requires human recovery evidence.

## Canonical identities

Compute identifiers byte-for-byte as follows. SHA-256 inputs are UTF-8 and use the shown NUL separators.

1. Read `git remote get-url origin`.
2. For GitHub SSH or HTTPS forms, remove credentials, query, fragment, and a trailing `.git`; lowercase host, owner, and repository; emit `github.com/<owner>/<repo>`. Reject any other host during ordinary execution.
3. For the eval-only local-origin exception, resolve the origin to its canonical real path and emit `file:<absolute-posix-realpath>`.
4. Repository ID is the lowercase hex SHA-256 of `plan-pr-loop-repo-v1\0<normalized-origin>`.
5. Express the canonical plan directory as a repository-relative POSIX path. Stable plan ID is the lowercase hex SHA-256 of `plan-pr-loop-plan-v1\0<repository-id>\0<relative-plan-path>`. It deliberately excludes file contents.
6. Order numbered Markdown plan files by integer prefix, rejecting duplicate prefixes. Begin the plan-content hash with `plan-pr-loop-content-v1\0`; for each file, append `<repo-relative-posix-path>\0<lowercase-sha256-of-raw-file-bytes>\0`. The resulting lowercase hex digest is the plan digest.
7. Canonicalize `git rev-parse --git-dir` for the invoking checkout. The checkout incarnation is a freshly generated random identifier stored in that private Git directory on first claim and copied into the plan owner. Reuse the stored value only when both records match. Do not derive an incarnation from a path that can be removed and recreated.
8. Feature branches use `plan-pr/<first-16-characters-of-stable-plan-id>/<sequence>-<slug>`. The helper rejects persisted branch metadata outside this namespace. An existing namespaced ref is resumable only when the current run state binds it to the same queue entry.

Store both the stable ID and ordered content digest. An edited plan therefore finds the same run and requires reconciliation rather than silently starting another run.

## Helper protocol

Run `python3 scripts/pr_loop_state.py <command>`. This is the stable entry point; its sibling modules separate pure model/validation rules, atomic state storage, leases, and feedback/outbox handling. Every lock and state mutation command receives the canonical `--git-common-dir`, canonical worktree `--git-dir`, and exact `--checkout-incarnation`. Lock commands also use the canonical `--lock`. Every mutating state command uses `--state`, owner token, executor ID, and live fencing token; the helper validates the plan-lock path, state path, checkout claim, and `lease.json` before it performs the state CAS. Pass structured command data with `--input-json` or stdin.

Required lock commands:

- `lock-init`: under the short coordination mutex, atomically claim or verify the canonical plan lock and checkout incarnation. It also creates/verifies the permanent legacy guard, or adopts the matching yielded legacy owner with explicit evidence.
- `lock-release`: remove a v2 plan lock and its exact checkout claim only after the owner proves no executor lease remains and the bound run state is complete. For a completed legacy run, convert the singleton owner to the permanent guard and release its checkout claim. Retain active claims for recovery or abort disposition.
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

Every mutating state command uses expected revision, expected phase when applicable, the current fencing token, `--lock`, `--owner-token`, `--executor-id`, `--git-common-dir`, `--git-dir`, and `--checkout-incarnation`. Exit codes: `0` success, `2` input/schema, `3` CAS/owner/lease/checkout/fencing conflict, `4` illegal transition, `5` I/O, `64` unknown command. Treat nonzero as a stop; never infer partial success.

Lock arguments:

| Command | Required arguments |
|---|---|
| `lock-init` | Canonical coordination arguments plus `--lock`, `--owner-token`, `--repository-id`, `--stable-plan-id`, `--plan-digest`; add `--goal-id` when available. Legacy checkout adoption also passes `legacy_checkout_adoption_evidence_digest`. |
| `lease-acquire` | Canonical coordination arguments plus `--lock`, `--owner-token`, `--executor-id`. |
| `lease-release` | Canonical coordination arguments plus `--lock`, `--owner-token`, `--executor-id`, `--fencing-token`. |
| `lease-takeover` | Canonical coordination arguments plus `--lock`, `--owner-token`, new `--executor-id`; JSON includes `takeover_evidence_digest` and, for an intact old lease, `prior_executor_id`. |
| `lock-update-plan` | Same exact checkout and lease identity plus `--plan-digest`. |
| `lock-release` | Canonical coordination arguments plus `--lock`, `--state`, `--owner-token`; call only after lease release and helper-verified completion. Retain active claims for abort/recovery disposition. |

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

1. Verify the plan owner and checkout-incarnation claim; acquire a fresh executor lease for that plan; bind its fencing token by state revision. A moved worktree remains the same checkout only when its private Git directory and incarnation marker still match. A missing or mismatched marker is recovery-required, never an automatic resume.
2. Re-read and digest the plan. Stop on changed content until its effect on queued/current work is resolved. Return through `preflight`, obtain and digest explicit human reconciliation for implementation-impacting changes, and update requirements as needed. If `application_context` changed, require a newly user-confirmed block produced during plan revision; never ask the initial context questions here. Then use `record-plan` and `lock-update-plan`; never create a new run for edited contents.
3. Inspect the checkout-bound branch, worktree, local/remote heads, captured target-base OID, current `origin/<base>` OID, PR state, pending outbox, and review artifact restoration state.
4. Fast-forward only linear human commits. Stop on divergence.
5. Continue exactly one safe phase. If remote success is ambiguous, reconcile or enter `human-required`; do not retry blindly.
6. Release the executor lease before yielding.

Never reclaim a lease based only on age. Prove no continuation owns it and inspect state/outbox before explicit takeover.

## Internal `$review` adapter

Load the current installed `$review` skill and preserve its base resolution, prerequisites, review stances, `review-v1` manifest, five-file reviewer contract, and final verification. Adapt only unsupported launcher primitives:

1. Fetch the target base and capture the exact `origin/<base>` OID. Do not read the review range through that mutable ref again; use the captured OID throughout the pass. Do not require, check out, or update the local named base.
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

Bind every internal review artifact to an immutable base OID value, never a remote-tracking ref name. Fetch immediately before initial implementation, review, PR creation, feedback handling, post-merge verification, DevEx work, and final acceptance; capture `origin/<base>` after each fetch. If the captured current OID differs from the recorded OID, reconcile through documented repository policy without force/rebase of published history, rerun validation, and repeat `$review`, `$fix-review`, and the thermo-nuclear gate. While a PR is open, compare every `baseRefOid` snapshot to the reviewed OID and repeat the full gate after movement. Never check out, fast-forward, or update the local base branch.

## Remote outbox

Persist an outbox intent before PR creation, replies, or review requests. Each operation has stable ID, kind, PR/repository identity, inputs/digests, intent time, and status.

- PR creation: require the intent's expected base OID and head SHA, and embed `<!-- plan-pr-loop:op=<id> -->`. Recover first by marker and repository/head/base, independent of current head SHA. Immediately query `baseRefOid` after create/recovery and compare it with the expected OID before publication. Never create a duplicate when a matching marker or head/base PR exists in any relevant state.
- Replies: use the marker when Markdown is supported and record the returned remote ID. Suppress only the returned ID as authoritative.
- Review requests: bind `target` to normalized reviewer/team identity and expected base/head to the current complete review gate. Bind one feedback item singularly, or bind a canonical target/digest list when the same commit addresses several items in one review cycle; issue only one re-request per reviewer/head. Reconcile exact-target requested-reviewer state, exact-target timeline events, and exact-target submitted reviews after intent time. Another reviewer's newer review does not satisfy the request. If success remains ambiguous, require human disposition instead of notifying twice.

Call `outbox-authorize` immediately before every PR-create, reply, or review-request POST; authorization changes the intent from `pending` to `authorized`, so an interrupted attempt cannot be authorized twice. Reconcile an authorized operation before any further provider write. Record ambiguity with attempted=true and a snapshot digest, then reconcile that same operation only to `resolved` or `cancelled-human-resolved`. Never turn an ambiguous intent into a pre-attempt cancellation. Use `cancelled-before-attempt` only for a still-pending, never-authorized intent with evidence that no provider call occurred. If a call may have reached GitHub, obtain the human's disposition, capture a provider reconciliation snapshot, and persist both digests as `cancelled-human-resolved`; otherwise leave it ambiguous and stop.

## Validation command safety

Automatically run only local, reversible, non-secret checks with a bounded working-copy target. Require separate exact approval for deployment, credentialed network write, non-disposable migration, destructive cleanup, or an unclear target. Report skipped/manual gates as such; never call them passed.

Before staging or pushing, verify the recorded `plan-pr/<first-16-stable-plan-id>/...` feature branch, exact checkout incarnation, explicit path allowlist, real local SHA, no plan/state/lock/review artifacts, and no unrelated work. Resolve Git metadata paths through `git rev-parse --git-path`; do not write shared config, refs, or `info/exclude` except through a documented narrow transaction. Never use `git add .`, `git add -A`, force push, hook bypass, or default-branch push.
