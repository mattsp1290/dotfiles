#!/usr/bin/env bash
# Unit Test Runner for Dotfiles Scripts
# Runs comprehensive unit tests for all utility libraries

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$DOTFILES_ROOT/tests"

# Source utilities
source "$SCRIPT_DIR/lib/utils.sh"

# Test configuration
PARALLEL_TESTS="${PARALLEL_TESTS:-false}"
VERBOSE="${VERBOSE:-false}"
COVERAGE="${COVERAGE:-false}"
SPECIFIC_TEST="${1:-}"

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Available test suites
UNIT_TESTS=(
    "utils"
    "detect-os"
    "secret-helpers"
    "stow-utils"
    "template-engine"
)

# Usage information
usage() {
    cat << EOF
Usage: $0 [TEST_NAME] [OPTIONS]

Run unit tests for dotfiles utility libraries.

Arguments:
  TEST_NAME    Specific test to run (optional)
               Options: ${UNIT_TESTS[*]}

Environment Variables:
  PARALLEL_TESTS=true    Run tests in parallel
  VERBOSE=true          Enable verbose output
  COVERAGE=true         Generate coverage report
  TEST_DEBUG=true       Enable test debugging

Examples:
  # Run all unit tests
  $0

  # Run specific test
  $0 utils

  # Run with verbose output
  VERBOSE=true $0

  # Run tests in parallel
  PARALLEL_TESTS=true $0

Available Tests:
$(printf "  - %s\n" "${UNIT_TESTS[@]}")
EOF
}

# Check if test exists
test_exists() {
    local test_name="$1"
    [[ -f "$TESTS_DIR/unit/${test_name}.sh" ]]
}

# Run a single test
run_test() {
    local test_name="$1"
    local test_file="$TESTS_DIR/unit/${test_name}.sh"
    
    if [[ ! -f "$test_file" ]]; then
        log_error "Test file not found: $test_file"
        return 1
    fi
    
    log_info "Running unit tests: $test_name"
    
    # Make test file executable
    chmod +x "$test_file"
    
    # Run the test
    local start_time=$(date +%s)
    if [[ "$VERBOSE" == "true" ]]; then
        bash "$test_file"
        local result=$?
    else
        local output
        if output=$(bash "$test_file" 2>&1); then
            local result=0
            echo "$output" | tail -n 10  # Show summary
        else
            local result=$?
            echo "$output"
        fi
    fi
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $result -eq 0 ]]; then
        log_success "Unit tests passed: $test_name (${duration}s)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "Unit tests failed: $test_name (${duration}s)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    return $result
}

# Run tests in parallel
run_tests_parallel() {
    local tests=("$@")
    local pids=()
    local results=()
    
    # Start all tests
    for test_name in "${tests[@]}"; do
        (run_test "$test_name"; echo $? > "$TESTS_DIR/result_${test_name}") &
        pids+=($!)
    done
    
    # Wait for all tests to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Collect results
    for test_name in "${tests[@]}"; do
        local result_file="$TESTS_DIR/result_${test_name}"
        if [[ -f "$result_file" ]]; then
            local result=$(cat "$result_file")
            results+=($result)
            rm -f "$result_file"
        else
            results+=(1)
        fi
    done
    
    # Calculate totals
    TOTAL_TESTS=${#tests[@]}
    PASSED_TESTS=0
    FAILED_TESTS=0
    
    for result in "${results[@]}"; do
        if [[ $result -eq 0 ]]; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
}

# Run tests sequentially
run_tests_sequential() {
    local tests=("$@")
    local failed_tests=()
    
    for test_name in "${tests[@]}"; do
        if ! run_test "$test_name"; then
            failed_tests+=("$test_name")
        fi
    done
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_warning "Failed tests: ${failed_tests[*]}"
        return 1
    fi
    
    return 0
}

# Generate coverage report (placeholder)
generate_coverage() {
    if [[ "$COVERAGE" != "true" ]]; then
        return 0
    fi
    
    log_info "Generating coverage report..."
    
    # This is a placeholder for future coverage implementation
    # Could integrate with tools like bashcov or custom coverage analysis
    log_warning "Coverage reporting not implemented yet"
}

# Show final summary
show_summary() {
    echo ""
    echo "================================================================"
    echo "                    UNIT TEST SUMMARY"
    echo "================================================================"
    echo "Total Tests:   $TOTAL_TESTS"
    echo "Passed:        ${GREEN}$PASSED_TESTS${NC}"
    echo "Failed:        ${RED}$FAILED_TESTS${NC}"
    echo "Skipped:       ${YELLOW}$SKIPPED_TESTS${NC}"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "${GREEN}${BOLD}✓ All tests passed!${NC}"
        echo ""
        return 0
    else
        echo "${RED}${BOLD}✗ Some tests failed!${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    # Handle help
    if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
        usage
        exit 0
    fi
    
    # Validate test environment
    if [[ ! -d "$TESTS_DIR" ]]; then
        log_error "Tests directory not found: $TESTS_DIR"
        exit 1
    fi
    
    log_info "Starting unit tests for dotfiles scripts"
    log_info "Test directory: $TESTS_DIR"
    
    # Determine which tests to run
    local tests_to_run=()
    
    if [[ -n "$SPECIFIC_TEST" ]]; then
        if test_exists "$SPECIFIC_TEST"; then
            tests_to_run=("$SPECIFIC_TEST")
        else
            log_error "Test not found: $SPECIFIC_TEST"
            log_info "Available tests: ${UNIT_TESTS[*]}"
            exit 1
        fi
    else
        # Run all available tests
        for test_name in "${UNIT_TESTS[@]}"; do
            if test_exists "$test_name"; then
                tests_to_run+=("$test_name")
            else
                log_warning "Test file not found: $test_name.sh"
                SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            fi
        done
    fi
    
    if [[ ${#tests_to_run[@]} -eq 0 ]]; then
        log_error "No tests to run"
        exit 1
    fi
    
    log_info "Running ${#tests_to_run[@]} test suites: ${tests_to_run[*]}"
    
    # Export environment variables for tests
    export DOTFILES_ROOT
    export TEST_DEBUG="${TEST_DEBUG:-false}"
    
    # Run tests
    local start_time=$(date +%s)
    
    if [[ "$PARALLEL_TESTS" == "true" && ${#tests_to_run[@]} -gt 1 ]]; then
        log_info "Running tests in parallel..."
        run_tests_parallel "${tests_to_run[@]}"
        local result=$?
    else
        run_tests_sequential "${tests_to_run[@]}"
        local result=$?
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Generate coverage if requested
    generate_coverage
    
    # Show summary
    echo ""
    log_info "Total execution time: ${total_duration}s"
    show_summary
    
    exit $result
}

# Handle script arguments
if [[ $# -gt 0 && "$1" =~ ^(-h|--help)$ ]]; then
    usage
    exit 0
fi

# Run main function
main "$@" 