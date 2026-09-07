# Cross-repository requests

Use this workflow when the local plan depends on another repository, or research identifies a concrete capability worth sharing with further projects. Request documents are planning handoffs, not issue-tracker replacements or authorization to implement, publish, or provision infrastructure.

## Choose an owner

Inspect the relevant existing repositories, their public contracts, and previous requests and responses. Resolve completed requests against the actual release or commit before filing another. Distinguish demonstrated reuse from prospective consumers. A named prospective consumer such as Birbparty is evidence of intended reuse, not proof that it already uses Eino.

Prefer extending an established owner when the capability fits its boundary. Propose a new repository when a coherent, independently testable responsibility spans consumers and no existing owner fits. Describe a small first deliverable and keep application routes, credentials, authorization decisions, UI branding, and deployment policy with their hosts unless the request specifically targets one of those responsibilities. Do not turn plausible future reuse into a mandatory platform rewrite.

## Write the request

Resolve the request root as `$HOME/.agents/projects`. Normalize the target repository directory to a single lowercase kebab-case segment. Use `requests/YYYY-MM-DD-short-name.md`; verify the resolved destination remains under that target's requests directory, including symlink resolution. Preserve existing requests unless this task explicitly revises them. Inspect representative requests in the target directory, or in sibling project directories for a new target, and follow their format.

Include:

- Requested by, date, target repository or **proposed new repository**, request status, priority, and decision owner.
- Current/blocking consumers and prospective consumers, with evidence for each.
- Background with observed source revisions, public interfaces, and the concrete duplication or missing contract.
- The requested behavior, ownership boundary, host responsibilities, and explicit exclusions.
- Acceptance criteria covering consumer integration, failure and lifecycle behavior, compatibility, and a published pin when a dependency will be consumed.
- The affected local work packages and whether the request is blocking or non-blocking.
- A response/unblock contract, normally a same-filename response under the target project's `responses/` directory. Owner acceptance is separate from implementation completion.
- Portable source references using module/repository identifiers and documented environment variables for local resolution. Never include secrets.

For a new repository, also record the proposed name, why existing owners do not fit, package/language boundaries, its minimal initial deliverable, intended maintainer/creation decision owner, and the evidence required before a consumer adopts it. Requesting creation does not mean the repository exists or authorize creating it in the current planning session.

## Connect requests to execution

Keep the local implementation specification in its normal plan directory. Add an external-dependency/request map that identifies each request's canonical location, owner, affected packages, blocking status, and exact unblock evidence. Use `$HOME/.agents/projects/<repo>/requests/<filename>` in plan text so another checkout can resolve it. Use the project's issue tracker for execution status.

If a requested contract is necessary for the chosen local implementation and has no verified usable pin, mark the plan blocked. Name the owner and exact unblock action. If the local work can finish independently, explain the bounded local result and defer adoption of the request explicitly. Never describe the same request as both required for completion and non-blocking.

Give each independent reviewer access to the canonical requests and require it to check ownership, evidence of reuse, local integration acceptance, new-repository justification, scope, and dependency gates. The caller owns edits to both requests and plan. Reconcile them after reviews so their requirements and status agree. Report created requests separately from implemented or accepted upstream work.
