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

# Only gate actual git commits — let every other Bash call through untouched.
case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Honor an explicit bypass.
case "$CMD" in
  *"--no-verify"*) exit 0 ;;
esac

# Detect project type and run tests. Order favors the languages used most.
run_tests() {
  if [ -f "go.mod" ]; then
    go test ./... 2>&1
  elif [ -f "Cargo.toml" ]; then
    cargo test --workspace 2>&1
  elif [ -f "package.json" ]; then
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
