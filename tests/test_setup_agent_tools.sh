#!/bin/sh
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_link() { [ -L "$1" ] || fail "missing link $1"; [ "$(readlink "$1")" = "$2" ] || fail "wrong target $1"; }
root="$tmp/source/.agents"
mkdir -p "$root/commands" "$root/hooks" "$root/skills" "$root/rules" "$tmp/external"
root=$(cd "$root" && pwd -P)
touch "$root/rules/beans.md" "$root/skills/example"
HOME="$tmp/home" DOTFILES_AGENT_ROOT="$root"; export HOME DOTFILES_AGENT_ROOT
. ./scripts/setup-agent-tools.sh
install_claude_code() { :; }
install_codex() { :; }
mkdir -p "$HOME/.claude/rules" "$HOME/.codex/rules"
mkdir -p "$HOME/.claude/skills" "$HOME/.codex/skills"
ln -s "$root/rules/beads.md" "$HOME/.claude/rules/beads.md"
ln -s "$root/rules/beads.md" "$HOME/.codex/rules/beads.md"
ln -s "$tmp/external/keep" "$HOME/.claude/rules/external"
ln -s "$tmp/external/keep" "$HOME/.codex/rules/external"
touch "$HOME/.claude/rules/sentinel" "$HOME/.codex/rules/sentinel"
ln -s "$tmp/external/keep" "$HOME/.claude/skills/external"
ln -s "$tmp/external/keep" "$HOME/.codex/skills/external"
setup_agent_tools
setup_agent_tools
assert_link "$HOME/.claude/rules/beans.md" "$root/rules/beans.md"
assert_link "$HOME/.codex/rules/beans.md" "$root/rules/beans.md"
[ ! -e "$HOME/.claude/rules/beads.md" ] && [ ! -L "$HOME/.claude/rules/beads.md" ] || fail stale-claude
[ ! -e "$HOME/.codex/rules/beads.md" ] && [ ! -L "$HOME/.codex/rules/beads.md" ] || fail stale-codex
[ -L "$HOME/.claude/rules/external" ] && [ -f "$HOME/.claude/rules/sentinel" ] || fail claude-sentinels
[ -L "$HOME/.codex/rules/external" ] && [ -f "$HOME/.codex/rules/sentinel" ] || fail codex-sentinels
[ -L "$HOME/.claude/skills/external" ] && [ -L "$HOME/.codex/skills/external" ] || fail unrelated-links
rm "$HOME/.claude/rules/beans.md" "$HOME/.codex/rules/beans.md"
ln -s "$tmp/external/keep" "$HOME/.claude/rules/beans.md"
ln -s "$tmp/external/keep" "$HOME/.codex/rules/beans.md"
if setup_agent_tools 2>"$tmp/collision.err"; then fail collision-accepted; fi
grep -q user-managed "$tmp/collision.err" || fail collision-warning
assert_link "$HOME/.claude/rules/beans.md" "$tmp/external/keep"
assert_link "$HOME/.codex/rules/beans.md" "$tmp/external/keep"
rm "$HOME/.claude/rules/beans.md" "$HOME/.codex/rules/beans.md"
rm -rf "$HOME/.claude/rules" "$HOME/.codex/rules"
ln -s "$tmp/external" "$HOME/.claude/rules"
touch "$HOME/.codex/rules"
if setup_agent_tools 2>"$tmp/directory.err"; then fail directory-collision-accepted; fi
grep -q 'must be a real directory' "$tmp/directory.err" || fail directory-warning
[ -L "$HOME/.claude/rules" ] && [ -f "$HOME/.codex/rules" ] || fail directory-mutated
