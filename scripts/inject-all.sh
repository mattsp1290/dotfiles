#!/usr/bin/env bash
# Inject All Templates
# Batch process all template files in common locations

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
BACKUP="${BACKUP:-true}"

# Common template locations (relative to home)
TEMPLATE_LOCATIONS=(
    ".aws"
    ".config"
    ".ssh"
    "configs"
    "templates"
    ".templates"
)

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
Inject All Templates - Batch Template Processor

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -d, --dry-run      Preview changes without modifying files
    -n, --no-backup    Don't create backup files
    -v, --verbose      Show detailed output
    -h, --help         Show this help message

DESCRIPTION:
    Finds and processes all template files in common locations:
$(for loc in "${TEMPLATE_LOCATIONS[@]}"; do echo "      ~/$loc"; done)

    Template files are identified by extensions: .template, .tmpl, .tpl

EXAMPLES:
    # Process all templates
    $(basename "$0")

    # Preview changes first
    $(basename "$0") --dry-run

    # Process without backups
    $(basename "$0") --no-backup

ENVIRONMENT:
    DRY_RUN=true     Same as --dry-run
    VERBOSE=true     Same as --verbose
    BACKUP=false     Same as --no-backup

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -n|--no-backup)
            BACKUP="false"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Build inject-secrets options
INJECT_OPTS=()
[[ "$DRY_RUN" == "true" ]] && INJECT_OPTS+=("--dry-run")
[[ "$BACKUP" == "true" ]] && INJECT_OPTS+=("--backup")
[[ "$VERBOSE" == "true" ]] && INJECT_OPTS+=("--verbose")

# Check if inject-secrets exists
if [[ ! -x "$SCRIPT_DIR/inject-secrets.sh" ]]; then
    print_error "inject-secrets.sh not found or not executable"
    exit 1
fi

# Find all template files
print_header "Finding Template Files"

template_files=()
for location in "${TEMPLATE_LOCATIONS[@]}"; do
    full_path="$HOME/$location"
    if [[ -d "$full_path" ]]; then
        while IFS= read -r -d '' file; do
            template_files+=("$file")
        done < <(find "$full_path" -type f \( -name "*.template" -o -name "*.tmpl" -o -name "*.tpl" \) -print0 2>/dev/null)
    fi
done

# Also check current directory if not home
if [[ "$PWD" != "$HOME" ]]; then
    while IFS= read -r -d '' file; do
        template_files+=("$file")
    done < <(find . -maxdepth 3 -type f \( -name "*.template" -o -name "*.tmpl" -o -name "*.tpl" \) -print0 2>/dev/null)
fi

# Remove duplicates
readarray -t template_files < <(printf '%s\n' "${template_files[@]}" | sort -u)

if [[ ${#template_files[@]} -eq 0 ]]; then
    print_warning "No template files found"
    exit 0
fi

echo "Found ${#template_files[@]} template files:"
for file in "${template_files[@]}"; do
    echo "  • ${file/$HOME/~}"
done
echo

# Process templates
print_header "Processing Templates"

if [[ "$DRY_RUN" == "true" ]]; then
    print_warning "Running in dry-run mode - no files will be modified"
    echo
fi

# Statistics
processed=0
failed=0
skipped=0

# Process each template
for template in "${template_files[@]}"; do
    # Determine output file
    output=""
    if [[ "$template" == *.template ]]; then
        output="${template%.template}"
    elif [[ "$template" == *.tmpl ]]; then
        output="${template%.tmpl}"
    elif [[ "$template" == *.tpl ]]; then
        output="${template%.tpl}"
    fi
    
    # Display progress
    echo -n "Processing ${template/$HOME/~} -> ${output/$HOME/~} ... "
    
    # Run inject-secrets
    if "$SCRIPT_DIR/inject-secrets.sh" "${INJECT_OPTS[@]}" "$template" >/dev/null 2>&1; then
        print_success "done"
        ((processed++))
    else
        # Check if it failed because no templates were found
        if "$SCRIPT_DIR/inject-secrets.sh" --dry-run "$template" 2>&1 | grep -q "No templates found"; then
            print_warning "skipped (no secrets)"
            ((skipped++))
        else
            print_error "failed"
            ((failed++))
            if [[ "$VERBOSE" == "true" ]]; then
                "$SCRIPT_DIR/inject-secrets.sh" "${INJECT_OPTS[@]}" "$template" 2>&1 | sed 's/^/    /'
            fi
        fi
    fi
done

echo

# Summary
print_header "Summary"
echo -e "${GREEN}✓ Processed:${NC} $processed"
[[ $skipped -gt 0 ]] && echo -e "${YELLOW}→ Skipped:${NC} $skipped (no secrets found)"
[[ $failed -gt 0 ]] && echo -e "${RED}✗ Failed:${NC} $failed"

# Exit with error if any failed
[[ $failed -eq 0 ]] 