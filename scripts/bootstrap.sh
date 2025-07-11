#!/usr/bin/env bash
# Bootstrap script for dotfiles installation
# This script sets up the environment and installs all dotfiles

set -euo pipefail

# Script version
readonly VERSION="1.0.0"

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/detect-os.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables
INSTALL_MODE="install"
DRY_RUN=false
VERBOSE=false
FORCE=false
SKIP_PREREQUISITES=false
SKIP_TOOLS=false
OFFLINE_MODE=false
INTERACTIVE=true

# Repository information
REPO_URL="${DOTFILES_REPO_URL:-https://github.com/$(whoami)/dotfiles.git}"
REPO_BRANCH="${DOTFILES_BRANCH:-main}"

# Tool versions (can be overridden by environment variables)
STOW_MIN_VERSION="${STOW_MIN_VERSION:-2.3.0}"
GIT_MIN_VERSION="${GIT_MIN_VERSION:-2.0.0}"

# Usage information
usage() {
    cat << EOF
Dotfiles Bootstrap Script v${VERSION}

USAGE:
    $(basename "$0") [OPTIONS] [MODE]

MODES:
    install     Install dotfiles (default)
    update      Update existing installation
    repair      Repair broken symlinks and configurations
    uninstall   Remove dotfiles installation
    doctor      Diagnose common issues

OPTIONS:
    -h, --help              Show this help message
    -V, --version          Show version information
    -d, --dry-run          Show what would be done without making changes
    -v, --verbose          Enable verbose output
    -f, --force            Force operations (skip confirmations)
    -q, --quiet            Suppress non-error output
    --offline              Run in offline mode (skip network operations)
    --skip-prerequisites   Skip prerequisite checking
    --skip-tools          Skip tool installation
    --non-interactive     Run without user prompts

EXAMPLES:
    # Fresh installation
    $(basename "$0") install

    # Update existing installation
    $(basename "$0") update

    # Dry run to see what would happen
    $(basename "$0") --dry-run install

    # Force update without confirmations
    $(basename "$0") --force update

    # Diagnose issues
    $(basename "$0") doctor

EOF
}

# Parse command line arguments
parse_arguments() {
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                echo "Dotfiles Bootstrap Script v${VERSION}"
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -f|--force)
                FORCE=true
                INTERACTIVE=false
                shift
                ;;
            -q|--quiet)
                CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
                shift
                ;;
            --offline)
                OFFLINE_MODE=true
                shift
                ;;
            --skip-prerequisites)
                SKIP_PREREQUISITES=true
                shift
                ;;
            --skip-tools)
                SKIP_TOOLS=true
                shift
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # Set mode from remaining arguments
    if [[ ${#args[@]} -gt 0 ]]; then
        INSTALL_MODE="${args[0]}"
    fi
    
    # Validate mode
    case "$INSTALL_MODE" in
        install|update|repair|uninstall|doctor)
            ;;
        *)
            log_error "Invalid mode: $INSTALL_MODE"
            usage
            exit 1
            ;;
    esac
}

# Show banner
show_banner() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║       Dotfiles Bootstrap Script        ║${NC}"
        echo -e "${BLUE}║            Version ${VERSION}             ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# Show system information
show_system_info() {
    log_info "System Information:"
    log_info "  ${BULLET} OS: $(get_os_string)"
    log_info "  ${BULLET} Architecture: $(detect_architecture)"
    log_info "  ${BULLET} Package Manager: $(detect_package_manager)"
    
    if is_container; then
        log_info "  ${BULLET} Environment: Container"
    elif is_wsl; then
        log_info "  ${BULLET} Environment: WSL"
    fi
    
    echo ""
}

# Check prerequisites
check_prerequisites() {
    if [[ "$SKIP_PREREQUISITES" == true ]]; then
        log_info "Skipping prerequisite checks"
        return 0
    fi
    
    log_info "Checking prerequisites..."
    
    # Check OS compatibility
    if ! check_os_compatibility; then
        local current_version=$(detect_os_version)
        local min_version=$(get_minimum_os_version)
        log_error "OS version $current_version is below minimum required version $min_version"
        return 1
    fi
    
    # Check required commands
    local required_commands=("bash" "mkdir" "chmod" "ln")
    if ! check_required_commands "${required_commands[@]}"; then
        return 1
    fi
    
    # Check disk space (100MB minimum)
    if ! check_disk_space 100 "$HOME"; then
        return 1
    fi
    
    # Check network connectivity (unless offline mode)
    if [[ "$OFFLINE_MODE" != true ]]; then
        show_progress "Checking network connectivity"
        if has_internet; then
            end_progress "success"
        else
            end_progress "failed"
            log_warning "No internet connection detected. Some features may not work."
            if [[ "$INTERACTIVE" == true ]]; then
                if ! confirm "Continue without internet?"; then
                    return 1
                fi
            fi
        fi
    fi
    
    log_success "All prerequisites satisfied"
    return 0
}

# Install Homebrew (macOS only)
install_homebrew() {
    if [[ $(detect_os_type) != "macos" ]]; then
        return 0
    fi
    
    if command_exists brew; then
        log_info "Homebrew is already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install Homebrew"
        return 0
    fi
    
    log_info "Installing Homebrew..."
    
    if [[ "$OFFLINE_MODE" == true ]]; then
        log_error "Cannot install Homebrew in offline mode"
        return 1
    fi
    
    local install_script="/tmp/homebrew-install.sh"
    if download_file "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$install_script" "Downloading Homebrew installer"; then
        bash "$install_script" </dev/null
        rm -f "$install_script"
        
        # Add Homebrew to PATH for current session
        if is_apple_silicon; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed successfully"
    else
        log_error "Failed to download Homebrew installer"
        return 1
    fi
}

# Install GNU Stow
install_stow() {
    if command_exists stow; then
        local stow_version=$(stow --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        if version_ge "$stow_version" "$STOW_MIN_VERSION"; then
            log_info "GNU Stow $stow_version is already installed"
            return 0
        else
            log_warning "GNU Stow $stow_version is below minimum version $STOW_MIN_VERSION"
        fi
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install GNU Stow"
        return 0
    fi
    
    log_info "Installing GNU Stow..."
    
    local os_type=$(detect_os_type)
    local package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            retry_command 3 2 brew install stow
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y stow
            ;;
        dnf)
            sudo dnf install -y stow
            ;;
        yum)
            sudo yum install -y stow
            ;;
        pacman)
            sudo pacman -S --noconfirm stow
            ;;
        zypper)
            sudo zypper install -y stow
            ;;
        apk)
            sudo apk add --no-cache stow
            ;;
        *)
            log_error "Unable to install Stow with package manager: $package_manager"
            log_info "Please install GNU Stow manually"
            return 1
            ;;
    esac
    
    log_success "GNU Stow installed successfully"
}

# Install Git if missing
install_git() {
    if command_exists git; then
        local git_version=$(git --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        if version_ge "$git_version" "$GIT_MIN_VERSION"; then
            log_info "Git $git_version is already installed"
            return 0
        else
            log_warning "Git $git_version is below minimum version $GIT_MIN_VERSION"
        fi
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install Git"
        return 0
    fi
    
    log_info "Installing Git..."
    
    local package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install git
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y git
            ;;
        dnf)
            sudo dnf install -y git
            ;;
        yum)
            sudo yum install -y git
            ;;
        pacman)
            sudo pacman -S --noconfirm git
            ;;
        *)
            log_error "Unable to install Git with package manager: $package_manager"
            return 1
            ;;
    esac
    
    log_success "Git installed successfully"
}

# Install 1Password CLI
install_1password_cli() {
    if command_exists op; then
        log_info "1Password CLI is already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install 1Password CLI"
        return 0
    fi
    
    if [[ "$OFFLINE_MODE" == true ]]; then
        log_warning "Skipping 1Password CLI installation in offline mode"
        return 0
    fi
    
    log_info "Installing 1Password CLI..."
    
    local os_type=$(detect_os_type)
    local arch=$(detect_architecture)
    local package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install --cask 1password-cli
            ;;
        apt)
            # Add 1Password repository
            curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
                sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
                sudo tee /etc/apt/sources.list.d/1password.list
            sudo apt update && sudo apt install -y 1password-cli
            ;;
        *)
            log_warning "Automatic installation of 1Password CLI not supported for package manager: $package_manager"
            log_info "Please install manually from: https://developer.1password.com/docs/cli/get-started/"
            ;;
    esac
    
    if command_exists op; then
        log_success "1Password CLI installed successfully"
    fi
}

# Install Linux packages
install_linux_packages() {
    if [[ "$OFFLINE_MODE" == true ]]; then
        log_warning "Skipping Linux package installation in offline mode"
        return 0
    fi
    
    log_info "Installing Linux packages..."
    
    local linux_packages_script="$DOTFILES_ROOT/scripts/linux-packages.sh"
    
    if [[ ! -x "$linux_packages_script" ]]; then
        log_warning "Linux packages script not found or not executable: $linux_packages_script"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $linux_packages_script --core-only"
        return 0
    fi
    
    # Install core packages by default
    if "$linux_packages_script" --core-only; then
        log_success "Linux packages installed successfully"
    else
        log_warning "Some Linux packages failed to install"
        return 1
    fi
}

# Install cross-platform tools
install_cross_platform_tools() {
    if [[ "$OFFLINE_MODE" == true ]]; then
        log_warning "Skipping cross-platform tools installation in offline mode"
        return 0
    fi
    
    log_info "Installing cross-platform tools..."
    
    local tools_script="$DOTFILES_ROOT/scripts/install-tools.sh"
    
    if [[ ! -x "$tools_script" ]]; then
        log_warning "Cross-platform tools script not found or not executable: $tools_script"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $tools_script core"
        return 0
    fi
    
    # Install core cross-platform tools
    if "$tools_script" core; then
        log_success "Cross-platform tools installed successfully"
    else
        log_warning "Some cross-platform tools failed to install"
        return 1
    fi
}

# Install all required tools
install_tools() {
    if [[ "$SKIP_TOOLS" == true ]]; then
        log_info "Skipping tool installation"
        return 0
    fi
    
    log_info "Installing required tools..."
    
    local os_type
    os_type=$(detect_os_type)
    
    case "$os_type" in
        macos)
            # Install package manager (Homebrew on macOS)
            install_homebrew || return 1
            ;;
        linux)
            # Install Linux packages
            install_linux_packages || return 1
            ;;
        *)
            log_warning "Automatic package installation not supported for OS: $os_type"
            ;;
    esac
    
    # Install core tools
    install_git || return 1
    install_stow || return 1
    
    # Install secret management
    install_1password_cli || true  # Don't fail if this doesn't install
    
    # Install cross-platform tools
    install_cross_platform_tools || true  # Don't fail if this doesn't install
    
    log_success "All tools installed"
}

# Clone or update repository
manage_repository() {
    # If we're already in the dotfiles directory, skip cloning
    if [[ -d "$DOTFILES_ROOT/.git" ]]; then
        log_info "Already in dotfiles repository"
        
        if [[ "$INSTALL_MODE" == "update" ]] && [[ "$OFFLINE_MODE" != true ]]; then
            log_info "Updating repository..."
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would update repository"
                return 0
            fi
            
            # Check for uncommitted changes
            if git -C "$DOTFILES_ROOT" diff-index --quiet HEAD --; then
                git -C "$DOTFILES_ROOT" pull origin "$REPO_BRANCH"
                log_success "Repository updated"
            else
                log_warning "Uncommitted changes detected. Skipping repository update."
                log_info "Please commit or stash your changes and try again."
            fi
        fi
        
        return 0
    fi
    
    # Clone repository if not present
    if [[ "$OFFLINE_MODE" == true ]]; then
        log_error "Cannot clone repository in offline mode"
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would clone repository from $REPO_URL"
        return 0
    fi
    
    local target_dir="$HOME/.dotfiles"
    
    if [[ -d "$target_dir" ]]; then
        log_warning "Directory $target_dir already exists"
        if [[ "$INTERACTIVE" == true ]]; then
            if ! confirm "Remove existing directory and clone fresh?"; then
                return 1
            fi
        fi
        rm -rf "$target_dir"
    fi
    
    log_info "Cloning repository..."
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$target_dir"
    
    # Update DOTFILES_ROOT to new location
    DOTFILES_ROOT="$target_dir"
    cd "$DOTFILES_ROOT"
    
    log_success "Repository cloned to $target_dir"
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."
    
    local dirs=(
        "$HOME/.config"
        "$HOME/.local/share"
        "$HOME/.local/bin"
        "$HOME/.local/state"
        "$HOME/.cache"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            [[ ! -d "$dir" ]] && log_info "[DRY RUN] Would create directory: $dir"
        else
            ensure_dir "$dir"
        fi
    done
    
    log_success "Directories created"
}

# Stow packages
stow_packages() {
    log_info "Installing dotfiles with Stow..."
    
    cd "$DOTFILES_ROOT"
    
    # Check if our stow script exists
    local stow_script="$DOTFILES_ROOT/scripts/stow-all.sh"
    
    if [[ ! -x "$stow_script" ]]; then
        log_error "Stow script not found or not executable: $stow_script"
        return 1
    fi
    
    # Build arguments for stow script
    local stow_args=()
    
    if [[ "$DRY_RUN" == true ]]; then
        stow_args+=("-n")  # dry-run mode
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        stow_args+=("-v")  # verbose mode
    fi
    
    if [[ "$FORCE" == true ]]; then
        stow_args+=("-f")  # force mode
    fi
    
    # Run the stow script
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $stow_script ${stow_args[*]}"
    else
        "$stow_script" "${stow_args[@]}"
    fi
    
    return $?
}

# Run post-installation scripts
run_post_install() {
    local post_install_dir="$DOTFILES_ROOT/scripts/setup"
    
    if [[ ! -d "$post_install_dir" ]]; then
        log_debug "No post-installation scripts found"
        return 0
    fi
    
    log_info "Running post-installation scripts..."
    
    # Find and run all executable scripts in setup directory
    while IFS= read -r -d '' script; do
        if [[ -x "$script" ]]; then
            local script_name=$(basename "$script")
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would run: $script_name"
            else
                log_info "Running $script_name..."
                if "$script"; then
                    log_success "$script_name completed"
                else
                    log_warning "$script_name failed"
                fi
            fi
        fi
    done < <(find "$post_install_dir" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)
}

# Repair installation
perform_repair() {
    log_info "Repairing dotfiles installation..."
    
    # Check and fix broken symlinks
    log_info "Checking for broken symlinks..."
    local broken_links=0
    
    while IFS= read -r -d '' link; do
        if [[ ! -e "$link" ]]; then
            ((broken_links++))
            log_warning "Broken symlink: $link"
            
            if [[ "$DRY_RUN" != true ]] && [[ "$FORCE" == true || "$INTERACTIVE" == false ]]; then
                rm -f "$link"
                log_info "Removed broken symlink: $link"
            fi
        fi
    done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)
    
    if [[ $broken_links -eq 0 ]]; then
        log_success "No broken symlinks found"
    else
        log_info "Found $broken_links broken symlinks"
        
        if [[ "$INTERACTIVE" == true ]] && [[ "$DRY_RUN" != true ]]; then
            if confirm "Remove all broken symlinks?"; then
                find "$HOME" -maxdepth 3 -type l ! -exec test -e {} \; -delete 2>/dev/null
                log_success "Removed broken symlinks"
            fi
        fi
    fi
    
    # Re-stow packages
    stow_packages
    
    log_success "Repair completed"
}

# Uninstall dotfiles
perform_uninstall() {
    log_warning "This will remove all dotfiles symlinks!"
    
    if [[ "$INTERACTIVE" == true ]] && [[ "$FORCE" != true ]]; then
        if ! confirm "Are you sure you want to uninstall?"; then
            log_info "Uninstall cancelled"
            return 0
        fi
    fi
    
    log_info "Uninstalling dotfiles..."
    
    cd "$DOTFILES_ROOT"
    
    # Check if our unstow script exists
    local unstow_script="$DOTFILES_ROOT/scripts/unstow-all.sh"
    
    if [[ ! -x "$unstow_script" ]]; then
        log_error "Unstow script not found or not executable: $unstow_script"
        return 1
    fi
    
    # Build arguments for unstow script
    local unstow_args=()
    
    if [[ "$DRY_RUN" == true ]]; then
        unstow_args+=("-n")  # dry-run mode
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        unstow_args+=("-v")  # verbose mode
    fi
    
    unstow_args+=("-m" "all")  # unstow all packages
    
    # Run the unstow script
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $unstow_script ${unstow_args[*]}"
    else
        "$unstow_script" "${unstow_args[@]}"
    fi
    
    log_success "Dotfiles uninstalled"
    log_info "Note: The repository at $DOTFILES_ROOT was not removed"
}

# Diagnose common issues
perform_doctor() {
    log_info "Running diagnostics..."
    
    local issues=0
    
    # Check OS compatibility
    show_progress "Checking OS compatibility"
    if check_os_compatibility; then
        end_progress "success"
    else
        end_progress "failed"
        ((issues++))
    fi
    
    # Check required tools
    local tools=("git" "stow" "bash")
    for tool in "${tools[@]}"; do
        show_progress "Checking for $tool"
        if command_exists "$tool"; then
            end_progress "success"
        else
            end_progress "failed"
            ((issues++))
        fi
    done
    
    # Check repository
    show_progress "Checking repository"
    if [[ -d "$DOTFILES_ROOT/.git" ]]; then
        end_progress "success"
    else
        end_progress "failed"
        log_warning "Not in a git repository"
        ((issues++))
    fi
    
    # Check for broken symlinks
    show_progress "Checking for broken symlinks"
    local broken_count=0
    while IFS= read -r -d '' link; do
        [[ ! -e "$link" ]] && ((broken_count++))
    done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)
    
    if [[ $broken_count -eq 0 ]]; then
        end_progress "success"
    else
        end_progress "failed"
        log_warning "Found $broken_count broken symlinks"
        ((issues++))
    fi
    
    # Check network
    if [[ "$OFFLINE_MODE" != true ]]; then
        show_progress "Checking network connectivity"
        if has_internet; then
            end_progress "success"
        else
            end_progress "failed"
            ((issues++))
        fi
    fi
    
    # Summary
    echo ""
    if [[ $issues -eq 0 ]]; then
        log_success "No issues found!"
    else
        log_warning "Found $issues issue(s)"
        log_info "Run '$(basename "$0") repair' to fix some issues automatically"
    fi
}

# Main installation function
perform_install() {
    log_info "Starting dotfiles installation..."
    
    # Clone/update repository
    manage_repository || return 1
    
    # Install required tools
    install_tools || return 1
    
    # Create directories
    create_directories || return 1
    
    # Install dotfiles
    stow_packages || return 1
    
    # Run post-installation scripts
    run_post_install || true
    
    log_success "Installation complete!"
}

# Main update function
perform_update() {
    log_info "Updating dotfiles..."
    
    # Update repository
    manage_repository || return 1
    
    # Update tools
    install_tools || return 1
    
    # Re-stow packages (will update changed files)
    stow_packages || return 1
    
    # Run post-installation scripts
    run_post_install || true
    
    log_success "Update complete!"
}

# Show summary
show_summary() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN completed. No changes were made."
    else
        case "$INSTALL_MODE" in
            install)
                log_info "Next steps:"
                log_info "  1. Restart your shell or run: source ~/.zshrc"
                log_info "  2. Run '$(basename "$0") doctor' to verify installation"
                log_info "  3. See docs/ for detailed documentation"
                ;;
            update)
                log_info "Update completed. You may need to restart your shell."
                ;;
            repair)
                log_info "Repair completed. Check that everything works as expected."
                ;;
            uninstall)
                log_info "Uninstall completed. Dotfiles repository remains at: $DOTFILES_ROOT"
                ;;
        esac
    fi
}

# Main function
main() {
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    # Show confirmation if interactive
    if [[ "$INTERACTIVE" == true ]] && [[ "$DRY_RUN" != true ]]; then
        echo ""
        log_info "Mode: $INSTALL_MODE"
        log_info "Location: $DOTFILES_ROOT"
        echo ""
        
        if ! confirm "Proceed with $INSTALL_MODE?"; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    # Execute based on mode
    case "$INSTALL_MODE" in
        install)
            perform_install
            ;;
        update)
            perform_update
            ;;
        repair)
            perform_repair
            ;;
        uninstall)
            perform_uninstall
            ;;
        doctor)
            perform_doctor
            ;;
    esac
    
    local exit_code=$?
    
    # Show summary
    show_summary
    
    return $exit_code
}

# Entry point
parse_arguments "$@"

if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY RUN MODE - No changes will be made"
fi

show_banner
show_system_info

# Run main function
main
exit $?
