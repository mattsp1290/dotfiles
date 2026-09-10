# Current evidence research

Use this after valid metadata is re-read and before candidate generation. Its output is a dated evidence set, not a roadmap.

## Repository and local ecosystem

Inspect only what bears on the configured vision, lenses, and acceptance journey:

- applicable guidance and contributor documentation;
- worktree status, HEAD, recent history, relevant branches, tags, releases, and dirty-path fingerprint;
- source entry points, public interfaces, configuration, data/control flow, tests, build/CI commands, architecture, and user documentation;
- `.agents/plans/`, tracker state, and project request/response records;
- configured related repositories, resolved read-only from literal hints, verified as Git roots, and deduplicated by canonical root.

Preserve unrelated changes and separate pre-existing failures. Never clean a checkout. Do not read `.env` values, credential stores, private keys, shell history, private conversations, prompt/session logs, raw reasoning, or sensitive tool payloads.

Classify every measured capability as exactly one of:

- `implemented`: a public executable path plus a passing meaningful test or observed executed behavior proves it;
- `partial`: real behavior exists but a required end-to-end seam is missing;
- `planned`: a plan or tracker claims it without executable proof;
- `absent`: grounded inspection finds no relevant path;
- `blocked`: a verified decision, owner contract, or evidence gate prevents this outcome;
- `unknown`: available evidence cannot support a stronger classification.

An inspected but unexecuted test, documentation, issue name, example, mock, generated name, and plan status proves only its own surface.

## Project records

Inspect direct files under `$HOME/.agents/projects/*/requests/` and same-owner `responses/` read-only when present. A record belongs to this consumer only when its exact blocker-consumer ID and canonical tagged repository identity match metadata. Match a response in the same owner directory by filename and verify any resolved claim against committed public code, meaningful tests, and a consumable revision/version.

Incoming requests under the current project's directory are demand evidence. Malformed, identity-free, stale, superseded, and unrelated records do not globally stop selection. Add matching unresolved records to the frontier, then block only candidates whose acceptance path requires the missing contract. Report the request, owner, affected path, and exact unblock evidence.

This skill never writes request or response records. In composed mode, `$implementation-plan` decides whether an authorized artifact is required.

## Comparator refresh

For every configured comparator, open every official seed and follow current official documentation, repository, release, migration, or security links relevant to the configured lenses. Record:

- publisher/product and page title;
- direct URL;
- access date;
- revision, release, or page update date when available;
- whether the claim is shipped behavior, a documented claim, an inference, or unknown.

Compare observable outcomes, constraints, and ownership boundaries. Never copy source, prompts, schemas, proprietary content, package layouts, private endpoints, or undocumented interfaces. Comparator features are lessons, not automatic requirements.

If publisher ownership or mandatory current coverage cannot be verified, mark the lane `unverified-current`, identify the exact comparator metadata field and missing evidence, and stop before a plan-ready recommendation. A repo-only exploratory result may be labeled evidence-blocked; it is not a completed comparator selection.

## Evidence identity and freshness

Before showing candidates, record:

- metadata SHA-256;
- repository HEAD and a stable dirty-path/status fingerprint;
- related-repository revisions used;
- comparator URLs, versions/update dates, and access timestamps.

Re-read these identities after the selection pause and immediately before a composed handoff. Any material metadata, repository, related-repository, or comparator change invalidates both the displayed set and a pending selection. Rerun affected research, rebuild and redisplay the matrix/candidates, and ask for a fresh selection before resolving decisions. This applies even when the former recommendation still appears viable. Refresh external evidence whenever its age or a newly observed release undermines a material claim.
