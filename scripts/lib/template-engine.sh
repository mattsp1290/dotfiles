#!/usr/bin/env bash
# Template Engine for Secret Injection
# Supports multiple template formats and replacement strategies

# Get the directory where this script is located
TEMPLATE_ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secret helpers
if [[ -f "$TEMPLATE_ENGINE_DIR/secret-helpers.sh" ]]; then
    source "$TEMPLATE_ENGINE_DIR/secret-helpers.sh"
else
    # Only exit if we're being executed directly, not sourced
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "Error: secret-helpers.sh not found" >&2
        exit 1
    fi
fi

# Template formats configuration
# Using separate variables instead of associative array for compatibility
TEMPLATE_FORMAT_ENV='${([A-Z_][A-Z0-9_]*)}'                          # ${SECRET_NAME}
TEMPLATE_FORMAT_ENV_SIMPLE='\$([A-Z_][A-Z0-9_]*)'                    # $SECRET_NAME
TEMPLATE_FORMAT_GO='{{ *op://Employee/([^/]+)/([^}]+) *}}'           # {{ op://Employee/SECRET_NAME/field }}
TEMPLATE_FORMAT_CUSTOM='%%([A-Z_][A-Z0-9_]*)%%'                      # %%SECRET_NAME%%
TEMPLATE_FORMAT_DOUBLE_BRACE='{{([A-Z_][A-Z0-9_]*)}}'                # {{SECRET_NAME}}

# Default format
DEFAULT_FORMAT="env"

# Debug mode
DEBUG="${TEMPLATE_DEBUG:-false}"

# Dry run mode
DRY_RUN="${TEMPLATE_DRY_RUN:-false}"

# Debug output
debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Detect template format in content
detect_template_format() {
    local content="$1"
    local detected_formats=()
    
    # Check each format with literal patterns
    if [[ "$content" =~ \$\{[A-Z_][A-Z0-9_]*\} ]]; then
        detected_formats+=("env")
        debug "Detected format: env"
    fi
    
    if [[ "$content" =~ \$[A-Z_][A-Z0-9_]* ]]; then
        detected_formats+=("env-simple")
        debug "Detected format: env-simple"
    fi
    
    if [[ "$content" =~ \{\{\ *op://Employee/[^/]+/[^}]+\ *\}\} ]]; then
        detected_formats+=("go")
        debug "Detected format: go"
    fi
    
    if [[ "$content" =~ %%[A-Z_][A-Z0-9_]*%% ]]; then
        detected_formats+=("custom")
        debug "Detected format: custom"
    fi
    
    if [[ "$content" =~ \{\{[A-Z_][A-Z0-9_]*\}\} ]]; then
        detected_formats+=("double-brace")
        debug "Detected format: double-brace"
    fi
    
    # Return first detected format or empty
    if [[ ${#detected_formats[@]} -gt 0 ]]; then
        echo "${detected_formats[0]}"
    fi
}

# Extract tokens from content
extract_tokens() {
    local content="$1"
    local format="${2:-$DEFAULT_FORMAT}"
    
    # Get pattern for format
    local pattern=""
    case "$format" in
        "env") pattern="$TEMPLATE_FORMAT_ENV" ;;
        "env-simple") pattern="$TEMPLATE_FORMAT_ENV_SIMPLE" ;;
        "go") pattern="$TEMPLATE_FORMAT_GO" ;;
        "custom") pattern="$TEMPLATE_FORMAT_CUSTOM" ;;
        "double-brace") pattern="$TEMPLATE_FORMAT_DOUBLE_BRACE" ;;
        *)
            echo "Error: Unknown template format: $format" >&2
            return 1
            ;;
    esac
    
    # Extract all matches
    local tokens=()
    
    case "$format" in
        "env")
            # Extract ${VAR} style
            while [[ "$content" =~ \$\{([A-Z_][A-Z0-9_]*)\} ]]; do
                tokens+=("${BASH_REMATCH[1]}")
                content="${content//${BASH_REMATCH[0]}/}"
            done
            ;;
        "env-simple")
            # Extract $VAR style (careful with word boundaries)
            # Use grep instead of complex regex for better compatibility
            local matches
            matches=$(echo "$content" | grep -o '\$[A-Z_][A-Z0-9_]*' | sed 's/^\$//')
            while IFS= read -r match; do
                [[ -n "$match" ]] && tokens+=("$match")
            done <<< "$matches"
            ;;
        "go")
            # Extract {{ op://Employee/SECRET/field }} style
            # Simplified regex for better compatibility
            local matches
            matches=$(echo "$content" | grep -o '{{ *op://Employee/[^/]*/[^}]* *}}' | sed -E 's/.*\/([^\/]+)\/[^}]* *}}/\1/')
            while IFS= read -r match; do
                [[ -n "$match" ]] && tokens+=("$match")
            done <<< "$matches"
            ;;
        "custom")
            # Extract %%VAR%% style
            while [[ "$content" =~ %%([A-Z_][A-Z0-9_]*)%% ]]; do
                tokens+=("${BASH_REMATCH[1]}")
                content="${content//${BASH_REMATCH[0]}/}"
            done
            ;;
        "double-brace")
            # Extract {{VAR}} style
            # Simplified for compatibility
            local matches
            matches=$(echo "$content" | grep -o '{{[A-Z_][A-Z0-9_]*}}' | sed 's/[{}]//g')
            while IFS= read -r match; do
                [[ -n "$match" ]] && tokens+=("$match")
            done <<< "$matches"
            ;;
    esac
    
    # Remove duplicates and print
    printf '%s\n' "${tokens[@]}" | sort -u
}

# Replace single token
replace_token() {
    local content="$1"
    local token="$2"
    local value="$3"
    local format="${4:-$DEFAULT_FORMAT}"
    
    case "$format" in
        "env")
            echo "${content//\$\{${token}\}/$value}"
            ;;
        "env-simple")
            # Use word boundary to avoid partial matches
            echo "$content" | sed -E "s/\\\$${token}\b/$value/g"
            ;;
        "go")
            # Replace any field reference for this token
            echo "$content" | sed -E "s|\\{\\{ *op://Employee/${token}/[^}]+ *\\}\\}|$value|g"
            ;;
        "custom")
            echo "${content//%%${token}%%/$value}"
            ;;
        "double-brace")
            echo "${content//\{\{${token}\}\}/$value}"
            ;;
        *)
            echo "$content"
            ;;
    esac
}

# Get secret value with field support
get_secret_value() {
    local token="$1"
    local field="${2:-credential}"
    local vault="${3:-Employee}"
    
    # Check if token contains field specification (TOKEN:field)
    if [[ "$token" =~ ^([^:]+):([^:]+)$ ]]; then
        token="${BASH_REMATCH[1]}"
        field="${BASH_REMATCH[2]}"
    fi
    
    # Get the secret (with caching if available)
    if command -v get_secret_cached >/dev/null 2>&1; then
        get_secret_cached "$token" "$field" "$vault"
    else
        get_secret "$token" "$field" "$vault"
    fi
}

# Process template content
process_template() {
    local content="$1"
    local format="${2:-auto}"
    local vault="${3:-Employee}"
    local missing_ok="${4:-false}"
    
    # Auto-detect format if needed
    if [[ "$format" == "auto" ]]; then
        format=$(detect_template_format "$content")
        if [[ -z "$format" ]]; then
            debug "No template format detected, using default: $DEFAULT_FORMAT"
            format="$DEFAULT_FORMAT"
        else
            debug "Auto-detected format: $format"
        fi
    fi
    
    # Extract tokens
    local tokens
    tokens=$(extract_tokens "$content" "$format")
    
    if [[ -z "$tokens" ]]; then
        debug "No tokens found in content"
        echo "$content"
        return 0
    fi
    
    # Process each token
    local processed="$content"
    local failed_tokens=()
    
    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        
        debug "Processing token: $token"
        
        # Get secret value
        local value
        if value=$(get_secret_value "$token" "credential" "$vault" 2>/dev/null); then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "[DRY RUN] Would replace $token with value (length: ${#value})" >&2
            else
                processed=$(replace_token "$processed" "$token" "$value" "$format")
            fi
        else
            failed_tokens+=("$token")
            if [[ "$missing_ok" != "true" ]]; then
                echo "Error: Failed to retrieve secret: $token" >&2
            else
                debug "Secret not found (ignored): $token"
            fi
        fi
    done <<< "$tokens"
    
    # Report results
    if [[ ${#failed_tokens[@]} -gt 0 && "$missing_ok" != "true" ]]; then
        echo "Failed to retrieve secrets: ${failed_tokens[*]}" >&2
        return 1
    fi
    
    echo "$processed"
}

# Process template file
process_template_file() {
    local input_file="$1"
    local output_file="${2:-}"
    local format="${3:-auto}"
    local vault="${4:-Employee}"
    local missing_ok="${5:-false}"
    
    # Check input file
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file not found: $input_file" >&2
        return 1
    fi
    
    # Check if file is binary
    if file --mime-encoding "$input_file" 2>/dev/null | grep -q "binary"; then
        echo "Error: Cannot process binary file: $input_file" >&2
        return 1
    fi
    
    # Read content
    local content
    content=$(<"$input_file")
    
    # Process template
    local processed
    if ! processed=$(process_template "$content" "$format" "$vault" "$missing_ok"); then
        return 1
    fi
    
    # Output
    if [[ -z "$output_file" ]] || [[ "$output_file" == "-" ]]; then
        echo "$processed"
    else
        # Atomic write (write to temp, then move)
        local temp_file
        temp_file=$(mktemp "${output_file}.XXXXXX")
        
        if echo "$processed" > "$temp_file"; then
            # Preserve permissions if updating existing file
            if [[ -f "$output_file" ]]; then
                chmod --reference="$output_file" "$temp_file" 2>/dev/null || true
            fi
            
            # Move atomically
            mv -f "$temp_file" "$output_file"
            debug "Wrote processed template to: $output_file"
        else
            rm -f "$temp_file"
            echo "Error: Failed to write output file: $output_file" >&2
            return 1
        fi
    fi
}

# Validate template syntax
validate_template() {
    local input_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: File not found: $input_file" >&2
        return 1
    fi
    
    local content
    content=$(<"$input_file")
    
    # Auto-detect format
    if [[ "$format" == "auto" ]]; then
        format=$(detect_template_format "$content")
        if [[ -z "$format" ]]; then
            echo "No template tokens detected"
            return 0
        fi
    fi
    
    # Extract tokens
    local tokens
    tokens=$(extract_tokens "$content" "$format")
    
    if [[ -z "$tokens" ]]; then
        echo "No tokens found (format: $format)"
        return 0
    fi
    
    echo "Template format: $format"
    echo "Found tokens:"
    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        echo "  - $token"
    done <<< "$tokens"
    
    return 0
}

# Show template diff
diff_template() {
    local input_file="$1"
    local format="${2:-auto}"
    local vault="${3:-Employee}"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: File not found: $input_file" >&2
        return 1
    fi
    
    # Create temp file with processed content
    local temp_file
    temp_file=$(mktemp)
    
    if process_template_file "$input_file" "$temp_file" "$format" "$vault" true; then
        # Show diff
        if command -v colordiff >/dev/null 2>&1; then
            colordiff -u "$input_file" "$temp_file" || true
        else
            diff -u "$input_file" "$temp_file" || true
        fi
    fi
    
    rm -f "$temp_file"
}

# Template engine help
template_help() {
    cat << EOF
Template Engine for Secret Injection

Supported template formats:
  env          - \${SECRET_NAME} (default)
  env-simple   - \$SECRET_NAME
  go           - {{ op://Employee/SECRET_NAME/field }}
  custom       - %%SECRET_NAME%%
  double-brace - {{SECRET_NAME}}

Functions:
  process_template CONTENT [FORMAT] [VAULT]        - Process template string
  process_template_file FILE [OUT] [FORMAT]         - Process template file
  validate_template FILE [FORMAT]                   - Validate template syntax
  diff_template FILE [FORMAT] [VAULT]               - Show diff preview
  extract_tokens CONTENT [FORMAT]                   - Extract token list
  detect_template_format CONTENT                    - Auto-detect format

Environment variables:
  TEMPLATE_DEBUG=true      - Enable debug output
  TEMPLATE_DRY_RUN=true    - Preview changes without applying

Examples:
  # Process a template file
  process_template_file ~/.aws/credentials.template ~/.aws/credentials

  # Validate template
  validate_template config.template

  # Preview changes
  TEMPLATE_DRY_RUN=true process_template_file config.template
EOF
}

# Export functions for use by other scripts
export -f process_template
export -f process_template_file
export -f validate_template
export -f extract_tokens
export -f detect_template_format 