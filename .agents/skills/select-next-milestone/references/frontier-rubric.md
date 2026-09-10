# Configuration-driven frontier

Use this only after repository, ecosystem, project-record, and official comparator evidence is current.

## Matrix and journey

Build one compact row for every configured evaluation lens. Add a row only when repository evidence proves it is required for the configured acceptance journey.

| Field | Required content |
| --- | --- |
| Lens | Exact metadata name and question |
| Current state | `implemented`, `partial`, `planned`, `absent`, `blocked`, or `unknown` |
| Repository proof | Paths, symbols, tests, observed behavior, or an explicit missing-evidence gate |
| Comparator evidence | Current relevant behavior for every configured product, preserving differences |
| Ownership | Current repository, related repository, host/user, or unknown |
| Gap | Smallest missing outcome or foundation |
| Vision relevance | Connection to the declared vision and acceptance journey |

Every initial and rebuilt matrix must render all seven columns above, including `Vision relevance`; do not rely on nearby prose to supply an omitted column.

Draw the current acceptance journey and each candidate's smallest before/after flow. Label existing, proposed, mocked, local-owner, related-owner, and externally owned seams. Discuss security, lifecycle, recovery, or operations only when the candidate affects them.

## Candidate contract

Present two to four coherent candidates when evidence supports them. If only one is defensible, present it and explain why. Never pad the list.

Use the same field template for every option; surrounding prose does not substitute for an omitted field. Each option contains:

- name and exactly one type: `user journey` or `enabling foundation`;
- primary beneficiary and one observable outcome;
- exact connection to the vision, affected lenses, and acceptance journey;
- repository proof and proposed insertion point;
- one relevant lesson and intentional difference for every comparator;
- smallest before/after flow;
- verified ownership and suspected external dependencies;
- readiness: `ready`, `foundation first`, `decision needed`, `upstream dependency`, `discovery`, or `planned`;
- largest material decision or dependency, prefixed with its exact evidence/reasoning class (normally `Inference`, `Proposal`, or `User decision`);
- bounded scope, non-goals, and comparator parity-claim limit;
- credential-free or otherwise safely bounded proof;
- concise rank rationale.

Within every option, label material evidence and reasoning with the exact applicable class: `Repository fact`, `Local ecosystem fact`, `External fact`, `Inference`, `Proposal`, or `User decision`.

Put fully planned outcomes outside the selectable list. Exclude duplicate plans, request-only work, cosmetic changes, broad refactors, comparator ports, feature-count parity, and outcomes already proved complete.

## Ranking and selection

Rank qualitatively by:

1. nearest complete repeatable acceptance journey or removal of its only hard blocker;
2. direct progress toward the vision across configured lenses;
3. fit with verified ownership and public boundaries;
4. ability to prove the outcome without uncontrolled external effects;
5. reduction of uncertainty for the following milestone;
6. bounded scope without premature platform construction.

Put the recommendation first and explain the evidence. Always display options before selection. Then stop and ask one concise question. The user may select or delegate only after seeing the choices. Preserve any non-recommended selection and state its trade-off.

## Decision and dependency resolution

After selection, ask no more than three short questions per interaction, only when an answer changes observable behavior, public interfaces, ownership, persistence, recovery, security, lifecycle, platform support, external effects, or scope. Keep unanswered material decisions explicit.

Trace every required contract to verified ownership. A selected candidate with a missing external contract becomes a blocked brief containing the owner, missing public behavior, affected acceptance path, and exact evidence that would unblock it. Do not hide a gap with a private import, local duplicate, speculative adapter, or mock claimed as completion.
