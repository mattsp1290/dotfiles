#!/usr/bin/env bash
# Load Secrets into Environment
# Loads commonly used secrets as environment variables

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secret helpers
source "$SCRIPT_DIR/lib/secret-helpers.sh"

# Configuration
VAULT="${1:-Employee}"
EXPORT_MODE="${2:-export}"  # export or print

# Colors for output
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

# Define secrets to load
# Format: VARIABLE_NAME:secret_name:field
DEFAULT_SECRETS=(
    "GITHUB_TOKEN:GITHUB_TOKEN:credential"
    "GITLAB_TOKEN:GITLAB_TOKEN:credential" 
    "ANTHROPIC_API_KEY:ANTHROPIC_API_KEY:credential"
    "AWS_ACCESS_KEY_ID:AWS_ACCESS_KEY_ID:credential"
    "AWS_SECRET_ACCESS_KEY:AWS_SECRET_ACCESS_KEY:credential"
    "HOMEBREW_GITHUB_API_TOKEN:HOMEBREW_GITHUB_API_TOKEN:credential"
    "OPENAI_API_KEY:OPENAI_API_KEY:credential"
)

# Work-specific secrets
WORK_SECRETS=(
    "DATADOG_API_KEY:DATADOG_API_KEY:credential"
    "DATADOG_APP_KEY:DATADOG_APP_KEY:credential"
    "DD_API_KEY:DATADOG_API_KEY:credential"
    "DD_APP_KEY:DATADOG_APP_KEY:credential"
)

# Personal-specific secrets
PERSONAL_SECRETS=(
    "DIGITALOCEAN_TOKEN:DIGITALOCEAN_TOKEN:credential"
    "CLOUDFLARE_API_TOKEN:CLOUDFLARE_API_TOKEN:credential"
)

# Usage information
usage() {
    cat << EOF
Load Secrets into Environment

USAGE:
    source $0 [VAULT] [MODE]
    eval "\$($0 [VAULT] print)"

ARGUMENTS:
    VAULT   - 1Password vault name (default: Employee)
    MODE    - export or print (default: export)
              export: directly export variables (when sourced)
              print:  print export commands (for eval)

EXAMPLES:
    # Load secrets by sourcing
    source $0

    # Load secrets using eval
    eval "\$($(basename "$0") Employee print)"

    # Load from specific vault
    source $0 Personal

Available secrets will be loaded based on your current account context.
EOF
}

# Check if help requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Ensure signed in
if ! op_check_signin; then
    echo -e "${RED}Error: Not signed in to 1Password${NC}" >&2
    echo "Run: eval \$(op signin)" >&2
    exit 1
fi

# Determine which secrets to load
SECRETS_TO_LOAD=("${DEFAULT_SECRETS[@]}")

# Add context-specific secrets
if [[ "$OP_ACCOUNT_ALIAS" == "work" ]]; then
    SECRETS_TO_LOAD+=("${WORK_SECRETS[@]}")
elif [[ "$OP_ACCOUNT_ALIAS" == "personal" ]]; then  
    SECRETS_TO_LOAD+=("${PERSONAL_SECRETS[@]}")
fi

# Load secrets
echo -e "${GREEN}Loading secrets from vault '$VAULT'...${NC}" >&2

loaded=0
failed=0
skipped=0

# Pre-warm cache if available
if command -v warm_cache >/dev/null 2>&1; then
    warm_cache "$VAULT" >/dev/null 2>&1
fi

for secret_spec in "${SECRETS_TO_LOAD[@]}"; do
    IFS=':' read -r var_name secret_name field <<< "$secret_spec"
    
    # Skip if already set and not empty
    if [[ -n "${!var_name}" ]]; then
        ((skipped++))
        continue
    fi
    
    # Get secret value
    if value=$(get_secret_cached "$secret_name" "$field" "$VAULT" 2>/dev/null); then
        if [[ "$EXPORT_MODE" == "export" ]]; then
            export "$var_name=$value"
        else
            # Print for eval
            printf 'export %s=%q\n' "$var_name" "$value"
        fi
        ((loaded++))
    else
        # Try alternate vaults
        found=false
        for alt_vault in "Employee" "Personal" "Private"; do
            if [[ "$alt_vault" != "$VAULT" ]]; then
                if value=$(get_secret_cached "$secret_name" "$field" "$alt_vault" 2>/dev/null); then
                    if [[ "$EXPORT_MODE" == "export" ]]; then
                        export "$var_name=$value"
                    else
                        printf 'export %s=%q\n' "$var_name" "$value"
                    fi
                    ((loaded++))
                    found=true
                    break
                fi
            fi
        done
        
        if [[ "$found" != "true" ]]; then
            ((failed++))
        fi
    fi
done

# Summary (only in export mode)
if [[ "$EXPORT_MODE" == "export" ]]; then
    echo -e "${GREEN}✓ Loaded $loaded secrets${NC}" >&2
    [[ $skipped -gt 0 ]] && echo -e "${YELLOW}→ Skipped $skipped (already set)${NC}" >&2
    [[ $failed -gt 0 ]] && echo -e "${YELLOW}→ Not found: $failed${NC}" >&2
fi

# Set indicator variable
if [[ "$EXPORT_MODE" == "export" ]]; then
    export OP_SECRETS_LOADED="true"
    export OP_SECRETS_LOADED_AT=$(date +%s)
else
    echo 'export OP_SECRETS_LOADED="true"'
    echo "export OP_SECRETS_LOADED_AT=$(date +%s)"
fi 