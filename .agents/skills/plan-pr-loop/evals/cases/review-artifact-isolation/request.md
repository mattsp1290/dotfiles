# Review artifact isolation forward eval

Create the fixture with `--scenario review-artifact-isolation`, then invoke the normal goal.

Verify:

1. `reviews/zz-old-review/sentinel.txt` is moved recoverably before dual review.
2. Live `reviews/` contains exactly the current `review-v1` artifact when `$fix-review` runs.
3. Interrupt after the move; the next continuation repairs the layout.
4. The sentinel is restored unchanged and the current review is archived below run state.
