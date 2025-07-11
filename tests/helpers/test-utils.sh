#!/usr/bin/env bash
# Test utilities for dotfiles testing framework
# Provides common functions, setup/teardown, and test helpers

set -euo pipefail

# Test framework configuration
if [[ -z "${TEST_FRAMEWORK_VERSION:-}" ]]; then
    readonly TEST_FRAMEWORK_VERSION="1.0.0"
fi

if [[ -z "${TEST_ROOT_DIR:-}" ]]; then
    readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Set DOTFILES_ROOT if not already set
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
    readonly DOTFILES_ROOT="$(cd "$TEST_ROOT_DIR/.." && pwd)"
fi

if [[ -z "${TEST_TEMP_PREFIX:-}" ]]; then
    readonly TEST_TEMP_PREFIX="dotfiles_test_"
fi

# Import utilities (only if not already sourced)
if ! declare -F log_info >/dev/null 2>&1; then
    source "$DOTFILES_ROOT/scripts/lib/utils.sh"
fi
if ! declare -F detect_os >/dev/null 2>&1; then
    source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"
fi

# Test state variables
TEST_TEMP_DIR=""
TEST_ORIGINAL_PWD="$PWD"
TEST_ORIGINAL_HOME="$HOME"
TEST_COUNT=0
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0

# Colors for test output
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    if ! declare -p T_RED >/dev/null 2>&1; then
        readonly T_RED=$(tput setaf 1)
        readonly T_GREEN=$(tput setaf 2)
        readonly T_YELLOW=$(tput setaf 3)
        readonly T_BLUE=$(tput setaf 4)
        readonly T_MAGENTA=$(tput setaf 5)
        readonly T_CYAN=$(tput setaf 6)
        readonly T_BOLD=$(tput bold)
        readonly T_RESET=$(tput sgr0)
    fi
else
    if ! declare -p T_RED >/dev/null 2>&1; then
        readonly T_RED=""
        readonly T_GREEN=""
        readonly T_YELLOW=""
        readonly T_BLUE=""
        readonly T_MAGENTA=""
        readonly T_CYAN=""
        readonly T_BOLD=""
        readonly T_RESET=""
    fi
fi

# Test logging functions
test_info() {
    echo "${T_BLUE}[INFO]${T_RESET} $*" >&2
}

test_success() {
    echo "${T_GREEN}[PASS]${T_RESET} $*" >&2
}

test_warning() {
    echo "${T_YELLOW}[WARN]${T_RESET} $*" >&2
}

test_error() {
    echo "${T_RED}[FAIL]${T_RESET} $*" >&2
}

test_debug() {
    if [[ "${TEST_DEBUG:-false}" == "true" ]]; then
        echo "${T_CYAN}[DEBUG]${T_RESET} $*" >&2
    fi
}

# Create isolated test environment
setup_test_env() {
    test_debug "Starting test environment setup..."
    
    TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/${TEST_TEMP_PREFIX}XXXXXX")
    test_debug "Created temp directory: $TEST_TEMP_DIR"
    
    # Set environment variables for testing
    export HOME="$TEST_TEMP_DIR/home"
    export DOTFILES_DIR="$TEST_TEMP_DIR/dotfiles"
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/config"
    export XDG_DATA_HOME="$TEST_TEMP_DIR/data"
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/cache"
    test_debug "Set environment variables"
    
    # Create directory structure
    mkdir -p "$HOME"
    mkdir -p "$DOTFILES_DIR"
    mkdir -p "$XDG_CONFIG_HOME"
    mkdir -p "$XDG_DATA_HOME"
    mkdir -p "$XDG_CACHE_HOME"
    test_debug "Created directory structure"
    
    # Change to test directory
    cd "$TEST_TEMP_DIR"
    test_debug "Changed to test directory: $(pwd)"
    
    test_debug "Test environment created at: $TEST_TEMP_DIR"
}

# Clean up test environment
teardown_test_env() {
    # Restore original state
    cd "$TEST_ORIGINAL_PWD"
    export HOME="$TEST_ORIGINAL_HOME"
    unset DOTFILES_DIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
    
    # Clean up temp directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        test_debug "Test environment cleaned up: $TEST_TEMP_DIR"
    fi
    
    TEST_TEMP_DIR=""
}

# Create test fixture file
create_test_file() {
    local filepath="$1"
    local content="${2:-}"
    
    mkdir -p "$(dirname "$filepath")"
    if [[ -n "$content" ]]; then
        echo "$content" > "$filepath"
    else
        touch "$filepath"
    fi
}

# Create test dotfiles package
create_test_package() {
    local package_name="$1"
    local package_dir="$DOTFILES_DIR/$package_name"
    
    mkdir -p "$package_dir"
    
    # Create some test files
    create_test_file "$package_dir/.testrc" "# Test configuration for $package_name"
    create_test_file "$package_dir/.config/test/config.yaml" "test: $package_name"
    
    echo "$package_dir"
}

# Run test function with error handling
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    test_info "Running: $test_name"
    
    # Setup test environment
    setup_test_env
    
    # Run the test
    local result=0
    if "$test_function"; then
        test_success "$test_name"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        result=$?
        test_error "$test_name (exit code: $result)"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    # Cleanup
    teardown_test_env
    
    return $result
}

# Skip a test with reason
skip_test() {
    local test_name="$1"
    local reason="${2:-No reason provided}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
    
    test_warning "SKIP: $test_name - $reason"
}

# Test if running in CI environment
is_ci() {
    [[ "${CI:-false}" == "true" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Test if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Test if command is available
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Mock external command
mock_command() {
    local cmd="$1"
    local mock_script="$2"
    local mock_dir="$TEST_TEMP_DIR/mock_bin"
    
    mkdir -p "$mock_dir"
    echo "$mock_script" > "$mock_dir/$cmd"
    chmod +x "$mock_dir/$cmd"
    
    # Add to PATH
    export PATH="$mock_dir:$PATH"
    
    test_debug "Mocked command: $cmd"
}

# Restore original PATH
restore_path() {
    if [[ -n "${ORIGINAL_PATH:-}" ]]; then
        export PATH="$ORIGINAL_PATH"
    fi
}

# Wait for file to exist or timeout
wait_for_file() {
    local file="$1"
    local timeout="${2:-10}"
    local count=0
    
    while [[ ! -f "$file" && $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done
    
    [[ -f "$file" ]]
}

# Capture command output
capture_output() {
    local cmd=("$@")
    local temp_file="$TEST_TEMP_DIR/capture_output"
    
    "${cmd[@]}" > "$temp_file" 2>&1
    local exit_code=$?
    
    cat "$temp_file"
    return $exit_code
}

# Generate test summary
test_summary() {
    echo ""
    echo "${T_BOLD}Test Summary${T_RESET}"
    echo "============="
    echo "Total:   $TEST_COUNT"
    echo "Passed:  ${T_GREEN}$TEST_PASSED${T_RESET}"
    echo "Failed:  ${T_RED}$TEST_FAILED${T_RESET}"
    echo "Skipped: ${T_YELLOW}$TEST_SKIPPED${T_RESET}"
    echo ""
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        echo "${T_GREEN}${T_BOLD}All tests passed!${T_RESET}"
        return 0
    else
        echo "${T_RED}${T_BOLD}Some tests failed!${T_RESET}"
        return 1
    fi
}

# Initialize test session
init_test_session() {
    # Store original PATH
    export ORIGINAL_PATH="$PATH"
    
    # Reset counters
    TEST_COUNT=0
    TEST_PASSED=0
    TEST_FAILED=0
    TEST_SKIPPED=0
    
    test_info "Test session initialized"
}

# Cleanup test session
cleanup_test_session() {
    restore_path
    test_debug "Test session cleaned up"
} 