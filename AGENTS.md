# Agent Configuration

This dotfiles repo supports both Claude Code and Codex during the migration.

## Source of Truth

- Put shared agent rules, skills, commands, and hooks under `.agents/`.
- Treat `.claude/` as the Claude compatibility tree while the migration is in progress.
- Do not put machine-local permission state in `.agents/`; keep that in tool-local files like `.claude/settings.local.json` or `~/.codex/config.toml`.

## Codex Notes

- Shared skills are linked into `~/.codex/skills/` by `scripts/setup-agent-tools.sh`.
- Shared rules are linked into `~/.codex/rules/` for reference, but this `AGENTS.md` is the Codex-active project guidance.
- When porting a Claude skill, remove or adapt Claude-only assumptions before relying on it from Codex: `Agent`, `Skill`, `AskUserQuestion`, `$ARGUMENTS`, `.claude/*` paths, and Claude hook JSON.

## Editing

- Update `.agents/` first for cross-agent behavior.
- Update `.claude/` only when preserving Claude compatibility requires a Claude-specific adapter.
- Keep Codex-specific behavior in Codex config or plugin files, not in Claude settings.
