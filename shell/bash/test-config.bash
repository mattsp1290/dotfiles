#!/bin/bash
# Bash Configuration Test Script
# Tests the bash compatibility layer for functionality and performance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_function() {
    local test_name="$1"
    local test_command="$2"
    ((TESTS_TOTAL++))
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
    else
        log_error "$test_name"
    fi
}

test_variable() {
    local test_name="$1"
    local variable_name="$2"
    ((TESTS_TOTAL++))
    
    if [[ -n "${!variable_name:-}" ]]; then
        log_success "$test_name - $variable_name=${!variable_name}"
    else
        log_error "$test_name - $variable_name is not set"
    fi
}

test_alias() {
    local test_name="$1"
    local alias_name="$2"
    ((TESTS_TOTAL++))
    
    if alias "$alias_name" >/dev/null 2>&1; then
        log_success "$test_name"
    else
        log_error "$test_name"
    fi
}

# Performance test
performance_test() {
    log_info "Running performance test..."
    
    local start_time=$(date +%s%N)
    
    # Source the configuration in a subshell
    (
        export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/git/dotfiles}"
        source "$DOTFILES_DIR/shell/bash/.bashrc"
    ) >/dev/null 2>&1
    
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $duration_ms -lt 500 ]]; then
        log_success "Performance test - startup time: ${duration_ms}ms (target: <500ms)"
    else
        log_warning "Performance test - startup time: ${duration_ms}ms (target: <500ms)"
    fi
}

# Main test function
main() {
    echo "======================================"
    echo "Bash Configuration Test Suite"
    echo "======================================"
    
    # Set DOTFILES_DIR for testing
    export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/git/dotfiles}"
    
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "DOTFILES_DIR not found: $DOTFILES_DIR"
        exit 1
    fi
    
    log_info "Testing bash configuration in: $DOTFILES_DIR"
    
    # Source the configuration
    if [[ -f "$DOTFILES_DIR/shell/bash/.bashrc" ]]; then
        log_info "Sourcing bash configuration..."
        source "$DOTFILES_DIR/shell/bash/.bashrc"
    else
        log_error "Bash configuration not found"
        exit 1
    fi
    
    echo
    log_info "Testing environment variables..."
    test_variable "DOTFILES_DIR" "DOTFILES_DIR"
    test_variable "OS_TYPE" "OS_TYPE"
    test_variable "PATH" "PATH"
    
    echo
    log_info "Testing essential aliases..."
    test_alias "ls alias" "ls"
    test_alias "ll alias" "ll"
    test_alias "grep alias" "grep"
    test_alias "git alias" "g"
    test_alias "git status alias" "gs"
    
    echo
    log_info "Testing functions..."
    test_function "mkcd function" "declare -f mkcd"
    test_function "extract function" "declare -f extract"
    test_function "backup function" "declare -f backup"
    test_function "weather function" "declare -f weather"
    test_function "gcom function" "declare -f gcom"
    
    echo
    log_info "Testing tool detection..."
    if command -v git >/dev/null 2>&1; then
        log_success "Git detected"
    else
        log_warning "Git not found"
    fi
    
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker detected"
    else
        log_warning "Docker not found (optional)"
    fi
    
    if command -v kubectl >/dev/null 2>&1; then
        log_success "kubectl detected"
    else
        log_warning "kubectl not found (optional)"
    fi
    
    echo
    log_info "Testing PATH management..."
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        log_success "Local bin in PATH"
    else
        log_warning "Local bin not in PATH"
    fi
    
    if [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
        log_success "Home bin in PATH"
    else
        log_warning "Home bin not in PATH"
    fi
    
    echo
    log_info "Testing completion system..."
    if command -v complete >/dev/null 2>&1; then
        log_success "Bash completion available"
    else
        log_error "Bash completion not available"
    fi
    
    echo
    log_info "Testing prompt..."
    if [[ -n "$PS1" ]]; then
        log_success "PS1 is set"
    else
        log_error "PS1 is not set"
    fi
    
    if [[ -n "$PROMPT_COMMAND" ]]; then
        log_success "PROMPT_COMMAND is set"
    else
        log_warning "PROMPT_COMMAND is not set"
    fi
    
    echo
    performance_test
    
    echo
    echo "======================================"
    echo "Test Results"
    echo "======================================"
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@" 