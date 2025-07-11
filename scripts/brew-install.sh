#!/usr/bin/env bash

# Homebrew Bundle Installation Script
# Install and manage macOS packages using Homebrew Bundle

set -euo pipefail

# Script directory and root directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$DOTFILES_ROOT/os/macos"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Progress tracking
TOTAL_STEPS=6
CURRENT_STEP=0

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${BLUE}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} $1"
}

# Check if we're on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is only supported on macOS"
        exit 1
    fi
}

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        return 1
    fi
    return 0
}

# Install Homebrew if not present
install_homebrew() {
    log_info "Homebrew not found. Installing Homebrew..."
    
    # Check if we have Xcode Command Line Tools
    if ! xcode-select -p &> /dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_warning "Please complete Xcode Command Line Tools installation and run this script again"
        exit 0
    fi
    
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installation completed"
}

# Update Homebrew and repositories
update_homebrew() {
    log_info "Updating Homebrew and repositories..."
    brew update
    log_success "Homebrew updated successfully"
}

# Install packages from a Brewfile
install_brewfile() {
    local brewfile_path="$1"
    local brewfile_name="$2"
    
    if [[ ! -f "$brewfile_path" ]]; then
        log_error "Brewfile not found: $brewfile_path"
        return 1
    fi
    
    log_info "Installing packages from $brewfile_name..."
    log_info "This may take several minutes depending on your internet connection..."
    
    # Use --no-lock to avoid issues with concurrent brew operations
    # Use --verbose for detailed output
    if brew bundle install --file="$brewfile_path" --verbose --no-lock; then
        log_success "$brewfile_name packages installed successfully"
        return 0
    else
        log_error "Failed to install some packages from $brewfile_name"
        log_info "You can run 'brew bundle check --file=$brewfile_path' to see what failed"
        return 1
    fi
}

# Check what packages would be installed/updated
check_brewfile() {
    local brewfile_path="$1"
    local brewfile_name="$2"
    
    if [[ ! -f "$brewfile_path" ]]; then
        log_error "Brewfile not found: $brewfile_path"
        return 1
    fi
    
    log_info "Checking $brewfile_name packages..."
    
    # Show what would be installed
    if brew bundle check --file="$brewfile_path" --verbose; then
        log_success "All $brewfile_name packages are already installed"
        return 0
    else
        log_info "Some $brewfile_name packages need to be installed or updated"
        return 1
    fi
}

# Cleanup Homebrew
cleanup_homebrew() {
    log_info "Cleaning up Homebrew cache and outdated packages..."
    brew cleanup
    brew autoremove
    log_success "Homebrew cleanup completed"
}

# Install mas-cli for Mac App Store apps if not present
install_mas() {
    if ! command -v mas &> /dev/null; then
        log_info "Installing mas-cli for Mac App Store integration..."
        brew install mas
        log_success "mas-cli installed successfully"
    else
        log_info "mas-cli already installed"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install and manage macOS packages using Homebrew Bundle.

OPTIONS:
    -c, --core-only     Install only core packages (default)
    -o, --optional      Install optional packages (includes core)
    -a, --all           Install all packages (core + optional)
    -u, --update        Update Homebrew and check for package updates
    -s, --status        Show status of packages without installing
    --cleanup           Clean up Homebrew cache and outdated packages
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Install core packages only
    $0 --optional       # Install core + optional packages
    $0 --status         # Check package status
    $0 --update         # Update Homebrew and packages
    $0 --cleanup        # Clean up Homebrew

EOF
}

# Parse command line arguments
INSTALL_CORE=true
INSTALL_OPTIONAL=false
UPDATE_MODE=false
STATUS_MODE=false
CLEANUP_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--core-only)
            INSTALL_CORE=true
            INSTALL_OPTIONAL=false
            shift
            ;;
        -o|--optional)
            INSTALL_CORE=true
            INSTALL_OPTIONAL=true
            shift
            ;;
        -a|--all)
            INSTALL_CORE=true
            INSTALL_OPTIONAL=true
            shift
            ;;
        -u|--update)
            UPDATE_MODE=true
            shift
            ;;
        -s|--status)
            STATUS_MODE=true
            shift
            ;;
        --cleanup)
            CLEANUP_MODE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Homebrew Bundle Installer                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo

    # Step 1: Verify environment
    show_progress "Verifying environment"
    check_macos
    
    # Step 2: Check/Install Homebrew
    show_progress "Checking Homebrew installation"
    if ! check_homebrew; then
        install_homebrew
    else
        log_success "Homebrew is already installed"
    fi
    
    # Step 3: Update Homebrew
    show_progress "Updating Homebrew"
    if [[ "$UPDATE_MODE" == true ]] || [[ "$STATUS_MODE" == false ]]; then
        update_homebrew
    fi
    
    # Step 4: Install mas-cli
    show_progress "Setting up Mac App Store CLI"
    install_mas
    
    # Define Brewfile paths
    CORE_BREWFILE="$MACOS_DIR/Brewfile"
    OPTIONAL_BREWFILE="$MACOS_DIR/Brewfile.optional"
    
    # Step 5: Handle different modes
    show_progress "Processing packages"
    
    if [[ "$STATUS_MODE" == true ]]; then
        # Status mode - check what's installed
        log_info "Checking package status..."
        
        if [[ "$INSTALL_CORE" == true ]]; then
            check_brewfile "$CORE_BREWFILE" "core"
        fi
        
        if [[ "$INSTALL_OPTIONAL" == true ]]; then
            check_brewfile "$OPTIONAL_BREWFILE" "optional"
        fi
        
    elif [[ "$UPDATE_MODE" == true ]]; then
        # Update mode - upgrade packages
        log_info "Upgrading installed packages..."
        brew upgrade
        brew upgrade --cask
        log_success "Package upgrade completed"
        
    else
        # Install mode
        local failed_installations=0
        
        if [[ "$INSTALL_CORE" == true ]]; then
            if ! install_brewfile "$CORE_BREWFILE" "core"; then
                failed_installations=$((failed_installations + 1))
            fi
        fi
        
        if [[ "$INSTALL_OPTIONAL" == true ]]; then
            if ! install_brewfile "$OPTIONAL_BREWFILE" "optional"; then
                failed_installations=$((failed_installations + 1))
            fi
        fi
        
        if [[ $failed_installations -gt 0 ]]; then
            log_warning "Some package installations failed. Check the output above for details."
        fi
    fi
    
    # Step 6: Cleanup
    show_progress "Finalizing"
    if [[ "$CLEANUP_MODE" == true ]] || [[ "$STATUS_MODE" == false && "$UPDATE_MODE" == false ]]; then
        cleanup_homebrew
    fi
    
    echo
    log_success "Homebrew Bundle operation completed!"
    
    # Show next steps
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "• Run 'brew doctor' to check for any issues"
    echo "• Run 'brew bundle check --file=$CORE_BREWFILE' to verify core packages"
    if [[ "$INSTALL_OPTIONAL" == true ]]; then
        echo "• Run 'brew bundle check --file=$OPTIONAL_BREWFILE' to verify optional packages"
    fi
    echo "• Restart your terminal or run 'source ~/.zshrc' to ensure PATH is updated"
}

# Handle script interruption
trap 'echo -e "\n${RED}Installation interrupted by user${NC}"; exit 130' INT

# Run main function
main "$@" 