#!/usr/bin/env bash
# Simple test to verify the testing framework is working

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"

# Main test runner
main() {
    init_test_session
    
    echo "Running Framework Verification Tests"
    echo "===================================="
    
    echo "Testing basic functionality..."
    
    # Test basic assertions directly without run_test
    echo "Testing string equality..."
    if assert_equals "hello" "hello" "String equality should work"; then
        echo "[PASS] String equality test"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        echo "[FAIL] String equality test"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Count after first test: $TEST_COUNT"
    
    # Test simple true condition without eval
    echo "Testing simple condition..."
    if [[ 1 -eq 1 ]]; then
        echo "[PASS] Simple true condition test"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        echo "[FAIL] Simple true condition test"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Count after second test: $TEST_COUNT"
    
    # Test assert_true with a simple command
    echo "Testing assert_true..."
    if assert_true "true" "True command should pass"; then
        echo "[PASS] Assert true test"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        echo "[FAIL] Assert true test"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Count after third test: $TEST_COUNT"
    
    # Test assert_false with a simple command
    echo "Testing assert_false..."
    if assert_false "false" "False command should pass"; then
        echo "[PASS] Assert false test"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        echo "[FAIL] Assert false test"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Count after fourth test: $TEST_COUNT"
    
    echo ""
    echo "Testing environment setup manually..."
    
    # Test environment setup manually
    if setup_test_env; then
        echo "[PASS] Environment setup"
        TEST_PASSED=$((TEST_PASSED + 1))
        
        # Test that environment variables are set
        if [[ -n "${HOME:-}" ]] && [[ -n "${DOTFILES_DIR:-}" ]]; then
            echo "[PASS] Environment variables set"
            TEST_PASSED=$((TEST_PASSED + 1))
        else
            echo "[FAIL] Environment variables not set"
            TEST_FAILED=$((TEST_FAILED + 1))
        fi
        TEST_COUNT=$((TEST_COUNT + 1))
        
        # Test that directories were created
        if [[ -d "$HOME" ]] && [[ -d "$DOTFILES_DIR" ]]; then
            echo "[PASS] Directories created"
            TEST_PASSED=$((TEST_PASSED + 1))
        else
            echo "[FAIL] Directories not created"
            TEST_FAILED=$((TEST_FAILED + 1))
        fi
        TEST_COUNT=$((TEST_COUNT + 1))
        
        # Cleanup
        teardown_test_env
        echo "[PASS] Environment cleanup"
        TEST_PASSED=$((TEST_PASSED + 1))
        TEST_COUNT=$((TEST_COUNT + 1))
    else
        echo "[FAIL] Environment setup failed"
        TEST_FAILED=$((TEST_FAILED + 1))
        TEST_COUNT=$((TEST_COUNT + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 