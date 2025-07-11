#!/usr/bin/env bash

# =============================================================================
# Git Configuration Setup and Management Script
# =============================================================================
# This script handles Git configuration installation, validation, and management
# It integrates with the dotfiles system and secret injection

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GIT_CONFIG_DIR="$DOTFILES_ROOT/config/git"
GIT_TEMPLATES_DIR="$DOTFILES_ROOT/templates/git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Git Configuration Setup and Management

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    install         Install Git configuration via stow
    validate        Validate Git configuration
    status          Show Git configuration status
    profile         Manage Git profiles
    hooks           Manage Git hooks
    clean           Clean Git configuration
    help            Show this help message

Options:
    -f, --force     Force operation (overwrite existing files)
    -v, --verbose   Verbose output
    -d, --dry-run   Show what would be done without making changes

Examples:
    $0 install              # Install Git configuration
    $0 validate             # Validate current Git configuration
    $0 profile list         # List available Git profiles
    $0 profile switch work  # Switch to work profile context
    $0 hooks install        # Install Git hooks to current repository

EOF
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if ! command_exists stow; then
        missing_deps+=("stow")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again"
        exit 1
    fi
    
    log_success "All dependencies are available"
}

# Get Git version
get_git_version() {
    git --version | sed 's/git version //' | head -1
}

# Check Git version compatibility
check_git_version() {
    local git_version
    git_version=$(get_git_version)
    local min_version="2.13.0"
    
    if ! printf '%s\n%s\n' "$min_version" "$git_version" | sort -V -C; then
        log_warn "Git version $git_version detected. Some features require Git $min_version or later."
        log_info "Consider upgrading Git for full functionality"
    else
        log_success "Git version $git_version is compatible"
    fi
}

# Install Git configuration
install_git_config() {
    local force=${1:-false}
    
    log_info "Installing Git configuration..."
    
    # Check if Git config already exists
    if [[ -f "$HOME/.gitconfig" ]] && [[ "$force" != true ]]; then
        log_warn "Existing Git configuration found at ~/.gitconfig"
        read -p "Do you want to backup and replace it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            return 0
        fi
        
        # Backup existing configuration
        local backup_file="$HOME/.gitconfig.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.gitconfig" "$backup_file"
        log_info "Backed up existing configuration to $backup_file"
    fi
    
    # Use stow to install Git configuration
    log_info "Using stow to install Git configuration..."
    if (cd "$DOTFILES_ROOT" && stow -v config/git -t "$HOME"); then
        log_success "Git configuration installed successfully"
    else
        log_error "Failed to install Git configuration"
        return 1
    fi
    
    # Create profile directories if they don't exist
    local profile_dirs=("$HOME/personal" "$HOME/work" "$HOME/opensource")
    for dir in "${profile_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating profile directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    log_success "Git configuration installation completed"
}

# Validate Git configuration
validate_git_config() {
    log_info "Validating Git configuration..."
    
    local exit_code=0
    
    # Check if Git config file exists and is readable
    if [[ ! -f "$HOME/.config/git/config" ]]; then
        log_error "Git configuration file not found at ~/.config/git/config"
        exit_code=1
    else
        log_success "Git configuration file found"
    fi
    
    # Validate Git configuration syntax
    if ! git config --list >/dev/null 2>&1; then
        log_error "Git configuration has syntax errors"
        exit_code=1
    else
        log_success "Git configuration syntax is valid"
    fi
    
    # Check for required global settings
    local required_settings=(
        "user.name"
        "user.email"
        "core.editor"
        "init.defaultBranch"
    )
    
    for setting in "${required_settings[@]}"; do
        if ! git config --global "$setting" >/dev/null 2>&1; then
            log_warn "Missing Git configuration: $setting"
        else
            local value
            value=$(git config --global "$setting")
            log_success "✓ $setting = $value"
        fi
    done
    
    # Check Git hooks
    if [[ -d "$HOME/.config/git/hooks" ]]; then
        local hook_count
        hook_count=$(find "$HOME/.config/git/hooks" -type f -executable | wc -l)
        log_success "Found $hook_count executable Git hooks"
    else
        log_warn "No Git hooks directory found"
    fi
    
    # Check profile configurations
    local profiles=("personal" "work" "opensource")
    for profile in "${profiles[@]}"; do
        local profile_file="$HOME/.config/git/includes/$profile.gitconfig"
        if [[ -f "$profile_file" ]]; then
            log_success "✓ Profile configuration found: $profile"
        else
            log_warn "Profile configuration missing: $profile"
        fi
    done
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Git configuration validation passed"
    else
        log_error "Git configuration validation failed"
    fi
    
    return $exit_code
}

# Show Git configuration status
show_git_status() {
    log_info "Git Configuration Status"
    echo "=========================="
    
    # Git version
    local git_version
    git_version=$(get_git_version)
    echo "Git Version: $git_version"
    
    # Current user configuration
    local user_name user_email
    user_name=$(git config --global user.name 2>/dev/null || echo "Not set")
    user_email=$(git config --global user.email 2>/dev/null || echo "Not set")
    echo "User Name: $user_name"
    echo "User Email: $user_email"
    
    # Signing configuration
    local signing_key gpg_sign
    signing_key=$(git config --global user.signingkey 2>/dev/null || echo "Not set")
    gpg_sign=$(git config --global commit.gpgsign 2>/dev/null || echo "false")
    echo "Signing Key: $signing_key"
    echo "GPG Signing: $gpg_sign"
    
    # Profile detection
    echo
    echo "Profile Configuration:"
    local profiles=("personal" "work" "opensource")
    for profile in "${profiles[@]}"; do
        local profile_file="$HOME/.config/git/includes/$profile.gitconfig"
        if [[ -f "$profile_file" ]]; then
            echo "  ✓ $profile"
        else
            echo "  ✗ $profile (missing)"
        fi
    done
    
    # Current repository context (if in a Git repository)
    if git rev-parse --git-dir >/dev/null 2>&1; then
        echo
        echo "Current Repository:"
        local repo_root
        repo_root=$(git rev-parse --show-toplevel)
        echo "  Path: $repo_root"
        
        # Detect active profile based on path
        case "$repo_root" in
            "$HOME/personal/"*) echo "  Active Profile: personal" ;;
            "$HOME/work/"*) echo "  Active Profile: work" ;;
            "$HOME/opensource/"*) echo "  Active Profile: opensource" ;;
            *) echo "  Active Profile: default" ;;
        esac
        
        # Repository-specific settings
        local repo_user_name repo_user_email
        repo_user_name=$(git config user.name 2>/dev/null || echo "Not set")
        repo_user_email=$(git config user.email 2>/dev/null || echo "Not set")
        echo "  Repository User: $repo_user_name <$repo_user_email>"
    fi
    
    # Aliases count
    local alias_count
    alias_count=$(git config --global --get-regexp '^alias\.' | wc -l)
    echo
    echo "Git Aliases: $alias_count configured"
    
    # Hooks status
    echo
    echo "Git Hooks:"
    if [[ -d "$HOME/.config/git/hooks" ]]; then
        find "$HOME/.config/git/hooks" -type f -executable -printf "  ✓ %f\n" 2>/dev/null || \
        find "$HOME/.config/git/hooks" -type f -perm +111 -exec basename {} \; | sed 's/^/  ✓ /'
    else
        echo "  No hooks directory found"
    fi
}

# Profile management
manage_profiles() {
    local action="${1:-list}"
    
    case "$action" in
        list)
            log_info "Available Git profiles:"
            local profiles=("personal" "work" "opensource")
            for profile in "${profiles[@]}"; do
                local profile_file="$HOME/.config/git/includes/$profile.gitconfig"
                if [[ -f "$profile_file" ]]; then
                    echo "  ✓ $profile"
                else
                    echo "  ✗ $profile (missing)"
                fi
            done
            ;;
        switch)
            local profile="$2"
            if [[ -z "$profile" ]]; then
                log_error "Profile name required for switch command"
                return 1
            fi
            
            log_info "Profile switching is automatic based on repository location:"
            echo "  ~/personal/* -> personal profile"
            echo "  ~/work/* -> work profile"
            echo "  ~/opensource/* -> opensource profile"
            echo "  Other locations -> default profile"
            
            local target_dir="$HOME/$profile"
            if [[ ! -d "$target_dir" ]]; then
                log_info "Creating profile directory: $target_dir"
                mkdir -p "$target_dir"
            fi
            
            log_success "Profile directory ready: $target_dir"
            ;;
        *)
            log_error "Unknown profile action: $action"
            log_info "Available actions: list, switch"
            return 1
            ;;
    esac
}

# Git hooks management
manage_hooks() {
    local action="${1:-install}"
    
    case "$action" in
        install)
            if ! git rev-parse --git-dir >/dev/null 2>&1; then
                log_error "Not in a Git repository"
                return 1
            fi
            
            local repo_hooks_dir
            repo_hooks_dir="$(git rev-parse --git-dir)/hooks"
            
            log_info "Installing Git hooks to current repository..."
            
            # Copy hooks from global configuration
            if [[ -d "$HOME/.config/git/hooks" ]]; then
                for hook in "$HOME/.config/git/hooks"/*; do
                    if [[ -f "$hook" && -x "$hook" ]]; then
                        local hook_name
                        hook_name=$(basename "$hook")
                        cp "$hook" "$repo_hooks_dir/$hook_name"
                        chmod +x "$repo_hooks_dir/$hook_name"
                        log_success "Installed hook: $hook_name"
                    fi
                done
            else
                log_error "No global hooks directory found"
                return 1
            fi
            ;;
        list)
            if git rev-parse --git-dir >/dev/null 2>&1; then
                local repo_hooks_dir
                repo_hooks_dir="$(git rev-parse --git-dir)/hooks"
                log_info "Repository hooks:"
                find "$repo_hooks_dir" -type f -executable -printf "  %f\n" 2>/dev/null || \
                find "$repo_hooks_dir" -type f -perm +111 -exec basename {} \; | sed 's/^/  /'
            else
                log_error "Not in a Git repository"
                return 1
            fi
            ;;
        *)
            log_error "Unknown hooks action: $action"
            log_info "Available actions: install, list"
            return 1
            ;;
    esac
}

# Clean Git configuration
clean_git_config() {
    log_info "Cleaning Git configuration..."
    
    # Unstow Git configuration
    if (cd "$DOTFILES_ROOT" && stow -D config/git -t "$HOME" 2>/dev/null); then
        log_success "Git configuration removed via stow"
    else
        log_warn "Failed to unstow Git configuration (may not have been stowed)"
    fi
    
    # Optionally remove backup files
    local backup_files
    backup_files=$(find "$HOME" -name ".gitconfig.backup.*" 2>/dev/null || true)
    if [[ -n "$backup_files" ]]; then
        log_info "Found Git configuration backup files:"
        echo "$backup_files"
        read -p "Do you want to remove backup files? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$backup_files" | xargs rm -f
            log_success "Backup files removed"
        fi
    fi
    
    log_success "Git configuration cleanup completed"
}

# Main function
main() {
    local command="${1:-help}"
    local force=false
    local verbose=false
    local dry_run=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Get command
    command="${1:-help}"
    
    case "$command" in
        install)
            check_dependencies
            check_git_version
            install_git_config "$force"
            ;;
        validate)
            validate_git_config
            ;;
        status)
            show_git_status
            ;;
        profile)
            manage_profiles "${2:-list}" "${3:-}"
            ;;
        hooks)
            manage_hooks "${2:-install}"
            ;;
        clean)
            clean_git_config
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