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
  source_dir=$(cd -P "$source_dir" && pwd) || return 1

  if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
    if [ -L "$target_dir" ] || [ ! -d "$target_dir" ]; then
      echo "Skipping $target_dir because it must be a real directory." >&2
      return 1
    fi
  else
    mkdir -p "$target_dir" || return 1
  fi

  for target_path in "$target_dir"/*; do
    [ -L "$target_path" ] || continue
    target_value=$(readlink "$target_path")
    case "$target_value" in
      /*) target_resolved="$target_value" ;;
      *) target_resolved="$(dirname "$target_path")/$target_value" ;;
    esac
    target_resolved=$(cd -P "$(dirname "$target_resolved")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$target_resolved")") || continue
    case "$target_resolved" in
      "$source_dir"/*)
        source_child=${target_resolved#"$source_dir"/}
        case "$source_child" in */*) continue ;; esac
        [ -e "$source_dir/$source_child" ] || rm "$target_path"
        ;;
    esac
  done

  result=0
  for child in "$source_dir"/*; do
    [ -e "$child" ] || continue
    child_name=$(basename "$child")
    target_path="$target_dir/$child_name"

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      if [ ! -L "$target_path" ]; then
        echo "Skipping $target_path because it already exists and is not a symlink." >&2
        result=1
        continue
      fi
      target_value=$(readlink "$target_path")
      case "$target_value" in
        /*) target_resolved="$target_value" ;;
        *) target_resolved="$(dirname "$target_path")/$target_value" ;;
      esac
      target_resolved=$(cd -P "$(dirname "$target_resolved")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$target_resolved")") || {
        echo "Skipping $target_path because its symlink target cannot be resolved." >&2
        result=1
        continue
      }
      case "$target_resolved" in
        "$source_dir"/*)
          source_child=${target_resolved#"$source_dir"/}
          case "$source_child" in */*)
            echo "Skipping $target_path because it is not an installer-owned direct-child link." >&2
            result=1
            continue
            ;;
          esac
          ;;
        *)
          echo "Skipping $target_path because it is a user-managed symlink." >&2
          result=1
          continue
          ;;
      esac
    fi

    ln -snf "$child" "$target_path" || result=1
  done
  return "$result"
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
  link_children "$agent_root/commands" "$HOME/.claude/commands" || return 1
  link_children "$agent_root/hooks" "$HOME/.claude/hooks" || return 1
  link_children "$agent_root/rules" "$HOME/.claude/rules" || return 1
  link_children "$agent_root/skills" "$HOME/.claude/skills" || return 1
}

link_shared_agent_config() {
  agent_root="${DOTFILES_AGENT_ROOT:-$HOME/git/dotfiles/.agents}"

  mkdir -p "$HOME/.agents"
  link_children "$agent_root/skills" "$HOME/.agents/skills" || return 1
}

link_codex_agent_config() {
  agent_root="${DOTFILES_AGENT_ROOT:-$HOME/git/dotfiles/.agents}"

  mkdir -p "$HOME/.codex"
  link_file "$agent_root/hooks/codex-hooks.json" "$HOME/.codex/hooks.json" || return 1
  link_children "$agent_root/commands" "$HOME/.codex/prompts" || return 1
  link_children "$agent_root/skills" "$HOME/.codex/skills" || return 1
  link_children "$agent_root/rules" "$HOME/.codex/rules" || return 1
}

setup_agent_tools() {
  install_claude_code
  install_codex
  link_shared_agent_config || return 1
  link_claude_agent_config || return 1
  link_codex_agent_config || return 1
}
