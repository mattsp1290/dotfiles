# Shared Agent Configuration

`.agents/` is the shared source for agent behavior in this dotfiles repo.

## Layout

- `commands/` - user-invoked command definitions where supported.
- `hooks/` - reusable hook scripts.
- `rules/` - durable behavior rules and conventions.
- `skills/` - skill directories with `SKILL.md` instructions and related assets.
- `pstack/` - the complete vanilla pstack plugin, with core skills linked from `skills/`.

## Install Targets

`scripts/setup-agent-tools.sh` links this tree into tool-specific homes:

- Shared agent discovery: `~/.agents/skills`
- Complete pstack source: `~/.agents/pstack`
- Claude Code: `~/.claude/{commands,hooks,rules,skills}`
- Codex: `~/.codex/{hooks.json,prompts,rules,skills}`. Shared
  `.agents/commands/*.md` files are linked into `~/.codex/prompts` so they can
  be used as Codex custom slash prompts. `.agents/hooks/codex-hooks.json` is
  linked to `~/.codex/hooks.json` for global Codex hook behavior.

Claude keeps `settings.local.json` separate because it contains local permissions and hook trust state. Codex keeps `config.toml`, auth, and approval policy in `~/.codex`.

## Portability Rules

- Prefer relative paths inside a skill directory.
- Prefer repo-local output paths such as `reviews/` over `.claude/*`.
- Avoid tool-specific names unless the skill has an explicit Claude or Codex adapter section.
- Document any required external CLI in the skill description or prerequisites.

The imported `pstack/` tree retains upstream tool names and model assumptions.
Keep local setup glue outside that tree. See [Set up pstack](pstack.local.md) for installation and compatibility details.
