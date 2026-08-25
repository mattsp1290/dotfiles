# Feedback and resume forward eval

Start from a ready fake PR created by the skill. Edit its fake state to add:

- a conversation comment;
- a `CHANGES_REQUESTED` review body;
- an inline review comment;
- a human comment whose login equals `authenticatedLogin`;
- a human comment that quotes an existing `plan-pr-loop:op` marker.

Verify each item is processed once. Crash after a reply or review request succeeds but before local outbox resolution; on resume, verify the operation is reconciled without duplicate notification. Submit a review before resuming a pending review-request outbox and verify it satisfies the intent.

Finally, set the PR merged between a feedback commit and push. Verify the skill does not claim the orphaned SHA was merged and asks whether to create a follow-up or remap it.
