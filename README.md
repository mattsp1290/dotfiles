# dotfiles
dotfiles, but competent this time.

## Agent tooling

This repo supports Claude Code and Codex during migration. Shared agent content lives in `.agents/`; setup scripts link it into `~/.agents`, `~/.claude`, and `~/.codex`.

Run `./setup.sh` on macOS or `./setup-linux.sh` on Linux to install and link the supported tools.

Both scripts include vanilla pstack 0.15.31, with all 57 core skills and the complete plugin source under `.agents/pstack/`.
Follow [Set up pstack](.agents/pstack.local.md) to link an existing machine, start poteto mode, and customize the local copy.
