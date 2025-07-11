#!/usr/bin/env bash
# Test script for secret injection system
# Run this to verify the system is working correctly

# Don't exit on error so we can see all test results
set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test directory
TEST_DIR=$(mktemp -d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        ((TESTS_FAILED++))
        # Show error for debugging
        if [[ "${DEBUG:-}" == "true" ]]; then
            echo "  Command: $test_command"
            eval "$test_command" 2>&1 | sed 's/^/  /'
        fi
    fi
}

# Header
echo "=== Secret Injection System Test Suite ==="
echo "Test directory: $TEST_DIR"
echo "Script directory: $SCRIPT_DIR"
echo

# Test 1: Check scripts exist
echo "Checking script files..."
run_test "inject-secrets.sh exists" "[[ -x $SCRIPT_DIR/scripts/inject-secrets.sh ]]"
run_test "load-secrets.sh exists" "[[ -x $SCRIPT_DIR/scripts/load-secrets.sh ]]"
run_test "inject-all.sh exists" "[[ -x $SCRIPT_DIR/scripts/inject-all.sh ]]"
run_test "validate-templates.sh exists" "[[ -x $SCRIPT_DIR/scripts/validate-templates.sh ]]"
run_test "diff-templates.sh exists" "[[ -x $SCRIPT_DIR/scripts/diff-templates.sh ]]"

# Test 2: Library files exist
echo -e "\nChecking library files..."
run_test "secret-helpers.sh exists" "[[ -f $SCRIPT_DIR/scripts/lib/secret-helpers.sh ]]"
run_test "template-engine.sh exists" "[[ -f $SCRIPT_DIR/scripts/lib/template-engine.sh ]]"

# Test 3: Create test templates
echo -e "\nCreating test templates..."
cat > "$TEST_DIR/test-env.tmpl" << 'EOF'
# Environment variable format test
token=${TEST_TOKEN}
key=${TEST_KEY}
EOF

cat > "$TEST_DIR/test-simple.tmpl" << 'EOF'
# Simple format test
token=$TEST_TOKEN
key=$TEST_KEY
EOF

cat > "$TEST_DIR/test-custom.tmpl" << 'EOF'
# Custom format test
token=%%TEST_TOKEN%%
key=%%TEST_KEY%%
EOF

# Test 4: Validate templates
echo -e "\nValidating templates..."
run_test "validate env template" "$SCRIPT_DIR/scripts/validate-templates.sh --no-check $TEST_DIR/test-env.tmpl"
run_test "validate simple template" "$SCRIPT_DIR/scripts/validate-templates.sh --no-check $TEST_DIR/test-simple.tmpl"
run_test "validate custom template" "$SCRIPT_DIR/scripts/validate-templates.sh --no-check $TEST_DIR/test-custom.tmpl"

# Test 5: Test template engine functions
echo -e "\n${YELLOW}Testing template engine functions...${NC}"

# Source the secret helpers first
if source "$SCRIPT_DIR/scripts/lib/secret-helpers.sh" 2>/dev/null; then
    echo "Loaded secret-helpers.sh"
else
    echo "Failed to load secret-helpers.sh"
fi

# Source the template engine
if source "$SCRIPT_DIR/scripts/lib/template-engine.sh" 2>/dev/null; then
    echo "Loaded template-engine.sh"
    
    # Test format detection
    test_content='token=${MY_TOKEN}'
    detected=$(detect_template_format "$test_content")
    run_test "detect env format" "[[ '$detected' == 'env' ]]"
    
    test_content='token=$MY_TOKEN'
    detected=$(detect_template_format "$test_content")
    run_test "detect env-simple format" "[[ '$detected' == 'env-simple' ]]"
    
    test_content='token=%%MY_TOKEN%%'
    detected=$(detect_template_format "$test_content")
    run_test "detect custom format" "[[ '$detected' == 'custom' ]]"
    
    # Test token extraction
    tokens=$(extract_tokens 'key=${API_KEY} token=${AUTH_TOKEN}' env)
    token_count=$(echo "$tokens" | wc -l | tr -d ' ')
    run_test "extract multiple tokens" "[[ $token_count -eq 2 ]]"
else
    echo "Failed to load template-engine.sh"
fi

# Test 6: Dry run test
echo -e "\n${YELLOW}Testing dry-run mode...${NC}"

# Create a template that doesn't need real secrets
cat > "$TEST_DIR/dry-run.tmpl" << 'EOF'
# This is a test
value=${FAKE_SECRET}
EOF

run_test "dry-run mode" "TEMPLATE_DRY_RUN=true $SCRIPT_DIR/scripts/inject-secrets.sh --dry-run $TEST_DIR/dry-run.tmpl"

# Test 7: Help commands
echo -e "\n${YELLOW}Testing help commands...${NC}"

run_test "inject-secrets help" "$SCRIPT_DIR/scripts/inject-secrets.sh --help"
run_test "load-secrets help" "$SCRIPT_DIR/scripts/load-secrets.sh --help"
run_test "inject-all help" "$SCRIPT_DIR/scripts/inject-all.sh --help"
run_test "validate-templates help" "$SCRIPT_DIR/scripts/validate-templates.sh --help"
run_test "diff-templates help" "$SCRIPT_DIR/scripts/diff-templates.sh --help"

# Summary
echo
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo
    echo "Run with DEBUG=true for more details"
else
    echo -e "${GREEN}All tests passed!${NC}"
fi

# Exit code
exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1) 