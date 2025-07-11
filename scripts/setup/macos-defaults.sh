#!/usr/bin/env bash
# macOS System Preferences Setup Script
# Called during bootstrap to configure macOS system preferences

set -euo pipefail

# Script information
readonly SCRIPT_NAME="macOS System Preferences Setup"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
fi

# Logging functions
log_info() { echo "${BLUE}[MACOS-SETUP]${RESET} $*"; }
log_success() { echo "${GREEN}[MACOS-SETUP]${RESET} $*"; }
log_warning() { echo "${YELLOW}[MACOS-SETUP]${RESET} $*" >&2; }
log_error() { echo "${RED}[MACOS-SETUP]${RESET} $*" >&2; }

# Configuration
DRY_RUN=false
VERBOSE=false
FORCE=false
INTERACTIVE=true

# Parse arguments passed from bootstrap
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --force) FORCE=true; INTERACTIVE=false; shift ;;
        --non-interactive) INTERACTIVE=false; shift ;;
        *) shift ;;
    esac
done

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "This script is designed for macOS only"
        log_info "Current OS: $OSTYPE"
        return 1
    fi
    
    local os_version
    os_version=$(sw_vers -productVersion)
    local major_version="${os_version%%.*}"
    
    if [[ $major_version -lt 12 ]]; then
        log_error "macOS 12.0 (Monterey) or later is required"
        log_error "Current version: $os_version"
        return 1
    fi
    
    [[ "$VERBOSE" == true ]] && log_info "macOS version $os_version is compatible"
    return 0
}

# Ask user for confirmation
confirm_execution() {
    if [[ "$INTERACTIVE" != true ]] || [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo ""
    log_info "${BOLD}macOS System Preferences Configuration${RESET}"
    echo ""
    log_info "This will configure macOS system preferences optimized for development:"
    log_info "  • Dock settings (auto-hide, size, hot corners)"
    log_info "  • Finder preferences (show extensions, hidden files, paths)"
    log_info "  • Input settings (keyboard repeat, trackpad, mouse)"
    log_info "  • Security preferences (screen lock, privacy settings)"
    log_info "  • Appearance settings (dark mode, animations, menu bar)"
    log_info "  • General system preferences (text input, energy, etc.)"
    echo ""
    log_warning "Some settings will override your current preferences"
    log_info "A backup will be created before making changes"
    echo ""
    
    local response
    echo -n "${YELLOW}Apply macOS system preferences? (y/N): ${RESET}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Run the main defaults configuration
run_macos_defaults() {
    local defaults_script="$DOTFILES_ROOT/os/macos/defaults.sh"
    
    if [[ ! -f "$defaults_script" ]]; then
        log_error "macOS defaults script not found: $defaults_script"
        return 1
    fi
    
    if [[ ! -x "$defaults_script" ]]; then
        log_info "Making defaults script executable"
        chmod +x "$defaults_script"
    fi
    
    log_info "Running macOS system preferences configuration..."
    
    # Build arguments to pass to the defaults script
    local args=()
    [[ "$DRY_RUN" == true ]] && args+=("--dry-run")
    [[ "$VERBOSE" == true ]] && args+=("--verbose")
    [[ "$FORCE" == true ]] && args+=("--force")
    [[ "$INTERACTIVE" != true ]] && args+=("--non-interactive")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute: $defaults_script ${args[*]}"
        return 0
    fi
    
    # Execute the defaults script
    if "$defaults_script" "${args[@]}"; then
        log_success "macOS system preferences configured successfully"
        return 0
    else
        log_error "Failed to configure macOS system preferences"
        return 1
    fi
}

# Make all configuration scripts executable
setup_permissions() {
    log_info "Setting up script permissions..."
    
    local scripts=(
        "$DOTFILES_ROOT/os/macos/defaults.sh"
        "$DOTFILES_ROOT/os/macos/dock.sh"
        "$DOTFILES_ROOT/os/macos/finder.sh"
        "$DOTFILES_ROOT/os/macos/input.sh"
        "$DOTFILES_ROOT/os/macos/security.sh"
        "$DOTFILES_ROOT/os/macos/appearance.sh"
        "$DOTFILES_ROOT/os/macos/general.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would make executable: $(basename "$script")"
            else
                chmod +x "$script"
                [[ "$VERBOSE" == true ]] && log_info "Made executable: $(basename "$script")"
            fi
        else
            log_warning "Script not found: $script"
        fi
    done
    
    log_success "Script permissions configured"
}

# Show post-configuration information
show_completion_info() {
    echo ""
    log_success "${BOLD}macOS System Preferences Configuration Complete!${RESET}"
    echo ""
    
    if [[ "$DRY_RUN" != true ]]; then
        log_info "What was configured:"
        log_info "  ✓ Dock preferences (auto-hide, size, hot corners)"
        log_info "  ✓ Finder settings (extensions, hidden files, paths)"
        log_info "  ✓ Input devices (keyboard, trackpad, mouse)"
        log_info "  ✓ Security settings (screen lock, privacy)"
        log_info "  ✓ Appearance (dark mode, animations)"
        log_info "  ✓ General system preferences"
        echo ""
        
        log_info "Next steps:"
        log_info "  1. Some changes require logout/restart to take full effect"
        log_info "  2. Review System Preferences for any manual adjustments needed"
        log_info "  3. Configure FileVault encryption in Security & Privacy"
        log_info "  4. Enable Firewall in Security & Privacy > Firewall"
        echo ""
        
        log_info "To modify preferences later:"
        log_info "  • Run individual scripts: $DOTFILES_ROOT/os/macos/<category>.sh"
        log_info "  • Create backup: $DOTFILES_ROOT/os/macos/defaults.sh --backup"
        log_info "  • Restore backup: $DOTFILES_ROOT/os/macos/defaults.sh --restore"
    else
        log_info "DRY RUN completed - no changes were made"
    fi
}

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Check if we're on macOS
    if ! check_macos; then
        log_info "Skipping macOS system preferences setup on non-macOS system"
        return 0
    fi
    
    # Set up script permissions
    setup_permissions
    
    # Get user confirmation if interactive
    if ! confirm_execution; then
        log_info "macOS system preferences setup cancelled"
        return 0
    fi
    
    # Run the configuration
    if run_macos_defaults; then
        show_completion_info
        return 0
    else
        log_error "macOS system preferences setup failed"
        return 1
    fi
}

# Handle errors
trap 'log_error "Setup script failed at line $LINENO"' ERR

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 