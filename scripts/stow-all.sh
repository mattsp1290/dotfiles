#!/usr/bin/env bash
# Stow All Packages
# Main script for stowing dotfiles using GNU Stow

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source utilities
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/detect-os.sh"
source "${SCRIPT_DIR}/lib/stow-utils.sh"

# Script configuration
STOW_MODE="auto"  # auto, all, select
FORCE_STOW=0
ADOPT_MODE=0
DRY_RUN=0
VERBOSE=0
LIST_ONLY=0
PACKAGES_TO_STOW=()

# Help message
show_help() {
    cat << EOF
GNU Stow-based Dotfiles Installation

Usage: $(basename "$0") [OPTIONS] [PACKAGES...]

Options:
    -h, --help              Show this help message
    -n, --dry-run           Simulate stow operations without making changes
    -v, --verbose           Enable verbose output
    -f, --force             Force stow even with conflicts (backs up conflicts)
    -a, --adopt             Adopt existing files into the repository
    -l, --list              List available packages and exit
    -m, --mode MODE         Stow mode: auto (default), all, select
    -t, --target DIR        Set target directory (default: \$HOME)
    -d, --dir DIR           Set stow directory (default: repository root)

Modes:
    auto    - Stow platform-appropriate packages automatically
    all     - Stow all available packages
    select  - Interactive package selection

Examples:
    $(basename "$0")                    # Auto-stow platform packages
    $(basename "$0") -n                 # Dry run to see what would happen
    $(basename "$0") config shell/zsh   # Stow specific packages
    $(basename "$0") -m select          # Interactive selection
    $(basename "$0") -f                 # Force stow with conflict backup
    $(basename "$0") -a config          # Adopt existing config files

Environment Variables:
    STOW_DIR        - Override stow directory
    STOW_TARGET     - Override target directory
    STOW_VERBOSE    - Enable verbose mode (0 or 1)
    STOW_SIMULATE   - Enable dry-run mode (0 or 1)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=1
                STOW_SIMULATE=1
                export STOW_SIMULATE
                ;;
            -v|--verbose)
                VERBOSE=1
                STOW_VERBOSE=1
                export STOW_VERBOSE
                ;;
            -f|--force)
                FORCE_STOW=1
                ;;
            -a|--adopt)
                ADOPT_MODE=1
                ;;
            -l|--list)
                LIST_ONLY=1
                ;;
            -m|--mode)
                shift
                STOW_MODE="$1"
                ;;
            -t|--target)
                shift
                STOW_TARGET="$1"
                export STOW_TARGET
                ;;
            -d|--dir)
                shift
                STOW_DIR="$1"
                export STOW_DIR
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                PACKAGES_TO_STOW+=("$1")
                ;;
        esac
        shift
    done
}

# List available packages
list_available_packages() {
    log_info "Available packages:"
    echo
    
    # Group packages by category
    local config_packages=()
    local shell_packages=()
    local os_packages=()
    local other_packages=()
    
    while IFS= read -r package; do
        case "$package" in
            config/*)
                config_packages+=("  ${BULLET} ${package#config/}")
                ;;
            shell/*)
                shell_packages+=("  ${BULLET} ${package#shell/}")
                ;;
            os/*)
                os_packages+=("  ${BULLET} ${package#os/}")
                ;;
            *)
                other_packages+=("  ${BULLET} $package")
                ;;
        esac
    done < <(list_packages)
    
    # Display grouped packages
    if [[ ${#config_packages[@]} -gt 0 ]]; then
        echo -e "${BOLD}Config packages:${NC}"
        printf '%s\n' "${config_packages[@]}"
        echo
    fi
    
    if [[ ${#shell_packages[@]} -gt 0 ]]; then
        echo -e "${BOLD}Shell packages:${NC}"
        printf '%s\n' "${shell_packages[@]}"
        echo
    fi
    
    if [[ ${#os_packages[@]} -gt 0 ]]; then
        echo -e "${BOLD}OS-specific packages:${NC}"
        printf '%s\n' "${os_packages[@]}"
        echo
    fi
    
    if [[ ${#other_packages[@]} -gt 0 ]]; then
        echo -e "${BOLD}Other packages:${NC}"
        printf '%s\n' "${other_packages[@]}"
        echo
    fi
    
    # Show current platform packages
    echo -e "${BOLD}Platform auto-selection for $(get_os_string):${NC}"
    while IFS= read -r package; do
        echo "  ${ARROW} $package"
    done < <(get_platform_packages)
}

# Interactive package selection
select_packages_interactive() {
    local available_packages=()
    local selected_packages=()
    
    # Get all available packages
    while IFS= read -r package; do
        available_packages+=("$package")
    done < <(list_packages)
    
    if [[ ${#available_packages[@]} -eq 0 ]]; then
        log_error "No packages found to stow"
        return 1
    fi
    
    log_info "Select packages to stow (space to toggle, enter to confirm):"
    echo
    
    # Simple menu selection (without external dependencies)
    local i=1
    for package in "${available_packages[@]}"; do
        echo "  [$i] $package"
        ((i++))
    done
    echo
    
    while true; do
        prompt_input "Enter package numbers to toggle (comma/space separated) or 'done'" "" selection
        
        if [[ "$selection" == "done" ]] || [[ -z "$selection" ]]; then
            break
        fi
        
        # Parse selection
        IFS=', ' read -ra numbers <<< "$selection"
        for num in "${numbers[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#available_packages[@]} ]]; then
                local idx=$((num - 1))
                local package="${available_packages[$idx]}"
                
                # Toggle selection
                if [[ " ${selected_packages[*]} " =~ " ${package} " ]]; then
                    # Remove from selection
                    selected_packages=("${selected_packages[@]/$package}")
                    echo "  [-] Deselected: $package"
                else
                    # Add to selection
                    selected_packages+=("$package")
                    echo "  [+] Selected: $package"
                fi
            else
                log_warning "Invalid selection: $num"
            fi
        done
        echo
    done
    
    # Set the selected packages
    PACKAGES_TO_STOW=("${selected_packages[@]}")
    
    if [[ ${#PACKAGES_TO_STOW[@]} -eq 0 ]]; then
        log_warning "No packages selected"
        return 1
    fi
    
    return 0
}

# Stow packages based on mode
stow_packages() {
    local packages=()
    local success_count=0
    local fail_count=0
    
    # Determine which packages to stow
    case "$STOW_MODE" in
        auto)
            if [[ ${#PACKAGES_TO_STOW[@]} -gt 0 ]]; then
                # Use command-line specified packages
                packages=("${PACKAGES_TO_STOW[@]}")
            else
                # Use platform-appropriate packages
                while IFS= read -r package; do
                    packages+=("$package")
                done < <(get_platform_packages)
            fi
            ;;
        all)
            # Stow all available packages
            while IFS= read -r package; do
                packages+=("$package")
            done < <(list_packages)
            ;;
        select)
            # Interactive selection
            if ! select_packages_interactive; then
                return 1
            fi
            packages=("${PACKAGES_TO_STOW[@]}")
            ;;
        *)
            log_error "Invalid mode: $STOW_MODE"
            return 1
            ;;
    esac
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages to stow"
        return 1
    fi
    
    # Display what will be stowed
    echo
    log_info "Packages to stow:"
    for package in "${packages[@]}"; do
        if is_stowed "$package"; then
            echo "  ${CHECK_MARK} $package (already stowed)"
        else
            echo "  ${ARROW} $package"
        fi
    done
    echo
    
    # Confirm if not in dry-run mode
    if [[ $DRY_RUN -eq 0 ]] && ! confirm "Proceed with stowing?"; then
        log_info "Stow operation cancelled"
        return 0
    fi
    
    # Stow each package
    for package in "${packages[@]}"; do
        # Skip if already stowed (unless restowing)
        if is_stowed "$package" && [[ $FORCE_STOW -eq 0 ]]; then
            log_info "Skipping already stowed package: $package"
            ((success_count++))
            continue
        fi
        
        # Stow the package
        if [[ $ADOPT_MODE -eq 1 ]]; then
            if adopt_existing "$package"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        else
            if stow_package "$package" "$FORCE_STOW"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        fi
    done
    
    # Summary
    echo
    log_info "Stow summary:"
    log_success "Successfully stowed: $success_count packages"
    [[ $fail_count -gt 0 ]] && log_error "Failed to stow: $fail_count packages"
    
    return $([ $fail_count -eq 0 ])
}

# Main execution
main() {
    # Parse arguments
    parse_args "$@"
    
    # Set up environment
    cd "$REPO_ROOT"
    
    # Export stow directory if not set
    export STOW_DIR="${STOW_DIR:-$REPO_ROOT}"
    export STOW_TARGET="${STOW_TARGET:-$HOME}"
    
    # Display header
    echo -e "${BOLD}GNU Stow Dotfiles Manager${NC}"
    echo -e "${DIM}Repository: $STOW_DIR${NC}"
    echo -e "${DIM}Target: $STOW_TARGET${NC}"
    [[ $DRY_RUN -eq 1 ]] && echo -e "${YELLOW}[DRY RUN MODE]${NC}"
    echo
    
    # Verify GNU Stow is installed
    if ! verify_stow; then
        log_error "Please install GNU Stow first"
        log_info "Run: ${BOLD}./scripts/bootstrap.sh${NC}"
        exit 1
    fi
    
    # List packages and exit if requested
    if [[ $LIST_ONLY -eq 1 ]]; then
        list_available_packages
        exit 0
    fi
    
    # Perform stow operations
    if stow_packages; then
        log_success "All stow operations completed successfully!"
        
        # Remind about shell reload
        if [[ $DRY_RUN -eq 0 ]]; then
            echo
            log_info "You may need to reload your shell or re-login for changes to take effect"
            log_info "Run: ${BOLD}source ~/.bashrc${NC} or ${BOLD}source ~/.zshrc${NC}"
        fi
        
        exit 0
    else
        log_error "Some stow operations failed"
        exit 1
    fi
}

# Run main function
main "$@" 