#!/usr/bin/env bash
# GNU Stow Utility Functions
# Helper functions for managing dotfiles with GNU Stow

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/detect-os.sh"

# Stow-specific configuration
STOW_DIR="${STOW_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
STOW_TARGET="${STOW_TARGET:-$HOME}"
STOW_VERBOSE="${STOW_VERBOSE:-0}"
STOW_SIMULATE="${STOW_SIMULATE:-0}"

# Default packages to always stow
DEFAULT_PACKAGES=("config" "home")

# Platform-specific package mappings
declare -A OS_PACKAGES
OS_PACKAGES[macos]="os/macos"
OS_PACKAGES[linux]="os/linux"

# Get the list of available packages
list_packages() {
    local packages=()
    
    # Only look for valid package directories
    # config/* - Application configs
    for dir in "$STOW_DIR"/config/*/; do
        [[ -d "$dir" ]] || continue
        local package="config/$(basename "$dir")"
        if find "$dir" -type f 2>/dev/null | head -1 | grep -q .; then
            packages+=("$package")
        fi
    done
    
    # home - Home directory files (only if exists and has files)
    if [[ -d "$STOW_DIR/home" ]] && find "$STOW_DIR/home" -type f 2>/dev/null | head -1 | grep -q .; then
        packages+=("home")
    fi
    
    # shell/* - Shell-specific configs
    for dir in "$STOW_DIR"/shell/*/; do
        [[ -d "$dir" ]] || continue
        local package="shell/$(basename "$dir")"
        if find "$dir" -type f 2>/dev/null | head -1 | grep -q .; then
            packages+=("$package")
        fi
    done
    
    # os/* - OS-specific configs (top level only)
    for dir in "$STOW_DIR"/os/*/; do
        [[ -d "$dir" ]] || continue
        local package="os/$(basename "$dir")"
        # Skip if it's a subdirectory of linux/
        [[ "$package" =~ ^os/linux/.+ ]] && continue
        if find "$dir" -type f 2>/dev/null | head -1 | grep -q .; then
            packages+=("$package")
        fi
    done
    
    # Sort and output
    printf '%s\n' "${packages[@]}" | sort
}

# Get packages for the current platform
get_platform_packages() {
    local os_type=$(detect_os_type)
    local packages=()
    
    # Add default packages only if they exist and have content
    for pkg in "${DEFAULT_PACKAGES[@]}"; do
        if [[ -d "$STOW_DIR/$pkg" ]] && find "$STOW_DIR/$pkg" -type f 2>/dev/null | head -1 | grep -q .; then
            packages+=("$pkg")
        fi
    done
    
    # Add OS-specific package if it exists and has content
    if [[ -n "${OS_PACKAGES[$os_type]:-}" ]] && [[ -d "$STOW_DIR/${OS_PACKAGES[$os_type]}" ]]; then
        if find "$STOW_DIR/${OS_PACKAGES[$os_type]}" -type f 2>/dev/null | head -1 | grep -q .; then
            packages+=("${OS_PACKAGES[$os_type]}")
        fi
    fi
    
    # Add shell packages only if they exist and have content
    if [[ -d "$STOW_DIR/shell/shared" ]] && find "$STOW_DIR/shell/shared" -type f 2>/dev/null | head -1 | grep -q .; then
        packages+=("shell/shared")
    fi
    
    # Add current shell if available and has content
    if [[ -n "${SHELL:-}" ]]; then
        local shell_name=$(basename "$SHELL")
        if [[ -d "$STOW_DIR/shell/$shell_name" ]] && find "$STOW_DIR/shell/$shell_name" -type f 2>/dev/null | head -1 | grep -q .; then
            packages+=("shell/$shell_name")
        fi
    fi
    
    printf '%s\n' "${packages[@]}"
}

# Check for conflicts before stowing
check_conflicts() {
    local package="$1"
    local conflicts=()
    local stow_args=()
    
    # Build stow arguments
    [[ "$STOW_VERBOSE" -eq 1 ]] && stow_args+=("-v")
    stow_args+=("-t" "$STOW_TARGET" "--no")
    
    # Handle nested packages (containing slashes)
    local stow_dir="$STOW_DIR"
    local package_name="$package"
    
    if [[ "$package" == */* ]]; then
        # Package has subdirectory - need to change stow directory
        local package_parent_dir="$(dirname "$package")"
        local package_basename="$(basename "$package")"
        stow_dir="$STOW_DIR/$package_parent_dir"
        package_name="$package_basename"
    fi
    
    stow_args+=("-d" "$stow_dir")
    
    # Use --no flag to simulate and check for conflicts
    local output
    if output=$(stow "${stow_args[@]}" "$package_name" 2>&1); then
        return 0
    else
        # Parse stow output for conflicts
        while IFS= read -r line; do
            if [[ "$line" =~ "existing target is" ]] || [[ "$line" =~ "conflict" ]]; then
                conflicts+=("$line")
            fi
        done <<< "$output"
        
        if [[ ${#conflicts[@]} -gt 0 ]]; then
            printf '%s\n' "${conflicts[@]}"
            return 1
        fi
    fi
    
    return 0
}

# Backup conflicting files
backup_conflicts() {
    local package="$1"
    local backup_dir="${2:-$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)}"
    local conflicts_found=0
    
    # Get list of files that would be created by this package
    local package_dir="$STOW_DIR/$package"
    
    while IFS= read -r -d '' file; do
        # Get the relative path from package dir
        local rel_path="${file#$package_dir/}"
        local target_path="$STOW_TARGET/$rel_path"
        
        # Check if target exists and is not a symlink pointing to our package
        if [[ -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
            conflicts_found=1
            local backup_path="$backup_dir/$package/$rel_path"
            
            # Create backup directory
            mkdir -p "$(dirname "$backup_path")"
            
            # Backup the file
            if cp -a "$target_path" "$backup_path" 2>/dev/null; then
                log_info "Backed up: $target_path -> $backup_path"
            else
                log_warning "Failed to backup: $target_path"
            fi
        elif [[ -L "$target_path" ]]; then
            # Check if it's pointing somewhere else
            local link_target=$(readlink "$target_path")
            if [[ ! "$link_target" =~ "$STOW_DIR" ]]; then
                conflicts_found=1
                log_warning "Existing symlink points elsewhere: $target_path -> $link_target"
            fi
        fi
    done < <(find "$package_dir" -type f -print0 2>/dev/null)
    
    if [[ $conflicts_found -eq 1 ]]; then
        log_info "Backups saved to: $backup_dir"
    fi
    
    return 0
}

# Stow a single package
stow_package() {
    local package="$1"
    local force="${2:-0}"
    local adopt="${3:-0}"
    local stow_args=()
    
    # Validate package exists
    if [[ ! -d "$STOW_DIR/$package" ]]; then
        log_error "Package not found: $package"
        return 1
    fi
    
    # Build stow arguments
    [[ "$STOW_VERBOSE" -eq 1 ]] && stow_args+=("-v")
    [[ "$STOW_SIMULATE" -eq 1 ]] && stow_args+=("-n")
    [[ "$adopt" -eq 1 ]] && stow_args+=("--adopt")
    stow_args+=("-t" "$STOW_TARGET")
    
    # Handle nested packages (containing slashes)
    local stow_dir="$STOW_DIR"
    local package_name="$package"
    
    if [[ "$package" == */* ]]; then
        # Package has subdirectory - need to change stow directory
        local package_parent_dir="$(dirname "$package")"
        local package_basename="$(basename "$package")"
        stow_dir="$STOW_DIR/$package_parent_dir"
        package_name="$package_basename"
    fi
    
    stow_args+=("-d" "$stow_dir")
    
    # Check for conflicts first (unless forcing or adopting)
    if [[ "$force" -eq 0 ]] && [[ "$adopt" -eq 0 ]] && [[ "$STOW_SIMULATE" -eq 0 ]]; then
        if ! check_conflicts "$package" >/dev/null 2>&1; then
            log_warning "Conflicts detected for package: $package"
            
            # Offer to backup conflicts
            if confirm "Backup conflicting files?"; then
                backup_conflicts "$package"
                
                # Remove conflicting files after backup
                while IFS= read -r -d '' file; do
                    local rel_path="${file#$STOW_DIR/$package/}"
                    local target_path="$STOW_TARGET/$rel_path"
                    
                    if [[ -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
                        rm -f "$target_path"
                    fi
                done < <(find "$STOW_DIR/$package" -type f -print0 2>/dev/null)
            else
                log_error "Cannot stow package with conflicts: $package"
                return 1
            fi
        fi
    fi
    
    # Perform the stow operation
    show_progress "Stowing $package"
    if stow "${stow_args[@]}" "$package_name" 2>/dev/null; then
        end_progress "success"
        log_success "Successfully stowed: $package"
        return 0
    else
        end_progress "failed"
        log_error "Failed to stow: $package"
        return 1
    fi
}

# Unstow a single package
unstow_package() {
    local package="$1"
    local stow_args=()
    
    # Build stow arguments
    [[ "$STOW_VERBOSE" -eq 1 ]] && stow_args+=("-v")
    [[ "$STOW_SIMULATE" -eq 1 ]] && stow_args+=("-n")
    stow_args+=("-D")  # Delete/unstow mode
    stow_args+=("-t" "$STOW_TARGET")
    
    # Handle nested packages (containing slashes)
    local stow_dir="$STOW_DIR"
    local package_name="$package"
    
    if [[ "$package" == */* ]]; then
        # Package has subdirectory - need to change stow directory
        local package_parent_dir="$(dirname "$package")"
        local package_basename="$(basename "$package")"
        stow_dir="$STOW_DIR/$package_parent_dir"
        package_name="$package_basename"
    fi
    
    stow_args+=("-d" "$stow_dir")
    
    # Perform the unstow operation
    show_progress "Unstowing $package"
    if stow "${stow_args[@]}" "$package_name" 2>/dev/null; then
        end_progress "success"
        log_success "Successfully unstowed: $package"
        return 0
    else
        end_progress "failed"
        log_error "Failed to unstow: $package"
        return 1
    fi
}

# Restow a package (unstow then stow - useful for updates)
restow_package() {
    local package="$1"
    
    log_info "Restowing package: $package"
    
    # First unstow
    if unstow_package "$package"; then
        # Then stow again
        stow_package "$package"
    else
        log_error "Failed to restow package: $package"
        return 1
    fi
}

# Adopt existing dotfiles into the repository
adopt_existing() {
    local package="$1"
    
    log_info "Adopting existing files for package: $package"
    
    # Use stow's --adopt flag
    if stow_package "$package" 0 1; then
        log_success "Successfully adopted existing files"
        log_warning "Please review adopted files and commit changes"
        return 0
    else
        log_error "Failed to adopt existing files"
        return 1
    fi
}

# Verify stow installation
verify_stow() {
    if ! command_exists stow; then
        log_error "GNU Stow is not installed"
        return 1
    fi
    
    # Check version (optional)
    local version=$(stow --version | head -n1 | awk '{print $NF}')
    log_debug "GNU Stow version: $version"
    
    return 0
}

# Check if a package is already stowed
is_stowed() {
    local package="$1"
    local package_dir="$STOW_DIR/$package"
    
    # Check a few representative files
    while IFS= read -r -d '' file; do
        local rel_path="${file#$package_dir/}"
        local target_path="$STOW_TARGET/$rel_path"
        
        # If target doesn't exist or isn't a symlink to our file, not stowed
        if [[ ! -L "$target_path" ]]; then
            return 1
        fi
        
        # Check if symlink points to our package
        local link_target=$(readlink "$target_path" 2>/dev/null || true)
        if [[ ! "$link_target" =~ "$package_dir" ]]; then
            return 1
        fi
        
        # Found at least one properly stowed file
        return 0
    done < <(find "$package_dir" -type f -print0 2>/dev/null | head -z -n 5)
    
    # No files found or none are stowed
    return 1
}

# Export all utility functions (silenced to avoid startup output)
export -f list_packages get_platform_packages check_conflicts >/dev/null 2>&1
export -f backup_conflicts stow_package unstow_package restow_package >/dev/null 2>&1
export -f adopt_existing verify_stow is_stowed >/dev/null 2>&1 