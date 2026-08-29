# Plan PR Loop Forward Evaluations

These evaluations exercise agent behavior in disposable local Git repositories with a state-backed fake `gh`. They never contact GitHub. The state helper unit tests are deterministic; the scenarios here are manual forward evals because they require an actual Codex skill invocation, subagents, goal continuation, and human-like events.

## Safety boundary

- Use a fresh `mktemp -d` directory.
- Keep the fake `gh` first in `PATH` for the entire run.
- Confirm `git remote get-url origin` is a local path before invoking the skill.
- Do not authenticate, create a live repository, or substitute a production checkout.
- Preserve the trace, fake state, review artifacts, and goal transcript as evidence.

## Prepare one scenario

From the skill directory:

```bash
eval_root=$(mktemp -d)
python3 evals/fixture_repo.py \
  --scenario normal-two-pr \
  --output "$eval_root/repo"
mkdir "$eval_root/bin"
cp "$PWD/evals/fake-gh.py" "$eval_root/bin/gh"
chmod 755 "$eval_root/bin/gh"
cp evals/cases/normal-two-pr/fake-gh-state.json "$eval_root/fake-gh-state.json"
export PLAN_PR_LOOP_FAKE_GH_STATE="$eval_root/fake-gh-state.json"
export PLAN_PR_LOOP_FAKE_GH_TRACE="$eval_root/fake-gh-trace.jsonl"
export PATH="$eval_root/bin:$PATH"
```

For a seeded feedback/resume PR, replace every `replace-with-*` value in the copied fake state after the fixture repository exists. Its `headRefName` must use `plan-pr/<first-16-stable-plan-id>/<sequence>-<slug>` computed from that fixture's canonical local origin and `.agents/plans/example-plan` path.

Verify isolation:

```bash
command -v gh
realpath "$(command -v gh)"
git -C "$eval_root/repo" remote get-url origin
gh auth status
```

Both executable paths must resolve inside `eval_root`; the remote must be the sibling local bare repository. Compare the copied fake's SHA-256 with the bundled source before invoking the skill.

## Invoke Codex

Use the request in the selected case directory. For example:

```text
/goal $plan-pr-loop <eval_root>/repo/.agents/plans/example-plan
```

This is the actual model boundary. Record evidence that:

- the installed skill was discovered and all routed references were read at the required phases;
- two supported subagents created the exact `review-v1` artifact against an immutable base OID;
- `$fix-review` used the persisted Critical + Important selection without changing Suggestions;
- `$thermo-nuclear-code-quality-review` ran after each review/fix pass, every recommendation received a disposition, and its fixes were validated, committed, and pushed before PR creation;
- the active-user, backward-compatibility, and feature-flag answers were loaded from the implementation plan's valid user-confirmed context block and persisted before mutation without being asked again;
- the goal yielded while the PR was open and later continued automatically;
- no second queue entry began before the fake PR changed to `MERGED`;
- state revisions, plan-lock ownership, checkout-incarnation ownership, independent per-plan executor leases/fences, outboxes, and artifact recovery matched observed Git/fake-GitHub state.

To drive later states, edit only the disposable `fake-gh-state.json`. Model a human comment with a new ID even when `user.login` equals `authenticatedLogin`. To model merge, set `state` to `MERGED`, set `mergedAt`, and set the local bare remote/base to contain the intended head before the next continuation.

## Assert the trace

```bash
python3 evals/assert_trace.py \
  --trace "$PLAN_PR_LOOP_FAKE_GH_TRACE" \
  --expect evals/cases/normal-two-pr/expected-events.json
```

Also inspect the Git log, fake state, state JSON below the fixture's shared Git directory, and review files. Trace assertions prove only the declared GitHub-command invariants; they do not prove code correctness or the subagent review quality.

## Cases

- `normal-two-pr`: full serial sequence, wait, merge, updated base, second PR, final coverage.
- `review-artifact-isolation`: an older lexically later review directory must be backed up, never selected by `$fix-review`, then restored.
- `feedback-and-resume`: all three feedback streams, same-login human feedback, marker quoting, crash recovery, review-request reconciliation, and merge/push races.

For `feedback-and-resume`, seed one actionable comment and inject interruption after each intent/provider boundary. Drive it through code push, one API-posted reply, one API-posted exact-target review request, and disposal. The fake provider rejects unsupported HTTP methods, returns stable comment IDs, mutates comment/requested-reviewer state, and the case contract requires exactly one reply POST and one review-request POST across recovery.

Delete the temporary evaluation root after evidence is captured. The live disposable-GitHub exercise in the implementation plan remains a separate approval-gated acceptance test.
