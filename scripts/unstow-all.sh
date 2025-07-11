#!/usr/bin/env bash
# Unstow All Packages
# Script for safely removing dotfile symlinks using GNU Stow

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source utilities
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/detect-os.sh"
source "${SCRIPT_DIR}/lib/stow-utils.sh"

# Script configuration
UNSTOW_MODE="current"  # current, all, select
DRY_RUN=0
VERBOSE=0
LIST_ONLY=0
PACKAGES_TO_UNSTOW=()

# Help message
show_help() {
    cat << EOF
GNU Stow-based Dotfiles Removal

Usage: $(basename "$0") [OPTIONS] [PACKAGES...]

Options:
    -h, --help              Show this help message
    -n, --dry-run           Simulate unstow operations without making changes
    -v, --verbose           Enable verbose output
    -l, --list              List currently stowed packages and exit
    -m, --mode MODE         Unstow mode: current (default), all, select
    -t, --target DIR        Set target directory (default: \$HOME)
    -d, --dir DIR           Set stow directory (default: repository root)

Modes:
    current - Unstow only currently stowed packages
    all     - Attempt to unstow all available packages
    select  - Interactive package selection

Examples:
    $(basename "$0")                    # Unstow currently stowed packages
    $(basename "$0") -n                 # Dry run to see what would happen
    $(basename "$0") config shell/zsh   # Unstow specific packages
    $(basename "$0") -m all             # Unstow all packages
    $(basename "$0") -l                 # List stowed packages

Note: This operation only removes symlinks. Your actual configuration
      files in the repository remain untouched.

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
            -l|--list)
                LIST_ONLY=1
                ;;
            -m|--mode)
                shift
                UNSTOW_MODE="$1"
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
                PACKAGES_TO_UNSTOW+=("$1")
                ;;
        esac
        shift
    done
}

# List currently stowed packages
list_stowed_packages() {
    log_info "Currently stowed packages:"
    echo
    
    local stowed_count=0
    local stowed_packages=()
    
    # Check each available package
    while IFS= read -r package; do
        if is_stowed "$package"; then
            stowed_packages+=("$package")
            ((stowed_count++))
        fi
    done < <(list_packages)
    
    if [[ $stowed_count -eq 0 ]]; then
        log_info "No packages are currently stowed"
    else
        # Group by category for display
        local config_packages=()
        local shell_packages=()
        local os_packages=()
        local other_packages=()
        
        for package in "${stowed_packages[@]}"; do
            case "$package" in
                config/*)
                    config_packages+=("  ${CHECK_MARK} ${package#config/}")
                    ;;
                shell/*)
                    shell_packages+=("  ${CHECK_MARK} ${package#shell/}")
                    ;;
                os/*)
                    os_packages+=("  ${CHECK_MARK} ${package#os/}")
                    ;;
                *)
                    other_packages+=("  ${CHECK_MARK} $package")
                    ;;
            esac
        done
        
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
    fi
    
    return 0
}

# Get currently stowed packages
get_stowed_packages() {
    local stowed_packages=()
    
    while IFS= read -r package; do
        if is_stowed "$package"; then
            stowed_packages+=("$package")
        fi
    done < <(list_packages)
    
    printf '%s\n' "${stowed_packages[@]}"
}

# Interactive package selection
select_packages_interactive() {
    local available_packages=()
    local selected_packages=()
    local stowed_packages=()
    
    # Get stowed packages
    while IFS= read -r package; do
        stowed_packages+=("$package")
    done < <(get_stowed_packages)
    
    if [[ ${#stowed_packages[@]} -eq 0 ]]; then
        log_error "No stowed packages found"
        return 1
    fi
    
    log_info "Select packages to unstow (currently stowed only):"
    echo
    
    # Simple menu selection
    local i=1
    for package in "${stowed_packages[@]}"; do
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
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#stowed_packages[@]} ]]; then
                local idx=$((num - 1))
                local package="${stowed_packages[$idx]}"
                
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
    PACKAGES_TO_UNSTOW=("${selected_packages[@]}")
    
    if [[ ${#PACKAGES_TO_UNSTOW[@]} -eq 0 ]]; then
        log_warning "No packages selected"
        return 1
    fi
    
    return 0
}

# Unstow packages based on mode
unstow_packages() {
    local packages=()
    local success_count=0
    local fail_count=0
    local skip_count=0
    
    # Determine which packages to unstow
    case "$UNSTOW_MODE" in
        current)
            if [[ ${#PACKAGES_TO_UNSTOW[@]} -gt 0 ]]; then
                # Use command-line specified packages
                packages=("${PACKAGES_TO_UNSTOW[@]}")
            else
                # Get currently stowed packages
                while IFS= read -r package; do
                    packages+=("$package")
                done < <(get_stowed_packages)
            fi
            ;;
        all)
            # Attempt to unstow all available packages
            while IFS= read -r package; do
                packages+=("$package")
            done < <(list_packages)
            ;;
        select)
            # Interactive selection
            if ! select_packages_interactive; then
                return 1
            fi
            packages=("${PACKAGES_TO_UNSTOW[@]}")
            ;;
        *)
            log_error "Invalid mode: $UNSTOW_MODE"
            return 1
            ;;
    esac
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_info "No packages to unstow"
        return 0
    fi
    
    # Display what will be unstowed
    echo
    log_info "Packages to unstow:"
    for package in "${packages[@]}"; do
        if is_stowed "$package"; then
            echo "  ${ARROW} $package"
        else
            echo "  ${DIM}${CROSS_MARK} $package (not stowed)${NC}"
        fi
    done
    echo
    
    # Confirm if not in dry-run mode
    if [[ $DRY_RUN -eq 0 ]]; then
        log_warning "This will remove all symlinks for the selected packages"
        log_info "Your configuration files in the repository will remain untouched"
        
        if ! confirm "Proceed with unstowing?" "n"; then
            log_info "Unstow operation cancelled"
            return 0
        fi
    fi
    
    # Unstow each package
    for package in "${packages[@]}"; do
        # Skip if not stowed
        if ! is_stowed "$package" && [[ "$UNSTOW_MODE" != "all" ]]; then
            log_debug "Skipping package not stowed: $package"
            ((skip_count++))
            continue
        fi
        
        # Unstow the package
        if unstow_package "$package"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    # Summary
    echo
    log_info "Unstow summary:"
    [[ $success_count -gt 0 ]] && log_success "Successfully unstowed: $success_count packages"
    [[ $skip_count -gt 0 ]] && log_info "Skipped (not stowed): $skip_count packages"
    [[ $fail_count -gt 0 ]] && log_error "Failed to unstow: $fail_count packages"
    
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
    echo -e "${BOLD}GNU Stow Dotfiles Removal${NC}"
    echo -e "${DIM}Repository: $STOW_DIR${NC}"
    echo -e "${DIM}Target: $STOW_TARGET${NC}"
    [[ $DRY_RUN -eq 1 ]] && echo -e "${YELLOW}[DRY RUN MODE]${NC}"
    echo
    
    # Verify GNU Stow is installed
    if ! verify_stow; then
        log_error "GNU Stow is not installed"
        exit 1
    fi
    
    # List packages and exit if requested
    if [[ $LIST_ONLY -eq 1 ]]; then
        list_stowed_packages
        exit 0
    fi
    
    # Perform unstow operations
    if unstow_packages; then
        if [[ $success_count -gt 0 ]]; then
            log_success "Unstow operations completed successfully!"
        fi
        exit 0
    else
        log_error "Some unstow operations failed"
        exit 1
    fi
}

# Run main function
main "$@" 