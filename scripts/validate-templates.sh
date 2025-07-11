#!/usr/bin/env bash
# Validate Template Files
# Check template syntax and list required secrets

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source template engine
source "$SCRIPT_DIR/lib/template-engine.sh"
source "$SCRIPT_DIR/lib/secret-helpers.sh"

# Configuration
CHECK_SECRETS="${CHECK_SECRETS:-true}"
VERBOSE="${VERBOSE:-false}"

# Colors
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    NC=''
fi

# Print functions
print_header() {
    echo -e "${BLUE}=== $* ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $*"
}

print_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Usage
usage() {
    cat << EOF
Validate Template Files

USAGE:
    $(basename "$0") [OPTIONS] FILE|DIRECTORY...

OPTIONS:
    -n, --no-check     Don't check if secrets exist
    -v, --verbose      Show detailed output
    -h, --help         Show this help message

DESCRIPTION:
    Validates template files for:
    - Correct syntax
    - Template format detection
    - Lists required secrets
    - Checks if secrets exist in 1Password (optional)

EXAMPLES:
    # Validate a single file
    $(basename "$0") ~/.aws/credentials.template

    # Validate multiple files
    $(basename "$0") ~/.aws/*.template

    # Validate without checking secret existence
    $(basename "$0") --no-check config.tmpl

    # Validate all templates in a directory
    $(basename "$0") ~/templates/

EOF
}

# Validate single file
validate_file() {
    local file="$1"
    local has_errors=false
    
    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi
    
    echo -e "\n${BLUE}Validating:${NC} ${file/$HOME/~}"
    
    # Read content
    local content
    content=$(<"$file")
    
    # Detect format
    local format
    format=$(detect_template_format "$content")
    
    if [[ -z "$format" ]]; then
        print_warning "No template tokens detected"
        return 0
    fi
    
    echo "  Format: $format"
    
    # Extract tokens
    local tokens
    tokens=$(extract_tokens "$content" "$format")
    
    if [[ -z "$tokens" ]]; then
        print_warning "No tokens found (empty template?)"
        return 0
    fi
    
    # Count tokens
    local token_count
    token_count=$(echo "$tokens" | wc -l)
    echo "  Tokens: $token_count found"
    
    # List tokens
    echo -e "\n  ${BLUE}Required Secrets:${NC}"
    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        
        # Check if secret exists
        if [[ "$CHECK_SECRETS" == "true" ]]; then
            if secret_exists "$token"; then
                echo -e "    ${GREEN}✓${NC} $token"
            else
                echo -e "    ${RED}✗${NC} $token (not found in 1Password)"
                has_errors=true
            fi
        else
            echo "    • $token"
        fi
    done <<< "$tokens"
    
    # Try to process template to check for syntax errors
    echo -e "\n  ${BLUE}Syntax Check:${NC}"
    local temp_output
    temp_output=$(mktemp)
    
    if TEMPLATE_DRY_RUN=true process_template_file "$file" "$temp_output" "$format" "Employee" true >/dev/null 2>&1; then
        print_success "Valid syntax"
    else
        print_error "Syntax errors detected"
        has_errors=true
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  Error details:"
            TEMPLATE_DEBUG=true TEMPLATE_DRY_RUN=true process_template_file "$file" "$temp_output" "$format" "Employee" true 2>&1 | sed 's/^/    /'
        fi
    fi
    
    rm -f "$temp_output"
    
    # Check for common issues
    echo -e "\n  ${BLUE}Common Issues:${NC}"
    local issues_found=false
    
    # Check for mixed formats
    local format_count=0
    for fmt in env env-simple go custom double-brace; do
        if [[ -n "$(extract_tokens "$content" "$fmt" 2>/dev/null)" ]]; then
            ((format_count++))
        fi
    done
    
    if [[ $format_count -gt 1 ]]; then
        print_warning "Mixed template formats detected"
        issues_found=true
    fi
    
    # Check for lowercase tokens (usually should be uppercase)
    if echo "$content" | grep -qE '\$\{[a-z_][a-z0-9_]*\}|\$[a-z_][a-z0-9_]*\b|%%[a-z_][a-z0-9_]*%%'; then
        print_warning "Lowercase tokens detected (should be UPPERCASE?)"
        issues_found=true
    fi
    
    # Check for potential typos in common secret names
    local common_typos=(
        "GITHUB_TOKNE:GITHUB_TOKEN"
        "GIHUB_TOKEN:GITHUB_TOKEN"
        "AWS_ACESS_KEY:AWS_ACCESS_KEY_ID"
        "AWS_SECERT:AWS_SECRET_ACCESS_KEY"
    )
    
    for typo_spec in "${common_typos[@]}"; do
        IFS=':' read -r typo correct <<< "$typo_spec"
        if echo "$tokens" | grep -q "^$typo$"; then
            print_warning "Possible typo: $typo (did you mean $correct?)"
            issues_found=true
        fi
    done
    
    if [[ "$issues_found" != "true" ]]; then
        print_success "No common issues found"
    fi
    
    # Summary
    echo
    if [[ "$has_errors" == "true" ]]; then
        print_error "Validation failed"
        return 1
    else
        print_success "Validation passed"
        return 0
    fi
}

# Main execution
main() {
    local files=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -n|--no-check)
                CHECK_SECRETS="false"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done
    
    # Check if files specified
    if [[ ${#files[@]} -eq 0 ]]; then
        print_error "No files specified"
        usage
        exit 1
    fi
    
    # Check 1Password connection if checking secrets
    if [[ "$CHECK_SECRETS" == "true" ]]; then
        if ! op_check_signin; then
            print_warning "Not signed in to 1Password - skipping secret existence checks"
            CHECK_SECRETS="false"
        fi
    fi
    
    # Process files
    print_header "Template Validation"
    
    local total=0
    local passed=0
    local failed=0
    
    for file_spec in "${files[@]}"; do
        # Handle directories
        if [[ -d "$file_spec" ]]; then
            while IFS= read -r -d '' file; do
                total=$((total + 1))
                if validate_file "$file"; then
                    passed=$((passed + 1))
                else
                    failed=$((failed + 1))
                fi
            done < <(find "$file_spec" -type f \( -name "*.template" -o -name "*.tmpl" -o -name "*.tpl" \) -print0)
        else
            # Handle single files and file globs
            # First check if it's a literal file
            if [[ -f "$file_spec" ]]; then
                total=$((total + 1))
                if validate_file "$file_spec"; then
                    passed=$((passed + 1))
                else
                    failed=$((failed + 1))
                fi
            else
                # Try as a glob pattern
                shopt -s nullglob
                local matched=false
                for file in $file_spec; do
                    if [[ -f "$file" ]]; then
                        matched=true
                        total=$((total + 1))
                        if validate_file "$file"; then
                            passed=$((passed + 1))
                        else
                            failed=$((failed + 1))
                        fi
                    fi
                done
                shopt -u nullglob
                
                if [[ "$matched" == "false" ]]; then
                    print_error "No files found matching: $file_spec"
                    failed=$((failed + 1))
                    total=$((total + 1))
                fi
            fi
        fi
    done
    
    # Summary
    echo
    print_header "Summary"
    echo "Total files: $total"
    [[ $passed -gt 0 ]] && echo -e "${GREEN}Passed: $passed${NC}"
    [[ $failed -gt 0 ]] && echo -e "${RED}Failed: $failed${NC}"
    
    # Exit code
    [[ $failed -eq 0 ]]
}

# Run main
main "$@" 