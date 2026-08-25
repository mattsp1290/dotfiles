# Reviewable PR Decomposition

Use this reference during plan ingestion, queue creation, and queue revision.

## Reviewability contract

A normal PR must satisfy all of these:

1. One coherent purpose that can be described without `and then` joining unrelated outcomes.
2. Independent merge: the updated base remains buildable, testable, and usable immediately after merge.
3. Related tests ship with the behavior they prove.
4. Bounded context: a reviewer can identify the main change and follow the files in a logical order.
5. Reversible scope: reverting the PR does not require reverting a later unmerged PR.
6. No hidden prerequisite from a later queue entry.

Changed-line counts are warning signals, not quotas. About 100 reviewer-written changed lines often fits a normal review. Approaching 1,000 reviewer-written changed lines requires another split attempt or explicit exception approval. Generated files, vendored output, deletions, lockfiles, snapshots, and mechanical rewrites must be counted separately.

Source guidance:

- [Google Engineering Practices — Small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html)
- [Google Engineering Practices — CL descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html)
- [Google Engineering Practices — Review navigation](https://google.github.io/eng-practices/review/reviewer/navigate.html)

## PR description contract

Open a ready, non-draft PR whose title states the outcome. Its body must explain why the change exists; list mapped requirement IDs; state the plan-recorded active-user, backward-compatibility, and feature-flag decisions; summarize included scope and explicit non-goals; give reviewers a logical file/order entry point; separate human-written, generated, deleted, and mechanical diff shape; list exact validation results; summarize both dual-review dispositions, thermo-nuclear recommendations/fixes, and any exception approval; state rollback concerns; and name the next queued slice for context. Include the stable outbox marker used for crash recovery. Keep implementation trivia in the diff unless it materially affects review.

## Requirement identity

Read numeric Markdown files in ascending integer-prefix order. Reject duplicate prefixes. Normalize requirement text by converting CRLF to LF, trimming trailing whitespace on each line, trimming the whole value, and collapsing remaining whitespace runs to one ASCII space. Build its full heading ancestry from the document headings. Slugify that ancestry by Unicode NFKD normalization, dropping non-ASCII marks, lowercasing, replacing non-alphanumeric runs with `-`, trimming `-`, and using `section` if empty.

For the Nth observable requirement in a source file, compute the lowercase SHA-256 of `plan-pr-loop-requirement-v1\0<repo-relative-posix-file>\0<heading-1>\0...\0<heading-n>\0<two-digit-source-ordinal>\0<normalized-requirement-text>`. Its ID is `<exact-numeric-file-prefix>-<heading-slug>-<two-digit-source-ordinal>-<first-12-hash-characters>`. Ordinals restart at one per file and are assigned in source order. Persist source coordinates and the full content digest so collisions or accidental source drift are detectable.

For every observable requirement, persist:

- `requirement_id`: file prefix + normalized full heading path + source ordinal + short content hash;
- source file, full heading ancestry, and ordinal;
- behavior or artifact;
- dependencies;
- proposed paths or symbols;
- verification and acceptance evidence;
- risk/irreversibility;
- generated or mechanical classification;
- remaining human decision.

Reject duplicate IDs, vague requirements without observable evidence, unresolved blocking decisions, duplicate numeric file prefixes, missing document-map files, or unmapped in-scope work. Keep requirement IDs stable when queue entries split.

## Queue entry shape

Each entry records:

```json
{
  "entry_id": "pr-a1b2c3",
  "revision": 1,
  "supersedes": [],
  "split_into": [],
  "sequence": 1,
  "slug": "add-parser-contract",
  "title": "Define and test the parser contract",
  "requirement_ids": ["P01-parser-contract-01-a1b2c3"],
  "prerequisites": [],
  "purpose": "One independently useful result",
  "compatibility": {
    "behavior_change": true,
    "backward_compatible": true,
    "feature_flag_decision": "required|not-required",
    "decision_evidence_digest": "digest when per-PR confirmation was required"
  },
  "included_paths": ["proposed paths"],
  "excluded_work": ["explicit later work"],
  "acceptance": ["observable gate"],
  "validation": ["exact or discovery-time command"],
  "estimated_review_shape": {
    "human_written_lines": "range or unknown",
    "generated_lines": "range or unknown",
    "files": "range or unknown"
  },
  "exception_required": false,
  "exception_reason": null,
  "status": "queued"
}
```

The queue must be acyclic, cover every requirement, preserve a usable intermediate base, and contain no duplicate coverage unless entries name distinct acceptance increments.

Create an initial queue entry ID from the lowercase SHA-256 of `plan-pr-loop-entry-v1\0<stable-plan-id>\0<ordered-requirement-id-1>\0...\0<normalized-purpose>\0<two-digit-initial-creation-ordinal>` and prefix its first 12 characters with `pr-`. Normalize purpose text with the requirement-text rule. For a split child, instead hash `plan-pr-loop-split-v1\0<parent-entry-id>\0<two-digit-split-ordinal>\0<normalized-purpose>` and use the same `pr-` prefix. Persist an ID at first creation and never recompute it after wording, sequence, status, or revision changes.

## Decomposition order

Try these before requesting a large-change exception:

1. Separate preparatory refactors from behavior changes.
2. Separate independent packages, services, or adapters.
3. Land backward-compatible interfaces before consumers when each is useful and tested.
4. Separate migration compatibility scaffolding from cutover and cleanup.
5. Separate generator/schema source from consumers when compatibility permits.
6. Separate repetitive mechanical output from reviewer-written logic.

Do not use stacked PRs. After merge, re-evaluate only unstarted entries. Reordering changes sequence/revision, not `entry_id`. A split creates new IDs and records `supersedes`/`split_into` lineage. Require human approval to combine entries, change external behavior, remove/defer scope, or invalidate an approved exception.

## Exceptional PR approval

Require explicit approval before implementation when generated/vendor output dominates, a trusted generator creates an unavoidable large change, reviewer-written work approaches 1,000 lines, many subsystems obscure the main logic, splitting breaks the base, or a migration bridge cannot safely separate.

Present:

1. Purpose and mapped requirement IDs.
2. Why normal splits fail.
3. Human-written, generated, deleted, total-line, and file-count estimates.
4. Primary files reviewers must inspect.
5. Generator/tool identity and pinned version.
6. Source inputs and exact reproduction command.
7. Deterministic clean-regeneration evidence.
8. Validation, rollback, and review strategy.
9. Existing `linguist-generated` convention.
10. Exact PR-contract digest.

Store approver, time, digest, and summary. Material scope growth invalidates approval. For generated output, review source changes line by line, regenerate twice with no second diff, report generated paths separately, and include behavior/interface tests.
