---
name: pr-attention
description: Summarize and prioritize GitHub PRs that need Matt's attention using scripts/github-pr-attention.py output
user-invocable: true
allowed-tools: Bash, Read
---

# PR Attention Skill

Use this skill when Matt asks what GitHub pull requests need his attention, what PRs he owns, what reviews are pending, or where he has been mentioned in PR comments.

The source of truth is the dotfiles script:

```bash
GITHUB_TOKEN="$GITHUB_TOKEN" python3 scripts/github-pr-attention.py --format json
```

The script returns agent-friendly JSON with:

- `viewer`: authenticated GitHub user
- `attention_count`: number of open PRs needing attention
- `items[]`: PRs with `priority`, `reasons`, metadata, mention snippets, and `agent_summary`
- `agent_instructions`: guardrails for interpreting the report

## Prerequisites

1. Ensure `GITHUB_TOKEN` is available in the environment. If it is missing, stop and ask Matt to provide or export it.
2. Run from the dotfiles repo root, or adjust the script path.
3. Do not take PR side effects (approve, merge, close, comment, request changes) unless Matt explicitly asks for that action.

## Collection

Run:

```bash
python3 scripts/github-pr-attention.py --format json
```

Optional human-readable view:

```bash
python3 scripts/github-pr-attention.py --format markdown
```

Optional deeper scan:

```bash
python3 scripts/github-pr-attention.py --format json --include-comment-scan-for-all
```

The deeper scan checks comments on every candidate PR, not only PRs found by GitHub mention search. It is slower and uses more API quota.

## Prioritization Rules

Use the script's `priority` field first, then refine within each bucket:

1. **High**
   - `review_requested`: Matt is requested for review and has not approved the PR.
   - `mentioned_in_comment`: someone tagged Matt in an issue or review comment.
2. **Medium**
   - `authored_by_me` on a non-draft open PR.
3. **Low**
   - Draft authored PRs or other low-urgency open PRs.

Within the same priority:

- Put explicit comment mentions before generic review requests if the mention is recent or sounds blocking.
- Put older review requests above newer ones when Matt likely owes a response.
- Put authored PRs with stale `updated_at` above recently touched PRs.
- Call out draft status; draft authored PRs are usually less urgent unless mentioned.

## Response Format to Matt

Give a concise summary, then the top items:

```markdown
Found N open PRs needing attention.

Top priorities:
1. [HIGH] owner/repo#123 — Title
   Why: review requested; not approved yet.
   Link: https://github.com/owner/repo/pull/123
   Suggested next action: review or delegate.

2. [HIGH] owner/repo#456 — Title
   Why: @mention from alice: "snippet..."
   Link: https://github.com/owner/repo/pull/456
   Suggested next action: answer the comment.

Lower priority:
- [MEDIUM] owner/repo#789 — authored by Matt, open since/updated at ...
```

If there are zero items, say that no open PRs matched the attention criteria.

## Agent Interpretation Notes

- Treat `mention_hits[].snippet` as the most important context for mentioned PRs.
- The script intentionally does not fetch CI status, mergeability, or full diffs. If Matt asks what to do next on a specific PR, fetch that PR separately before making recommendations.
- If an item has `collection_error`, the PR matched an attention search but detail collection failed (often token permissions or SAML). Keep it in the summary and tell Matt manual inspection or token authorization is needed.
- `review_requested` comes from GitHub's open PR search plus review state filtering. If a team review request appears, check `requested_teams` before assuming it is personally assigned.
- `authored_by_me` means open PRs created by Matt, not necessarily blocked on Matt. Summarize these as "owned/open" rather than "urgent" unless other signals exist.

## Common Pitfalls

1. **Summarizing raw JSON without ranking.** Always group high/medium/low and put actionable items first.
2. **Assuming a mention requires a code review.** Mentions may ask a question; read the snippet and phrase the suggested action accordingly.
3. **Approving or commenting automatically.** The report is informational. Wait for explicit instruction before mutating GitHub state.
4. **Ignoring missing token errors.** The script requires `GITHUB_TOKEN`; do not fall back to unauthenticated GitHub API calls.
5. **Overstating completeness.** GitHub search and token permissions bound what the script can see. If a repo is inaccessible to the token, it cannot be reported.

## Verification

For changes to this workflow, run:

```bash
python3 -m unittest tests/test_github_pr_attention.py
python3 -m unittest -v tests.test_github_pr_attention.AttentionReportE2ETests
python3 -m py_compile scripts/github-pr-attention.py tests/test_github_pr_attention.py
```

These tests do not require a real `GITHUB_TOKEN`; the E2E coverage runs the CLI against a local mock GitHub HTTP server with a fake token.
