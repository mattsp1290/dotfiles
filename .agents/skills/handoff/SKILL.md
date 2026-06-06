---
name: handoff
description: >-
  Run the end-of-session handoff ritual that leaves a repo ready for the next
  session: file follow-up issues for remaining work, run the project's quality
  gates if code changed, close/update tracked issues, commit related changes,
  push to the remote (beads/dolt-aware when present), verify the tree is clean
  and up to date with origin, prune stale local state, and print a handoff
  summary for the next session. Use when wrapping up work — instead of
  re-typing the close checklist each time. Composes /preflight before pushing.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Skill
---

# Handoff Skill

Codifies the recurring "leave the repo ready for the next session" ritual into
one command. It is generic — it detects beads (`.beads/` + `bd` CLI) and Dolt at
runtime and adapts — and it respects git conventions: feature-branch pushes
proceed without asking, but pushing a **default branch** requires explicit
approval.

Work is not "handed off" until changes are committed AND confirmed pushed.

## Arguments

Parse `$ARGUMENTS`:

- `--no-push`: do everything except the push (stop after commit). Use when the
  remote is unreachable or you want to review before pushing.
- `--no-gates`: skip the quality-gate phase (use only when no code changed).
- `--dry-run`: report what each phase *would* do; make no commits, no pushes, no
  issue-state changes.

## Phase 0 — Detect environment

Run once up front; every later phase keys off this.

```bash
pwd; git rev-parse --show-toplevel 2>/dev/null   # confirm repo root
git rev-parse --abbrev-ref HEAD                   # BRANCH
git status --porcelain                            # dirty?
test -d .beads && command -v bd >/dev/null && echo "BEADS=yes"
bd dolt status >/dev/null 2>&1 && echo "DOLT=yes" # only if BEADS=yes
```

Record: `BRANCH`, whether the tree is dirty, `BEADS`, `DOLT`, and whether
`BRANCH` is a default branch (`main`/`master`/`develop`/`trunk`).

If `pwd` is under a `.claude/worktrees/` path or otherwise ≠ toplevel, `cd` to
the toplevel before continuing (background agents can leave cwd drifted).

## Phase 1 — Capture remaining work as issues

Look at what is unfinished and make it durable so the next session can pick it
up. Sources to scan: uncommitted TODO/FIXME added this session
(`git diff` for new `TODO`/`FIXME`), partially-done work, and anything the user
flagged but didn't finish.

- **If BEADS:** create issues with `bd create` (short title, details in `-d`,
  set `-p` and `-l`). Do not invent work — only file genuinely-pending items.
  If a task is partially done, `bd update <id>` its status/notes rather than
  duplicating.
- **If no beads:** list the remaining items in the final summary and ask the
  user whether to record them anywhere (don't silently drop them).

In `--dry-run`, list the issues you *would* file instead of creating them.

## Phase 2 — Quality gates (skip if --no-gates or no code changed)

Only if code changed this session. Discover the project's gates rather than
assuming — check, in order, for the commands the repo actually uses:

- A `justfile` / `Makefile` (`just`, `make test`, `make lint`).
- Language defaults: Go (`go build ./... && go test ./... && go vet ./...`),
  Node (`npm test`/`pnpm test` + lint script in `package.json`), Nim
  (`nimble test`), Rust (`cargo build && cargo test && cargo clippy`).
- A `.github/workflows/` CI file — mirror what CI runs locally.

Run them. **Report results honestly**: if a gate fails, say so with the output
and do NOT proceed to commit/push as if clean — surface the failure and stop for
a decision. Never mark work done on compile-success alone when tests exist.

## Phase 3 — Update issue state

- **If BEADS:** close finished issues (`bd close <id> -r "..."`, batch multiple
  in one call), and update any still in-progress with current notes. Run
  `bd ready` afterward so the summary can show what's unblocked next.
- Confirm nothing you're about to commit is tracked by an issue you forgot to
  update.

## Phase 4 — Commit related changes

Stage and commit logically-grouped changes (per git conventions: group related
edits per commit, write a body explaining the *why*). Exclude unrelated drift
and local-only files (e.g. `settings.local.json`). Use a clear message and the
required co-author trailer.

In `--dry-run`, show the planned `git add` set and commit message; commit
nothing.

## Phase 5 — Preflight, then push

1. **Default-branch guard:** if `BRANCH` is a default branch, STOP and get
   explicit approval via AskUserQuestion before any push. Per git conventions,
   pushing to `main`/`master` is a confirm-first operation. (Some repos'
   CLAUDE.md mandate it — even then, confirm once.)
2. Invoke `/preflight --push` (Skill tool). If it returns
   `PREFLIGHT_RESULT=BLOCKED`, stop and surface the remedies — do not attempt
   the push.
3. Push, beads/dolt-aware. Run as **separate, individually-checked commands**
   (no compound `&&` chain that can mask a mid-step failure):

   ```bash
   git pull --rebase            # reconcile first
   # if DOLT: persist the beads task graph to its remote
   bd dolt push                 # only when DOLT=yes
   git push                     # push code
   git status -sb               # MUST show "up to date with origin/<branch>"
   ```

   If any step fails, resolve and retry until `git status` confirms up to date —
   do not report success on an unverified push. Skip entirely under
   `--no-push`/`--dry-run` (report what would run).

## Phase 6 — Cleanup (non-destructive by default)

- Report any stashes (`git stash list`); clearing them is destructive — only
  with explicit approval.
- Offer to prune stale remote-tracking branches (`git remote prune origin
  --dry-run` first; only prune after showing what it would remove).
- Note any leftover worktrees under `.claude/worktrees/`.

## Phase 7 — Handoff summary

Print a tight summary for the next session:

```
Handoff — <repo> @ <BRANCH>
  Done:        <commits this session, 1 line each>
  Gates:       <pass/fail per gate, or skipped>
  Pushed:      <SHA> → origin/<BRANCH>  (verified up to date)
  Issues:      closed [<ids>]; still open [<ids>]; newly ready [<ids>]
  Remaining:   <unfinished items / follow-ups filed>
  Next up:     <suggested starting point>
```

Only claim "Pushed … verified" if Phase 5 actually confirmed it. If anything
was skipped or failed, say so plainly here.
