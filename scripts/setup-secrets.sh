#!/usr/bin/env bash
# 1Password CLI Setup and Management Script
# Handles multiple accounts and provides helper functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if 1Password CLI is installed
check_op_installed() {
    if ! command -v op >/dev/null 2>&1; then
        error "1Password CLI not installed"
        info "Install with: brew install --cask 1password-cli"
        return 1
    fi
    info "1Password CLI version: $(op --version)"
    return 0
}

# Add a 1Password account
add_account() {
    local shorthand=$1
    local signin_address=$2
    local email=$3
    
    info "Adding 1Password account: $shorthand"
    info "Sign-in address: $signin_address"
    info "Email: $email"
    
    if op account get --account "$shorthand" >/dev/null 2>&1; then
        warn "Account '$shorthand' already exists"
        return 0
    fi
    
    op account add \
        --address "$signin_address" \
        --email "$email" \
        --shorthand "$shorthand"
    
    success "Account '$shorthand' added successfully"
}

# Interactive account setup
setup_accounts() {
    info "Setting up 1Password accounts for dotfiles"
    echo
    
    # Personal account
    read -p "Do you want to set up a personal account? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Personal account sign-in address (e.g., my.1password.com): " personal_address
        read -p "Personal account email: " personal_email
        add_account "personal" "$personal_address" "$personal_email"
    fi
    
    echo
    
    # Work account
    read -p "Do you want to set up a work account? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Work account sign-in address (e.g., company.1password.com): " work_address
        read -p "Work account email: " work_email
        add_account "work" "$work_address" "$work_email"
    fi
}

# Create development vault
create_vault() {
    local account=$1
    local vault_name="Development"
    
    info "Creating '$vault_name' vault in account '$account'"
    
    # Sign in to the account
    if ! op account get --account "$account" >/dev/null 2>&1; then
        error "Not signed in to account '$account'"
        info "Run: eval \$(op signin --account $account)"
        return 1
    fi
    
    # Check if vault exists
    if op vault get "$vault_name" --account "$account" >/dev/null 2>&1; then
        warn "Vault '$vault_name' already exists in account '$account'"
        return 0
    fi
    
    # Create vault
    if op vault create "$vault_name" --account "$account" >/dev/null; then
        success "Created vault '$vault_name' in account '$account'"
    else
        error "Failed to create vault '$vault_name' in account '$account'"
        return 1
    fi
}

# List all configured accounts
list_accounts() {
    info "Configured 1Password accounts:"
    op account list
}

# Test environment detection
test_env_detection() {
    info "Testing environment detection..."
    
    local detected_env=$("$SCRIPT_DIR/op-env-detect.sh")
    info "Detected environment: $detected_env"
    
    echo
    info "Detection methods checked:"
    echo "  - Hostname: $(hostname)"
    echo "  - Work directories: $(ls -d ~/work ~/Work /opt/company 2>/dev/null | tr '\n' ' ' || echo 'none found')"
    echo "  - Git email: $(git config --global user.email 2>/dev/null || echo 'not set')"
    echo "  - Override variable: ${OP_ACCOUNT_OVERRIDE:-not set}"
}

# Generate shell integration
generate_shell_integration() {
    info "Generating shell integration code..."
    
    cat << 'EOF'

# Add this to your ~/.zshrc or ~/.bashrc:

# 1Password CLI Integration
if [[ -f "$HOME/git/dotfiles/scripts/op-env-detect.sh" ]]; then
    export OP_ACCOUNT_ALIAS=$("$HOME/git/dotfiles/scripts/op-env-detect.sh" 2>/dev/null || echo "personal")
fi

# Sign in to the detected account
op-signin() {
    local account=${1:-$OP_ACCOUNT_ALIAS}
    echo "Signing in to 1Password account: $account"
    eval $(op signin --account "$account")
}

# Quick switch between accounts
op-work() {
    eval $(op signin --account work)
    export OP_ACCOUNT_ALIAS="work"
}

op-personal() {
    eval $(op signin --account personal)
    export OP_ACCOUNT_ALIAS="personal"
}

# Get current account
op-current() {
    echo "Current account alias: $OP_ACCOUNT_ALIAS"
    if op account get --account "$OP_ACCOUNT_ALIAS" 2>/dev/null; then
        echo "Status: Signed in ✓"
    else
        echo "Status: Not signed in ✗"
    fi
}

# Universal secret getter
get-secret() {
    local secret_name="$1"
    local field="${2:-password}"
    
    # Try current account first
    if op item get "$secret_name" --vault Development --fields "$field" 2>/dev/null; then
        return 0
    fi
    
    # Try other accounts
    for account in personal work; do
        if [[ "$account" != "$OP_ACCOUNT_ALIAS" ]]; then
            if op item get "$secret_name" --vault Development --fields "$field" --account "$account" 2>/dev/null; then
                return 0
            fi
        fi
    done
    
    return 1
}

# Check 1Password status on shell startup
if command -v op >/dev/null 2>&1; then
    if ! op account list >/dev/null 2>&1; then
        echo "1Password CLI not configured. Run: ~/git/dotfiles/scripts/setup-secrets.sh"
    fi
fi
EOF
}

# Main menu
main() {
    check_op_installed || exit 1
    
    echo
    info "1Password CLI Setup for Dotfiles"
    echo "================================="
    echo
    echo "1) Set up 1Password accounts"
    echo "2) List configured accounts"
    echo "3) Create Development vaults"
    echo "4) Test environment detection"
    echo "5) Show shell integration code"
    echo "6) Exit"
    echo
    read -p "Choose an option: " choice
    
    case $choice in
        1)
            setup_accounts
            ;;
        2)
            list_accounts
            ;;
        3)
            for account in personal work; do
                if op account get --account "$account" >/dev/null 2>&1; then
                    create_vault "$account"
                fi
            done
            ;;
        4)
            test_env_detection
            ;;
        5)
            generate_shell_integration
            ;;
        6)
            exit 0
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 