#!/usr/bin/env bash
# Secret Injection System Shell Integration
# Add this to your ~/.bashrc, ~/.zshrc, or shell initialization file:
#   source ~/dotfiles/templates/shell/secret-injection-init.sh

# Check if dotfiles directory is set
if [[ -z "${DOTFILES_DIR}" ]]; then
    # Try to detect dotfiles directory
    if [[ -d "$HOME/dotfiles" ]]; then
        export DOTFILES_DIR="$HOME/dotfiles"
    elif [[ -d "$HOME/.dotfiles" ]]; then
        export DOTFILES_DIR="$HOME/.dotfiles"
    else
        echo "Warning: DOTFILES_DIR not set and dotfiles directory not found" >&2
        return 1
    fi
fi

# Check if 1Password CLI is available
if ! command -v op >/dev/null 2>&1; then
    return 0  # Silently skip if op is not installed
fi

# Source secret helpers (provides caching and other functions)
if [[ -f "$DOTFILES_DIR/scripts/lib/secret-helpers.sh" ]]; then
    source "$DOTFILES_DIR/scripts/lib/secret-helpers.sh"
fi

# Aliases for convenience
alias inject-secrets='$DOTFILES_DIR/scripts/inject-secrets.sh'
alias inject-all='$DOTFILES_DIR/scripts/inject-all.sh'
alias validate-templates='$DOTFILES_DIR/scripts/validate-templates.sh'
alias diff-templates='$DOTFILES_DIR/scripts/diff-templates.sh'
alias load-secrets='source $DOTFILES_DIR/scripts/load-secrets.sh'

# Function to quickly inject a single template
inject() {
    local template="$1"
    if [[ -z "$template" ]]; then
        echo "Usage: inject <template-file>" >&2
        return 1
    fi
    "$DOTFILES_DIR/scripts/inject-secrets.sh" "$template"
}

# Function to validate a template
validate() {
    local template="$1"
    if [[ -z "$template" ]]; then
        echo "Usage: validate <template-file>" >&2
        return 1
    fi
    "$DOTFILES_DIR/scripts/validate-templates.sh" "$template"
}

# Optional: Auto-load secrets on shell startup (disabled by default)
# Uncomment the following lines to enable:
# if op_check_signin 2>/dev/null; then
#     source "$DOTFILES_DIR/scripts/load-secrets.sh" 2>/dev/null
# fi

# Optional: Warm cache on shell startup (disabled by default)
# Uncomment the following lines to enable:
# if op_check_signin 2>/dev/null; then
#     (warm_cache >/dev/null 2>&1 &)
# fi

# Function to show secret injection status
secret-status() {
    echo "Secret Injection System Status:"
    echo "  DOTFILES_DIR: $DOTFILES_DIR"
    
    if command -v op >/dev/null 2>&1; then
        echo "  1Password CLI: $(op --version)"
        if op_check_signin 2>/dev/null; then
            echo "  1Password Status: Signed in"
            echo "  Account: ${OP_ACCOUNT_ALIAS:-unknown}"
        else
            echo "  1Password Status: Not signed in"
        fi
    else
        echo "  1Password CLI: Not installed"
    fi
    
    if [[ "${OP_SECRETS_LOADED}" == "true" ]]; then
        echo "  Secrets Loaded: Yes"
        if [[ -n "${OP_SECRETS_LOADED_AT}" ]]; then
            local loaded_ago=$(( $(date +%s) - OP_SECRETS_LOADED_AT ))
            echo "  Loaded: ${loaded_ago}s ago"
        fi
    else
        echo "  Secrets Loaded: No"
    fi
    
    if [[ "${OP_CACHE_ENABLED}" == "true" ]] || [[ -z "${OP_CACHE_ENABLED}" ]]; then
        echo "  Cache: Enabled (TTL: ${OP_CACHE_TTL:-300}s)"
    else
        echo "  Cache: Disabled"
    fi
} 