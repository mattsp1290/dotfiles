# Normal two-PR forward eval

Invoke:

```text
/goal $plan-pr-loop <fixture-repo>/.agents/plans/example-plan
```

Expected human actions:

1. Wait until PR 1 is ready and the goal asks for review.
2. Change the fake PR to merged and update the local bare `main` with PR 1's head.
3. Confirm PR 2 starts only after that continuation verifies the updated base.
4. Merge PR 2 the same way.
5. Confirm the goal completes only after all requirement coverage and final acceptance pass.
