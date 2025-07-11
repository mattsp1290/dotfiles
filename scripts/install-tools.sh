#!/usr/bin/env bash
# Cross-Platform Tool Installation Script
# Main entry point for installing cross-platform development tools

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
DRY_RUN=false
VERBOSE=false
FORCE=false
OFFLINE_MODE=false
INTERACTIVE=true

# Tool categories to install
INSTALL_ASDF=true
INSTALL_DOCKER=true
INSTALL_CLOUD=true
INSTALL_DEV_TOOLS=true
INSTALL_OPTIONAL=false

# Usage information
usage() {
    cat << EOF
Cross-Platform Tool Installation Script v${VERSION}

USAGE:
    $(basename "$0") [OPTIONS] [CATEGORY]

CATEGORIES:
    core        Install core cross-platform tools (default)
    asdf        Install ASDF version manager only
    docker      Install Docker and container tools only
    cloud       Install cloud CLI tools only
    dev         Install development tools only
    optional    Install optional tools
    all         Install all tools including optional ones

OPTIONS:
    -h, --help              Show this help message
    -V, --version          Show version information
    -d, --dry-run          Show what would be done without making changes
    -v, --verbose          Enable verbose output
    -f, --force            Force operations (skip confirmations)
    -q, --quiet            Suppress non-error output
    --offline              Run in offline mode (skip network operations)
    --non-interactive     Run without user prompts
    --skip-asdf           Skip ASDF installation
    --skip-docker         Skip Docker installation
    --skip-cloud          Skip cloud tools installation
    --skip-dev            Skip development tools installation

EXAMPLES:
    # Install core tools
    $(basename "$0") core

    # Install all tools including optional ones
    $(basename "$0") all

    # Install only ASDF and development tools
    $(basename "$0") --skip-docker --skip-cloud core

    # Dry run to see what would be installed
    $(basename "$0") --dry-run all

    # Install cloud tools only
    $(basename "$0") cloud

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
                echo "Cross-Platform Tool Installation Script v${VERSION}"
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
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            --skip-asdf)
                INSTALL_ASDF=false
                shift
                ;;
            --skip-docker)
                INSTALL_DOCKER=false
                shift
                ;;
            --skip-cloud)
                INSTALL_CLOUD=false
                shift
                ;;
            --skip-dev)
                INSTALL_DEV_TOOLS=false
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
    
    # Set category from remaining arguments
    if [[ ${#args[@]} -gt 0 ]]; then
        local category="${args[0]}"
        
        case "$category" in
            core)
                # Default: all core tools
                ;;
            asdf)
                INSTALL_ASDF=true
                INSTALL_DOCKER=false
                INSTALL_CLOUD=false
                INSTALL_DEV_TOOLS=false
                ;;
            docker)
                INSTALL_ASDF=false
                INSTALL_DOCKER=true
                INSTALL_CLOUD=false
                INSTALL_DEV_TOOLS=false
                ;;
            cloud)
                INSTALL_ASDF=false
                INSTALL_DOCKER=false
                INSTALL_CLOUD=true
                INSTALL_DEV_TOOLS=false
                ;;
            dev)
                INSTALL_ASDF=false
                INSTALL_DOCKER=false
                INSTALL_CLOUD=false
                INSTALL_DEV_TOOLS=true
                ;;
            optional)
                INSTALL_OPTIONAL=true
                ;;
            all)
                INSTALL_OPTIONAL=true
                ;;
            *)
                log_error "Invalid category: $category"
                usage
                exit 1
                ;;
        esac
    fi
}

# Show banner
show_banner() {
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║   Cross-Platform Tool Installation     ║${NC}"
        echo -e "${BLUE}║            Version ${VERSION}             ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# Show installation plan
show_installation_plan() {
    log_info "Installation Plan:"
    log_info "  ${BULLET} ASDF Version Manager: $([ "$INSTALL_ASDF" = true ] && echo "Yes" || echo "No")"
    log_info "  ${BULLET} Docker & Container Tools: $([ "$INSTALL_DOCKER" = true ] && echo "Yes" || echo "No")"
    log_info "  ${BULLET} Cloud CLI Tools: $([ "$INSTALL_CLOUD" = true ] && echo "Yes" || echo "No")"
    log_info "  ${BULLET} Development Tools: $([ "$INSTALL_DEV_TOOLS" = true ] && echo "Yes" || echo "No")"
    log_info "  ${BULLET} Optional Tools: $([ "$INSTALL_OPTIONAL" = true ] && echo "Yes" || echo "No")"
    
    if [[ "$DRY_RUN" = true ]]; then
        log_info "  ${BULLET} Mode: DRY RUN (no changes will be made)"
    fi
    
    if [[ "$OFFLINE_MODE" = true ]]; then
        log_info "  ${BULLET} Offline Mode: Enabled"
    fi
    
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check OS compatibility
    if ! check_os_compatibility; then
        local current_version=$(detect_os_version)
        local min_version=$(get_minimum_os_version)
        log_error "OS version $current_version is below minimum required version $min_version"
        return 1
    fi
    
    # Check required commands
    local required_commands=("bash" "curl" "git")
    if ! check_required_commands "${required_commands[@]}"; then
        return 1
    fi
    
    # Check disk space (500MB minimum for tools)
    if ! check_disk_space 500 "$HOME"; then
        return 1
    fi
    
    # Check network connectivity (unless offline mode)
    if [[ "$OFFLINE_MODE" != true ]]; then
        show_progress "Checking network connectivity"
        if has_internet; then
            end_progress "success"
        else
            end_progress "failed"
            log_warning "No internet connection detected. Some tools may not install properly."
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

# Install ASDF version manager
install_asdf_tools() {
    if [[ "$INSTALL_ASDF" != true ]]; then
        return 0
    fi
    
    log_info "Installing ASDF version manager and tools..."
    
    local asdf_script="$DOTFILES_ROOT/tools/scripts/install-asdf.sh"
    
    if [[ ! -x "$asdf_script" ]]; then
        log_error "ASDF installation script not found: $asdf_script"
        return 1
    fi
    
    if [[ "$DRY_RUN" = true ]]; then
        log_info "[DRY RUN] Would run: $asdf_script install"
        return 0
    fi
    
    if "$asdf_script" install; then
        log_success "ASDF installation completed"
    else
        log_warning "ASDF installation encountered issues"
        return 1
    fi
}

# Install Docker and container tools
install_docker_tools() {
    if [[ "$INSTALL_DOCKER" != true ]]; then
        return 0
    fi
    
    log_info "Installing Docker and container tools..."
    
    local docker_script="$DOTFILES_ROOT/tools/scripts/install-docker.sh"
    
    if [[ ! -x "$docker_script" ]]; then
        log_error "Docker installation script not found: $docker_script"
        return 1
    fi
    
    if [[ "$DRY_RUN" = true ]]; then
        log_info "[DRY RUN] Would run: $docker_script install"
        return 0
    fi
    
    if "$docker_script" install; then
        log_success "Docker installation completed"
    else
        log_warning "Docker installation encountered issues"
        return 1
    fi
}

# Install cloud CLI tools
install_cloud_tools() {
    if [[ "$INSTALL_CLOUD" != true ]]; then
        return 0
    fi
    
    log_info "Installing cloud CLI tools..."
    
    local cloud_script="$DOTFILES_ROOT/tools/scripts/install-cloud-tools.sh"
    
    if [[ ! -x "$cloud_script" ]]; then
        log_error "Cloud tools installation script not found or not executable: $cloud_script"
        return 1
    fi
    
    if [[ "$DRY_RUN" = true ]]; then
        if [[ "$INSTALL_OPTIONAL" = true ]]; then
            log_info "[DRY RUN] Would run: $cloud_script all"
        else
            log_info "[DRY RUN] Would run: $cloud_script install"
        fi
        return 0
    fi
    
    if [[ "$OFFLINE_MODE" = true ]]; then
        log_warning "Cloud tools installation requires internet connectivity, skipping..."
        return 0
    fi
    
    # Install core or all cloud tools based on optional flag
    local install_mode="install"
    if [[ "$INSTALL_OPTIONAL" = true ]]; then
        install_mode="all"
    fi
    
    if "$cloud_script" "$install_mode"; then
        log_success "Cloud tools installation completed"
    else
        log_warning "Cloud tools installation encountered issues"
        return 1
    fi
}

# Install development tools
install_development_tools() {
    if [[ "$INSTALL_DEV_TOOLS" != true ]]; then
        return 0
    fi
    
    log_info "Installing development tools..."
    
    local dev_script="$DOTFILES_ROOT/tools/scripts/setup-development-tools.sh"
    
    if [[ ! -x "$dev_script" ]]; then
        log_error "Development tools installation script not found or not executable: $dev_script"
        return 1
    fi
    
    if [[ "$DRY_RUN" = true ]]; then
        if [[ "$INSTALL_OPTIONAL" = true ]]; then
            log_info "[DRY RUN] Would run: $dev_script all"
        else
            log_info "[DRY RUN] Would run: $dev_script install"
        fi
        return 0
    fi
    
    if [[ "$OFFLINE_MODE" = true ]]; then
        log_warning "Development tools installation requires internet connectivity, skipping..."
        return 0
    fi
    
    # Install core or all development tools based on optional flag
    local install_mode="install"
    if [[ "$INSTALL_OPTIONAL" = true ]]; then
        install_mode="all"
    fi
    
    if "$dev_script" "$install_mode"; then
        log_success "Development tools installation completed"
    else
        log_warning "Development tools installation encountered issues"
        return 1
    fi
}

# Show installation status
show_installation_status() {
    log_info "Installation Status Summary:"
    
    # ASDF status
    if [[ "$INSTALL_ASDF" = true ]]; then
        if command -v asdf >/dev/null 2>&1; then
            local asdf_version=$(asdf version 2>/dev/null | cut -d' ' -f1 || echo "unknown")
            log_success "  ${BULLET} ASDF: $asdf_version"
        else
            log_warning "  ${BULLET} ASDF: Not installed"
        fi
    fi
    
    # Docker status
    if [[ "$INSTALL_DOCKER" = true ]]; then
        if command -v docker >/dev/null 2>&1; then
            local docker_version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
            log_success "  ${BULLET} Docker: $docker_version"
        else
            log_warning "  ${BULLET} Docker: Not installed"
        fi
    fi
    
    # Cloud tools status
    if [[ "$INSTALL_CLOUD" = true ]]; then
        local cloud_tools_installed=0
        local cloud_tools_total=0
        
        # Check AWS CLI
        ((cloud_tools_total++))
        if command -v aws >/dev/null 2>&1; then
            ((cloud_tools_installed++))
        fi
        
        # Check Terraform
        ((cloud_tools_total++))
        if command -v terraform >/dev/null 2>&1; then
            ((cloud_tools_installed++))
        fi
        
        if [[ "$INSTALL_OPTIONAL" = true ]]; then
            # Check optional cloud tools
            for tool in "gcloud" "az"; do
                ((cloud_tools_total++))
                if command -v "$tool" >/dev/null 2>&1; then
                    ((cloud_tools_installed++))
                fi
            done
        fi
        
        log_info "  ${BULLET} Cloud Tools: $cloud_tools_installed/$cloud_tools_total installed"
    fi
    
    # Development tools status
    if [[ "$INSTALL_DEV_TOOLS" = true ]]; then
        local dev_tools_installed=0
        local dev_tools_total=0
        
        # Check core development tools
        for tool in "bat" "exa" "fd" "rg" "fzf" "jq" "delta" "gh"; do
            ((dev_tools_total++))
            if command -v "$tool" >/dev/null 2>&1; then
                ((dev_tools_installed++))
            fi
        done
        
        log_info "  ${BULLET} Development Tools: $dev_tools_installed/$dev_tools_total installed"
    fi
}

# Show next steps
show_next_steps() {
    if [[ "$DRY_RUN" = true ]]; then
        log_info "DRY RUN completed. No changes were made."
        log_info "Run without --dry-run to perform actual installation."
        return 0
    fi
    
    echo ""
    log_info "Next Steps:"
    
    # Shell restart recommendation
    log_info "  1. Restart your shell or run: source ~/.zshrc (or ~/.bashrc)"
    
    # ASDF specific instructions
    if [[ "$INSTALL_ASDF" = true ]] && command -v asdf >/dev/null 2>&1; then
        log_info "  2. ASDF is now available. Check status with: asdf --version"
        log_info "     - View installed plugins: asdf plugin list"
        log_info "     - View current tool versions: asdf current"
    fi
    
    # Docker specific instructions
    if [[ "$INSTALL_DOCKER" = true ]] && command -v docker >/dev/null 2>&1; then
        local os_type=$(detect_os_type)
        if [[ "$os_type" = "macos" ]]; then
            log_info "  3. Start Docker Desktop from Applications folder"
        else
            log_info "  3. Docker is installed. You may need to log out and back in for group changes"
        fi
    fi
    
    # Cloud tools instructions
    if [[ "$INSTALL_CLOUD" = true ]]; then
        log_info "  4. Configure cloud tools:"
        if command -v aws >/dev/null 2>&1; then
            log_info "     - AWS CLI: aws configure"
        fi
        if command -v gcloud >/dev/null 2>&1; then
            log_info "     - Google Cloud: gcloud init"
        fi
        if command -v az >/dev/null 2>&1; then
            log_info "     - Azure CLI: az login"
        fi
    fi
    
    # General instructions
    log_info "  5. Verify installations with: $SCRIPT_DIR/$(basename "$0") status"
    log_info "  6. See documentation in docs/ for tool-specific configuration"
    
    echo ""
    log_success "Cross-platform tools installation completed!"
}

# Show tools status
show_tools_status() {
    log_info "Cross-Platform Tools Status:"
    echo ""
    
    # Run individual status checks
    local asdf_script="$DOTFILES_ROOT/tools/scripts/install-asdf.sh"
    local docker_script="$DOTFILES_ROOT/tools/scripts/install-docker.sh"
    local cloud_script="$DOTFILES_ROOT/tools/scripts/install-cloud-tools.sh"
    local dev_script="$DOTFILES_ROOT/tools/scripts/setup-development-tools.sh"
    
    # ASDF status
    if [[ -x "$asdf_script" ]]; then
        "$asdf_script" status 2>/dev/null || log_warning "ASDF status check failed"
        echo ""
    fi
    
    # Docker status
    if [[ -x "$docker_script" ]]; then
        "$docker_script" status 2>/dev/null || log_warning "Docker status check failed"
        echo ""
    fi
    
    # Cloud tools status
    if [[ -x "$cloud_script" ]]; then
        "$cloud_script" status 2>/dev/null || log_warning "Cloud tools status check failed"
        echo ""
    fi
    
    # Development tools status
    if [[ -x "$dev_script" ]]; then
        "$dev_script" status 2>/dev/null || log_warning "Development tools status check failed"
        echo ""
    fi
}

# Main installation function
perform_installation() {
    log_info "Starting cross-platform tools installation..."
    
    # Install tools in order
    install_asdf_tools || log_warning "ASDF installation had issues"
    install_docker_tools || log_warning "Docker installation had issues"
    install_cloud_tools || log_warning "Cloud tools installation had issues"
    install_development_tools || log_warning "Development tools installation had issues"
    
    # Show status and next steps
    show_installation_status
    show_next_steps
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show banner
    show_banner
    
    # Show system information
    log_info "System Information:"
    log_info "  ${BULLET} OS: $(get_os_string)"
    log_info "  ${BULLET} Architecture: $(detect_architecture)"
    log_info "  ${BULLET} Package Manager: $(detect_package_manager)"
    echo ""
    
    # Handle status command
    if [[ "${1:-}" = "status" ]]; then
        show_tools_status
        exit 0
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    # Show installation plan
    show_installation_plan
    
    # Show confirmation if interactive
    if [[ "$INTERACTIVE" = true ]] && [[ "$DRY_RUN" != true ]]; then
        if ! confirm "Proceed with installation?"; then
            log_info "Installation cancelled"
            exit 0
        fi
        echo ""
    fi
    
    # Perform installation
    perform_installation
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 