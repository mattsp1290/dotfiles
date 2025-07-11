#!/bin/bash
# Terminal Setup Script - DEV-004
# Configures terminal emulators across different platforms with consistent theming

set -e

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Source common utilities
if [[ -f "$DOTFILES_DIR/scripts/utils.sh" ]]; then
    source "$DOTFILES_DIR/scripts/utils.sh"
else
    # Basic logging functions if utils.sh is not available
    log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
    log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
    log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
    log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
fi

# Configuration
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
VERBOSE="${VERBOSE:-false}"

# Terminal emulators to configure
TERMINALS=(
    "alacritty"
    "kitty"
    "iterm2"
    "terminal_app"
)

# Font configuration
FONTS=(
    "JetBrains Mono"
    "Fira Code"
    "SF Mono"
    "Menlo"
)

# Print usage information
usage() {
    cat << EOF
Terminal Setup Script - DEV-004

Configures terminal emulators with Catppuccin Mocha theme and optimal settings.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run          Show what would be done without making changes
    -f, --force            Force overwrite existing configurations
    -v, --verbose          Enable verbose output
    -t, --terminal NAME    Configure specific terminal only
    --install-fonts        Install programming fonts
    --validate             Validate existing configurations
    --backup               Backup existing configurations before changes

TERMINALS:
    alacritty              Cross-platform GPU-accelerated terminal
    kitty                  Fast, featureful terminal emulator
    iterm2                 macOS terminal emulator (macOS only)
    terminal_app           Built-in Terminal.app (macOS only)

EXAMPLES:
    $0                     Configure all available terminals
    $0 -t alacritty        Configure Alacritty only
    $0 --dry-run           Preview changes without applying
    $0 --install-fonts     Install programming fonts first

EOF
}

# Parse command line arguments
parse_args() {
    local selected_terminal=""
    local install_fonts=false
    local validate_only=false
    local backup_configs=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_info "Dry run mode enabled"
                ;;
            -f|--force)
                FORCE=true
                log_info "Force mode enabled"
                ;;
            -v|--verbose)
                VERBOSE=true
                log_info "Verbose mode enabled"
                ;;
            -t|--terminal)
                selected_terminal="$2"
                shift
                ;;
            --install-fonts)
                install_fonts=true
                ;;
            --validate)
                validate_only=true
                ;;
            --backup)
                backup_configs=true
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
    
    # Set global variables
    if [[ -n "$selected_terminal" ]]; then
        TERMINALS=("$selected_terminal")
    fi
    
    if [[ "$install_fonts" == "true" ]]; then
        install_programming_fonts
    fi
    
    if [[ "$validate_only" == "true" ]]; then
        validate_terminal_configs
        exit 0
    fi
    
    if [[ "$backup_configs" == "true" ]]; then
        backup_terminal_configs
    fi
}

# Check system compatibility
check_system() {
    log_info "Checking system compatibility..."
    
    # Detect operating system
    case "$(uname -s)" in
        Darwin)
            OS="macos"
            log_info "Detected macOS"
            ;;
        Linux)
            OS="linux"
            log_info "Detected Linux"
            # Remove macOS-specific terminals
            TERMINALS=($(printf '%s\n' "${TERMINALS[@]}" | grep -v "iterm2\|terminal_app"))
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    # Check for required tools
    local required_tools=("stow")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            log_info "Please install GNU Stow before continuing"
            exit 1
        fi
    done
    
    log_success "System check passed"
}

# Install programming fonts
install_programming_fonts() {
    log_info "Installing programming fonts..."
    
    case "$OS" in
        macos)
            # Use Homebrew to install fonts
            if command -v brew &> /dev/null; then
                local fonts=(
                    "font-jetbrains-mono"
                    "font-fira-code"
                    "font-jetbrains-mono-nerd-font"
                    "font-fira-code-nerd-font"
                )
                
                # Tap the cask-fonts repository
                if [[ "$DRY_RUN" != "true" ]]; then
                    brew tap homebrew/cask-fonts || true
                    
                    for font in "${fonts[@]}"; do
                        log_info "Installing $font..."
                        brew install --cask "$font" || log_warning "Failed to install $font"
                    done
                else
                    log_info "[DRY RUN] Would install fonts: ${fonts[*]}"
                fi
            else
                log_warning "Homebrew not found, skipping font installation"
            fi
            ;;
        linux)
            log_info "Installing fonts on Linux..."
            # Download and install fonts manually on Linux
            local font_dir="$HOME/.local/share/fonts"
            mkdir -p "$font_dir"
            
            if [[ "$DRY_RUN" != "true" ]]; then
                # JetBrains Mono
                curl -L -o "/tmp/JetBrainsMono.zip" \
                    "https://github.com/JetBrains/JetBrainsMono/releases/latest/download/JetBrainsMono-2.304.zip"
                unzip -o "/tmp/JetBrainsMono.zip" -d "/tmp/JetBrainsMono"
                cp /tmp/JetBrainsMono/fonts/ttf/*.ttf "$font_dir/"
                
                # Update font cache
                fc-cache -fv
            else
                log_info "[DRY RUN] Would download and install JetBrains Mono font"
            fi
            ;;
    esac
    
    log_success "Font installation completed"
}

# Backup existing terminal configurations
backup_terminal_configs() {
    log_info "Backing up existing terminal configurations..."
    
    local backup_dir="$HOME/.config/terminal-backups/$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$backup_dir"
        
        # Backup configurations
        [[ -f "$HOME/.config/alacritty/alacritty.yml" ]] && cp "$HOME/.config/alacritty/alacritty.yml" "$backup_dir/"
        [[ -f "$HOME/.config/kitty/kitty.conf" ]] && cp "$HOME/.config/kitty/kitty.conf" "$backup_dir/"
        [[ -f "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]] && cp "$HOME/Library/Preferences/com.googlecode.iterm2.plist" "$backup_dir/"
        [[ -f "$HOME/Library/Preferences/com.apple.Terminal.plist" ]] && cp "$HOME/Library/Preferences/com.apple.Terminal.plist" "$backup_dir/"
        
        log_success "Configurations backed up to: $backup_dir"
    else
        log_info "[DRY RUN] Would backup configurations to: $backup_dir"
    fi
}

# Configure Alacritty
configure_alacritty() {
    log_info "Configuring Alacritty..."
    
    if command -v alacritty &> /dev/null; then
        local config_dir="$HOME/.config/alacritty"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            mkdir -p "$config_dir"
            
            # Use Stow to link configuration
            cd "$DOTFILES_DIR"
            stow -t "$HOME" config/alacritty
            
            log_success "Alacritty configuration applied"
        else
            log_info "[DRY RUN] Would configure Alacritty at: $config_dir"
        fi
    else
        log_warning "Alacritty not found, skipping configuration"
        
        if [[ "$OS" == "macos" ]]; then
            log_info "Install with: brew install --cask alacritty"
        elif [[ "$OS" == "linux" ]]; then
            log_info "Install with your package manager or from https://github.com/alacritty/alacritty"
        fi
    fi
}

# Configure Kitty
configure_kitty() {
    log_info "Configuring Kitty..."
    
    if command -v kitty &> /dev/null; then
        local config_dir="$HOME/.config/kitty"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            mkdir -p "$config_dir"
            
            # Use Stow to link configuration
            cd "$DOTFILES_DIR"
            stow -t "$HOME" config/kitty
            
            log_success "Kitty configuration applied"
        else
            log_info "[DRY RUN] Would configure Kitty at: $config_dir"
        fi
    else
        log_warning "Kitty not found, skipping configuration"
        
        if [[ "$OS" == "macos" ]]; then
            log_info "Install with: brew install --cask kitty"
        elif [[ "$OS" == "linux" ]]; then
            log_info "Install with your package manager or from https://sw.kovidgoyal.net/kitty/"
        fi
    fi
}

# Configure iTerm2 (macOS only)
configure_iterm2() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi
    
    log_info "Configuring iTerm2..."
    
    if [[ -d "/Applications/iTerm.app" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            log_info "iTerm2 configuration requires manual setup"
            log_info "Please see: $DOTFILES_DIR/os/macos/iterm2/README.md"
        else
            log_info "[DRY RUN] Would configure iTerm2"
        fi
    else
        log_warning "iTerm2 not found, skipping configuration"
        log_info "Install with: brew install --cask iterm2"
    fi
}

# Configure Terminal.app (macOS only)
configure_terminal_app() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi
    
    log_info "Configuring Terminal.app..."
    
    local setup_script="$DOTFILES_DIR/os/macos/terminal/setup.sh"
    
    if [[ -f "$setup_script" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            chmod +x "$setup_script"
            "$setup_script"
        else
            log_info "[DRY RUN] Would run Terminal.app setup script"
        fi
    else
        log_error "Terminal.app setup script not found: $setup_script"
    fi
}

# Validate terminal configurations
validate_terminal_configs() {
    log_info "Validating terminal configurations..."
    
    local errors=0
    
    # Check Alacritty
    if [[ -f "$HOME/.config/alacritty/alacritty.yml" ]]; then
        if command -v alacritty &> /dev/null; then
            if alacritty --print-events &> /dev/null; then
                log_success "Alacritty configuration is valid"
            else
                log_error "Alacritty configuration has errors"
                ((errors++))
            fi
        fi
    fi
    
    # Check Kitty
    if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
        if command -v kitty &> /dev/null; then
            if kitty --config "$HOME/.config/kitty/kitty.conf" --check-config &> /dev/null; then
                log_success "Kitty configuration is valid"
            else
                log_error "Kitty configuration has errors"
                ((errors++))
            fi
        fi
    fi
    
    # Check fonts
    log_info "Checking font availability..."
    local font_found=false
    for font in "${FONTS[@]}"; do
        if fc-list | grep -i "$font" &> /dev/null 2>&1 || \
           system_profiler SPFontsDataType 2>/dev/null | grep -i "$font" &> /dev/null; then
            log_success "Font available: $font"
            font_found=true
            break
        fi
    done
    
    if [[ "$font_found" != "true" ]]; then
        log_warning "No programming fonts found, consider running with --install-fonts"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "All configurations are valid"
        return 0
    else
        log_error "Found $errors configuration errors"
        return 1
    fi
}

# Configure all terminals
configure_terminals() {
    log_info "Configuring terminal emulators..."
    
    for terminal in "${TERMINALS[@]}"; do
        case "$terminal" in
            "alacritty")
                configure_alacritty
                ;;
            "kitty")
                configure_kitty
                ;;
            "iterm2")
                configure_iterm2
                ;;
            "terminal_app")
                configure_terminal_app
                ;;
            *)
                log_warning "Unknown terminal: $terminal"
                ;;
        esac
    done
}

# Display post-installation information
show_post_install_info() {
    cat << EOF

$(tput setaf 2)✓ Terminal Setup Complete!$(tput sgr0)

$(tput setaf 4)Next Steps:$(tput sgr0)
1. Restart your terminals to see the new configurations
2. Verify fonts are displaying correctly with ligatures
3. Test color scheme consistency across terminals
4. Adjust font sizes if needed for your display

$(tput setaf 4)Available Commands:$(tput sgr0)
• Validate configurations: $0 --validate
• Install fonts: $0 --install-fonts
• Configure specific terminal: $0 -t alacritty

$(tput setaf 4)Troubleshooting:$(tput sgr0)
• Check font installation: fc-list | grep -i jetbrains
• Verify terminal installations: which alacritty kitty
• Review logs for any errors above

$(tput setaf 4)Documentation:$(tput sgr0)
• Alacritty: $DOTFILES_DIR/config/alacritty/
• Kitty: $DOTFILES_DIR/config/kitty/
• iTerm2: $DOTFILES_DIR/os/macos/iterm2/README.md
• Terminal.app: $DOTFILES_DIR/os/macos/terminal/

EOF
}

# Main execution
main() {
    log_info "Starting terminal emulator configuration (DEV-004)..."
    log_info "Dotfiles directory: $DOTFILES_DIR"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check system compatibility
    check_system
    
    # Configure terminals
    configure_terminals
    
    # Validate configurations unless in dry-run mode
    if [[ "$DRY_RUN" != "true" ]]; then
        validate_terminal_configs
    fi
    
    # Show completion message
    if [[ "$DRY_RUN" != "true" ]]; then
        show_post_install_info
    else
        log_info "Dry run completed. Use without --dry-run to apply changes."
    fi
    
    log_success "Terminal setup completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 