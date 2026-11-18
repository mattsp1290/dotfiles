#!/bin/bash
# Pre-commit hook: runs the project's test suite before allowing git commit.
# Wired as a Claude Code PreToolUse hook on the Bash tool; this script itself
# filters for `git commit` so non-commit Bash calls pass straight through.
#
# Bypass: include `--no-verify` in the git commit command to skip the gate.

set -o pipefail

# Read hook input from stdin (PreToolUse protocol).
INPUT=$(cat)

# Extract the Bash command being run.
CMD=$(printf '%s' "$INPUT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)

# Honor an explicit bypass.
case "$CMD" in
  *"--no-verify"*) exit 0 ;;
esac

# Find the repository the commit targets, not the hook process's directory:
# a commit in another worktree (`git -C <dir> commit`, `cd <dir> && git commit`)
# would otherwise be gated on the session's primary checkout. Prints nothing
# when the command contains no git commit, which lets it straight through.
TARGET_DIR=$(printf '%s' "$INPUT" | python3 -c '
import json, os, shlex, sys
data = json.load(sys.stdin)
cwd = data.get("cwd") or os.getcwd()
lexer = shlex.shlex(data.get("tool_input", {}).get("command", ""), posix=True, punctuation_chars=True)
tokens = []
try:
    for tok in lexer:
        tokens.append(tok)
except ValueError:
    pass  # e.g. a heredoc message with an apostrophe; the tokens before it still count
for i, tok in enumerate(tokens):
    if tok == "cd" and i + 1 < len(tokens):
        cwd = os.path.join(cwd, os.path.expanduser(tokens[i + 1]))
    elif tok == "git" and tokens[i + 1:i + 2] == ["commit"]:
        print(cwd)
        break
    elif tok == "git" and tokens[i + 1:i + 2] == ["-C"] and tokens[i + 3:i + 4] == ["commit"]:
        print(os.path.join(cwd, os.path.expanduser(tokens[i + 2])))
        break
' 2>/dev/null)
[ -n "$TARGET_DIR" ] || exit 0
cd "$TARGET_DIR" 2>/dev/null || exit 0
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null) && cd "$TOPLEVEL"

# Detect project type and run tests. Order favors the languages used most.
run_tests() {
  if [ -f "go.mod" ]; then
    go test ./... 2>&1
  elif [ -f "Cargo.toml" ]; then
    cargo test --workspace 2>&1
  elif [ -f "package.json" ]; then
    # Use the Node version the project pins when nvm has it installed.
    for PIN_FILE in .node-version .nvmrc; do
      [ -f "$PIN_FILE" ] || continue
      PINNED_NODE="$HOME/.nvm/versions/node/v$(tr -d '[:space:]v' < "$PIN_FILE")/bin"
      [ -x "$PINNED_NODE/node" ] && PATH="$PINNED_NODE:$PATH"
      break
    done
    if [ -f "pnpm-lock.yaml" ]; then
      pnpm test 2>&1
    elif [ -f "yarn.lock" ]; then
      yarn test 2>&1
    else
      npm test 2>&1
    fi
  elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.cfg" ]; then
    pytest 2>&1
  elif ls ./*.nimble >/dev/null 2>&1; then
    nimble test 2>&1
  elif [ -f "Makefile" ] && grep -q '^test:' Makefile; then
    make test 2>&1
  else
    # No recognized test runner — allow the commit.
    return 0
  fi
}

TEST_OUTPUT=$(run_tests)
TEST_EXIT=$?

if [ $TEST_EXIT -eq 0 ]; then
  exit 0
else
  # Trim output to last 50 lines to avoid overwhelming the response.
  TRIMMED=$(echo "$TEST_OUTPUT" | tail -50)
  REASON="Tests failed — fix failures before committing (or add --no-verify to bypass).\n\n$TRIMMED"
  # Escape for JSON.
  REASON_JSON=$(printf '%s' "$REASON" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $REASON_JSON
  }
}
EOF
  exit 0
fi
