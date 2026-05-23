# Git Conventions

## Committing and pushing

Committing finished work and pushing feature branches (including opening/updating PRs) is fine — no need to ask first. Create a new commit whenever a logical unit of work is complete and verified; group related file edits per commit, and write message bodies that explain the *why*. Only destructive operations (force-push, push to `main`/`master`, amending published commits, rewriting remote history, `git reset --hard`, `git clean -f`, branch deletes) require explicit user approval.

## Verify repo context

When working across multiple repositories, worktrees, or git contexts, always verify you're in the correct repo before committing:
- Run `pwd` and `git remote -v` to confirm
- If the working directory doesn't match the user's intent, stop and ask

This is especially important in worktrees (`.claude/worktrees/`) where paths can be ambiguous.
