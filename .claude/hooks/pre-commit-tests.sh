#!/bin/bash
# Pre-commit hook: runs the project's test suite before allowing git commit.
# Called by Claude Code as a PreToolUse hook on Bash(git commit).

set -o pipefail

# Read hook input from stdin (required by protocol)
INPUT=$(cat)

# Detect project type and run tests
run_tests() {
  if [ -f "Cargo.toml" ]; then
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
  elif [ -f "Makefile" ] && grep -q '^test:' Makefile; then
    make test 2>&1
  else
    # No test runner found — allow the commit
    return 0
  fi
}

TEST_OUTPUT=$(run_tests)
TEST_EXIT=$?

if [ $TEST_EXIT -eq 0 ]; then
  exit 0
else
  # Trim output to last 50 lines to avoid overwhelming the response
  TRIMMED=$(echo "$TEST_OUTPUT" | tail -50)
  REASON="Tests failed. Fix failures before committing.\n\n$TRIMMED"
  # Escape for JSON
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
