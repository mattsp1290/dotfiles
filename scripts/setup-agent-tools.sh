#!/bin/sh

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

install_opencode() {
  if ! command_exists opencode && [ ! -f "$HOME/.opencode/bin/opencode" ]; then
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
  fi
}

install_claude_code() {
  if ! command_exists claude && [ ! -f "$HOME/.local/bin/claude" ]; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi
}

install_codex() {
  if ! command_exists codex; then
    npm install -g @openai/codex
  fi
}

link_children() {
  source_dir="$1"
  target_dir="$2"

  [ -d "$source_dir" ] || return 0

  if [ -L "$target_dir" ]; then
    rm "$target_dir"
  fi

  mkdir -p "$target_dir"
  for child in "$source_dir"/*; do
    [ -e "$child" ] || continue
    child_name=$(basename "$child")
    target_path="$target_dir/$child_name"

    if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
      echo "Skipping $target_path because it already exists and is not a symlink." >&2
      continue
    fi

    ln -snf "$child" "$target_path"
  done
}

link_file() {
  source_path="$1"
  target_path="$2"

  [ -f "$source_path" ] || return 0

  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    echo "Skipping $target_path because it already exists and is not a symlink." >&2
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  ln -snf "$source_path" "$target_path"
}

link_claude_agent_config() {
  agent_root="${DOTFILES_AGENT_ROOT:-$HOME/git/dotfiles/.agents}"

  mkdir -p "$HOME/.claude"
  link_children "$agent_root/commands" "$HOME/.claude/commands"
  link_children "$agent_root/hooks" "$HOME/.claude/hooks"
  link_children "$agent_root/rules" "$HOME/.claude/rules"
  link_children "$agent_root/skills" "$HOME/.claude/skills"
}

link_codex_agent_config() {
  agent_root="${DOTFILES_AGENT_ROOT:-$HOME/git/dotfiles/.agents}"

  mkdir -p "$HOME/.codex"
  link_file "$agent_root/hooks/codex-hooks.json" "$HOME/.codex/hooks.json"
  link_children "$agent_root/commands" "$HOME/.codex/prompts"
  link_children "$agent_root/skills" "$HOME/.codex/skills"
  link_children "$agent_root/rules" "$HOME/.codex/rules"
}

setup_agent_tools() {
  install_claude_code
  install_codex
  link_claude_agent_config
  link_codex_agent_config
}
