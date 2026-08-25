# DevEx Retrospective

Read this reference when every ordinary implementation-plan queue entry is terminal and the final conditional DevEx entry is next.

## Preflight contract

Add exactly one workflow requirement and queue entry during the original preflight. Give the queue entry `workflow_kind: devex-retrospective`, make it the final sequence, and set its only possible repository paths to `AGENTS.md` and `.agents/**`. Its prerequisites are the ordinary plan entries known at preflight; the helper also prevents it from starting while any other non-superseded entry is nonterminal.

The workflow requirement comes from this skill, not from product scope. Use the exact source `skill://plan-pr-loop/devex-retrospective`, describe the behavior as a one-time evidence-based assessment of repository guidance, and map it only to the DevEx entry. Exclude product code, personal `~/.agents`, input plans under `.agents/plans/`, review artifacts, run state, locks, generated output, and unrelated cleanup.

## Assess the completed session

Run the retrospective once, after the ordinary plan PRs merge and before final acceptance. Review concrete evidence from this run:

- navigation or ownership facts that took repeated searches to discover;
- missing, stale, conflicting, or overly broad instructions in root `AGENTS.md`;
- repository commands, validation gates, or architecture landmarks that future agents are likely to need;
- repo-owned `.agents/` skills or guidance that were hard to discover or use;
- repeated recoverable mistakes caused by repository-specific ambiguity rather than general tool behavior.

Inspect the current root `AGENTS.md` and repo-owned `.agents/` contents before deciding. Prefer correcting an existing canonical instruction over adding another file. Add only durable repository-specific guidance with a demonstrated future benefit; do not turn a one-off incident, generic coding advice, personal preference, or this workflow's private state into permanent repo instructions.

Write the assessment under the run directory beside `state.json`, outside the worktree. Persist its run-relative path and exact SHA-256 digest; the helper resolves the path beneath that run directory, reads the file, and verifies the digest both when terminalizing the entry and before final acceptance. Persist no transcript, secrets, credentials, feedback bodies, or other sensitive data.

## No-change outcome

If existing guidance is adequate, do not create an empty commit or PR. Record the DevEx queue entry and its workflow requirement as `satisfied-by-base` with terminal evidence containing:

- `outcome: no-change`;
- the retrospective artifact path;
- its exact artifact SHA-256 plus the repository verification digest.

Then run final acceptance. This is a positive assessed outcome, not a skipped gate.

## Improvement-PR outcome

If the evidence supports changes:

1. Keep the persisted path boundary at root `AGENTS.md` and repo-owned `.agents/**`, but stage only the explicit files justified by the assessment; never stage `.agents/plans/` or workflow artifacts.
2. Create a fresh final `plan-pr/<sequence>-devex-retrospective` branch from the verified updated base.
3. Make only the justified guidance or agent-navigation changes. Validate structural syntax plus any affected skill or repository checks.
4. Run the complete dual `$review` and Critical + Important `$fix-review` pass, then the thermo-nuclear review and fixes. Commit and push the final reviewed head before opening a ready PR.
5. Ask for human review, run the five-minute monitor, address feedback, and wait for the human to merge exactly as for an ordinary entry.
6. Verify the merge, record `outcome: changes-merged` with retrospective evidence, complete workflow-requirement coverage, and then run final acceptance.

Do not merge, auto-merge, push the base branch, or bypass any normal review gate. The retrospective executes exactly once per goal; merging its PR never schedules another retrospective in that run.
