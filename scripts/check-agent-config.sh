#!/bin/sh

set -u

ROOT="${1:-$HOME/git/dotfiles}"
AGENT_ROOT="$ROOT/.agents"
FAILED=0

check_dir() {
  if [ -d "$1" ]; then
    echo "ok: $1"
  else
    echo "missing: $1" >&2
    FAILED=1
  fi
}

check_command() {
  if command -v "$1" > /dev/null 2>&1; then
    echo "ok: $1 ($(command -v "$1"))"
  else
    echo "missing command: $1" >&2
    FAILED=1
  fi
}

check_skill_frontmatter() {
  for skill in "$AGENT_ROOT"/skills/*/SKILL.md; do
    [ -e "$skill" ] || continue

    if ! sed -n '1,8p' "$skill" | grep -q '^name:'; then
      echo "missing skill name: $skill" >&2
      FAILED=1
    fi

    if ! sed -n '1,8p' "$skill" | grep -q '^description:'; then
      echo "missing skill description: $skill" >&2
      FAILED=1
    fi
  done
}

check_dir "$AGENT_ROOT"
check_dir "$AGENT_ROOT/commands"
check_dir "$AGENT_ROOT/hooks"
check_dir "$AGENT_ROOT/rules"
check_dir "$AGENT_ROOT/skills"
check_command claude
check_command codex
check_skill_frontmatter

if [ "$FAILED" -eq 0 ]; then
  echo "Agent config looks valid."
else
  echo "Agent config has problems." >&2
fi

exit "$FAILED"
