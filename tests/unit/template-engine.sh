#!/usr/bin/env bash
# Unit tests for scripts/lib/template-engine.sh
# Tests template processing, secret injection, and format detection

set -euo pipefail

# Source testing framework
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/test-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/assertions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/mock-tools.sh"

# Initialize test session
init_test_session
init_mock_logging

# Setup template test environment
setup_template_test_env() {
    # Mock secret functions
    get_secret() {
        local secret_name="$1"
        case "$secret_name" in
            "GITHUB_TOKEN") echo "ghp_test_token_123456" ;;
            "AWS_ACCESS_KEY_ID") echo "AKIATEST123456" ;;
            "DATABASE_PASSWORD") echo "super_secret_password" ;;
            "API_KEY") echo "test_api_key_value" ;;
            *) return 1 ;;
        esac
    }
    
    get_secret_cached() {
        get_secret "$@"
    }
    
    # Export mock functions
    export -f get_secret get_secret_cached
    
    # Mock external tools
    mock_command "file" "#!/bin/bash
if [[ \"\$*\" == *\"--mime-encoding\"* ]]; then
    echo 'text/plain; charset=utf-8'
else
    echo 'ASCII text'
fi"
    
    mock_command "mktemp" "#!/bin/bash
if [[ \"\$1\" == *.* ]]; then
    echo \"\$1.tmp\$\$\"
else
    echo \"$TEST_TEMP_DIR/tmp.\$\$\"
fi"
    
    # Create test template files
    mkdir -p "$TEST_TEMP_DIR/templates"
}

#
# Format Detection Tests
#

test_detect_template_format_env() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}'
    local result
    result=$(detect_template_format "$content")
    
    assert_equals "env" "$result" "Should detect env format"
}

test_detect_template_format_env_simple() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=$GITHUB_TOKEN'
    local result
    result=$(detect_template_format "$content")
    
    assert_equals "env-simple" "$result" "Should detect env-simple format"
}

test_detect_template_format_go() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='token: {{ op://Employee/GITHUB_TOKEN/credential }}'
    local result
    result=$(detect_template_format "$content")
    
    assert_equals "go" "$result" "Should detect go format"
}

test_detect_template_format_custom() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='api_key = %%API_KEY%%'
    local result
    result=$(detect_template_format "$content")
    
    assert_equals "custom" "$result" "Should detect custom format"
}

test_detect_template_format_double_brace() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='password: {{DATABASE_PASSWORD}}'
    local result
    result=$(detect_template_format "$content")
    
    assert_equals "double-brace" "$result" "Should detect double-brace format"
}

test_detect_template_format_none() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='This is just plain text with no templates'
    local result
    result=$(detect_template_format "$content")
    
    assert_equals "" "$result" "Should return empty for no template format"
}

#
# Token Extraction Tests
#

test_extract_tokens_env() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}
export AWS_KEY=${AWS_ACCESS_KEY_ID}'
    
    local tokens
    tokens=$(extract_tokens "$content" "env")
    
    assert_contains "$tokens" "GITHUB_TOKEN" "Should extract GITHUB_TOKEN"
    assert_contains "$tokens" "AWS_ACCESS_KEY_ID" "Should extract AWS_ACCESS_KEY_ID"
}

test_extract_tokens_env_simple() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=$GITHUB_TOKEN
export AWS_KEY=$AWS_ACCESS_KEY_ID'
    
    local tokens
    tokens=$(extract_tokens "$content" "env-simple")
    
    assert_contains "$tokens" "GITHUB_TOKEN" "Should extract GITHUB_TOKEN"
    assert_contains "$tokens" "AWS_ACCESS_KEY_ID" "Should extract AWS_ACCESS_KEY_ID"
}

test_extract_tokens_go() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='token: {{ op://Employee/GITHUB_TOKEN/credential }}
key: {{ op://Employee/AWS_ACCESS_KEY_ID/password }}'
    
    local tokens
    tokens=$(extract_tokens "$content" "go")
    
    assert_contains "$tokens" "GITHUB_TOKEN" "Should extract GITHUB_TOKEN"
    assert_contains "$tokens" "AWS_ACCESS_KEY_ID" "Should extract AWS_ACCESS_KEY_ID"
}

test_extract_tokens_custom() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='api_key = %%API_KEY%%
password = %%DATABASE_PASSWORD%%'
    
    local tokens
    tokens=$(extract_tokens "$content" "custom")
    
    assert_contains "$tokens" "API_KEY" "Should extract API_KEY"
    assert_contains "$tokens" "DATABASE_PASSWORD" "Should extract DATABASE_PASSWORD"
}

test_extract_tokens_double_brace() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='password: {{DATABASE_PASSWORD}}
api_key: {{API_KEY}}'
    
    local tokens
    tokens=$(extract_tokens "$content" "double-brace")
    
    assert_contains "$tokens" "DATABASE_PASSWORD" "Should extract DATABASE_PASSWORD"
    assert_contains "$tokens" "API_KEY" "Should extract API_KEY"
}

test_extract_tokens_duplicates() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='${GITHUB_TOKEN} and ${GITHUB_TOKEN} again'
    
    local tokens
    tokens=$(extract_tokens "$content" "env")
    
    # Should only appear once (sort -u removes duplicates)
    local token_count
    token_count=$(echo "$tokens" | grep -c "GITHUB_TOKEN")
    assert_equals "1" "$token_count" "Should remove duplicate tokens"
}

test_extract_tokens_no_tokens() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='This is plain text with no tokens'
    
    local tokens
    tokens=$(extract_tokens "$content" "env")
    
    assert_equals "" "$tokens" "Should return empty for no tokens"
}

#
# Token Replacement Tests
#

test_replace_token_env() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}'
    local result
    result=$(replace_token "$content" "GITHUB_TOKEN" "secret_value" "env")
    
    assert_equals 'export GITHUB_TOKEN=secret_value' "$result" "Should replace env token"
}

test_replace_token_env_simple() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=$GITHUB_TOKEN'
    local result
    result=$(replace_token "$content" "GITHUB_TOKEN" "secret_value" "env-simple")
    
    assert_equals 'export GITHUB_TOKEN=secret_value' "$result" "Should replace env-simple token"
}

test_replace_token_go() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='token: {{ op://Employee/GITHUB_TOKEN/credential }}'
    local result
    result=$(replace_token "$content" "GITHUB_TOKEN" "secret_value" "go")
    
    assert_equals 'token: secret_value' "$result" "Should replace go template token"
}

test_replace_token_custom() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='api_key = %%API_KEY%%'
    local result
    result=$(replace_token "$content" "API_KEY" "secret_value" "custom")
    
    assert_equals 'api_key = secret_value' "$result" "Should replace custom token"
}

test_replace_token_double_brace() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='password: {{DATABASE_PASSWORD}}'
    local result
    result=$(replace_token "$content" "DATABASE_PASSWORD" "secret_value" "double-brace")
    
    assert_equals 'password: secret_value' "$result" "Should replace double-brace token"
}

test_replace_token_multiple() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='${GITHUB_TOKEN} and ${GITHUB_TOKEN} again'
    local result
    result=$(replace_token "$content" "GITHUB_TOKEN" "secret_value" "env")
    
    assert_equals 'secret_value and secret_value again' "$result" "Should replace multiple occurrences"
}

#
# Secret Value Retrieval Tests
#

test_get_secret_value_simple() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local result
    result=$(get_secret_value "GITHUB_TOKEN")
    
    assert_equals "ghp_test_token_123456" "$result" "Should retrieve simple secret"
}

test_get_secret_value_with_field() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local result
    result=$(get_secret_value "GITHUB_TOKEN:password")
    
    assert_equals "ghp_test_token_123456" "$result" "Should handle field specification"
}

test_get_secret_value_not_found() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    assert_command_failure get_secret_value "NONEXISTENT_SECRET" "Should fail for non-existent secret"
}

#
# Template Processing Tests
#

test_process_template_env() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}
export AWS_KEY=${AWS_ACCESS_KEY_ID}'
    
    local result
    result=$(process_template "$content" "env")
    
    assert_contains "$result" "ghp_test_token_123456" "Should replace GITHUB_TOKEN"
    assert_contains "$result" "AKIATEST123456" "Should replace AWS_ACCESS_KEY_ID"
}

test_process_template_auto_detect() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}'
    
    local result
    result=$(process_template "$content" "auto")
    
    assert_contains "$result" "ghp_test_token_123456" "Should auto-detect and replace"
}

test_process_template_missing_secret() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export TOKEN=${NONEXISTENT_SECRET}'
    
    assert_command_failure process_template "$content" "env" "Employee" "false" "Should fail for missing secret"
}

test_process_template_missing_ok() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export TOKEN=${NONEXISTENT_SECRET}
export GITHUB_TOKEN=${GITHUB_TOKEN}'
    
    local result
    result=$(process_template "$content" "env" "Employee" "true")
    
    assert_contains "$result" "ghp_test_token_123456" "Should replace available secrets"
    assert_contains "$result" "NONEXISTENT_SECRET" "Should leave missing secrets unchanged"
}

test_process_template_no_tokens() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='This is plain text with no templates'
    
    local result
    result=$(process_template "$content" "env")
    
    assert_equals "$content" "$result" "Should return unchanged content"
}

#
# Template File Processing Tests
#

test_process_template_file_basic() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create test template file
    local template_file="$TEST_TEMP_DIR/test.template"
    echo 'export GITHUB_TOKEN=${GITHUB_TOKEN}' > "$template_file"
    
    local result
    result=$(process_template_file "$template_file")
    
    assert_contains "$result" "ghp_test_token_123456" "Should process file template"
}

test_process_template_file_output() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create test template file
    local template_file="$TEST_TEMP_DIR/test.template"
    local output_file="$TEST_TEMP_DIR/test.output"
    echo 'export GITHUB_TOKEN=${GITHUB_TOKEN}' > "$template_file"
    
    process_template_file "$template_file" "$output_file"
    
    assert_file_exists "$output_file" "Should create output file"
    assert_file_contains "$output_file" "ghp_test_token_123456" "Output file should contain processed content"
}

test_process_template_file_not_found() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    assert_command_failure process_template_file "/nonexistent/file.template" "Should fail for non-existent file"
}

test_process_template_file_binary() {
    setup_template_test_env
    
    # Mock file command to return binary
    mock_command "file" "#!/bin/bash
echo 'application/octet-stream; charset=binary'"
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create binary-like file
    local binary_file="$TEST_TEMP_DIR/binary.file"
    echo -e '\x00\x01\x02\x03' > "$binary_file"
    
    assert_command_failure process_template_file "$binary_file" "Should fail for binary files"
}

test_process_template_file_permissions() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create test files
    local template_file="$TEST_TEMP_DIR/test.template"
    local output_file="$TEST_TEMP_DIR/test.output"
    echo 'export GITHUB_TOKEN=${GITHUB_TOKEN}' > "$template_file"
    echo 'old content' > "$output_file"
    chmod 644 "$output_file"
    
    process_template_file "$template_file" "$output_file"
    
    # Check permissions are preserved
    local perms
    perms=$(stat -c %a "$output_file" 2>/dev/null || stat -f %A "$output_file" 2>/dev/null || echo "644")
    assert_equals "644" "$perms" "Should preserve file permissions"
}

#
# Template Validation Tests
#

test_validate_template_valid() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create test template file
    local template_file="$TEST_TEMP_DIR/test.template"
    echo 'export GITHUB_TOKEN=${GITHUB_TOKEN}' > "$template_file"
    
    local output
    output=$(validate_template "$template_file")
    
    assert_contains "$output" "Template format: env" "Should identify template format"
    assert_contains "$output" "GITHUB_TOKEN" "Should list tokens"
}

test_validate_template_no_tokens() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create plain text file
    local template_file="$TEST_TEMP_DIR/plain.txt"
    echo 'This is plain text' > "$template_file"
    
    local output
    output=$(validate_template "$template_file")
    
    assert_contains "$output" "No template tokens" "Should report no tokens"
}

test_validate_template_not_found() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    assert_command_failure validate_template "/nonexistent/file.template" "Should fail for non-existent file"
}

#
# Template Diff Tests
#

test_diff_template() {
    setup_template_test_env
    
    # Mock diff command
    mock_command "diff" "#!/bin/bash
echo '--- \$1'
echo '+++ \$2'
echo '@@ -1 +1 @@'
echo '-export GITHUB_TOKEN=\${GITHUB_TOKEN}'
echo '+export GITHUB_TOKEN=ghp_test_token_123456'"
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create test template file
    local template_file="$TEST_TEMP_DIR/test.template"
    echo 'export GITHUB_TOKEN=${GITHUB_TOKEN}' > "$template_file"
    
    local output
    output=$(diff_template "$template_file")
    
    assert_contains "$output" "ghp_test_token_123456" "Should show diff with processed content"
}

#
# Dry Run Tests
#

test_dry_run_mode() {
    setup_template_test_env
    
    TEMPLATE_DRY_RUN="true"
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}'
    
    local output
    output=$(process_template "$content" "env" 2>&1)
    
    assert_contains "$output" "DRY RUN" "Should indicate dry run mode"
    assert_contains "$output" "Would replace" "Should show what would be replaced"
}

#
# Debug Mode Tests
#

test_debug_mode() {
    setup_template_test_env
    
    TEMPLATE_DEBUG="true"
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}'
    
    local output
    output=$(process_template "$content" "auto" 2>&1)
    
    assert_contains "$output" "[DEBUG]" "Should show debug output"
}

#
# Error Condition Tests
#

test_invalid_format() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}'
    
    assert_command_failure extract_tokens "$content" "invalid_format" "Should fail for invalid format"
}

test_failed_secret_retrieval() {
    setup_template_test_env
    
    # Override get_secret to always fail
    get_secret() {
        return 1
    }
    get_secret_cached() {
        return 1
    }
    export -f get_secret get_secret_cached
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local content='export TOKEN=${SOME_SECRET}'
    
    assert_command_failure process_template "$content" "env" "Should fail when secret retrieval fails"
}

#
# Help and Documentation Tests
#

test_template_help() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    local output
    output=$(template_help)
    
    assert_contains "$output" "Template Engine for Secret Injection" "Should show help title"
    assert_contains "$output" "Supported template formats" "Should document formats"
    assert_contains "$output" "Functions:" "Should list functions"
    assert_contains "$output" "Examples:" "Should provide examples"
}

#
# Integration Tests
#

test_end_to_end_template_processing() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Create comprehensive template
    local template_file="$TEST_TEMP_DIR/comprehensive.template"
    cat > "$template_file" << 'EOF'
# Configuration file
github_token = ${GITHUB_TOKEN}
aws_access_key = ${AWS_ACCESS_KEY_ID}
database_password = ${DATABASE_PASSWORD}
api_key = ${API_KEY}
EOF
    
    # Validate template
    local validation
    validation=$(validate_template "$template_file")
    assert_contains "$validation" "Template format: env" "Should validate successfully"
    
    # Process template
    local output_file="$TEST_TEMP_DIR/comprehensive.conf"
    process_template_file "$template_file" "$output_file"
    
    # Verify output
    assert_file_exists "$output_file" "Should create output file"
    assert_file_contains "$output_file" "ghp_test_token_123456" "Should contain GitHub token"
    assert_file_contains "$output_file" "AKIATEST123456" "Should contain AWS key"
    assert_file_contains "$output_file" "super_secret_password" "Should contain DB password"
    assert_file_contains "$output_file" "test_api_key_value" "Should contain API key"
    
    # Test diff functionality
    local diff_output
    diff_output=$(diff_template "$template_file" 2>/dev/null || true)
    assert_true "[[ -n '$diff_output' ]]" "Should generate diff output"
}

test_mixed_format_detection() {
    setup_template_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/template-engine.sh"
    
    # Template with multiple formats (should detect first one)
    local content='export GITHUB_TOKEN=${GITHUB_TOKEN}
api_key: {{API_KEY}}'
    
    local format
    format=$(detect_template_format "$content")
    
    assert_equals "env" "$format" "Should detect first format found"
}

#
# Test Execution Framework
#

# Run all tests
run_test "detect_template_format env" test_detect_template_format_env
run_test "detect_template_format env-simple" test_detect_template_format_env_simple
run_test "detect_template_format go" test_detect_template_format_go
run_test "detect_template_format custom" test_detect_template_format_custom
run_test "detect_template_format double-brace" test_detect_template_format_double_brace
run_test "detect_template_format none" test_detect_template_format_none
run_test "extract_tokens env" test_extract_tokens_env
run_test "extract_tokens env-simple" test_extract_tokens_env_simple
run_test "extract_tokens go" test_extract_tokens_go
run_test "extract_tokens custom" test_extract_tokens_custom
run_test "extract_tokens double-brace" test_extract_tokens_double_brace
run_test "extract_tokens duplicates" test_extract_tokens_duplicates
run_test "extract_tokens no tokens" test_extract_tokens_no_tokens
run_test "replace_token env" test_replace_token_env
run_test "replace_token env-simple" test_replace_token_env_simple
run_test "replace_token go" test_replace_token_go
run_test "replace_token custom" test_replace_token_custom
run_test "replace_token double-brace" test_replace_token_double_brace
run_test "replace_token multiple" test_replace_token_multiple
run_test "get_secret_value simple" test_get_secret_value_simple
run_test "get_secret_value with field" test_get_secret_value_with_field
run_test "get_secret_value not found" test_get_secret_value_not_found
run_test "process_template env" test_process_template_env
run_test "process_template auto detect" test_process_template_auto_detect
run_test "process_template missing secret" test_process_template_missing_secret
run_test "process_template missing ok" test_process_template_missing_ok
run_test "process_template no tokens" test_process_template_no_tokens
run_test "process_template_file basic" test_process_template_file_basic
run_test "process_template_file output" test_process_template_file_output
run_test "process_template_file not found" test_process_template_file_not_found
run_test "process_template_file binary" test_process_template_file_binary
run_test "process_template_file permissions" test_process_template_file_permissions
run_test "validate_template valid" test_validate_template_valid
run_test "validate_template no tokens" test_validate_template_no_tokens
run_test "validate_template not found" test_validate_template_not_found
run_test "diff_template" test_diff_template
run_test "dry run mode" test_dry_run_mode
run_test "debug mode" test_debug_mode
run_test "invalid format" test_invalid_format
run_test "failed secret retrieval" test_failed_secret_retrieval
run_test "template_help" test_template_help
run_test "end-to-end template processing" test_end_to_end_template_processing
run_test "mixed format detection" test_mixed_format_detection

# Cleanup and show summary
cleanup_test_session
test_summary 