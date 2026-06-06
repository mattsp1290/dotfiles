---
name: preflight
description: >-
  Verify push/PR prerequisites BEFORE attempting a push or PR operation:
  confirms an origin remote exists, the working directory is the repo root,
  the GitHub token (gh CLI) is authenticated with the scopes the requested
  operation needs, and you actually have push access to the remote. Reports
  exactly what to run manually when a check fails, instead of stalling at the
  final push step. Use before /ship, before a manual push, or any time you
  want to confirm auth before doing remote work.
user-invocable: true
allowed-tools: Bash, AskUserQuestion
---

# Preflight Skill

A fast, read-only gate that catches the auth, token-scope, and remote-permission
problems that otherwise only surface at the final push/PR step — after the work
is already done. It changes nothing; it only checks and reports.

Run it standalone (`/preflight`) before a risky remote operation, or let `/ship`
and `/handoff` call it as their first phase.

## Arguments

Parse `$ARGUMENTS` for an optional intent flag. It widens or narrows which
scopes are required:

- `--push` (default): about to `git push` a branch.
- `--pr`: about to create or update a pull request (needs `repo` + `workflow`).
- `--release`: about to push tags / create a release (needs `repo`).

If no flag is given, assume `--push`.

## Checks

Run these in order. Each check prints a ✅/❌ line. Collect all failures; do not
abort on the first one — the point is a complete report.

### 1. Working directory is the repo root

```bash
pwd
git rev-parse --show-toplevel 2>/dev/null
```

If `pwd` ≠ toplevel, that's a ⚠️ (not fatal) — note that the caller may be in a
subdir or a worktree. If `git rev-parse` fails entirely, ❌ "Not inside a git
repository" and stop (nothing else is meaningful).

### 2. Origin remote exists

```bash
git remote get-url origin 2>/dev/null
```

- ❌ if missing: "No `origin` remote — push target unknown. Add one with
  `git remote add origin <url>`."
- If present, note whether it's an SSH (`git@…`) or HTTPS (`https://…`) URL —
  it determines which auth matters in check 4.

### 3. Branch / base sanity

```bash
git rev-parse --abbrev-ref HEAD
```

- If on a default branch (`main`, `master`, `develop`, `trunk`) and intent is
  `--push`, emit ⚠️: "On a default branch — per git conventions, pushing here
  needs explicit approval." (Do not block; just flag.)
- Report ahead/behind vs upstream if an upstream is set:
  `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null` then
  `git status -sb | head -1`.

### 4. GitHub auth + token scopes (only if origin is a GitHub remote)

Skip this whole section if origin is not a GitHub URL (e.g. self-hosted GitLab,
Dolt-only repos). Say so explicitly.

```bash
gh auth status 2>&1
```

- ❌ if `gh` is not installed or not logged in. Tell the user:
  `gh auth login` (and for fine-grained needs, `gh auth refresh -s repo,workflow`).
- Parse the reported **Token scopes** line. For the active intent, the required
  scopes are:
  - `--push`: `repo`
  - `--pr`: `repo`, `workflow`
  - `--release`: `repo`
- For each missing scope, ❌ with the exact remedy:
  `gh auth refresh -s <scope>`.

### 5. Actual push access to the remote

A token can be authenticated yet lack write access to *this* repo. Verify
permission rather than assuming it:

```bash
# Preferred: ask GitHub directly for your permission level.
gh repo view --json viewerPermission -q .viewerPermission 2>/dev/null
```

- `ADMIN` / `WRITE` / `MAINTAIN` → ✅ push access.
- `READ` / `TRIAGE` / empty → ❌ "Token authenticates but lacks write access to
  this repo. You'll need a fork + PR, or write access granted."
- If `gh repo view` is unavailable (non-GitHub remote), fall back to a dry run:

```bash
git push --dry-run --no-verify 2>&1 | head -20
```

  Treat a clean dry run as ✅ and an auth/permission error in the output as ❌.
  (The dry run contacts the remote but writes nothing.)

## Output

Print a compact report:

```
Preflight (<intent>):
  ✅ repo root
  ✅ origin: git@github.com:owner/repo.git (SSH)
  ⚠️  on branch main — default-branch push needs approval
  ✅ gh authenticated, scopes: repo, workflow
  ✅ push access: WRITE

Result: READY  (or)  Result: BLOCKED — <n> issue(s), see remedies above
```

If `BLOCKED`, list each remedy as a copy-pasteable command. Do **not** attempt
the push/PR yourself — preflight only reports. The caller decides whether to
proceed (and for default-branch pushes, must get explicit user approval first).

## Notes for skill-to-skill use

When invoked from another skill (e.g. `/ship`, `/handoff`), return a clear
machine-readable last line: `PREFLIGHT_RESULT=READY` or
`PREFLIGHT_RESULT=BLOCKED` so the caller can branch on it.
