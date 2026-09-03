---
name: review-gauntlet
description: >-
  Run a two-stage branch hardening workflow: the dotfiles dual-review and
  fix-review pass, then the live Cursor thermonuclear maintainability rubric
  and the dotfiles fix-review pass, with a separate commit and push checkpoint
  after each stage. Use when the user asks for both review rounds or invokes
  the review gauntlet.
---

# Review Gauntlet

Harden the current feature branch in two ordered stages. Do not collapse the
stages into one review, one commit, or one push: the first push is a checkpoint
that must succeed before the thermonuclear stage begins.

## Canonical Sources

Use these sources directly on every run rather than copying their instructions
into this skill:

- Standard review: `~/git/dotfiles/.agents/skills/review/SKILL.md`
- Fixer for both stages: `~/git/dotfiles/.agents/skills/fix-review/SKILL.md`
- Thermonuclear rubric: the current contents of
  <https://github.com/cursor/plugins/blob/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md>

Read each selected `SKILL.md` completely before following it. Use the
platform's skill invocation mechanism when it can select that exact local
skill; otherwise execute the instructions from the file directly. Fetch the
thermonuclear source from its corresponding `raw.githubusercontent.com` URL at
the start of stage 2 and verify its frontmatter name is
`thermo-nuclear-code-quality-review`. Do not silently substitute the local
copy or a remembered version when the fetch fails.

## Prerequisites

Before either review:

1. Read and obey the target repository's `AGENTS.md` files and task-tracking
   conventions.
2. Work from the repository root. Resolve its default/base branch from
   `origin/HEAD`, falling back to `main` only when it is unavailable.
3. Require a non-default branch, an `origin` remote, a clean working tree, and
   at least one committed change in `BASE...HEAD`. Stop instead of mixing
   unrelated or uncommitted work into review fixes.
4. Fetch `origin` and run the local `preflight` skill with push intent. Stop if
   it reports `PREFLIGHT_RESULT=BLOCKED`.
5. Record the starting branch and SHA. Never switch branches during the run,
   and never force-push.

## Stage 1: Standard Review

1. Run the canonical dotfiles `review` skill exactly as written. It must create
   its two independently produced reviewer artifact sets.
2. Identify the review directory created by this invocation and verify it is
   the directory the canonical `fix-review` skill will select as most recent.
   Stop on an ambiguous or different selection rather than applying stale
   feedback.
3. Run the canonical dotfiles `fix-review` skill with `--auto`, even when the
   review appears to have no action items. Preserve its structured summary.
4. If the fixer reports any `needs-manual` items or fails, stop before commit
   and push. Otherwise run the repository-required quality gates for changed
   files, plus `git diff --check`.
5. Stage only changes produced for this stage. Exclude review artifacts and
   any unrelated paths. If there are staged changes, commit them with a message
   describing the standard-review fixes. Do not create an empty commit.
6. Push the branch with `git push -u origin HEAD` when it has no upstream, or
   `git push origin HEAD` otherwise. Verify the pushed remote branch resolves
   to the local `HEAD`. Do not begin stage 2 unless this push succeeds.

## Stage 2: Thermonuclear Review

The upstream thermonuclear skill is a review rubric, while the canonical
fixer consumes the dotfiles `review-v1` artifact schema. Adapt only the output
shape; do not weaken, summarize, or replace the upstream rubric.

1. Fetch and read the live upstream rubric as described under Canonical
   Sources. Record the source URL and fetched commit SHA when GitHub exposes
   one.
2. Gather the same branch diff, full changed-file contents, file list, stats,
   and commit history required by the canonical dotfiles `review` skill.
3. Apply the complete upstream rubric to that evidence. Write a new,
   unambiguous review directory whose name sorts after stage 1's directory,
   using a reviewer slug of `thermo-nuclear-code-quality-review`.
4. Use the canonical review skill's `review-v1` manifest and five-file output
   format (`00-overview.md` through `04-action-items.md`). Include the upstream
   source URL and fetched commit SHA in `00-overview.md`. Convert every
   actionable thermonuclear finding into a self-contained unchecked action
   item with severity, file, line, problem, and concrete remedy. State
   explicitly when there are no findings.
5. Verify this new directory is the exact directory the canonical
   `fix-review` skill will select. Then run that fixer with `--auto`, even when
   no findings were produced.
6. If the fixer reports any `needs-manual` items or fails, stop before commit
   and push. Otherwise run the repository-required quality gates for changed
   files, plus `git diff --check`.
7. Stage only changes produced for this stage. Exclude review artifacts and
   unrelated paths. If there are staged changes, commit them with a message
   describing the thermonuclear-review fixes. Do not create an empty commit.
8. Push with `git push origin HEAD` and verify the remote branch resolves to
   local `HEAD`.

## Completion Report

Report both review directories, reviewer verdicts, fixer summaries, quality
gates actually run, commit SHAs (or `no changes`), and both push results. Show
the final `git status --short --branch` and confirm that local `HEAD` equals the
remote branch SHA. Never report a commit, test, or push as successful without
checking its authoritative command output.

Review artifacts may remain uncommitted when that is the repository's normal
convention. Do not delete or commit pre-existing artifacts, and call out any
newly generated artifacts left in the working tree.
