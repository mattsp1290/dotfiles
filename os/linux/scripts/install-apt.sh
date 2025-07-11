#!/usr/bin/env bash

# APT Package Installation Script
# Install and manage packages on Debian/Ubuntu systems

set -euo pipefail

# Script directory and root directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source required libraries
source "$DOTFILES_ROOT/scripts/lib/utils.sh"
source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[APT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[APT]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[APT]${NC} $1"
}

log_error() {
    echo -e "${RED}[APT]${NC} $1"
}

# Check if we're on a Debian-based system
check_debian_based() {
    local distro
    distro=$(detect_linux_distribution)
    
    case "$distro" in
        ubuntu|debian|linuxmint|pop|elementary)
            return 0
            ;;
        *)
            log_error "This script is for Debian-based systems only. Detected: $distro"
            return 1
            ;;
    esac
}

# Update package database
update_package_database() {
    log_info "Updating APT package database..."
    
    if sudo apt update; then
        log_success "Package database updated successfully"
    else
        log_error "Failed to update package database"
        return 1
    fi
}

# Setup additional repositories
setup_repositories() {
    local distro
    distro=$(detect_linux_distribution)
    
    log_info "Setting up additional repositories for $distro..."
    
    case "$distro" in
        ubuntu)
            # Enable universe repository
            log_info "Enabling universe repository..."
            sudo add-apt-repository universe -y 2>/dev/null || log_warning "Failed to enable universe repository"
            
            # Enable restricted repository for codecs, drivers, etc.
            log_info "Enabling restricted repository..."
            sudo add-apt-repository restricted -y 2>/dev/null || log_warning "Failed to enable restricted repository"
            ;;
        debian)
            # Enable non-free repository for proprietary packages
            local sources_file="/etc/apt/sources.list"
            if ! grep -q "non-free" "$sources_file"; then
                log_info "Enabling non-free repository..."
                sudo sed -i 's/main$/main contrib non-free/' "$sources_file" || log_warning "Failed to enable non-free repository"
            fi
            ;;
    esac
    
    # Update after adding repositories
    update_package_database
}

# Install essential packages first
install_essential_packages() {
    log_info "Installing essential packages..."
    
    local essential_packages=(
        "apt-transport-https"
        "ca-certificates"
        "curl"
        "gnupg"
        "lsb-release"
        "software-properties-common"
    )
    
    for package in "${essential_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing essential package: $package"
            sudo apt install -y "$package" || log_warning "Failed to install: $package"
        fi
    done
}

# Add external repositories (PPAs, third-party repos)
add_external_repositories() {
    log_info "Adding external repositories..."
    
    # Git PPA for latest Git version
    if ! grep -q "git-core/ppa" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_info "Adding Git PPA..."
        sudo add-apt-repository ppa:git-core/ppa -y 2>/dev/null || log_warning "Failed to add Git PPA"
    fi
    
    # GitHub CLI repository
    if ! grep -q "github.com/cli/cli" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_info "Adding GitHub CLI repository..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    fi
    
    # Docker repository (optional, commented out by default)
    # if ! grep -q "docker.com" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    #     log_info "Adding Docker repository..."
    #     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    #     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    # fi
    
    # Update after adding repositories
    update_package_database
}

# Parse package list and install packages
install_packages_from_list() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    if [[ ! -f "$package_file" ]]; then
        log_error "Package file not found: $package_file"
        return 1
    fi
    
    log_info "Installing packages from: $(basename "$package_file")"
    
    # Extract package names
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
    done < "$package_file"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages to install"
        return 0
    fi
    
    log_info "Installing ${#packages[@]} packages..."
    
    # Install packages in batches for better error handling
    local batch_size=10
    local failed_packages=()
    local installed_count=0
    
    for ((i=0; i<${#packages[@]}; i+=batch_size)); do
        local batch=("${packages[@]:i:batch_size}")
        
        log_info "Installing batch: ${batch[*]}"
        
        # Try to install the batch
        if sudo apt install -y "${batch[@]}" 2>/dev/null; then
            installed_count=$((installed_count + ${#batch[@]}))
            log_success "Installed batch successfully"
        else
            # If batch fails, try individual packages
            log_warning "Batch installation failed, trying individual packages..."
            
            for package in "${batch[@]}"; do
                if sudo apt install -y "$package" 2>/dev/null; then
                    ((installed_count++))
                    log_success "Installed: $package"
                else
                    failed_packages+=("$package")
                    log_warning "Failed to install: $package"
                fi
            done
        fi
    done
    
    # Report results
    log_success "Installed $installed_count/${#packages[@]} packages successfully"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed packages: ${failed_packages[*]}"
        log_info "You can try installing failed packages manually or check if they're available in your distribution"
        return 1
    fi
    
    return 0
}

# Check package installation status
check_package_status() {
    local package_file="$1"
    local include_optional="${2:-false}"
    
    if [[ ! -f "$package_file" ]]; then
        log_error "Package file not found: $package_file"
        return 1
    fi
    
    log_info "Checking package status from: $(basename "$package_file")"
    
    # Extract package names
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
    done < "$package_file"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages to check"
        return 0
    fi
    
    local installed_count=0
    local not_installed=()
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            ((installed_count++))
        else
            not_installed+=("$package")
        fi
    done
    
    log_info "Package status: $installed_count/${#packages[@]} installed"
    
    if [[ ${#not_installed[@]} -gt 0 ]]; then
        log_info "Not installed: ${not_installed[*]}"
    fi
    
    return 0
}

# Cleanup packages
cleanup_packages() {
    log_info "Cleaning up APT packages..."
    
    # Remove orphaned packages
    sudo apt autoremove -y
    
    # Clean package cache
    sudo apt autoclean
    
    # Clean all cached packages (more aggressive)
    # sudo apt clean
    
    log_success "APT cleanup completed"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] PACKAGE_FILE

Install and manage APT packages on Debian/Ubuntu systems.

OPTIONS:
    --optional      Include optional packages
    --status        Check package status without installing
    --cleanup       Clean up package cache and orphaned packages
    --setup-repos   Setup additional repositories only
    -h, --help      Show this help message

ARGUMENTS:
    PACKAGE_FILE    Path to package list file

EXAMPLES:
    $0 /path/to/apt.txt
    $0 --optional /path/to/apt.txt
    $0 --status /path/to/apt.txt
    $0 --cleanup

EOF
}

# Parse command line arguments
INCLUDE_OPTIONAL=false
STATUS_MODE=false
CLEANUP_MODE=false
SETUP_REPOS_ONLY=false
PACKAGE_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --optional)
            INCLUDE_OPTIONAL=true
            shift
            ;;
        --status)
            STATUS_MODE=true
            shift
            ;;
        --cleanup)
            CLEANUP_MODE=true
            shift
            ;;
        --setup-repos)
            SETUP_REPOS_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            PACKAGE_FILE="$1"
            shift
            ;;
    esac
done

# Main execution
main() {
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    APT Package Manager                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check if we're on a supported system
    if ! check_debian_based; then
        exit 1
    fi
    
    # Handle cleanup mode
    if [[ "$CLEANUP_MODE" == true ]]; then
        cleanup_packages
        exit 0
    fi
    
    # Setup repositories
    if [[ "$SETUP_REPOS_ONLY" == true ]] || [[ "$STATUS_MODE" != true ]]; then
        install_essential_packages
        setup_repositories
        add_external_repositories
    fi
    
    # Exit if only setting up repositories
    if [[ "$SETUP_REPOS_ONLY" == true ]]; then
        log_success "Repository setup completed"
        exit 0
    fi
    
    # Validate package file
    if [[ -z "$PACKAGE_FILE" ]]; then
        log_error "Package file is required"
        show_usage
        exit 1
    fi
    
    # Handle status mode
    if [[ "$STATUS_MODE" == true ]]; then
        check_package_status "$PACKAGE_FILE" "$INCLUDE_OPTIONAL"
        exit 0
    fi
    
    # Install packages
    if install_packages_from_list "$PACKAGE_FILE" "$INCLUDE_OPTIONAL"; then
        log_success "Package installation completed successfully"
    else
        log_warning "Package installation completed with some failures"
        exit 1
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Installation interrupted by user${NC}"; exit 130' INT

# Run main function
main "$@" 