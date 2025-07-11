#!/usr/bin/env bash
# Secret Injection Tool
# Main script for injecting secrets into configuration files

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/secret-helpers.sh"
source "$SCRIPT_DIR/lib/template-engine.sh"

# Script configuration
PROGRAM_NAME=$(basename "$0")
VERSION="1.0.0"

# Default values
DEFAULT_FORMAT="auto"
DEFAULT_VAULT="Employee"
DRY_RUN="false"
RECURSIVE="false"
VERBOSE="false"
FORCE="false"
FROM_STDIN="false"
OUTPUT_FILE=""
BACKUP_SUFFIX=".backup"
TEMPLATE_EXTENSIONS=("template" "tmpl" "tpl")

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Print colored output
print_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Verbose output
verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

# Show usage
usage() {
    cat << EOF
$PROGRAM_NAME - Secret Injection Tool v$VERSION

USAGE:
    $PROGRAM_NAME [OPTIONS] FILE|DIRECTORY|-
    $PROGRAM_NAME --help
    $PROGRAM_NAME --version

DESCRIPTION:
    Inject secrets from 1Password into configuration files using templates.

OPTIONS:
    -f, --format FORMAT      Template format (env, env-simple, go, custom, double-brace, auto)
                            Default: $DEFAULT_FORMAT
    -v, --vault VAULT       1Password vault name
                            Default: $DEFAULT_VAULT
    -o, --output FILE       Output file (default: replace input file)
    -r, --recursive         Process directories recursively
    -d, --dry-run          Show what would be changed without modifying files
    -b, --backup           Create backup files before modifying
    --no-backup            Don't create backup files (default)
    --force                Process files even if no templates detected
    --verbose              Enable verbose output
    --stdin                Read from stdin instead of file
    --cache-ttl SECONDS    Set cache TTL (default: 300)
    --no-cache             Disable caching
    --warm-cache           Pre-warm the cache with common secrets
    -h, --help             Show this help message
    --version              Show version information

TEMPLATE FORMATS:
    env          - \${SECRET_NAME} (default)
    env-simple   - \$SECRET_NAME
    go           - {{ op://Employee/SECRET_NAME/field }}
    custom       - %%SECRET_NAME%%
    double-brace - {{SECRET_NAME}}
    auto         - Auto-detect format

EXAMPLES:
    # Process a single file
    $PROGRAM_NAME ~/.aws/credentials.template

    # Process with specific output
    $PROGRAM_NAME -o ~/.aws/credentials ~/.aws/credentials.template

    # Recursive directory processing
    $PROGRAM_NAME -r ~/configs/

    # Dry run to preview changes
    $PROGRAM_NAME --dry-run ~/.aws/credentials.template

    # Process from stdin
    echo '\${GITHUB_TOKEN}' | $PROGRAM_NAME --stdin

    # Use specific format
    $PROGRAM_NAME --format go config.template

    # Create backups before modifying
    $PROGRAM_NAME --backup ~/.gitconfig.template

ENVIRONMENT VARIABLES:
    OP_CACHE_ENABLED    Enable/disable caching (true/false)
    OP_CACHE_TTL        Cache TTL in seconds
    TEMPLATE_DEBUG      Enable debug output (true/false)

EOF
}

# Parse command line arguments
parse_args() {
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                echo "$PROGRAM_NAME v$VERSION"
                exit 0
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -v|--vault)
                VAULT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                export TEMPLATE_DRY_RUN="true"
                shift
                ;;
            -b|--backup)
                CREATE_BACKUP="true"
                shift
                ;;
            --no-backup)
                CREATE_BACKUP="false"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                export TEMPLATE_DEBUG="true"
                shift
                ;;
            --stdin)
                FROM_STDIN="true"
                shift
                ;;
            --cache-ttl)
                export OP_CACHE_TTL="$2"
                shift 2
                ;;
            --no-cache)
                export OP_CACHE_ENABLED="false"
                shift
                ;;
            --warm-cache)
                WARM_CACHE="true"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # Set remaining args
    set -- "${args[@]}"
    
    # Set defaults
    FORMAT="${FORMAT:-$DEFAULT_FORMAT}"
    VAULT="${VAULT:-$DEFAULT_VAULT}"
    CREATE_BACKUP="${CREATE_BACKUP:-false}"
    WARM_CACHE="${WARM_CACHE:-false}"
    
    # Validate input
    if [[ "$FROM_STDIN" == "true" ]]; then
        if [[ $# -gt 0 ]]; then
            print_error "Cannot specify files when using --stdin"
            exit 1
        fi
        INPUT_SOURCE="-"
    else
        if [[ $# -eq 0 ]]; then
            print_error "No input file or directory specified"
            usage
            exit 1
        fi
        INPUT_SOURCE="$1"
    fi
}

# Check if file should be processed
should_process_file() {
    local file="$1"
    
    # Check if it's a template file
    for ext in "${TEMPLATE_EXTENSIONS[@]}"; do
        if [[ "$file" == *."$ext" ]]; then
            return 0
        fi
    done
    
    # If force mode, check if file contains templates
    if [[ "$FORCE" == "true" ]]; then
        local content
        content=$(<"$file" 2>/dev/null) || return 1
        
        if [[ -n "$(detect_template_format "$content")" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Create backup of file
create_backup() {
    local file="$1"
    
    if [[ "$CREATE_BACKUP" == "true" ]] && [[ -f "$file" ]]; then
        local backup="${file}${BACKUP_SUFFIX}"
        cp -p "$file" "$backup"
        verbose "Created backup: $backup"
    fi
}

# Process single file
process_file() {
    local input_file="$1"
    local output_file="${2:-}"
    
    # Determine output file
    if [[ -z "$output_file" ]]; then
        if [[ "$input_file" == *".template" ]]; then
            output_file="${input_file%.template}"
        elif [[ "$input_file" == *".tmpl" ]]; then
            output_file="${input_file%.tmpl}"
        elif [[ "$input_file" == *".tpl" ]]; then
            output_file="${input_file%.tpl}"
        else
            output_file="$input_file"
        fi
    fi
    
    # Check if we should process
    if ! should_process_file "$input_file" && [[ "$FORCE" != "true" ]]; then
        verbose "Skipping non-template file: $input_file"
        return 0
    fi
    
    print_info "Processing: $input_file -> $output_file"
    
    # Validate template first
    if ! validate_template "$input_file" "$FORMAT" >/dev/null 2>&1; then
        print_warning "No templates found in: $input_file"
        if [[ "$FORCE" != "true" ]]; then
            return 0
        fi
    fi
    
    # Create backup if needed
    if [[ "$input_file" == "$output_file" ]]; then
        create_backup "$input_file"
    fi
    
    # Process the template
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Dry run - showing changes:"
        diff_template "$input_file" "$FORMAT" "$VAULT"
    else
        if process_template_file "$input_file" "$output_file" "$FORMAT" "$VAULT"; then
            print_success "Processed: $output_file"
        else
            print_error "Failed to process: $input_file"
            return 1
        fi
    fi
}

# Process directory recursively
process_directory() {
    local dir="$1"
    local count=0
    local errors=0
    
    print_info "Processing directory: $dir"
    
    # Find all potential template files
    while IFS= read -r -d '' file; do
        if process_file "$file"; then
            ((count++))
        else
            ((errors++))
        fi
    done < <(find "$dir" -type f \( -name "*.template" -o -name "*.tmpl" -o -name "*.tpl" \) -print0)
    
    # Also process files with template content if force mode
    if [[ "$FORCE" == "true" ]]; then
        while IFS= read -r -d '' file; do
            # Skip already processed files
            if [[ "$file" == *".template" ]] || [[ "$file" == *".tmpl" ]] || [[ "$file" == *".tpl" ]]; then
                continue
            fi
            
            if process_file "$file"; then
                ((count++))
            else
                ((errors++))
            fi
        done < <(find "$dir" -type f -print0)
    fi
    
    print_info "Processed $count files, $errors errors"
    
    [[ $errors -eq 0 ]]
}

# Process from stdin
process_stdin() {
    local content
    content=$(cat)
    
    if [[ -z "$OUTPUT_FILE" ]] || [[ "$OUTPUT_FILE" == "-" ]]; then
        # Output to stdout
        process_template "$content" "$FORMAT" "$VAULT"
    else
        # Output to file
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "Would write to: $OUTPUT_FILE"
            echo "$content" | process_template - "$FORMAT" "$VAULT"
        else
            create_backup "$OUTPUT_FILE"
            if echo "$content" | process_template - "$FORMAT" "$VAULT" > "$OUTPUT_FILE"; then
                print_success "Wrote output to: $OUTPUT_FILE"
            else
                print_error "Failed to write output"
                return 1
            fi
        fi
    fi
}

# Main execution
main() {
    # Parse arguments
    parse_args "$@"
    
    # Ensure signed in to 1Password
    if ! op_check_signin; then
        print_error "Not signed in to 1Password"
        print_info "Run: eval \$(op signin)"
        exit 1
    fi
    
    # Warm cache if requested
    if [[ "$WARM_CACHE" == "true" ]]; then
        print_info "Warming cache..."
        warm_cache "$VAULT"
    fi
    
    # Process based on input type
    if [[ "$FROM_STDIN" == "true" ]]; then
        process_stdin
    elif [[ -d "$INPUT_SOURCE" ]]; then
        if [[ "$RECURSIVE" == "true" ]]; then
            process_directory "$INPUT_SOURCE"
        else
            print_error "$INPUT_SOURCE is a directory. Use -r for recursive processing."
            exit 1
        fi
    elif [[ -f "$INPUT_SOURCE" ]]; then
        process_file "$INPUT_SOURCE" "$OUTPUT_FILE"
    else
        print_error "Input not found: $INPUT_SOURCE"
        exit 1
    fi
}

# Run main function
main "$@" 