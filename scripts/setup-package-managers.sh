#!/usr/bin/env bash
# Package Manager Setup Script
# Configures npm, pip, gem, and cargo with optimized settings

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$DOTFILES_DIR/config"
HOME_DIR="$DOTFILES_DIR/home"

# Logging setup
log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            if [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if package manager is installed
check_package_manager() {
    local manager="$1"
    if command -v "$manager" >/dev/null 2>&1; then
        log_info "$manager is installed at $(command -v "$manager")"
        return 0
    else
        log_warn "$manager is not installed"
        return 1
    fi
}

# Setup npm configuration
setup_npm() {
    log_info "Setting up npm configuration..."
    
    if ! check_package_manager "npm"; then
        log_warn "Skipping npm configuration - npm not found"
        return 0
    fi

    local npm_config="$CONFIG_DIR/npm/.npmrc"
    if [[ -f "$npm_config" ]]; then
        log_info "npm configuration file exists at $npm_config"
        
        # Create backup of existing global config if it exists
        local global_npmrc
        global_npmrc="$(npm config get globalconfig 2>/dev/null || echo ~/.npmrc)"
        if [[ -f "$global_npmrc" ]] && [[ "$global_npmrc" != "$npm_config" ]]; then
            log_info "Backing up existing npm config to ${global_npmrc}.backup"
            cp "$global_npmrc" "${global_npmrc}.backup"
        fi
        
        log_info "npm configuration ready for stow"
    else
        log_error "npm configuration file not found at $npm_config"
        return 1
    fi
}

# Setup pip configuration
setup_pip() {
    log_info "Setting up pip configuration..."
    
    if ! check_package_manager "pip"; then
        log_warn "Skipping pip configuration - pip not found"
        return 0
    fi

    local pip_config="$CONFIG_DIR/pip/pip.conf"
    if [[ -f "$pip_config" ]]; then
        log_info "pip configuration file exists at $pip_config"
        
        # Check for existing pip config
        local platform
        platform=$(detect_platform)
        local pip_config_dir
        case "$platform" in
            macos)
                pip_config_dir="$HOME/Library/Application Support/pip"
                ;;
            linux|wsl)
                pip_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/pip"
                ;;
            *)
                pip_config_dir="$HOME/.config/pip"
                ;;
        esac
        
        if [[ -f "$pip_config_dir/pip.conf" ]]; then
            log_info "Backing up existing pip config to $pip_config_dir/pip.conf.backup"
            cp "$pip_config_dir/pip.conf" "$pip_config_dir/pip.conf.backup"
        fi
        
        log_info "pip configuration ready for stow"
    else
        log_error "pip configuration file not found at $pip_config"
        return 1
    fi
}

# Setup gem configuration
setup_gem() {
    log_info "Setting up gem configuration..."
    
    if ! check_package_manager "gem"; then
        log_warn "Skipping gem configuration - gem not found"
        return 0
    fi

    local gem_config="$HOME_DIR/.gemrc"
    if [[ -f "$gem_config" ]]; then
        log_info "gem configuration file exists at $gem_config"
        
        # Backup existing .gemrc if it exists
        if [[ -f "$HOME/.gemrc" ]] && [[ "$HOME/.gemrc" != "$gem_config" ]]; then
            log_info "Backing up existing gem config to $HOME/.gemrc.backup"
            cp "$HOME/.gemrc" "$HOME/.gemrc.backup"
        fi
        
        log_info "gem configuration ready for stow"
    else
        log_error "gem configuration file not found at $gem_config"
        return 1
    fi
}

# Setup cargo configuration
setup_cargo() {
    log_info "Setting up cargo configuration..."
    
    if ! check_package_manager "cargo"; then
        log_warn "Skipping cargo configuration - cargo not found"
        return 0
    fi

    local cargo_config="$CONFIG_DIR/cargo/config.toml"
    if [[ -f "$cargo_config" ]]; then
        log_info "cargo configuration file exists at $cargo_config"
        
        # Check for existing cargo config
        local cargo_config_dir="${CARGO_HOME:-$HOME/.cargo}/config.toml"
        if [[ -f "$cargo_config_dir" ]]; then
            log_info "Backing up existing cargo config to ${cargo_config_dir}.backup"
            cp "$cargo_config_dir" "${cargo_config_dir}.backup"
        fi
        
        log_info "cargo configuration ready for stow"
    else
        log_error "cargo configuration file not found at $cargo_config"
        return 1
    fi
}

# Validate configurations
validate_configs() {
    log_info "Validating package manager configurations..."
    
    local validation_script="$SCRIPT_DIR/validate-package-managers.sh"
    if [[ -f "$validation_script" ]]; then
        bash "$validation_script"
    else
        log_warn "Validation script not found, skipping validation"
    fi
}

# Main setup function
main() {
    log_info "Starting package manager configuration setup..."
    log_info "Platform: $(detect_platform)"
    log_info "Dotfiles directory: $DOTFILES_DIR"
    
    local exit_code=0
    
    # Setup each package manager
    setup_npm || exit_code=$?
    setup_pip || exit_code=$?
    setup_gem || exit_code=$?
    setup_cargo || exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Package manager configurations setup successfully"
        log_info "Run 'stow config home' from the dotfiles directory to apply configurations"
        
        # Validate configurations
        validate_configs
    else
        log_error "Some package manager configurations failed to setup"
        exit $exit_code
    fi
}

# Help function
show_help() {
    cat << EOF
Package Manager Setup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -v, --validate  Only run validation, don't setup
    --npm-only      Setup only npm configuration
    --pip-only      Setup only pip configuration  
    --gem-only      Setup only gem configuration
    --cargo-only    Setup only cargo configuration

DESCRIPTION:
    This script sets up configurations for npm, pip, gem, and cargo package
    managers with optimized settings for development. The configurations are
    designed to work with GNU Stow for symlink management.

EXAMPLES:
    $0                      # Setup all package managers
    $0 --npm-only          # Setup only npm
    $0 --validate          # Only validate existing configurations
EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--validate)
        validate_configs
        exit 0
        ;;
    --npm-only)
        setup_npm
        exit 0
        ;;
    --pip-only)
        setup_pip
        exit 0
        ;;
    --gem-only)
        setup_gem
        exit 0
        ;;
    --cargo-only)
        setup_cargo
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 