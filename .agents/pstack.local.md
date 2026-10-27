# Set up pstack

## Install on a new machine

Clone this repo into `~/git/dotfiles`. Run `./setup.sh` on macOS or
`./setup-linux.sh` on Linux. Both scripts call `scripts/setup-agent-tools.sh`.

The helper links `~/.agents/pstack` to this checkout's complete plugin source.
It also links the core skills into `~/.agents/skills`, `~/.claude/skills`, and
`~/.codex/skills`. The checked-in skill links are relative, so the repo can move
between machines without changing them.

## Link an existing installation

To update agent links without running package installers, run:

```sh
cd "$HOME/git/dotfiles"
. ./scripts/setup-agent-tools.sh
link_shared_agent_config && link_claude_agent_config && link_codex_agent_config
```

The helper preserves real files and directories at link destinations and
reports collisions. Resolve the reported collision, then rerun the command.
Repeated runs preserve unrelated content.

If `~/.agents` already points to this checkout's `.agents`, the helper leaves
the source directories intact. If it points to another checkout, the helper
stops before writing through it. Choose which dotfiles checkout owns that
machine's agent configuration before replacing an existing root link.

On a Datadog machine, use the Datadog dotfiles setup to retain work skills and
running program state. This personal copy is independent and needs no work
checkout or Datadog credentials.

## Start a task

Start a new agent session after installation. In Codex, select the imported
`pstack:poteto-help` or `pstack:poteto-mode` skill. For example:

```text
Use $pstack:poteto-mode to implement this feature and verify its behavior.
```

The local skill directory is `~/.agents/skills/poteto-mode`. This repo has no
legacy mode loader, so that link points directly to the upstream mode.

For Cursor's native plugin installation and model setup, follow the
[upstream setup guide](pstack/docs/guide/01-setup.md). For Claude Code's native
plugin installation, use the same guide and its
[Claude Code adapter](pstack/docs/harness/claude-code.md).
Avoid loading both a native plugin and these loose skill links in the same
tool if that creates duplicate commands.

The links expose skills and supporting files. They do not register native
plugin agents, configure model roles, or enable cloud agents and automations.
This upstream snapshot has no Codex adapter. Its Cursor tool names, model
defaults, and separate `cursor-team-kit` dependencies remain as shipped.
Use each tool's available capabilities when you run the skills.

## Customize the source

Edit files under `.agents/pstack/` and commit the changes in this repo.
Keep host-specific installation code in `scripts/setup-agent-tools.sh`.
Preserve the upstream license.

This import contains 199 files and 57 core skills from `cursor/plugins`
version 0.15.31, commit `e7fb9647db242b96206978d56e8aff4a68718088`.
The unmodified subtree has Git tree
`90127ceeb9778cddf67f685d4f3c0356625fa153`.
`pstack.upstream.json` records the file hashes, modes, and discovery links.
The three Benny automation skills remain in the plugin source and are not
global discovery links.

To check the imported tree and core skill count after staging, run:

```sh
git write-tree --prefix=.agents/pstack/
find .agents/pstack/skills -name SKILL.md | wc -l
```

Before importing a newer upstream version, review its diff against the pinned
commit. Merge local customizations and update `pstack.upstream.json` in the
same change. Setup does not update pstack automatically.
