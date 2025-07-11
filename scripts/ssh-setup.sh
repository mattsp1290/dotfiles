#!/usr/bin/env bash

# SSH Setup Script
# Manages SSH configuration setup, key management, and validation
# Part of the dotfiles SSH configuration system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
SSH_CONFIG_DIR="$DOTFILES_DIR/config/ssh"
SSH_HOME="$HOME/.ssh"
BACKUP_DIR="$SSH_HOME.backup.$(date +%Y%m%d_%H%M%S)"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Help function
show_help() {
    cat << EOF
SSH Setup Script

USAGE:
    $(basename "$0") [COMMAND] [OPTIONS]

COMMANDS:
    install     Install SSH configuration using Stow
    backup      Create backup of existing SSH configuration
    validate    Validate SSH configuration
    test        Test SSH connectivity
    keygen      Generate new SSH keys
    audit       Run security audit on SSH configuration
    help        Show this help message

OPTIONS:
    -f, --force     Force installation (overwrite existing)
    -v, --verbose   Verbose output
    -d, --dry-run   Show what would be done without executing

EXAMPLES:
    $(basename "$0") install
    $(basename "$0") backup
    $(basename "$0") validate --verbose
    $(basename "$0") keygen --type ed25519
    $(basename "$0") test github.com

EOF
}

# Backup existing SSH configuration
backup_ssh() {
    log_info "Creating backup of existing SSH configuration..."
    
    if [[ -d "$SSH_HOME" ]]; then
        cp -r "$SSH_HOME" "$BACKUP_DIR"
        log_success "Backup created at $BACKUP_DIR"
    else
        log_warning "No existing SSH directory found to backup"
    fi
}

# Validate SSH configuration syntax
validate_ssh_config() {
    log_info "Validating SSH configuration..."
    
    local config_file="$DOTFILES_DIR/home/.ssh/config"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "SSH config file not found: $config_file"
        return 1
    fi
    
    # Test SSH configuration syntax using -G option (doesn't make connections)
    if ssh -F "$config_file" -G localhost &>/dev/null; then
        log_success "SSH configuration syntax is valid"
    else
        log_error "SSH configuration has syntax errors"
        # Show the actual error for debugging
        ssh -F "$config_file" -G localhost 2>&1 | head -5
        return 1
    fi
}

# Set proper SSH file permissions
set_ssh_permissions() {
    log_info "Setting proper SSH file permissions..."
    
    if [[ -d "$SSH_HOME" ]]; then
        chmod 700 "$SSH_HOME"
        
        # Set permissions for config files
        find "$SSH_HOME" -name "config*" -type f -exec chmod 600 {} \;
        
        # Set permissions for private keys
        find "$SSH_HOME" -name "id_*" -not -name "*.pub" -type f -exec chmod 600 {} \;
        
        # Set permissions for public keys
        find "$SSH_HOME" -name "*.pub" -type f -exec chmod 644 {} \;
        
        # Set permissions for known_hosts
        if [[ -f "$SSH_HOME/known_hosts" ]]; then
            chmod 600 "$SSH_HOME/known_hosts"
        fi
        
        log_success "SSH file permissions set correctly"
    else
        log_warning "SSH directory does not exist"
    fi
}

# Install SSH configuration using Stow
install_ssh() {
    local force_install=${1:-false}
    
    log_info "Installing SSH configuration..."
    
    # Create backup if not forcing and files exist
    if [[ "$force_install" != "true" ]] && [[ -d "$SSH_HOME" ]]; then
        backup_ssh
    fi
    
    # Ensure SSH directory exists
    mkdir -p "$SSH_HOME"
    
    # Use Stow to create symlinks
    cd "$DOTFILES_DIR"
    
    if [[ "$force_install" == "true" ]]; then
        stow --restow --target="$HOME" home
    else
        stow --target="$HOME" home
    fi
    
    # Set proper permissions
    set_ssh_permissions
    
    log_success "SSH configuration installed successfully"
}

# Generate new SSH keys
generate_ssh_key() {
    local key_type="${1:-ed25519}"
    local key_comment="${2:-$(whoami)@$(hostname)}"
    local key_file="${3:-$SSH_HOME/id_$key_type}"
    
    log_info "Generating new SSH key: $key_type"
    
    case "$key_type" in
        ed25519)
            ssh-keygen -t ed25519 -C "$key_comment" -f "$key_file"
            ;;
        rsa)
            ssh-keygen -t rsa -b 4096 -C "$key_comment" -f "$key_file"
            ;;
        ecdsa)
            ssh-keygen -t ecdsa -b 521 -C "$key_comment" -f "$key_file"
            ;;
        *)
            log_error "Unsupported key type: $key_type"
            return 1
            ;;
    esac
    
    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "$key_file.pub"
    
    log_success "SSH key generated: $key_file"
    log_info "Public key:"
    cat "$key_file.pub"
}

# Test SSH connectivity
test_ssh_connection() {
    local host="${1:-github.com}"
    
    log_info "Testing SSH connection to $host..."
    
    if ssh -T "$host" &>/dev/null; then
        log_success "SSH connection to $host successful"
    else
        log_warning "SSH connection to $host failed (this may be expected for some hosts)"
        # Show actual connection attempt for debugging
        ssh -T "$host" || true
    fi
}

# Run SSH security audit
audit_ssh() {
    log_info "Running SSH security audit..."
    
    local issues=0
    
    # Check SSH directory permissions
    if [[ -d "$SSH_HOME" ]]; then
        local ssh_perms=$(stat -c %a "$SSH_HOME" 2>/dev/null || stat -f %A "$SSH_HOME" 2>/dev/null || echo "unknown")
        if [[ "$ssh_perms" != "700" ]]; then
            log_warning "SSH directory permissions are $ssh_perms (should be 700)"
            ((issues++))
        fi
    fi
    
    # Check for private keys with wrong permissions
    while IFS= read -r -d '' key_file; do
        local key_perms=$(stat -c %a "$key_file" 2>/dev/null || stat -f %A "$key_file" 2>/dev/null || echo "unknown")
        if [[ "$key_perms" != "600" ]]; then
            log_warning "Private key $key_file has permissions $key_perms (should be 600)"
            ((issues++))
        fi
    done < <(find "$SSH_HOME" -name "id_*" -not -name "*.pub" -type f -print0 2>/dev/null || true)
    
    # Check for weak key algorithms
    if [[ -f "$SSH_HOME/config" ]]; then
        if grep -q "ssh-rsa" "$SSH_HOME/config" 2>/dev/null; then
            log_warning "SSH config may be using older RSA keys (consider ed25519)"
        fi
    fi
    
    # Check for unprotected private keys
    while IFS= read -r -d '' key_file; do
        if ssh-keygen -l -f "$key_file" &>/dev/null; then
            if ! ssh-keygen -y -f "$key_file" &>/dev/null; then
                log_warning "Private key $key_file appears to be unprotected (no passphrase)"
                ((issues++))
            fi
        fi
    done < <(find "$SSH_HOME" -name "id_*" -not -name "*.pub" -type f -print0 2>/dev/null || true)
    
    if [[ $issues -eq 0 ]]; then
        log_success "SSH security audit passed with no issues"
    else
        log_warning "SSH security audit found $issues potential issues"
    fi
    
    return $issues
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        install)
            shift
            local force=false
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -f|--force) force=true; shift ;;
                    *) log_error "Unknown option: $1"; exit 1 ;;
                esac
            done
            install_ssh "$force"
            ;;
        backup)
            backup_ssh
            ;;
        validate)
            validate_ssh_config
            ;;
        test)
            shift
            test_ssh_connection "${1:-github.com}"
            ;;
        keygen)
            shift
            local key_type="ed25519"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --type) key_type="$2"; shift 2 ;;
                    *) log_error "Unknown option: $1"; exit 1 ;;
                esac
            done
            generate_ssh_key "$key_type"
            ;;
        audit)
            audit_ssh
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 