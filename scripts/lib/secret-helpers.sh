#!/usr/bin/env bash
# 1Password CLI Secret Helper Functions
# Provides utilities for retrieving and managing secrets

# Get the directory where this script is located
SECRET_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment detection
if [[ -f "$SECRET_HELPERS_DIR/../op-env-detect.sh" ]]; then
    export OP_ACCOUNT_ALIAS=${OP_ACCOUNT_ALIAS:-$("$SECRET_HELPERS_DIR/../op-env-detect.sh" 2>/dev/null || echo "personal")}
fi

# Check if signed in to 1Password
op_check_signin() {
    local account=${1:-$OP_ACCOUNT_ALIAS}
    # Map work alias to actual account
    if [[ "$account" == "work" ]]; then
        account="datadog.1password.com"
    fi
    if op account get --account "$account" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Ensure signed in to 1Password
op_ensure_signin() {
    local account=${1:-$OP_ACCOUNT_ALIAS}
    # Map work alias to actual account
    if [[ "$account" == "work" ]]; then
        account="datadog.1password.com"
    fi
    if ! op_check_signin "$account"; then
        echo "Not signed in to 1Password account: $account" >&2
        echo "Run: eval \$(op signin --account $account)" >&2
        return 1
    fi
    return 0
}

# Get a secret from 1Password (with fallback to other accounts)
get_secret() {
    local secret_name="$1"
    local field="${2:-password}"
    local vault="${3:-Employee}"
    
    # Try current account first
    if op item get "$secret_name" --vault "$vault" --fields "$field" 2>/dev/null; then
        return 0
    fi
    
    # Try other accounts if the secret wasn't found
    for account in personal work; do
        if [[ "$account" != "$OP_ACCOUNT_ALIAS" ]]; then
            if op item get "$secret_name" --vault "$vault" --fields "$field" --account "$account" 2>/dev/null; then
                return 0
            fi
        fi
    done
    
    # Secret not found
    return 1
}

# Get a secret or return a default value
get_secret_or_default() {
    local secret_name="$1"
    local default_value="$2"
    local field="${3:-password}"
    local vault="${4:-Employee}"
    
    local value
    if value=$(get_secret "$secret_name" "$field" "$vault" 2>/dev/null); then
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Check if a secret exists
secret_exists() {
    local secret_name="$1"
    local vault="${2:-Employee}"
    
    # Check current account
    if op item get "$secret_name" --vault "$vault" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check other accounts
    for account in personal work; do
        if [[ "$account" != "$OP_ACCOUNT_ALIAS" ]]; then
            if op item get "$secret_name" --vault "$vault" --account "$account" >/dev/null 2>&1; then
                return 0
            fi
        fi
    done
    
    return 1
}

# Create or update a secret
set_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local vault="${3:-Employee}"
    local category="${4:-API Credential}"
    local field="${5:-credential}"
    
    # Ensure signed in
    op_ensure_signin || return 1
    
    # Check if secret exists
    if op item get "$secret_name" --vault "$vault" >/dev/null 2>&1; then
        # Update existing
        op item edit "$secret_name" --vault "$vault" "$field=$secret_value" >/dev/null
        echo "Updated secret: $secret_name" >&2
    else
        # Create new
        op item create \
            --category "$category" \
            --title "$secret_name" \
            --vault "$vault" \
            "$field=$secret_value" >/dev/null
        echo "Created secret: $secret_name" >&2
    fi
}

# Load secrets as environment variables
load_secrets() {
    local vault="${1:-Employee}"
    
    # Ensure signed in
    op_ensure_signin || return 1
    
    # Define the secrets to load
    # Format: VARIABLE_NAME:secret_name:field
    local secrets=(
        "GITHUB_TOKEN:GITHUB_TOKEN:credential"
        "GITLAB_TOKEN:GITLAB_TOKEN:credential"
        "ANTHROPIC_API_KEY:ANTHROPIC_API_KEY:credential"
        "AWS_ACCESS_KEY_ID:AWS_ACCESS_KEY_ID:credential"
        "AWS_SECRET_ACCESS_KEY:AWS_SECRET_ACCESS_KEY:credential"
    )
    
    # Work-specific secrets
    if [[ "$OP_ACCOUNT_ALIAS" == "work" ]]; then
        secrets+=(
            "DATADOG_API_KEY:DATADOG_API_KEY:credential"
            "DATADOG_APP_KEY:DATADOG_APP_KEY:credential"
        )
    fi
    
    # Load each secret
    local loaded=0
    local failed=0
    for secret_spec in "${secrets[@]}"; do
        IFS=':' read -r var_name secret_name field <<< "$secret_spec"
        
        if value=$(get_secret "$secret_name" "$field" "$vault" 2>/dev/null); then
            export "$var_name=$value"
            ((loaded++))
        else
            ((failed++))
        fi
    done
    
    echo "Loaded $loaded secrets, $failed not found" >&2
}

# List all secrets in Employee vault
list_secrets() {
    local vault="${1:-Employee}"
    
    echo "Secrets in vault '$vault':" >&2
    echo "Account: $OP_ACCOUNT_ALIAS" >&2
    echo "" >&2
    
    op item list --vault "$vault" --format json | \
        jq -r '.[] | "\(.title) (\(.category))"' | \
        sort
}

# Backup secrets to a file (encrypted)
backup_secrets() {
    local vault="${1:-Employee}"
    local backup_file="${2:-secrets-backup-$(date +%Y%m%d-%H%M%S).json.age}"
    
    # Ensure signed in
    op_ensure_signin || return 1
    
    echo "Backing up vault '$vault' to $backup_file" >&2
    
    # Export vault items
    op item list --vault "$vault" --format json | \
        jq '.' | \
        age -e -a > "$backup_file"
    
    echo "Backup completed: $backup_file" >&2
    echo "To decrypt: age -d $backup_file" >&2
}

# Interactive secret creation
create_secret_interactive() {
    local vault="${1:-Employee}"
    
    # Ensure signed in
    op_ensure_signin || return 1
    
    echo "Create a new secret in vault '$vault'" >&2
    echo "" >&2
    
    read -p "Secret name: " name
    read -p "Secret value: " -s value
    echo "" >&2
    read -p "Category (default: API Credential): " category
    category="${category:-API Credential}"
    
    set_secret "$name" "$value" "$vault" "$category"
}

# Show help
secret_help() {
    cat << EOF
1Password CLI Secret Helper Functions

Available functions:
  get_secret NAME [FIELD] [VAULT]       - Get a secret value
  get_secret_or_default NAME DEFAULT    - Get secret or return default
  secret_exists NAME [VAULT]            - Check if secret exists
  set_secret NAME VALUE [VAULT]         - Create or update a secret
  load_secrets [VAULT]                  - Load secrets as env vars
  list_secrets [VAULT]                  - List all secrets in vault
  backup_secrets [VAULT] [FILE]         - Backup vault to encrypted file
  create_secret_interactive [VAULT]     - Interactive secret creation
  
Current account: $OP_ACCOUNT_ALIAS

Examples:
  # Get a secret
  GITHUB_TOKEN=\$(get_secret "GITHUB_TOKEN" credential)
  
  # Check if signed in
  op_check_signin && echo "Signed in" || echo "Not signed in"
  
  # Load all secrets
  load_secrets
  
  # List secrets
  list_secrets Employee
EOF
}

# If sourced with arguments, run the help
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ $# -gt 0 ]] && [[ "$1" == "help" ]]; then
    secret_help
fi

# ===== CACHING FUNCTIONALITY =====
# Cache configuration
CACHE_DIR="${TMPDIR:-/tmp}/op-cache-$$"
CACHE_TTL="${OP_CACHE_TTL:-300}"  # 5 minutes default
CACHE_ENABLED="${OP_CACHE_ENABLED:-true}"

# Initialize cache
init_cache() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Create cache directory
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
    
    # Set restrictive permissions
    chmod 700 "$CACHE_DIR" 2>/dev/null || return 1
    
    # Clean old cache on init
    clean_cache
}

# Clean expired cache entries
clean_cache() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        return 0
    fi
    
    local now=$(date +%s)
    find "$CACHE_DIR" -type f -name "*.cache" | while read -r cache_file; do
        local timestamp_file="${cache_file%.cache}.timestamp"
        if [[ -f "$timestamp_file" ]]; then
            local cached_time=$(cat "$timestamp_file" 2>/dev/null || echo 0)
            local age=$((now - cached_time))
            if [[ $age -gt $CACHE_TTL ]]; then
                rm -f "$cache_file" "$timestamp_file" 2>/dev/null
            fi
        else
            # No timestamp file, remove cache
            rm -f "$cache_file" 2>/dev/null
        fi
    done
}

# Generate cache key
cache_key() {
    local key="$*"
    echo "$key" | sha256sum | cut -d' ' -f1
}

# Get from cache
cache_get() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 1
    fi
    
    local key=$(cache_key "$@")
    local cache_file="$CACHE_DIR/${key}.cache"
    local timestamp_file="$CACHE_DIR/${key}.timestamp"
    
    if [[ -f "$cache_file" && -f "$timestamp_file" ]]; then
        local cached_time=$(cat "$timestamp_file" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local age=$((now - cached_time))
        
        if [[ $age -lt $CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    return 1
}

# Set cache value
cache_set() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local value="$1"
    shift
    local key=$(cache_key "$@")
    local cache_file="$CACHE_DIR/${key}.cache"
    local timestamp_file="$CACHE_DIR/${key}.timestamp"
    
    # Initialize cache if needed
    [[ -d "$CACHE_DIR" ]] || init_cache
    
    # Write cache files
    echo "$value" > "$cache_file" 2>/dev/null || return 1
    date +%s > "$timestamp_file" 2>/dev/null || return 1
    
    # Set restrictive permissions
    chmod 600 "$cache_file" "$timestamp_file" 2>/dev/null
    
    return 0
}

# Clear all cache
clear_cache() {
    if [[ -d "$CACHE_DIR" ]]; then
        rm -rf "$CACHE_DIR"
    fi
}

# Get secret with caching
get_secret_cached() {
    local secret_name="$1"
    local field="${2:-password}"
    local vault="${3:-Employee}"
    
    # Try cache first
    local cached_value
    if cached_value=$(cache_get "secret" "$secret_name" "$field" "$vault"); then
        echo "$cached_value"
        return 0
    fi
    
    # Get from 1Password
    local value
    if value=$(get_secret "$secret_name" "$field" "$vault"); then
        # Cache the result
        cache_set "$value" "secret" "$secret_name" "$field" "$vault"
        echo "$value"
        return 0
    fi
    
    return 1
}

# Batch retrieve secrets (more efficient for multiple secrets)
get_secrets_batch() {
    local vault="${1:-Employee}"
    shift
    
    # Ensure signed in
    op_ensure_signin || return 1
    
    # Process each secret spec
    for secret_spec in "$@"; do
        # Parse spec: name[:field]
        local secret_name="${secret_spec%%:*}"
        local field="${secret_spec#*:}"
        [[ "$field" == "$secret_spec" ]] && field="password"
        
        # Get secret (with caching)
        if value=$(get_secret_cached "$secret_name" "$field" "$vault"); then
            echo "${secret_name}=${value}"
        else
            echo "${secret_name}=NOT_FOUND" >&2
        fi
    done
}

# Performance timing wrapper
time_function() {
    local func="$1"
    shift
    
    local start=$(date +%s%N)
    "$func" "$@"
    local result=$?
    local end=$(date +%s%N)
    
    local duration=$(( (end - start) / 1000000 ))
    echo "Execution time: ${duration}ms" >&2
    
    return $result
}

# Warm cache by preloading common secrets
warm_cache() {
    local vault="${1:-Employee}"
    
    echo "Warming secret cache..." >&2
    
    local common_secrets=(
        "GITHUB_TOKEN:credential"
        "GITLAB_TOKEN:credential"
        "ANTHROPIC_API_KEY:credential"
        "AWS_ACCESS_KEY_ID:credential"
        "AWS_SECRET_ACCESS_KEY:credential"
    )
    
    local warmed=0
    for secret_spec in "${common_secrets[@]}"; do
        local secret_name="${secret_spec%%:*}"
        local field="${secret_spec#*:}"
        
        if get_secret_cached "$secret_name" "$field" "$vault" >/dev/null 2>&1; then
            ((warmed++))
        fi
    done
    
    echo "Warmed $warmed secrets in cache" >&2
}

# Initialize cache on source
init_cache 2>/dev/null || true 