#!/usr/bin/env bash
# Diff Templates - Show what would change after secret injection
# Wrapper script for the diff_template function

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/secret-helpers.sh"
source "$SCRIPT_DIR/lib/template-engine.sh"

# Script info
PROGRAM_NAME=$(basename "$0")
VERSION="1.0.0"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Print functions
print_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Usage
usage() {
    cat << EOF
$PROGRAM_NAME - Show template injection diff v$VERSION

USAGE:
    $PROGRAM_NAME [OPTIONS] FILE...
    $PROGRAM_NAME --help

DESCRIPTION:
    Shows a diff preview of what would change if secrets were injected
    into the template files. No files are modified.

OPTIONS:
    -f, --format FORMAT    Template format (env, env-simple, go, custom, double-brace, auto)
                          Default: auto
    -v, --vault VAULT     1Password vault name
                          Default: Employee
    -c, --color           Force colored output
    --no-color            Disable colored output
    -h, --help            Show this help message

EXAMPLES:
    # Show diff for a single file
    $PROGRAM_NAME ~/.aws/credentials.template

    # Show diff for multiple files
    $PROGRAM_NAME templates/*.tmpl

    # Use specific format
    $PROGRAM_NAME --format go config.template

EOF
}

# Main function
main() {
    local files=()
    local format="auto"
    local vault="Employee"
    local use_color="auto"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -v|--vault)
                vault="$2"
                shift 2
                ;;
            -c|--color)
                use_color="always"
                shift
                ;;
            --no-color)
                use_color="never"
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
    
    # Check 1Password connection
    if ! op_check_signin; then
        print_error "Not signed in to 1Password"
        print_info "Run: eval \$(op signin)"
        exit 1
    fi
    
    # Set up diff command
    local diff_cmd="diff"
    if [[ "$use_color" == "always" ]] || ([[ "$use_color" == "auto" ]] && [[ -t 1 ]]); then
        if command -v colordiff >/dev/null 2>&1; then
            diff_cmd="colordiff"
        fi
    fi
    
    # Process each file
    local processed=0
    local failed=0
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "File not found: $file"
            ((failed++))
            continue
        fi
        
        print_info "Showing diff for: $file"
        
        # Create temp file with processed content
        local temp_file
        temp_file=$(mktemp)
        
        if process_template_file "$file" "$temp_file" "$format" "$vault" true >/dev/null 2>&1; then
            # Show diff
            $diff_cmd -u "$file" "$temp_file" || true
            ((processed++))
        else
            print_error "Failed to process: $file"
            ((failed++))
        fi
        
        rm -f "$temp_file"
        echo
    done
    
    # Summary
    if [[ $failed -gt 0 ]]; then
        print_error "Processed: $processed, Failed: $failed"
        exit 1
    else
        print_info "Processed: $processed files"
    fi
}

# Run main
main "$@" 