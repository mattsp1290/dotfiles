#!/usr/bin/env bash

# Linux Package Installation Script
# Install and manage Linux packages across multiple distributions and package managers

set -euo pipefail

# Script directory and root directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINUX_DIR="$DOTFILES_ROOT/os/linux"

# Source required libraries
# shellcheck source=scripts/lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=scripts/lib/detect-os.sh  
source "$SCRIPT_DIR/lib/detect-os.sh"

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
TOTAL_STEPS=8
CURRENT_STEP=0

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${BLUE}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} $1"
}

# Check if we're on Linux
check_linux() {
    if [[ "$(detect_os_type)" != "linux" ]]; then
        log_error "This script is only supported on Linux"
        exit 1
    fi
}

# Check if running with appropriate privileges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This may cause permission issues."
        log_info "Consider running as a regular user with sudo access."
    fi
    
    # Check if user can use sudo
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo access for package installation"
        log_info "You may be prompted for your password"
    fi
}

# Get the primary package manager for the current distribution
get_primary_package_manager() {
    local pm
    pm=$(detect_package_manager)
    
    case "$pm" in
        apt|dnf|pacman)
            echo "$pm"
            ;;
        yum)
            # Prefer DNF over YUM on newer systems
            if command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        *)
            log_warning "Unsupported package manager: $pm"
            echo "unknown"
            ;;
    esac
}

# Parse package list file and extract package names
parse_package_list() {
    local file="$1"
    local include_optional="${2:-false}"
    
    if [[ ! -f "$file" ]]; then
        log_error "Package list not found: $file"
        return 1
    fi
    
    # Extract package names, ignoring comments and empty lines
    local packages=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract package name (first word)
        local package
        package=$(echo "$line" | awk '{print $1}')
        [[ -z "$package" ]] && continue
        
        # Check if it's optional
        if [[ "$line" =~ \#OPTIONAL ]]; then
            [[ "$include_optional" == true ]] && packages+=("$package")
        else
            packages+=("$package")
        fi
    done < "$file"
    
    printf '%s\n' "${packages[@]}"
}

# Install packages using APT (Debian/Ubuntu)
install_apt_packages() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    log_info "Installing APT packages from $package_file..."
    
    # Parse package list
    local packages
    if ! packages=$(parse_package_list "$package_file" "$include_optional"); then
        return 1
    fi
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages to install"
        return 0
    fi
    
    # Update package database
    log_info "Updating APT package database..."
    if ! sudo apt update; then
        log_warning "Failed to update package database"
    fi
    
    # Convert packages to array
    local package_array
    mapfile -t package_array <<< "$packages"
    
    log_info "Installing ${#package_array[@]} packages..."
    
    # Install packages with error handling
    local failed_packages=()
    for package in "${package_array[@]}"; do
        [[ -z "$package" ]] && continue
        
        log_info "Installing: $package"
        if ! sudo apt install -y "$package" 2>/dev/null; then
            log_warning "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    local installed_count=$((${#package_array[@]} - ${#failed_packages[@]}))
    log_success "Installed $installed_count/${#package_array[@]} packages successfully"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Install packages using DNF (Fedora/RHEL)
install_dnf_packages() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    log_info "Installing DNF packages from $package_file..."
    
    # Parse package list
    local packages
    if ! packages=$(parse_package_list "$package_file" "$include_optional"); then
        return 1
    fi
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages to install"
        return 0
    fi
    
    # Update package database
    log_info "Updating DNF package database..."
    if ! sudo dnf check-update; then
        # dnf check-update returns 100 if updates are available, which is normal
        if [[ $? -ne 100 ]]; then
            log_warning "Failed to check for updates"
        fi
    fi
    
    # Convert packages to array
    local package_array
    mapfile -t package_array <<< "$packages"
    
    log_info "Installing ${#package_array[@]} packages..."
    
    # Install packages with error handling
    local failed_packages=()
    for package in "${package_array[@]}"; do
        [[ -z "$package" ]] && continue
        
        log_info "Installing: $package"
        if ! sudo dnf install -y "$package" 2>/dev/null; then
            log_warning "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    local installed_count=$((${#package_array[@]} - ${#failed_packages[@]}))
    log_success "Installed $installed_count/${#package_array[@]} packages successfully"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Install packages using Pacman (Arch Linux)
install_pacman_packages() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    log_info "Installing Pacman packages from $package_file..."
    
    # Parse package list
    local packages
    if ! packages=$(parse_package_list "$package_file" "$include_optional"); then
        return 1
    fi
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages to install"
        return 0
    fi
    
    # Update package database
    log_info "Updating Pacman package database..."
    if ! sudo pacman -Sy; then
        log_warning "Failed to update package database"
    fi
    
    # Convert packages to array
    local package_array
    mapfile -t package_array <<< "$packages"
    
    log_info "Installing ${#package_array[@]} packages..."
    
    # Install packages with error handling
    local failed_packages=()
    for package in "${package_array[@]}"; do
        [[ -z "$package" ]] && continue
        
        log_info "Installing: $package"
        if ! sudo pacman -S --noconfirm "$package" 2>/dev/null; then
            log_warning "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    local installed_count=$((${#package_array[@]} - ${#failed_packages[@]}))
    log_success "Installed $installed_count/${#package_array[@]} packages successfully"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Install Snap packages
install_snap_packages() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    # Check if snap is available
    if ! command -v snap >/dev/null 2>&1; then
        log_warning "Snap not available. Install snapd first."
        return 1
    fi
    
    log_info "Installing Snap packages from $package_file..."
    
    # Parse package list
    local packages
    if ! packages=$(parse_package_list "$package_file" "$include_optional"); then
        return 1
    fi
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages to install"
        return 0
    fi
    
    # Convert packages to array
    local package_array
    mapfile -t package_array <<< "$packages"
    
    log_info "Installing ${#package_array[@]} snap packages..."
    
    # Install packages with error handling
    local failed_packages=()
    for package in "${package_array[@]}"; do
        [[ -z "$package" ]] && continue
        
        log_info "Installing snap: $package"
        # Try classic mode first, then strict mode
        if ! sudo snap install "$package" --classic 2>/dev/null && ! sudo snap install "$package" 2>/dev/null; then
            log_warning "Failed to install snap: $package"
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    local installed_count=$((${#package_array[@]} - ${#failed_packages[@]}))
    log_success "Installed $installed_count/${#package_array[@]} snap packages successfully"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed snap packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Install Flatpak packages
install_flatpak_packages() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    # Check if flatpak is available
    if ! command -v flatpak >/dev/null 2>&1; then
        log_warning "Flatpak not available. Install flatpak first."
        return 1
    fi
    
    log_info "Installing Flatpak packages from $package_file..."
    
    # Ensure Flathub repository is added
    if ! flatpak remote-list | grep -q flathub; then
        log_info "Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    # Parse package list
    local packages
    if ! packages=$(parse_package_list "$package_file" "$include_optional"); then
        return 1
    fi
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages to install"
        return 0
    fi
    
    # Convert packages to array
    local package_array
    mapfile -t package_array <<< "$packages"
    
    log_info "Installing ${#package_array[@]} flatpak packages..."
    
    # Install packages with error handling
    local failed_packages=()
    for package in "${package_array[@]}"; do
        [[ -z "$package" ]] && continue
        
        log_info "Installing flatpak: $package"
        if ! flatpak install -y flathub "$package" 2>/dev/null; then
            log_warning "Failed to install flatpak: $package"
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    local installed_count=$((${#package_array[@]} - ${#failed_packages[@]}))
    log_success "Installed $installed_count/${#package_array[@]} flatpak packages successfully"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed flatpak packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Setup package repositories
setup_repositories() {
    local distro
    distro=$(detect_linux_distribution)
    
    log_info "Setting up additional repositories for $distro..."
    
    case "$distro" in
        ubuntu|debian)
            # Enable universe repository for Ubuntu
            if [[ "$distro" == "ubuntu" ]]; then
                sudo add-apt-repository universe -y 2>/dev/null || true
            fi
            ;;
        fedora)
            # Enable RPM Fusion repositories
            if ! dnf repolist | grep -q rpmfusion; then
                log_info "Enabling RPM Fusion repositories..."
                sudo dnf install -y \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
                    2>/dev/null || log_warning "Failed to enable RPM Fusion"
            fi
            ;;
        arch)
            # Update package database
            sudo pacman -Sy 2>/dev/null || true
            ;;
    esac
}

# Cleanup package caches
cleanup_packages() {
    local pm
    pm=$(get_primary_package_manager)
    
    log_info "Cleaning up package caches..."
    
    case "$pm" in
        apt)
            sudo apt autoremove -y
            sudo apt autoclean
            ;;
        dnf)
            sudo dnf autoremove -y
            sudo dnf clean all
            ;;
        pacman)
            # Clean package cache but keep 3 most recent versions
            sudo pacman -Sc --noconfirm
            ;;
    esac
    
    log_success "Package cleanup completed"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install and manage Linux packages across multiple distributions and package managers.

OPTIONS:
    -c, --core-only     Install only core packages (default)
    -o, --optional      Install optional packages (includes core)
    -a, --all           Install all packages (core + optional)
    --snap              Install Snap packages only
    --flatpak           Install Flatpak packages only
    --native            Install native packages only (apt/dnf/pacman)
    -u, --update        Update package databases
    -s, --status        Show package status without installing
    --cleanup           Clean up package caches
    --dry-run           Show what would be installed without installing
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Install core native packages only
    $0 --optional       # Install core + optional native packages
    $0 --all            # Install all packages (native + snap + flatpak)
    $0 --snap           # Install snap packages only
    $0 --status         # Check package status
    $0 --cleanup        # Clean up package caches

SUPPORTED DISTRIBUTIONS:
    - Ubuntu 20.04+ (APT)
    - Debian 11+ (APT)
    - Fedora 36+ (DNF)
    - Arch Linux (Pacman)

EOF
}

# Parse command line arguments
INSTALL_CORE=true
INSTALL_OPTIONAL=false
INSTALL_SNAP=false
INSTALL_FLATPAK=false
INSTALL_NATIVE=true
UPDATE_MODE=false
STATUS_MODE=false
CLEANUP_MODE=false
DRY_RUN=false

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
            INSTALL_SNAP=true
            INSTALL_FLATPAK=true
            shift
            ;;
        --snap)
            INSTALL_SNAP=true
            INSTALL_NATIVE=false
            shift
            ;;
        --flatpak)
            INSTALL_FLATPAK=true
            INSTALL_NATIVE=false
            shift
            ;;
        --native)
            INSTALL_NATIVE=true
            INSTALL_SNAP=false
            INSTALL_FLATPAK=false
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
        --dry-run)
            DRY_RUN=true
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
    echo -e "${GREEN}║                 Linux Package Installer                     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Step 1: Verify environment
    show_progress "Verifying environment"
    check_linux
    check_privileges
    
    # Step 2: Detect distribution and package manager
    show_progress "Detecting distribution"
    local distro
    distro=$(detect_linux_distribution)
    local pm
    pm=$(get_primary_package_manager)
    
    log_info "Distribution: $distro"
    log_info "Package manager: $pm"
    
    if [[ "$pm" == "unknown" ]]; then
        log_error "Unsupported distribution or package manager"
        exit 1
    fi
    
    # Step 3: Setup repositories
    show_progress "Setting up repositories"
    if [[ "$DRY_RUN" != true ]] && [[ "$STATUS_MODE" != true ]]; then
        setup_repositories
    fi
    
    # Step 4: Handle update mode
    if [[ "$UPDATE_MODE" == true ]]; then
        show_progress "Updating package databases"
        case "$pm" in
            apt) sudo apt update ;;
            dnf) sudo dnf check-update || true ;;
            pacman) sudo pacman -Sy ;;
        esac
        log_success "Package databases updated"
        return 0
    fi
    
    # Step 5: Handle cleanup mode
    if [[ "$CLEANUP_MODE" == true ]]; then
        show_progress "Cleaning up packages"
        if [[ "$DRY_RUN" != true ]]; then
            cleanup_packages
        else
            log_info "[DRY RUN] Would clean up package caches"
        fi
        return 0
    fi
    
    # Step 6: Install native packages
    show_progress "Installing native packages"
    if [[ "$INSTALL_NATIVE" == true ]] || [[ "$INSTALL_CORE" == true ]]; then
        local package_file="$LINUX_DIR/packages/${pm}.txt"
        
        if [[ "$STATUS_MODE" == true ]]; then
            log_info "Would install packages from: $package_file"
        elif [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would install packages from: $package_file"
            local packages
            packages=$(parse_package_list "$package_file" "$INSTALL_OPTIONAL")
            if [[ -n "$packages" ]]; then
                log_info "Packages to install:"
                echo "$packages" | sed 's/^/  - /'
            fi
        else
            case "$pm" in
                apt) install_apt_packages "$package_file" "$INSTALL_OPTIONAL" ;;
                dnf) install_dnf_packages "$package_file" "$INSTALL_OPTIONAL" ;;
                pacman) install_pacman_packages "$package_file" "$INSTALL_OPTIONAL" ;;
            esac
        fi
    fi
    
    # Step 7: Install Snap packages
    show_progress "Installing Snap packages"
    if [[ "$INSTALL_SNAP" == true ]]; then
        local snap_file="$LINUX_DIR/packages/snap.txt"
        
        if [[ "$STATUS_MODE" == true ]]; then
            if command -v snap >/dev/null 2>&1; then
                log_info "Snap is available"
            else
                log_warning "Snap is not installed"
            fi
        elif [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would install snap packages from: $snap_file"
        else
            install_snap_packages "$snap_file" "$INSTALL_OPTIONAL"
        fi
    fi
    
    # Step 8: Install Flatpak packages
    show_progress "Installing Flatpak packages"
    if [[ "$INSTALL_FLATPAK" == true ]]; then
        local flatpak_file="$LINUX_DIR/packages/flatpak.txt"
        
        if [[ "$STATUS_MODE" == true ]]; then
            if command -v flatpak >/dev/null 2>&1; then
                log_info "Flatpak is available"
            else
                log_warning "Flatpak is not installed"
            fi
        elif [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would install flatpak packages from: $flatpak_file"
        else
            install_flatpak_packages "$flatpak_file" "$INSTALL_OPTIONAL"
        fi
    fi
    
    echo
    log_success "Linux package operation completed!"
    
    # Show next steps
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "• Restart your terminal or run 'source ~/.bashrc' to ensure PATH is updated"
    echo "• Run '$0 --status' to check package installation status"
    if [[ "$INSTALL_SNAP" == true ]] || [[ "$INSTALL_FLATPAK" == true ]]; then
        echo "• Some GUI applications may need to be launched from the applications menu"
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Installation interrupted by user${NC}"; exit 130' INT

# Make script executable
chmod +x "$0" 2>/dev/null || true

# Run main function
main "$@" 