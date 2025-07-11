#!/usr/bin/env bash

# =============================================================================
# Template Security Testing
# =============================================================================
# Comprehensive security testing for the dotfiles template system
# Part of the TEST-004 Security Validation implementation
#
# This script validates template security to ensure:
# - Secret injection system prevents leakage
# - Templates don't expose secrets in error conditions
# - Proper sanitization of user inputs
# - Template rendering handles malicious inputs safely
# - No template execution vulnerabilities
#
# Usage: ./template-security-test.sh [options]
# Options:
#   --fast        Skip comprehensive tests (basic validation only)
#   --report-only Generate report without failing
#   --verbose     Enable verbose output
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_DIR="${SCRIPT_DIR}/reports"
TEMPLATES_DIR="${REPO_ROOT}/templates"

# Command line options
FAST_MODE=false
REPORT_ONLY=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fast)
                FAST_MODE=true
                shift
                ;;
            --report-only)
                REPORT_ONLY=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Template Security Testing

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --fast         Skip comprehensive tests (basic validation only)
    --report-only  Generate report without failing
    --verbose      Enable verbose output
    --help, -h     Show this help message

DESCRIPTION:
    Tests template system security:
    - Secret injection system validation
    - Template error handling security
    - Input sanitization testing
    - Malicious input resistance
    - Template execution safety

EXAMPLES:
    $0                    # Full security test suite
    $0 --fast            # Basic validation only
    $0 --verbose         # Enable debug output
EOF
}

# Test template file existence and structure
test_template_structure() {
    log_test "Testing template structure and accessibility..."
    
    local issues=0
    
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        return 1
    fi
    
    log_debug "Found templates directory: $TEMPLATES_DIR"
    
    # Check for common template files
    local expected_templates=(
        "ssh"
        "git" 
        "shell"
        "aws"
    )
    
    for template_type in "${expected_templates[@]}"; do
        local template_path="$TEMPLATES_DIR/$template_type"
        if [[ -d "$template_path" ]]; then
            log_debug "Found template directory: $template_type"
            
            # Check permissions on template files
            while IFS= read -r -d '' template_file; do
                local perms
                if [[ "$(uname)" == "Darwin" ]]; then
                    perms=$(stat -f "%A" "$template_file" 2>/dev/null || echo "000")
                else
                    perms=$(stat -c "%a" "$template_file" 2>/dev/null || echo "000")
                fi
                
                # Template files should not be world-writable
                if [[ "${perms:2:1}" =~ [2367] ]]; then
                    log_error "World-writable template file: $template_file ($perms)"
                    ((issues++))
                fi
                
                log_debug "Template file permissions OK: $template_file ($perms)"
                
            done < <(find "$template_path" -type f -print0 2>/dev/null)
        else
            log_warn "Expected template directory not found: $template_type"
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log_success "Template structure validation passed"
        return 0
    else
        log_error "Template structure validation found $issues issues"
        return 1
    fi
}

# Test for template injection vulnerabilities
test_template_injection() {
    log_test "Testing template injection vulnerabilities..."
    
    local issues=0
    local test_output="${LOG_DIR}/template-injection-$(date +%Y%m%d-%H%M%S).log"
    
    # Malicious input patterns to test
    local malicious_inputs=(
        '$(rm -rf /tmp/test)'
        '`whoami`'
        '${USER}'
        '{{user.password}}'
        '#{system("id")}'
        '<script>alert("xss")</script>'
        '../../../etc/passwd'
        '{{config.secret_key}}'
        '${env:SECRET_KEY}'
        '<%=system("id")%>'
    )
    
    # Find template files to test
    while IFS= read -r -d '' template_file; do
        if [[ -f "$template_file" ]]; then
            log_debug "Testing template injection for: $template_file"
            
            # Test each malicious input
            for malicious_input in "${malicious_inputs[@]}"; do
                # Create a test environment variable
                export TEST_MALICIOUS_INPUT="$malicious_input"
                
                # Try to process template (safely, in a controlled way)
                local result=""
                if command -v envsubst >/dev/null 2>&1; then
                    # Test envsubst processing (common template processor)
                    result=$(echo "$malicious_input" | envsubst 2>/dev/null || echo "ERROR")
                fi
                
                # Check if malicious input was executed
                if [[ "$result" != "$malicious_input" ]] && [[ "$result" != "ERROR" ]]; then
                    echo "TEMPLATE_INJECTION: $template_file | $malicious_input | $result" >> "$test_output"
                    ((issues++))
                    log_error "Template injection vulnerability: $template_file with input '$malicious_input'"
                fi
                
                unset TEST_MALICIOUS_INPUT
            done
        fi
    done < <(find "$TEMPLATES_DIR" -type f \( -name "*.template" -o -name "*.tmpl" -o -name "*.tpl" \) -print0 2>/dev/null)
    
    if [[ $issues -eq 0 ]]; then
        log_success "Template injection tests passed"
        return 0
    else
        log_error "Template injection tests found $issues vulnerabilities"
        return 1
    fi
}

# Test secret exposure in templates
test_secret_exposure() {
    log_test "Testing for secret exposure in templates..."
    
    local issues=0
    local test_output="${LOG_DIR}/secret-exposure-$(date +%Y%m%d-%H%M%S).log"
    
    # Patterns that might indicate secret exposure
    local secret_patterns=(
        'password\s*[=:]\s*[^{][^}]*[^{][^}]*'
        'api[_-]?key\s*[=:]\s*[^{][^}]*[^{][^}]*'
        'secret\s*[=:]\s*[^{][^}]*[^{][^}]*'
        'token\s*[=:]\s*[^{][^}]*[^{][^}]*'
        'credential\s*[=:]\s*[^{][^}]*[^{][^}]*'
        'BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY'
        'AKIA[0-9A-Z]{16}'
    )
    
    # Scan all template files for potential secret exposure
    while IFS= read -r -d '' template_file; do
        if [[ -f "$template_file" ]]; then
            log_debug "Scanning for secret exposure: $template_file"
            
            for pattern in "${secret_patterns[@]}"; do
                if grep -iE "$pattern" "$template_file" >/dev/null 2>&1; then
                    echo "SECRET_EXPOSURE: $template_file | $pattern" >> "$test_output"
                    ((issues++))
                    log_error "Potential secret exposure in template: $template_file"
                fi
            done
        fi
    done < <(find "$TEMPLATES_DIR" -type f -print0 2>/dev/null)
    
    if [[ $issues -eq 0 ]]; then
        log_success "Secret exposure tests passed"
        return 0
    else
        log_error "Secret exposure tests found $issues potential issues"
        return 1
    fi
}

# Test template variable handling
test_variable_handling() {
    log_test "Testing template variable handling security..."
    
    local issues=0
    local test_output="${LOG_DIR}/variable-handling-$(date +%Y%m%d-%H%M%S).log"
    
    # Create a temporary test template
    local test_template="/tmp/security_test_template.txt"
    cat > "$test_template" << 'EOF'
User: ${USER}
Home: ${HOME}
Test: ${TEST_VAR}
Secret: ${SECRET_KEY}
EOF
    
    # Test with various environment configurations
    export TEST_VAR="safe_value"
    export SECRET_KEY="this_should_not_appear"
    
    # Process template with envsubst
    if command -v envsubst >/dev/null 2>&1; then
        local result
        result=$(envsubst < "$test_template" 2>/dev/null || echo "ERROR")
        
        # Check if secrets leaked through
        if echo "$result" | grep -q "this_should_not_appear"; then
            echo "SECRET_LEAK: envsubst exposed SECRET_KEY" >> "$test_output"
            ((issues++))
            log_error "Secret leaked through template processing"
        fi
        
        log_debug "Template processing result: $result"
    fi
    
    # Test variable substitution edge cases
    local edge_cases=(
        '${PATH:0:1000000}'  # Potential buffer overflow
        '${!HOME}'           # Variable indirection
        '${USER[0]}'         # Array access
        '${#USER}'           # String length
    )
    
    for edge_case in "${edge_cases[@]}"; do
        local test_result
        test_result=$(echo "$edge_case" | envsubst 2>/dev/null || echo "ERROR")
        
        if [[ "$test_result" != "ERROR" ]] && [[ "$test_result" != "$edge_case" ]]; then
            echo "EDGE_CASE_EXPOSURE: $edge_case | $test_result" >> "$test_output"
            log_warn "Edge case variable expansion: $edge_case -> $test_result"
        fi
    done
    
    # Cleanup
    rm -f "$test_template"
    unset TEST_VAR SECRET_KEY
    
    if [[ $issues -eq 0 ]]; then
        log_success "Variable handling tests passed"
        return 0
    else
        log_error "Variable handling tests found $issues issues"
        return 1
    fi
}

# Test template error handling
test_error_handling() {
    log_test "Testing template error handling..."
    
    local issues=0
    local test_output="${LOG_DIR}/error-handling-$(date +%Y%m%d-%H%M%S).log"
    
    # Create test templates with various error conditions
    local test_dir="/tmp/template_security_tests"
    mkdir -p "$test_dir"
    
    # Test 1: Missing variable
    echo '${NONEXISTENT_VARIABLE}' > "$test_dir/missing_var.tmpl"
    
    # Test 2: Malformed variable
    echo '${INCOMPLETE_VAR' > "$test_dir/malformed.tmpl"
    
    # Test 3: Nested variables
    echo '${${USER}}' > "$test_dir/nested.tmpl"
    
    # Process each test template
    for test_file in "$test_dir"/*.tmpl; do
        if [[ -f "$test_file" ]]; then
            log_debug "Testing error handling for: $(basename "$test_file")"
            
            local result
            local error_output
            
            # Capture both stdout and stderr
            result=$(envsubst < "$test_file" 2>&1 || echo "PROCESSING_ERROR")
            
            # Check if error reveals sensitive information
            if echo "$result" | grep -iE "(password|secret|key|token)" >/dev/null; then
                echo "ERROR_INFO_LEAK: $(basename "$test_file") | $result" >> "$test_output"
                ((issues++))
                log_error "Error message leaked sensitive information: $(basename "$test_file")"
            fi
            
            log_debug "Error handling result for $(basename "$test_file"): $result"
        fi
    done
    
    # Cleanup
    rm -rf "$test_dir"
    
    if [[ $issues -eq 0 ]]; then
        log_success "Error handling tests passed"
        return 0
    else
        log_error "Error handling tests found $issues issues"
        return 1
    fi
}

# Test file inclusion vulnerabilities
test_file_inclusion() {
    if [[ "$FAST_MODE" == "true" ]]; then
        log_info "Skipping file inclusion tests (fast mode)"
        return 0
    fi
    
    log_test "Testing file inclusion vulnerabilities..."
    
    local issues=0
    local test_output="${LOG_DIR}/file-inclusion-$(date +%Y%m%d-%H%M%S).log"
    
    # Look for template include patterns that might be vulnerable
    local include_patterns=(
        'include\s+'
        'source\s+'
        'import\s+'
        '\{\{\s*include'
        '\[\[\s*include'
        'require\s*\('
        'load\s*\('
    )
    
    while IFS= read -r -d '' template_file; do
        if [[ -f "$template_file" ]]; then
            for pattern in "${include_patterns[@]}"; do
                if grep -iE "$pattern" "$template_file" >/dev/null 2>&1; then
                    # Check if the include path can be manipulated
                    local include_line
                    include_line=$(grep -iE "$pattern" "$template_file" | head -1)
                    
                    if echo "$include_line" | grep -E '\$\{|\{\{' >/dev/null; then
                        echo "DYNAMIC_INCLUDE: $template_file | $include_line" >> "$test_output"
                        ((issues++))
                        log_error "Dynamic file inclusion found: $template_file"
                    fi
                    
                    log_debug "Include pattern found: $template_file - $include_line"
                fi
            done
        fi
    done < <(find "$TEMPLATES_DIR" -type f -print0 2>/dev/null)
    
    if [[ $issues -eq 0 ]]; then
        log_success "File inclusion tests passed"
        return 0
    else
        log_error "File inclusion tests found $issues vulnerabilities"
        return 1
    fi
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Starting template security testing..."
    log_info "Repository: $REPO_ROOT"
    log_info "Templates directory: $TEMPLATES_DIR"
    log_info "Fast mode: $FAST_MODE"
    
    # Setup
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
    
    local total_issues=0
    local failed_tests=()
    
    # Run all security tests
    if ! test_template_structure; then
        ((total_issues++))
        failed_tests+=("Template Structure")
    fi
    
    if ! test_template_injection; then
        ((total_issues++))
        failed_tests+=("Template Injection")
    fi
    
    if ! test_secret_exposure; then
        ((total_issues++))
        failed_tests+=("Secret Exposure")
    fi
    
    if ! test_variable_handling; then
        ((total_issues++))
        failed_tests+=("Variable Handling")
    fi
    
    if ! test_error_handling; then
        ((total_issues++))
        failed_tests+=("Error Handling")
    fi
    
    if ! test_file_inclusion; then
        ((total_issues++))
        failed_tests+=("File Inclusion")
    fi
    
    # Summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "Template security testing completed in ${duration}s"
    
    if [[ $total_issues -eq 0 ]]; then
        log_success "🎉 All template security tests passed!"
    else
        log_error "⚠️  Template security tests failed: ${failed_tests[*]}"
        log_error "Review the findings and fix template vulnerabilities."
    fi
    
    # In report-only mode, always exit 0
    if [[ "$REPORT_ONLY" == "true" ]]; then
        log_info "Report-only mode: Exit code forced to 0"
        total_issues=0
    fi
    
    exit $total_issues
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi 