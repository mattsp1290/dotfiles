#!/usr/bin/env bash
# Main test runner for dotfiles testing framework
# Executes unit tests, integration tests, and performance benchmarks

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TEST_ROOT="$DOTFILES_ROOT/tests"

# Source test framework
source "$TEST_ROOT/helpers/test-utils.sh"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/mock-tools.sh"
source "$TEST_ROOT/helpers/env-setup.sh"

# Test runner configuration
TEST_PATTERN=""
TEST_TYPE="all"
PARALLEL_JOBS=4
VERBOSE=false
DRY_RUN=false
COVERAGE=false
BENCHMARK=false
REPORT_FILE=""
EXIT_ON_FAILURE=true
TIMEOUT=300

# Test discovery
UNIT_TESTS=()
INTEGRATION_TESTS=()
PERFORMANCE_TESTS=()

# Results tracking
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
TEST_RESULTS=()

# Usage information
usage() {
    cat << EOF
Dotfiles Test Runner

USAGE:
    $(basename "$0") [OPTIONS] [PATTERN]

OPTIONS:
    -h, --help              Show this help message
    -t, --type TYPE         Test type: unit, integration, performance, all (default: all)
    -p, --pattern PATTERN   Run tests matching pattern (regex)
    -j, --jobs JOBS         Number of parallel jobs (default: 4)
    -v, --verbose           Enable verbose output
    -n, --dry-run           Show what would be run without executing
    -c, --coverage          Enable code coverage analysis
    -b, --benchmark         Run performance benchmarks
    -r, --report FILE       Write test report to file
    --no-exit-on-failure    Continue running tests after failures
    --timeout SECONDS       Test timeout in seconds (default: 300)

TEST TYPES:
    unit                    Run unit tests only
    integration            Run integration tests only
    performance            Run performance tests only
    all                    Run all tests (default)

EXAMPLES:
    # Run all tests
    $(basename "$0")

    # Run unit tests only
    $(basename "$0") --type unit

    # Run tests matching pattern
    $(basename "$0") --pattern "stow.*"

    # Run tests with coverage
    $(basename "$0") --coverage

    # Generate test report
    $(basename "$0") --report test-results.html

    # Dry run to see what would be executed
    $(basename "$0") --dry-run

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -t|--type)
                TEST_TYPE="$2"
                shift 2
                ;;
            -p|--pattern)
                TEST_PATTERN="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                export TEST_DEBUG=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            -b|--benchmark)
                BENCHMARK=true
                shift
                ;;
            -r|--report)
                REPORT_FILE="$2"
                shift 2
                ;;
            --no-exit-on-failure)
                EXIT_ON_FAILURE=false
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                TEST_PATTERN="$1"
                shift
                ;;
        esac
    done
}

# Discover test files
discover_tests() {
    test_info "Discovering tests..."
    
    # Find unit tests
    if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "unit" ]]; then
        while IFS= read -r -d '' test_file; do
            if [[ -z "$TEST_PATTERN" ]] || [[ "$test_file" =~ $TEST_PATTERN ]]; then
                UNIT_TESTS+=("$test_file")
            fi
        done < <(find "$TEST_ROOT/unit" -name "test-*.sh" -type f -print0 2>/dev/null)
    fi
    
    # Find integration tests
    if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "integration" ]]; then
        while IFS= read -r -d '' test_file; do
            if [[ -z "$TEST_PATTERN" ]] || [[ "$test_file" =~ $TEST_PATTERN ]]; then
                INTEGRATION_TESTS+=("$test_file")
            fi
        done < <(find "$TEST_ROOT/integration" -name "test-*.sh" -type f -print0 2>/dev/null)
    fi
    
    # Find performance tests
    if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "performance" ]] && [[ "$BENCHMARK" == "true" ]]; then
        while IFS= read -r -d '' test_file; do
            if [[ -z "$TEST_PATTERN" ]] || [[ "$test_file" =~ $TEST_PATTERN ]]; then
                PERFORMANCE_TESTS+=("$test_file")
            fi
        done < <(find "$TEST_ROOT/performance" -name "benchmark-*.sh" -type f -print0 2>/dev/null)
    fi
    
    local total_discovered=$((${#UNIT_TESTS[@]} + ${#INTEGRATION_TESTS[@]} + ${#PERFORMANCE_TESTS[@]}))
    test_info "Discovered $total_discovered tests:"
    test_info "  Unit: ${#UNIT_TESTS[@]}"
    test_info "  Integration: ${#INTEGRATION_TESTS[@]}"
    test_info "  Performance: ${#PERFORMANCE_TESTS[@]}"
}

# Run single test file
run_test_file() {
    local test_file="$1"
    local test_name
    test_name="$(basename "$test_file" .sh)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would run: $test_file"
        return 0
    fi
    
    test_info "Running: $test_name"
    
    local start_time
    start_time=$(date +%s)
    
    local output_file="$TEST_TEMP_DIR/${test_name}_output.log"
    local result=0
    
    # Run test with timeout
    if timeout "$TIMEOUT" bash "$test_file" > "$output_file" 2>&1; then
        result=0
    else
        result=$?
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse test results from output
    local passed=0
    local failed=0
    local skipped=0
    
    if [[ -f "$output_file" ]]; then
        passed=$(grep -c "^\[PASS\]" "$output_file" 2>/dev/null | tr -d '\n' || echo "0")
        failed=$(grep -c "^\[FAIL\]" "$output_file" 2>/dev/null | tr -d '\n' || echo "0")
        skipped=$(grep -c "^\[WARN\] SKIP:" "$output_file" 2>/dev/null | tr -d '\n' || echo "0")
        
        # Ensure numeric values
        passed=${passed:-0}
        failed=${failed:-0}
        skipped=${skipped:-0}
    fi
    
    # Store results
    TEST_RESULTS+=("$test_name:$result:$duration:$passed:$failed:$skipped")
    
    if [[ $result -eq 0 ]]; then
        test_success "$test_name (${duration}s, $passed passed, $skipped skipped)"
        TOTAL_PASSED=$((TOTAL_PASSED + passed))
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))
    else
        test_error "$test_name (${duration}s, $passed passed, $failed failed, $skipped skipped)"
        TOTAL_FAILED=$((TOTAL_FAILED + failed))
        TOTAL_PASSED=$((TOTAL_PASSED + passed))
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))
        
        if [[ "$VERBOSE" == "true" && -f "$output_file" ]]; then
            echo "--- Test Output ---"
            cat "$output_file"
            echo "--- End Output ---"
        fi
        
        if [[ "$EXIT_ON_FAILURE" == "true" ]]; then
            return $result
        fi
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    return $result
}

# Run tests in parallel
run_tests_parallel() {
    local test_files=("$@")
    local pids=()
    local max_jobs="$PARALLEL_JOBS"
    local job_count=0
    
    for test_file in "${test_files[@]}"; do
        # Wait if we've reached max jobs
        while [[ $job_count -ge $max_jobs ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}" || true
                    unset "pids[i]"
                    ((job_count--))
                fi
            done
            sleep 0.1
        done
        
        # Start new job
        run_test_file "$test_file" &
        pids+=($!)
        ((job_count++))
    done
    
    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
}

# Run tests sequentially
run_tests_sequential() {
    local test_files=("$@")
    local overall_result=0
    
    for test_file in "${test_files[@]}"; do
        if ! run_test_file "$test_file"; then
            overall_result=1
            if [[ "$EXIT_ON_FAILURE" == "true" ]]; then
                break
            fi
        fi
    done
    
    return $overall_result
}

# Generate test report
generate_report() {
    local report_file="$1"
    local format="${2:-text}"
    
    case "$format" in
        html)
            generate_html_report "$report_file"
            ;;
        json)
            generate_json_report "$report_file"
            ;;
        *)
            generate_text_report "$report_file"
            ;;
    esac
}

# Generate HTML report
generate_html_report() {
    local report_file="$1"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Dotfiles Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .skipped { color: #ffc107; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Dotfiles Test Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Tests: $TOTAL_TESTS</p>
        <p class="passed">Passed: $TOTAL_PASSED</p>
        <p class="failed">Failed: $TOTAL_FAILED</p>
        <p class="skipped">Skipped: $TOTAL_SKIPPED</p>
        <p>Generated: $(date)</p>
    </div>
    
    <h2>Test Results</h2>
    <table>
        <tr>
            <th>Test Name</th>
            <th>Status</th>
            <th>Duration</th>
            <th>Passed</th>
            <th>Failed</th>
            <th>Skipped</th>
        </tr>
EOF
    
    for result in "${TEST_RESULTS[@]}"; do
        IFS=':' read -r name exit_code duration passed failed skipped <<< "$result"
        local status="PASSED"
        local status_class="passed"
        
        if [[ $exit_code -ne 0 ]]; then
            status="FAILED"
            status_class="failed"
        fi
        
        cat >> "$report_file" << EOF
        <tr>
            <td>$name</td>
            <td class="$status_class">$status</td>
            <td>${duration}s</td>
            <td class="passed">$passed</td>
            <td class="failed">$failed</td>
            <td class="skipped">$skipped</td>
        </tr>
EOF
    done
    
    cat >> "$report_file" << EOF
    </table>
</body>
</html>
EOF
    
    test_info "HTML report generated: $report_file"
}

# Generate JSON report
generate_json_report() {
    local report_file="$1"
    
    cat > "$report_file" << EOF
{
    "summary": {
        "total": $TOTAL_TESTS,
        "passed": $TOTAL_PASSED,
        "failed": $TOTAL_FAILED,
        "skipped": $TOTAL_SKIPPED,
        "timestamp": "$(date -Iseconds)"
    },
    "tests": [
EOF
    
    local first=true
    for result in "${TEST_RESULTS[@]}"; do
        IFS=':' read -r name exit_code duration passed failed skipped <<< "$result"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$report_file"
        fi
        
        cat >> "$report_file" << EOF
        {
            "name": "$name",
            "status": "$([ $exit_code -eq 0 ] && echo "passed" || echo "failed")",
            "duration": $duration,
            "passed": $passed,
            "failed": $failed,
            "skipped": $skipped
        }
EOF
    done
    
    cat >> "$report_file" << EOF
    ]
}
EOF
    
    test_info "JSON report generated: $report_file"
}

# Generate text report
generate_text_report() {
    local report_file="$1"
    
    cat > "$report_file" << EOF
Dotfiles Test Report
====================

Summary:
  Total Tests: $TOTAL_TESTS
  Passed:      $TOTAL_PASSED
  Failed:      $TOTAL_FAILED
  Skipped:     $TOTAL_SKIPPED
  Generated:   $(date)

Test Results:
EOF
    
    printf "%-30s %-8s %-8s %-6s %-6s %-7s\n" "Test Name" "Status" "Duration" "Passed" "Failed" "Skipped" >> "$report_file"
    printf "%-30s %-8s %-8s %-6s %-6s %-7s\n" "----------" "------" "--------" "------" "------" "-------" >> "$report_file"
    
    for result in "${TEST_RESULTS[@]}"; do
        IFS=':' read -r name exit_code duration passed failed skipped <<< "$result"
        local status="PASSED"
        
        if [[ $exit_code -ne 0 ]]; then
            status="FAILED"
        fi
        
        printf "%-30s %-8s %-8s %-6s %-6s %-7s\n" "$name" "$status" "${duration}s" "$passed" "$failed" "$skipped" >> "$report_file"
    done
    
    test_info "Text report generated: $report_file"
}

# Show test summary
show_summary() {
    echo ""
    echo "${T_BOLD}Test Summary${T_RESET}"
    echo "============="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed:      ${T_GREEN}$TOTAL_PASSED${T_RESET}"
    echo "Failed:      ${T_RED}$TOTAL_FAILED${T_RESET}"
    echo "Skipped:     ${T_YELLOW}$TOTAL_SKIPPED${T_RESET}"
    echo ""
    
    if [[ $TOTAL_FAILED -eq 0 ]]; then
        echo "${T_GREEN}${T_BOLD}All tests passed!${T_RESET}"
        return 0
    else
        echo "${T_RED}${T_BOLD}Some tests failed!${T_RESET}"
        
        # Show failed tests
        echo ""
        echo "Failed tests:"
        for result in "${TEST_RESULTS[@]}"; do
            IFS=':' read -r name exit_code duration passed failed skipped <<< "$result"
            if [[ $exit_code -ne 0 ]]; then
                echo "  - $name"
            fi
        done
        
        return 1
    fi
}

# Main execution
main() {
    parse_arguments "$@"
    
    # Initialize test session
    init_test_session
    
    # Set up temp directory for test outputs
    if [[ -z "${TEST_TEMP_DIR:-}" ]]; then
        TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles_test_runner_XXXXXX")
    fi
    
    echo "${T_BOLD}Dotfiles Test Runner${T_RESET}"
    echo "===================="
    echo ""
    
    # Discover tests
    discover_tests
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Dry run mode - showing what would be executed:"
        echo ""
        for test_file in "${UNIT_TESTS[@]}" "${INTEGRATION_TESTS[@]}" "${PERFORMANCE_TESTS[@]}"; do
            echo "  $test_file"
        done
        return 0
    fi
    
    # Run tests
    local all_tests=("${UNIT_TESTS[@]}" "${INTEGRATION_TESTS[@]}" "${PERFORMANCE_TESTS[@]}")
    
    if [[ ${#all_tests[@]} -eq 0 ]]; then
        test_warning "No tests found matching criteria"
        return 0
    fi
    
    test_info "Running ${#all_tests[@]} tests with $PARALLEL_JOBS parallel jobs"
    echo ""
    
    local start_time
    start_time=$(date +%s)
    
    # Run tests based on parallel job setting
    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        run_tests_parallel "${all_tests[@]}"
    else
        run_tests_sequential "${all_tests[@]}"
    fi
    
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo ""
    test_info "Test execution completed in ${total_duration}s"
    
    # Generate report if requested
    if [[ -n "$REPORT_FILE" ]]; then
        local format="text"
        case "$REPORT_FILE" in
            *.html) format="html" ;;
            *.json) format="json" ;;
        esac
        generate_report "$REPORT_FILE" "$format"
    fi
    
    # Show summary
    show_summary
    local exit_code=$?
    
    # Cleanup temp directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Cleanup test session
    cleanup_test_session
    
    return $exit_code
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 