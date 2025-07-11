#!/usr/bin/env bash

# SSH Key Generation Helper
# Interactive script for generating SSH keys with secure defaults
# Part of the dotfiles SSH configuration system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSH_HOME="$HOME/.ssh"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Help function
show_help() {
    cat << EOF
SSH Key Generation Helper

This script helps you generate SSH keys with secure defaults and best practices.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -t, --type TYPE     Key type (ed25519, rsa, ecdsa) [default: ed25519]
    -f, --file FILE     Output file path [default: ~/.ssh/id_TYPE]
    -c, --comment TEXT  Key comment [default: user@hostname]
    -p, --purpose TEXT  Key purpose (personal, work, github, etc.)
    -i, --interactive   Interactive mode (default)
    -h, --help          Show this help

EXAMPLES:
    $(basename "$0")                           # Interactive mode
    $(basename "$0") -t ed25519 -p github      # GitHub key
    $(basename "$0") -t rsa -p work            # Work key

KEY TYPES:
    ed25519    Recommended - Modern, fast, secure (default)
    rsa        Traditional - Compatible, 4096 bits
    ecdsa      Elliptic curve - Good compromise, 521 bits

SECURITY NOTES:
    - Always use a strong passphrase
    - Consider using different keys for different purposes
    - Rotate keys annually or when compromised
    - Store keys securely with proper permissions

EOF
}

# Prompt for user input
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " response
        echo "${response:-$default}"
    else
        read -p "$prompt: " response
        echo "$response"
    fi
}

# Prompt for secure input (hidden)
prompt_secure() {
    local prompt="$1"
    local response
    read -s -p "$prompt: " response
    echo
    echo "$response"
}

# Validate key type
validate_key_type() {
    local key_type="$1"
    case "$key_type" in
        ed25519|rsa|ecdsa)
            return 0
            ;;
        *)
            log_error "Invalid key type: $key_type"
            log_info "Supported types: ed25519, rsa, ecdsa"
            return 1
            ;;
    esac
}

# Generate SSH key
generate_key() {
    local key_type="$1"
    local key_file="$2"
    local comment="$3"
    local passphrase="$4"
    
    log_info "Generating $key_type SSH key..."
    log_info "Output file: $key_file"
    log_info "Comment: $comment"
    
    # Ensure SSH directory exists
    mkdir -p "$SSH_HOME"
    chmod 700 "$SSH_HOME"
    
    # Check if key already exists
    if [[ -f "$key_file" ]]; then
        echo
        log_warning "Key file already exists: $key_file"
        local overwrite
        overwrite=$(prompt_input "Overwrite existing key? (y/N)" "n")
        if [[ "${overwrite,,}" != "y" ]]; then
            log_info "Key generation cancelled"
            return 1
        fi
    fi
    
    # Generate key based on type
    case "$key_type" in
        ed25519)
            if [[ -n "$passphrase" ]]; then
                ssh-keygen -t ed25519 -C "$comment" -f "$key_file" -N "$passphrase"
            else
                ssh-keygen -t ed25519 -C "$comment" -f "$key_file"
            fi
            ;;
        rsa)
            if [[ -n "$passphrase" ]]; then
                ssh-keygen -t rsa -b 4096 -C "$comment" -f "$key_file" -N "$passphrase"
            else
                ssh-keygen -t rsa -b 4096 -C "$comment" -f "$key_file"
            fi
            ;;
        ecdsa)
            if [[ -n "$passphrase" ]]; then
                ssh-keygen -t ecdsa -b 521 -C "$comment" -f "$key_file" -N "$passphrase"
            else
                ssh-keygen -t ecdsa -b 521 -C "$comment" -f "$key_file"
            fi
            ;;
    esac
    
    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "$key_file.pub"
    
    log_success "SSH key generated successfully!"
    echo
    log_info "Private key: $key_file"
    log_info "Public key: $key_file.pub"
    echo
    log_info "Public key content:"
    cat "$key_file.pub"
    echo
    
    # Show key fingerprint
    log_info "Key fingerprint:"
    ssh-keygen -l -f "$key_file"
    echo
    
    # Add to SSH agent if available
    if command -v ssh-add >/dev/null && [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        echo
        local add_to_agent
        add_to_agent=$(prompt_input "Add key to SSH agent? (Y/n)" "y")
        if [[ "${add_to_agent,,}" != "n" ]]; then
            if ssh-add "$key_file"; then
                log_success "Key added to SSH agent"
            else
                log_warning "Failed to add key to SSH agent"
            fi
        fi
    fi
    
    # Show next steps
    echo
    log_info "Next steps:"
    echo "1. Add the public key to your remote servers/services"
    echo "2. Test the connection: ssh -T git@github.com (for GitHub)"
    echo "3. Update SSH config if needed"
    echo "4. Consider adding key-specific configuration"
    echo
}

# Interactive mode
interactive_mode() {
    log_info "SSH Key Generation Helper - Interactive Mode"
    echo
    
    # Key type selection
    echo "Available key types:"
    echo "  1. ed25519 (Recommended - Modern, fast, secure)"
    echo "  2. rsa     (Traditional - Compatible, 4096 bits)"
    echo "  3. ecdsa   (Elliptic curve - Good compromise, 521 bits)"
    echo
    
    local key_type_choice
    key_type_choice=$(prompt_input "Select key type (1-3)" "1")
    
    local key_type
    case "$key_type_choice" in
        1|ed25519) key_type="ed25519" ;;
        2|rsa) key_type="rsa" ;;
        3|ecdsa) key_type="ecdsa" ;;
        *) 
            log_error "Invalid selection"
            return 1
            ;;
    esac
    
    # Purpose/comment
    local purpose
    purpose=$(prompt_input "Key purpose (personal/work/github/etc.)" "personal")
    
    # Generate comment
    local default_comment="$(whoami)@$(hostname)-$purpose"
    local comment
    comment=$(prompt_input "Key comment" "$default_comment")
    
    # File location
    local default_file="$SSH_HOME/id_${key_type}_${purpose}"
    local key_file
    key_file=$(prompt_input "Output file path" "$default_file")
    
    # Passphrase
    echo
    log_info "A strong passphrase is highly recommended for security"
    local use_passphrase
    use_passphrase=$(prompt_input "Use passphrase? (Y/n)" "y")
    
    local passphrase=""
    if [[ "${use_passphrase,,}" != "n" ]]; then
        passphrase=$(prompt_secure "Enter passphrase")
        local passphrase_confirm
        passphrase_confirm=$(prompt_secure "Confirm passphrase")
        
        if [[ "$passphrase" != "$passphrase_confirm" ]]; then
            log_error "Passphrases do not match"
            return 1
        fi
    fi
    
    echo
    log_info "Summary:"
    echo "  Key type: $key_type"
    echo "  Purpose: $purpose"
    echo "  Comment: $comment"
    echo "  File: $key_file"
    echo "  Passphrase: ${passphrase:+Yes (hidden)}"
    echo
    
    local confirm
    confirm=$(prompt_input "Generate key? (Y/n)" "y")
    if [[ "${confirm,,}" == "n" ]]; then
        log_info "Key generation cancelled"
        return 0
    fi
    
    generate_key "$key_type" "$key_file" "$comment" "$passphrase"
}

# Main function
main() {
    local key_type="ed25519"
    local key_file=""
    local comment=""
    local purpose=""
    local interactive=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                key_type="$2"
                interactive=false
                shift 2
                ;;
            -f|--file)
                key_file="$2"
                interactive=false
                shift 2
                ;;
            -c|--comment)
                comment="$2"
                interactive=false
                shift 2
                ;;
            -p|--purpose)
                purpose="$2"
                interactive=false
                shift 2
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate key type
    if ! validate_key_type "$key_type"; then
        exit 1
    fi
    
    # Interactive mode if no specific parameters provided
    if [[ "$interactive" == "true" ]]; then
        interactive_mode
        return $?
    fi
    
    # Non-interactive mode
    if [[ -z "$key_file" ]]; then
        if [[ -n "$purpose" ]]; then
            key_file="$SSH_HOME/id_${key_type}_${purpose}"
        else
            key_file="$SSH_HOME/id_${key_type}"
        fi
    fi
    
    if [[ -z "$comment" ]]; then
        if [[ -n "$purpose" ]]; then
            comment="$(whoami)@$(hostname)-$purpose"
        else
            comment="$(whoami)@$(hostname)"
        fi
    fi
    
    generate_key "$key_type" "$key_file" "$comment" ""
}

# Run main function with all arguments
main "$@" 