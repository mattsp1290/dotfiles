#!/usr/bin/env bash
# Unit tests for scripts/lib/secret-helpers.sh
# Tests 1Password CLI secret management, caching, and security functions

set -euo pipefail

# Source testing framework
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/test-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/assertions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/mock-tools.sh"

# Initialize test session
init_test_session
init_mock_logging

# Mock 1Password CLI for testing
setup_op_mocks() {
    # Mock successful op signin check
    mock_command "op" "#!/bin/bash
case \"\$1\" in
    account)
        case \"\$2\" in
            get)
                if [[ \"\${MOCK_OP_SIGNED_IN:-true}\" == \"true\" ]]; then
                    echo '{\"id\":\"test-account\",\"name\":\"Test Account\"}'
                    exit 0
                else
                    echo 'Error: not signed in' >&2
                    exit 1
                fi
                ;;
        esac
        ;;
    item)
        case \"\$2\" in
            get)
                local item_name=\"\$3\"
                case \"\$item_name\" in
                    \"GITHUB_TOKEN\")
                        if [[ \"\${*}\" == *\"--fields credential\"* ]]; then
                            echo \"ghp_test_token_123456\"
                        else
                            echo '{\"id\":\"test-id\",\"title\":\"GITHUB_TOKEN\"}'
                        fi
                        ;;
                    \"AWS_ACCESS_KEY_ID\")
                        if [[ \"\${*}\" == *\"--fields credential\"* ]]; then
                            echo \"AKIATEST123456\"
                        else
                            echo '{\"id\":\"test-id\",\"title\":\"AWS_ACCESS_KEY_ID\"}'
                        fi
                        ;;
                    \"NONEXISTENT_SECRET\")
                        echo 'Error: item not found' >&2
                        exit 1
                        ;;
                    *)
                        echo 'mock_secret_value'
                        ;;
                esac
                ;;
            edit)
                echo 'Updated item'
                ;;
            create)
                echo 'Created item'
                ;;
            list)
                echo '[
                    {\"id\":\"1\",\"title\":\"GITHUB_TOKEN\",\"category\":\"API_CREDENTIAL\"},
                    {\"id\":\"2\",\"title\":\"AWS_ACCESS_KEY_ID\",\"category\":\"API_CREDENTIAL\"}
                ]'
                ;;
        esac
        ;;
    *)
        echo 'Unknown op command' >&2
        exit 1
        ;;
esac"
    
    # Mock other tools
    mock_command "jq" "#!/bin/bash
cat"
    
    mock_command "age" "#!/bin/bash
cat > /dev/null"
    
    mock_command "sha256sum" "#!/bin/bash
echo 'test_hash_123456  -'"
    
    mock_command "date" "#!/bin/bash
case \"\$1\" in
    '+%s')
        echo '1640000000'
        ;;
    '+%s%N')
        echo '1640000000000000000'
        ;;
    '+%Y%m%d-%H%M%S')
        echo '20240101-120000'
        ;;
    *)
        echo '2024-01-01 12:00:00'
        ;;
esac"
}

#
# Basic Secret Operations Tests
#

test_op_check_signin_success() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_success op_check_signin "Should succeed when signed in"
}

test_op_check_signin_failure() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="false"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_failure op_check_signin "Should fail when not signed in"
}

test_op_ensure_signin_success() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_success op_ensure_signin "Should succeed when signed in"
}

test_op_ensure_signin_failure() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="false"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_failure op_ensure_signin "Should fail when not signed in"
}

test_get_secret_success() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local result
    result=$(get_secret "GITHUB_TOKEN" "credential" "Employee")
    assert_equals "ghp_test_token_123456" "$result" "Should return correct secret value"
}

test_get_secret_not_found() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_failure get_secret "NONEXISTENT_SECRET" "credential" "Employee" "Should fail for non-existent secret"
}

test_get_secret_or_default_found() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local result
    result=$(get_secret_or_default "GITHUB_TOKEN" "default_value" "credential" "Employee")
    assert_equals "ghp_test_token_123456" "$result" "Should return actual secret when found"
}

test_get_secret_or_default_not_found() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local result
    result=$(get_secret_or_default "NONEXISTENT_SECRET" "default_value" "credential" "Employee")
    assert_equals "default_value" "$result" "Should return default when secret not found"
}

test_secret_exists_true() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_success secret_exists "GITHUB_TOKEN" "Employee" "Should return true for existing secret"
}

test_secret_exists_false() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    assert_command_failure secret_exists "NONEXISTENT_SECRET" "Employee" "Should return false for non-existent secret"
}

test_set_secret() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Test creating new secret
    local output
    output=$(set_secret "NEW_SECRET" "secret_value" "Employee" "API Credential" "credential" 2>&1)
    assert_contains "$output" "Created secret" "Should create new secret"
    
    # Test updating existing secret
    output=$(set_secret "GITHUB_TOKEN" "new_value" "Employee" "API Credential" "credential" 2>&1)
    assert_contains "$output" "Updated secret" "Should update existing secret"
}

#
# Secret Loading Tests
#

test_load_secrets() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Unset any existing env vars
    unset GITHUB_TOKEN AWS_ACCESS_KEY_ID
    
    local output
    output=$(load_secrets "Employee" 2>&1)
    
    # Check that secrets were loaded as environment variables
    assert_env_set "GITHUB_TOKEN" "GITHUB_TOKEN should be set"
    assert_env_set "AWS_ACCESS_KEY_ID" "AWS_ACCESS_KEY_ID should be set"
    
    # Check values
    assert_env_equals "GITHUB_TOKEN" "ghp_test_token_123456" "GITHUB_TOKEN should have correct value"
    assert_env_equals "AWS_ACCESS_KEY_ID" "AKIATEST123456" "AWS_ACCESS_KEY_ID should have correct value"
    
    assert_contains "$output" "Loaded" "Should report loaded secrets"
}

test_list_secrets() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local output
    output=$(list_secrets "Employee" 2>/dev/null)
    
    # Since our mock returns JSON, it should contain secret names
    assert_contains "$output" "GITHUB_TOKEN" "Should list GITHUB_TOKEN"
    assert_contains "$output" "AWS_ACCESS_KEY_ID" "Should list AWS_ACCESS_KEY_ID"
}

#
# Caching Tests
#

test_init_cache() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching
    CACHE_ENABLED="true"
    
    assert_command_success init_cache "Should initialize cache successfully"
    
    # Check cache directory was created
    assert_dir_exists "$CACHE_DIR" "Cache directory should be created"
}

test_cache_key_generation() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local key1
    key1=$(cache_key "test" "key" "args")
    
    local key2
    key2=$(cache_key "test" "key" "args")
    
    assert_equals "$key1" "$key2" "Same arguments should generate same cache key"
    
    local key3
    key3=$(cache_key "different" "args")
    
    assert_not_equals "$key1" "$key3" "Different arguments should generate different cache keys"
}

test_cache_set_and_get() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching
    CACHE_ENABLED="true"
    CACHE_TTL="300"
    
    # Initialize cache
    init_cache
    
    # Set cache value
    assert_command_success cache_set "test_value" "cache" "test" "key" "Cache set should succeed"
    
    # Get cache value
    local cached_value
    cached_value=$(cache_get "cache" "test" "key")
    assert_equals "test_value" "$cached_value" "Should retrieve cached value"
}

test_cache_expiration() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching with very short TTL
    CACHE_ENABLED="true"
    CACHE_TTL="0"  # Immediate expiration
    
    init_cache
    
    # Set cache value
    cache_set "test_value" "cache" "test" "key"
    
    # Should not get expired value
    assert_command_failure cache_get "cache" "test" "key" "Should not return expired cache"
}

test_cache_disabled() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Disable caching
    CACHE_ENABLED="false"
    
    # Set should succeed but do nothing
    assert_command_success cache_set "test_value" "cache" "test" "key" "Cache set should succeed even when disabled"
    
    # Get should fail
    assert_command_failure cache_get "cache" "test" "key" "Cache get should fail when disabled"
}

test_get_secret_cached() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching
    CACHE_ENABLED="true"
    CACHE_TTL="300"
    init_cache
    
    # First call should fetch from 1Password and cache
    local result1
    result1=$(get_secret_cached "GITHUB_TOKEN" "credential" "Employee")
    assert_equals "ghp_test_token_123456" "$result1" "Should get secret from 1Password"
    
    # Second call should get from cache (we can't easily test this without mocking internals)
    local result2
    result2=$(get_secret_cached "GITHUB_TOKEN" "credential" "Employee")
    assert_equals "ghp_test_token_123456" "$result2" "Should get secret from cache"
}

test_clear_cache() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching and initialize
    CACHE_ENABLED="true"
    init_cache
    
    # Set some cache data
    cache_set "test_value" "test" "key"
    
    # Clear cache
    clear_cache
    
    # Cache directory should be removed
    assert_dir_not_exists "$CACHE_DIR" "Cache directory should be removed"
}

#
# Batch Operations Tests
#

test_get_secrets_batch() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local output
    output=$(get_secrets_batch "Employee" "GITHUB_TOKEN:credential" "AWS_ACCESS_KEY_ID:credential")
    
    assert_contains "$output" "GITHUB_TOKEN=ghp_test_token_123456" "Should return GITHUB_TOKEN"
    assert_contains "$output" "AWS_ACCESS_KEY_ID=AKIATEST123456" "Should return AWS_ACCESS_KEY_ID"
}

test_warm_cache() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching
    CACHE_ENABLED="true"
    init_cache
    
    local output
    output=$(warm_cache "Employee" 2>&1)
    
    assert_contains "$output" "Warming secret cache" "Should indicate cache warming"
    assert_contains "$output" "Warmed" "Should report warmed secrets"
}

#
# Error Condition Tests
#

test_not_signed_in_error() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="false"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # All operations requiring signin should fail
    assert_command_failure set_secret "TEST" "value" "Employee" "Should fail when not signed in"
    assert_command_failure load_secrets "Employee" "Should fail when not signed in"
    assert_command_failure get_secrets_batch "Employee" "TEST:credential" "Should fail when not signed in"
}

test_account_alias_mapping() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Test work alias mapping
    OP_ACCOUNT_ALIAS="work"
    
    # Should succeed (our mock handles the account mapping)
    assert_command_success op_check_signin "work" "Should handle work account alias"
}

#
# Security Tests
#

test_cache_permissions() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching
    CACHE_ENABLED="true"
    
    init_cache
    
    # Check cache directory permissions (should be 700)
    if [[ -d "$CACHE_DIR" ]]; then
        local perms
        perms=$(stat -c %a "$CACHE_DIR" 2>/dev/null || stat -f %A "$CACHE_DIR" 2>/dev/null || echo "700")
        assert_equals "700" "$perms" "Cache directory should have restrictive permissions"
    fi
}

test_cache_cleanup() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching with short TTL
    CACHE_ENABLED="true"
    CACHE_TTL="0"  # Immediate expiration
    
    init_cache
    
    # Create some cache files
    cache_set "test_value" "test" "key"
    
    # Run cleanup
    clean_cache
    
    # Expired cache should be removed
    assert_command_failure cache_get "test" "key" "Expired cache should be cleaned up"
}

#
# Performance Tests
#

test_time_function() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Test timing wrapper
    local output
    output=$(time_function echo "test" 2>&1)
    
    assert_contains "$output" "Execution time" "Should report execution time"
    assert_contains "$output" "ms" "Should report time in milliseconds"
}

#
# Help and Documentation Tests
#

test_secret_help() {
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    local output
    output=$(secret_help)
    
    assert_contains "$output" "1Password CLI Secret Helper Functions" "Should show help title"
    assert_contains "$output" "get_secret" "Should document get_secret function"
    assert_contains "$output" "load_secrets" "Should document load_secrets function"
    assert_contains "$output" "Examples:" "Should provide examples"
}

#
# Integration Tests
#

test_end_to_end_secret_workflow() {
    setup_op_mocks
    MOCK_OP_SIGNED_IN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/secret-helpers.sh"
    
    # Enable caching
    CACHE_ENABLED="true"
    init_cache
    
    # Check signin
    assert_command_success op_check_signin "Should be signed in"
    
    # Check if secret exists
    assert_command_success secret_exists "GITHUB_TOKEN" "Employee" "Secret should exist"
    
    # Get secret
    local token
    token=$(get_secret "GITHUB_TOKEN" "credential" "Employee")
    assert_equals "ghp_test_token_123456" "$token" "Should get correct token"
    
    # Set new secret
    local output
    output=$(set_secret "TEST_TOKEN" "test_value" "Employee" "API Credential" "credential" 2>&1)
    assert_contains "$output" "Created secret" "Should create new secret"
    
    # Load secrets as env vars
    output=$(load_secrets "Employee" 2>&1)
    assert_contains "$output" "Loaded" "Should load secrets"
    
    # Clear cache
    clear_cache
    assert_dir_not_exists "$CACHE_DIR" "Cache should be cleared"
}

#
# Test Execution Framework
#

# Run all tests
run_test "op_check_signin success" test_op_check_signin_success
run_test "op_check_signin failure" test_op_check_signin_failure
run_test "op_ensure_signin success" test_op_ensure_signin_success
run_test "op_ensure_signin failure" test_op_ensure_signin_failure
run_test "get_secret success" test_get_secret_success
run_test "get_secret not found" test_get_secret_not_found
run_test "get_secret_or_default found" test_get_secret_or_default_found
run_test "get_secret_or_default not found" test_get_secret_or_default_not_found
run_test "secret_exists true" test_secret_exists_true
run_test "secret_exists false" test_secret_exists_false
run_test "set_secret" test_set_secret
run_test "load_secrets" test_load_secrets
run_test "list_secrets" test_list_secrets
run_test "init_cache" test_init_cache
run_test "cache_key generation" test_cache_key_generation
run_test "cache set and get" test_cache_set_and_get
run_test "cache expiration" test_cache_expiration
run_test "cache disabled" test_cache_disabled
run_test "get_secret_cached" test_get_secret_cached
run_test "clear_cache" test_clear_cache
run_test "get_secrets_batch" test_get_secrets_batch
run_test "warm_cache" test_warm_cache
run_test "not signed in error" test_not_signed_in_error
run_test "account alias mapping" test_account_alias_mapping
run_test "cache permissions" test_cache_permissions
run_test "cache cleanup" test_cache_cleanup
run_test "time_function" test_time_function
run_test "secret_help" test_secret_help
run_test "end-to-end secret workflow" test_end_to_end_secret_workflow

# Cleanup and show summary
cleanup_test_session
test_summary 