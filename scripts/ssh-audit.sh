#!/usr/bin/env bash

# SSH Security Audit Script
# Performs comprehensive security audit of SSH configuration
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
AUDIT_RESULTS=()
WARNINGS=0
ERRORS=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; ((ERRORS++)); }

# Check SSH directory permissions
check_ssh_directory() {
    log_info "Checking SSH directory permissions..."
    
    if [[ ! -d "$SSH_HOME" ]]; then
        log_error "SSH directory does not exist: $SSH_HOME"
        return
    fi
    
    local perms
    if command -v stat > /dev/null; then
        # Try Linux stat format first, then macOS
        perms=$(stat -c %a "$SSH_HOME" 2>/dev/null || stat -f %A "$SSH_HOME" 2>/dev/null || echo "unknown")
    else
        perms="unknown"
    fi
    
    if [[ "$perms" == "700" ]]; then
        log_success "SSH directory permissions are correct (700)"
    else
        log_error "SSH directory permissions are $perms (should be 700)"
    fi
}

# Check SSH config file permissions and syntax
check_ssh_config() {
    log_info "Checking SSH configuration file..."
    
    local config_file="$SSH_HOME/config"
    
    if [[ ! -f "$config_file" ]]; then
        log_warning "SSH config file does not exist"
        return
    fi
    
    # Check permissions (follow symlinks)
    local perms
    if command -v stat > /dev/null; then
        perms=$(stat -L -c %a "$config_file" 2>/dev/null || stat -L -f %A "$config_file" 2>/dev/null || echo "unknown")
    else
        perms="unknown"
    fi
    
    if [[ "$perms" == "600" ]] || [[ "$perms" == "644" ]]; then
        log_success "SSH config file permissions are acceptable ($perms)"
    else
        log_warning "SSH config file permissions are $perms (should be 600 or 644)"
    fi
    
    # Check syntax
    if ssh -F "$config_file" -G localhost &>/dev/null; then
        log_success "SSH configuration syntax is valid"
    else
        log_error "SSH configuration has syntax errors"
    fi
}

# Check private key permissions and security
check_private_keys() {
    log_info "Checking private key security..."
    
    local key_count=0
    local unprotected_keys=0
    
    while IFS= read -r -d '' key_file; do
        ((key_count++))
        
        # Check permissions
        local perms
        if command -v stat > /dev/null; then
            perms=$(stat -c %a "$key_file" 2>/dev/null || stat -f %A "$key_file" 2>/dev/null || echo "unknown")
        else
            perms="unknown"
        fi
        
        if [[ "$perms" == "600" ]]; then
            log_success "Private key $(basename "$key_file") has correct permissions (600)"
        else
            log_error "Private key $(basename "$key_file") has permissions $perms (should be 600)"
        fi
        
        # Check if key is passphrase protected
        if ssh-keygen -y -f "$key_file" -N "" &>/dev/null; then
            log_warning "Private key $(basename "$key_file") is not passphrase protected"
            ((unprotected_keys++))
        else
            log_success "Private key $(basename "$key_file") is passphrase protected"
        fi
        
        # Check key algorithm and strength
        local key_info
        if key_info=$(ssh-keygen -l -f "$key_file" 2>/dev/null); then
            local bits=$(echo "$key_info" | awk '{print $1}')
            local type=$(echo "$key_info" | awk '{print $NF}' | sed 's/.*(\([^)]*\)).*/\1/')
            
            case "$type" in
                RSA)
                    if [[ "$bits" -ge 2048 ]]; then
                        log_success "RSA key $(basename "$key_file") has adequate strength ($bits bits)"
                    else
                        log_error "RSA key $(basename "$key_file") is too weak ($bits bits, minimum 2048)"
                    fi
                    ;;
                ED25519)
                    log_success "Key $(basename "$key_file") uses modern Ed25519 algorithm"
                    ;;
                ECDSA)
                    if [[ "$bits" -ge 256 ]]; then
                        log_success "ECDSA key $(basename "$key_file") has adequate strength ($bits bits)"
                    else
                        log_warning "ECDSA key $(basename "$key_file") may be weak ($bits bits)"
                    fi
                    ;;
                *)
                    log_warning "Key $(basename "$key_file") uses unknown algorithm: $type"
                    ;;
            esac
        fi
        
    done < <(find "$SSH_HOME" -name "id_*" -not -name "*.pub" -type f -print0 2>/dev/null)
    
    if [[ $key_count -eq 0 ]]; then
        log_warning "No SSH private keys found"
    else
        log_info "Found $key_count private key(s), $unprotected_keys unprotected"
    fi
}

# Check public key permissions
check_public_keys() {
    log_info "Checking public key permissions..."
    
    local key_count=0
    
    while IFS= read -r -d '' key_file; do
        ((key_count++))
        
        local perms
        if command -v stat > /dev/null; then
            perms=$(stat -c %a "$key_file" 2>/dev/null || stat -f %A "$key_file" 2>/dev/null || echo "unknown")
        else
            perms="unknown"
        fi
        
        if [[ "$perms" == "644" ]]; then
            log_success "Public key $(basename "$key_file") has correct permissions (644)"
        else
            log_warning "Public key $(basename "$key_file") has permissions $perms (should be 644)"
        fi
        
    done < <(find "$SSH_HOME" -name "*.pub" -type f -print0 2>/dev/null)
    
    if [[ $key_count -eq 0 ]]; then
        log_warning "No SSH public keys found"
    fi
}

# Check known_hosts security
check_known_hosts() {
    log_info "Checking known_hosts file..."
    
    local known_hosts="$SSH_HOME/known_hosts"
    
    if [[ ! -f "$known_hosts" ]]; then
        log_warning "known_hosts file does not exist"
        return
    fi
    
    # Check permissions
    local perms
    if command -v stat > /dev/null; then
        perms=$(stat -c %a "$known_hosts" 2>/dev/null || stat -f %A "$known_hosts" 2>/dev/null || echo "unknown")
    else
        perms="unknown"
    fi
    
    if [[ "$perms" == "600" ]] || [[ "$perms" == "644" ]]; then
        log_success "known_hosts file permissions are acceptable ($perms)"
    else
        log_warning "known_hosts file permissions are $perms (should be 600 or 644)"
    fi
    
    # Check if hosts are hashed
    if grep -q "^|1|" "$known_hosts" 2>/dev/null; then
        log_success "known_hosts contains hashed host entries (good for privacy)"
    else
        log_warning "known_hosts contains unhashed host entries (consider HashKnownHosts yes)"
    fi
    
    # Count entries
    local entry_count
    entry_count=$(wc -l < "$known_hosts" 2>/dev/null || echo "0")
    log_info "known_hosts contains $entry_count host entries"
}

# Check for weak SSH configuration patterns
check_config_security() {
    log_info "Checking SSH configuration security settings..."
    
    local config_file="$SSH_HOME/config"
    
    if [[ ! -f "$config_file" ]]; then
        log_warning "No SSH config file to audit"
        return
    fi
    
    # Check for weak authentication methods
    if grep -qi "PreferredAuthentications.*password" "$config_file" 2>/dev/null; then
        log_warning "SSH config allows password authentication (consider publickey only)"
    fi
    
    # Check for StrictHostKeyChecking disabled globally
    if grep -qi "StrictHostKeyChecking.*no" "$config_file" | grep -v "^#" 2>/dev/null; then
        log_warning "StrictHostKeyChecking is disabled (security risk)"
    fi
    
    # Check for ForwardAgent enabled globally
    if grep -qi "ForwardAgent.*yes" "$config_file" | grep -v "^#" 2>/dev/null; then
        log_warning "ForwardAgent is enabled globally (potential security risk)"
    fi
    
    # Check for HashKnownHosts
    if grep -qi "HashKnownHosts.*yes" "$config_file" 2>/dev/null; then
        log_success "HashKnownHosts is enabled (good for privacy)"
    else
        log_info "Consider enabling HashKnownHosts for privacy"
    fi
    
    # Check for VisualHostKey
    if grep -qi "VisualHostKey.*yes" "$config_file" 2>/dev/null; then
        log_success "VisualHostKey is enabled (helps detect MITM attacks)"
    else
        log_info "Consider enabling VisualHostKey for better security"
    fi
}

# Check SSH agent security
check_ssh_agent() {
    log_info "Checking SSH agent configuration..."
    
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        log_success "SSH agent is running"
        
        # List loaded keys
        local key_count
        if key_count=$(ssh-add -l 2>/dev/null | wc -l); then
            if [[ $key_count -gt 0 ]]; then
                log_info "SSH agent has $key_count key(s) loaded"
                # Check for key lifetime
                if ssh-add -l 2>/dev/null | grep -q "lifetime"; then
                    log_success "SSH agent keys have lifetime restrictions"
                else
                    log_warning "SSH agent keys have no lifetime restrictions"
                fi
            else
                log_warning "SSH agent is running but no keys are loaded"
            fi
        else
            log_warning "Cannot query SSH agent key list"
        fi
    else
        log_warning "SSH agent is not running"
    fi
}

# Generate audit report
generate_report() {
    echo
    echo "==================== SSH SECURITY AUDIT REPORT ===================="
    echo "Audit completed at: $(date)"
    echo "SSH directory: $SSH_HOME"
    echo
    
    if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
        log_success "SSH configuration audit passed with no issues"
        echo "✅ Your SSH configuration appears to be secure!"
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  SSH configuration audit completed with $WARNINGS warning(s)${NC}"
        echo "Consider addressing the warnings above for improved security."
    else
        echo -e "${RED}❌ SSH configuration audit failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
        echo "Please address the errors above before proceeding."
    fi
    
    echo
    echo "Recommendations:"
    echo "• Use Ed25519 keys for new key generation"
    echo "• Enable passphrase protection on all private keys"
    echo "• Use SSH agent with key lifetime restrictions"
    echo "• Enable HashKnownHosts and VisualHostKey"
    echo "• Regularly rotate SSH keys"
    echo "• Monitor SSH access logs"
    echo "======================================================================"
}

# Main audit function
main() {
    echo "Starting SSH security audit..."
    echo
    
    check_ssh_directory
    check_ssh_config
    check_private_keys
    check_public_keys
    check_known_hosts
    check_config_security
    check_ssh_agent
    
    generate_report
    
    # Return appropriate exit code
    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Run the audit
main "$@" 