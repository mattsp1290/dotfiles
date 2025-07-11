#!/usr/bin/env bash
# Unit tests for scripts/lib/utils.sh
# Tests all utility functions for logging, error handling, file operations, etc.

set -euo pipefail

# Source testing framework
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/test-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/assertions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/mock-tools.sh"

# Initialize test session
init_test_session
init_mock_logging

# Source the module under test
source "$DOTFILES_ROOT/scripts/lib/utils.sh"

#
# Logging Function Tests
#

test_log_debug() {
    local output
    
    # Test debug logging when level allows
    CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
    output=$(log_debug "Test debug message" 2>&1)
    assert_contains "$output" "[DEBUG]" "Debug message should contain [DEBUG] tag"
    assert_contains "$output" "Test debug message" "Debug message should contain the message"
    
    # Test debug logging when level doesn't allow
    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
    output=$(log_debug "Hidden debug message" 2>&1 || true)
    assert_equals "" "$output" "Debug message should be hidden when log level is higher"
}

test_log_info() {
    local output
    
    output=$(log_info "Test info message")
    assert_contains "$output" "[INFO]" "Info message should contain [INFO] tag"
    assert_contains "$output" "Test info message" "Info message should contain the message"
}

test_log_success() {
    local output
    
    output=$(log_success "Test success message")
    assert_contains "$output" "[SUCCESS]" "Success message should contain [SUCCESS] tag"
    assert_contains "$output" "Test success message" "Success message should contain the message"
    assert_contains "$output" "$CHECK_MARK" "Success message should contain check mark"
}

test_log_warning() {
    local output
    
    output=$(log_warning "Test warning message" 2>&1)
    assert_contains "$output" "[WARNING]" "Warning message should contain [WARNING] tag"
    assert_contains "$output" "Test warning message" "Warning message should contain the message"
}

test_log_error() {
    local output
    
    output=$(log_error "Test error message" 2>&1)
    assert_contains "$output" "[ERROR]" "Error message should contain [ERROR] tag"
    assert_contains "$output" "Test error message" "Error message should contain the message"
    assert_contains "$output" "$CROSS_MARK" "Error message should contain cross mark"
}

#
# Progress Indication Tests
#

test_show_progress() {
    local output
    
    output=$(show_progress "Testing progress")
    assert_contains "$output" "$ARROW" "Progress should contain arrow symbol"
    assert_contains "$output" "Testing progress" "Progress should contain the message"
    assert_contains "$output" "..." "Progress should end with dots"
}

test_end_progress() {
    local output
    
    # Test successful completion
    output=$(end_progress "success")
    assert_contains "$output" "done" "Success progress should show 'done'"
    
    # Test failed completion
    output=$(end_progress "failed")
    assert_contains "$output" "failed" "Failed progress should show 'failed'"
}

#
# Command Existence Tests
#

test_command_exists() {
    # Test with existing command
    assert_true "command_exists 'bash'" "bash command should exist"
    
    # Test with non-existing command
    assert_false "command_exists 'non_existent_command_12345'" "Non-existent command should not exist"
    
    # Test with empty string
    assert_false "command_exists ''" "Empty command should not exist"
}

test_function_exists() {
    # Test with existing function
    assert_true "function_exists 'log_info'" "log_info function should exist"
    
    # Test with non-existing function
    assert_false "function_exists 'non_existent_function_12345'" "Non-existent function should not exist"
    
    # Test with existing command (not function)
    assert_false "function_exists 'bash'" "bash is not a function"
}

test_check_required_commands() {
    # Test with all existing commands
    assert_command_success check_required_commands bash echo "Should succeed with existing commands"
    
    # Test with missing command
    assert_command_failure check_required_commands bash non_existent_command_12345 "Should fail with missing command"
    
    # Test with no commands
    assert_command_success check_required_commands "Should succeed with no commands"
}

#
# Version Comparison Tests
#

test_version_ge() {
    # Test equal versions
    assert_true "version_ge '1.0.0' '1.0.0'" "Equal versions should return true"
    
    # Test greater version
    assert_true "version_ge '1.1.0' '1.0.0'" "Greater version should return true"
    
    # Test lesser version
    assert_false "version_ge '1.0.0' '1.1.0'" "Lesser version should return false"
    
    # Test with complex versions
    assert_true "version_ge '2.1.3' '2.1.2'" "Complex greater version should return true"
    assert_false "version_ge '2.1.2' '2.1.3'" "Complex lesser version should return false"
}

#
# Network Tests (with mocking)
#

test_check_network() {
    # Mock ping command to simulate success
    mock_command "ping" "#!/bin/bash
if [[ \"\$1\" == '-c' && \"\$2\" == '1' && \"\$3\" == '-W' ]]; then
    exit 0
fi
exit 1"
    
    assert_command_success check_network "8.8.8.8" "Network check should succeed with mocked ping"
    
    # Test fallback to curl by removing ping from PATH
    # Save original PATH
    local original_path="$PATH"
    
    # Remove ping from PATH (simulate ping not available)
    PATH="/non/existent/path"
    
    # Mock curl to succeed
    mock_command "curl" "#!/bin/bash
if [[ \"\$1\" == '-s' && \"\$2\" == '--connect-timeout' ]]; then
    exit 0
fi
exit 1"
    
    assert_command_success check_network "8.8.8.8" "Network check should fallback to curl"
    
    # Restore PATH
    PATH="$original_path"
}

test_has_internet() {
    # Mock successful network check
    mock_command "ping" "#!/bin/bash
exit 0"
    
    assert_command_success has_internet "Internet check should succeed with mocked commands"
}

#
# Download Tests
#

test_download_file() {
    local test_url="https://example.com/test.txt"
    local output_file="$TEST_TEMP_DIR/downloaded.txt"
    local test_content="Test download content"
    
    # Mock curl to simulate successful download
    mock_command "curl" "#!/bin/bash
if [[ \"\$1\" == '-fsSL' && \"\$3\" == '-o' ]]; then
    echo '$test_content' > \"\$4\"
    exit 0
fi
exit 1"
    
    assert_command_success download_file "$test_url" "$output_file" "Download should succeed"
    assert_file_exists "$output_file" "Downloaded file should exist"
    assert_file_contains "$output_file" "$test_content" "Downloaded file should contain expected content"
}

#
# Temporary Directory Tests
#

test_create_temp_dir() {
    local temp_dir
    temp_dir=$(create_temp_dir "test_prefix")
    
    assert_dir_exists "$temp_dir" "Temp directory should be created"
    assert_contains "$temp_dir" "test_prefix" "Temp directory should contain prefix"
    
    # Clean up
    rm -rf "$temp_dir"
}

test_cleanup_on_exit() {
    local temp_dir
    temp_dir=$(create_temp_dir "cleanup_test")
    
    # Create a test file
    touch "$temp_dir/test_file"
    assert_file_exists "$temp_dir/test_file" "Test file should exist"
    
    # Set up cleanup (in a subshell to test trap)
    (
        cleanup_on_exit "$temp_dir"
        exit 0
    )
    
    # Directory should still exist since cleanup_on_exit just sets trap
    assert_dir_exists "$temp_dir" "Temp directory should still exist after setting trap"
    
    # Clean up manually
    rm -rf "$temp_dir"
}

#
# User Interaction Tests (with mocking)
#

test_confirm() {
    # Mock 'yes' response
    mock_command "read" "#!/bin/bash
echo 'y'"
    
    # We can't easily test interactive functions, so we'll test the logic
    # by examining the function's structure
    assert_true "function_exists 'confirm'" "Confirm function should exist"
}

test_prompt_input() {
    # Similar to confirm, testing existence and basic structure
    assert_true "function_exists 'prompt_input'" "Prompt input function should exist"
}

#
# Script Directory Tests
#

test_get_script_dir() {
    local script_dir
    script_dir=$(get_script_dir)
    
    assert_dir_exists "$script_dir" "Script directory should exist"
    assert_contains "$script_dir" "scripts/lib" "Script directory should contain scripts/lib path"
}

#
# Disk Space Tests
#

test_check_disk_space() {
    # Mock df command
    mock_command "df" "#!/bin/bash
if [[ \"\$1\" == '-k' ]]; then
    echo 'Filesystem 1K-blocks Used Available Use% Mounted on'
    echo '/dev/disk1 500000 300000 200000 60% /'
fi"
    
    # Test with sufficient space (requiring 100MB, 200MB available)
    assert_command_success check_disk_space 100 "$HOME" "Should succeed with sufficient disk space"
    
    # Test with insufficient space (requiring 300MB, 200MB available)
    assert_command_failure check_disk_space 300 "$HOME" "Should fail with insufficient disk space"
}

#
# File Operations Tests
#

test_backup_file() {
    local test_file="$TEST_TEMP_DIR/test_file.txt"
    local test_content="Original content"
    
    # Create test file
    echo "$test_content" > "$test_file"
    
    # Backup the file
    backup_file "$test_file"
    
    # Check backup was created
    assert_file_exists "${test_file}.backup" "Backup file should be created"
    assert_file_contains "${test_file}.backup" "$test_content" "Backup should contain original content"
    
    # Test backing up again creates numbered backup
    backup_file "$test_file"
    assert_file_exists "${test_file}.backup.1" "Second backup should be numbered"
}

test_ensure_dir() {
    local test_dir="$TEST_TEMP_DIR/new/nested/directory"
    
    assert_dir_not_exists "$test_dir" "Directory should not exist initially"
    
    ensure_dir "$test_dir"
    
    assert_dir_exists "$test_dir" "Directory should be created"
    
    # Test with existing directory (should not fail)
    ensure_dir "$test_dir"
    assert_dir_exists "$test_dir" "Directory should still exist"
}

test_safe_symlink() {
    local source_file="$TEST_TEMP_DIR/source.txt"
    local target_link="$TEST_TEMP_DIR/target_link"
    local existing_file="$TEST_TEMP_DIR/existing.txt"
    
    # Create source file
    echo "Source content" > "$source_file"
    
    # Test creating symlink
    safe_symlink "$source_file" "$target_link"
    assert_symlink "$target_link" "Target should be a symlink"
    assert_symlink_target "$target_link" "$source_file" "Symlink should point to source"
    
    # Test with existing file (should backup and replace)
    echo "Existing content" > "$existing_file"
    safe_symlink "$source_file" "$existing_file"
    assert_symlink "$existing_file" "Existing file should become symlink"
    assert_file_exists "${existing_file}.backup" "Original file should be backed up"
    
    # Test with non-existent source
    assert_command_failure safe_symlink "/non/existent/source" "$TEST_TEMP_DIR/bad_link" "Should fail with non-existent source"
}

#
# Command Execution Tests
#

test_run_with_timeout() {
    # Mock timeout command
    mock_command "timeout" "#!/bin/bash
shift  # Remove timeout duration
exec \"\$@\""
    
    assert_command_success run_with_timeout 5 echo "test" "Should run command with timeout"
    
    # Test fallback when timeout command doesn't exist
    PATH="/non/existent/path:$PATH"
    assert_command_success run_with_timeout 5 echo "test" "Should fallback without timeout"
}

test_retry_command() {
    local attempt_file="$TEST_TEMP_DIR/attempt_count"
    echo "0" > "$attempt_file"
    
    # Create a command that fails twice then succeeds
    mock_command "flaky_command" "#!/bin/bash
count=\$(cat '$attempt_file')
count=\$((count + 1))
echo \"\$count\" > '$attempt_file'
if [[ \$count -lt 3 ]]; then
    exit 1
else
    exit 0
fi"
    
    # Should succeed after 3 attempts
    assert_command_success retry_command 3 1 flaky_command "Should succeed after retries"
    
    # Verify it actually retried
    local final_count
    final_count=$(cat "$attempt_file")
    assert_equals "3" "$final_count" "Should have made 3 attempts"
}

#
# Test Execution Framework
#

# Run all tests
run_test "log_debug functionality" test_log_debug
run_test "log_info functionality" test_log_info
run_test "log_success functionality" test_log_success
run_test "log_warning functionality" test_log_warning
run_test "log_error functionality" test_log_error
run_test "show_progress functionality" test_show_progress
run_test "end_progress functionality" test_end_progress
run_test "command_exists functionality" test_command_exists
run_test "function_exists functionality" test_function_exists
run_test "check_required_commands functionality" test_check_required_commands
run_test "version_ge functionality" test_version_ge
run_test "check_network functionality" test_check_network
run_test "has_internet functionality" test_has_internet
run_test "download_file functionality" test_download_file
run_test "create_temp_dir functionality" test_create_temp_dir
run_test "cleanup_on_exit functionality" test_cleanup_on_exit
run_test "confirm functionality" test_confirm
run_test "prompt_input functionality" test_prompt_input
run_test "get_script_dir functionality" test_get_script_dir
run_test "check_disk_space functionality" test_check_disk_space
run_test "backup_file functionality" test_backup_file
run_test "ensure_dir functionality" test_ensure_dir
run_test "safe_symlink functionality" test_safe_symlink
run_test "run_with_timeout functionality" test_run_with_timeout
run_test "retry_command functionality" test_retry_command

# Cleanup and show summary
cleanup_test_session
test_summary 