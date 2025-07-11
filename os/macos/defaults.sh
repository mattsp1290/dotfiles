#!/usr/bin/env bash
# macOS System Preferences Configuration
# This script applies comprehensive macOS system preferences for development workflows

set -euo pipefail

# Script information
readonly SCRIPT_NAME="macOS System Preferences"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
if [[ -t 1 ]] && c`ommand -v tput >/dev/null 2>&1; then
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
log_info() { echo "${BLUE}[INFO]${RESET} $*"; }
log_success() { echo "${GREEN}[SUCCESS]${RESET} $*"; }
log_warning() { echo "${YELLOW}[WARNING]${RESET} $*" >&2; }
log_error() { echo "${RED}[ERROR]${RESET} $*" >&2; }

# Configuration
DRY_RUN=false
VERBOSE=false
FORCE=false
INTERACTIVE=true
BACKUP_DIR="$SCRIPT_DIR/backup"
CATEGORIES_TO_APPLY=()

# Available configuration categories
AVAILABLE_CATEGORIES=(
    "dock"
    "finder"
    "input"
    "security"
    "appearance"
    "general"
)

# Show usage information
usage() {
    cat << EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${RESET}

Apply macOS system preferences optimized for development workflows.

${BOLD}USAGE:${RESET}
    $(basename "$0") [OPTIONS] [CATEGORIES...]

${BOLD}OPTIONS:${RESET}
    -h, --help              Show this help message
    -d, --dry-run          Show what would be changed without making changes
    -v, --verbose          Enable verbose output
    -f, --force            Skip confirmations and apply all settings
    -q, --quiet            Suppress non-error output
    --non-interactive      Run without user prompts
    --backup               Create backup before applying settings
    --restore              Restore from backup instead of applying settings
    --list-categories      List available configuration categories

${BOLD}CATEGORIES:${RESET}
    dock                   Dock settings and behavior
    finder                 Finder preferences and defaults
    input                  Keyboard, trackpad, and input settings  
    security               Security and privacy preferences
    appearance             Visual appearance and interface settings
    general                General system preferences
    all                    Apply all categories (default if none specified)

${BOLD}EXAMPLES:${RESET}
    # Apply all settings with confirmation
    $(basename "$0")
    
    # Apply only Dock and Finder settings
    $(basename "$0") dock finder
    
    # Dry run to see what would change
    $(basename "$0") --dry-run
    
    # Force apply all settings without prompts
    $(basename "$0") --force
    
    # Create backup of current settings
    $(basename "$0") --backup
    
    # Restore from backup
    $(basename "$0") --restore

${BOLD}NOTES:${RESET}
    - Some settings require administrator privileges
    - Changes may require logout/restart to take full effect
    - Always create a backup before applying settings
    - Settings are designed to enhance development workflows

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                INTERACTIVE=false
                shift
                ;;
            -q|--quiet)
                exec >/dev/null
                shift
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            --backup)
                create_backup
                exit $?
                ;;
            --restore)
                restore_backup
                exit $?
                ;;
            --list-categories)
                list_categories
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # Category argument
                if [[ " ${AVAILABLE_CATEGORIES[*]} " =~ " $1 " ]] || [[ "$1" == "all" ]]; then
                    CATEGORIES_TO_APPLY+=("$1")
                else
                    log_error "Unknown category: $1"
                    log_error "Available categories: ${AVAILABLE_CATEGORIES[*]}"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to all categories if none specified
    if [[ ${#CATEGORIES_TO_APPLY[@]} -eq 0 ]]; then
        CATEGORIES_TO_APPLY=("all")
    fi
}

# List available categories
list_categories() {
    echo "${BOLD}Available Configuration Categories:${RESET}"
    echo ""
    
    echo "${BLUE}dock${RESET}       - Auto-hide, size, position, Mission Control integration"
    echo "${BLUE}finder${RESET}     - Default views, sidebar, extensions, hidden files"
    echo "${BLUE}input${RESET}      - Keyboard repeat, trackpad gestures, mouse settings"
    echo "${BLUE}security${RESET}   - Firewall, Gatekeeper, screen lock, privacy settings"
    echo "${BLUE}appearance${RESET} - Dark mode, accent colors, menu bar configuration"
    echo "${BLUE}general${RESET}    - System-wide preferences and behaviors"
    echo ""
    echo "${BLUE}all${RESET}        - Apply all categories above"
}

# Check macOS version compatibility
check_compatibility() {
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

# Confirm action with user
confirm() {
    if [[ "$INTERACTIVE" != true ]] || [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    local message="$1"
    local response
    
    echo -n "${YELLOW}${message} (y/N): ${RESET}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Create backup of current settings
create_backup() {
    log_info "Creating backup of current system preferences..."
    
    # Create backup directory with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$timestamp"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create backup at: $backup_path"
        return 0
    fi
    
    mkdir -p "$backup_path"
    
    # Backup important domains
    local domains=(
        "com.apple.dock"
        "com.apple.finder"
        "com.apple.HIToolbox"
        "com.apple.screensaver"
        "com.apple.screencapture"
        "com.apple.desktopservices"
        "com.apple.trackpad"
        "com.apple.AppleMultitouchTrackpad"
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
        "com.apple.keyboard"
        "NSGlobalDomain"
    )
    
    local backed_up=0
    for domain in "${domains[@]}"; do
        local backup_file="$backup_path/${domain}.plist"
        
        if defaults read "$domain" > "$backup_file" 2>/dev/null; then
            ((backed_up++))
            [[ "$VERBOSE" == true ]] && log_info "Backed up: $domain"
        else
            [[ "$VERBOSE" == true ]] && log_warning "Could not backup: $domain"
            rm -f "$backup_file"
        fi
    done
    
    # Create restore script
    cat > "$backup_path/restore.sh" << EOF
#!/usr/bin/env bash
# Restore script generated on $timestamp

set -euo pipefail

echo "Restoring macOS preferences from backup..."

EOF
    
    for domain in "${domains[@]}"; do
        local backup_file="$backup_path/${domain}.plist"
        if [[ -f "$backup_file" ]]; then
            echo "defaults delete '$domain' 2>/dev/null || true" >> "$backup_path/restore.sh"
            echo "defaults import '$domain' '$backup_file'" >> "$backup_path/restore.sh"
        fi
    done
    
    cat >> "$backup_path/restore.sh" << EOF

echo "Killing affected applications..."
killall "Dock" "Finder" "SystemUIServer" 2>/dev/null || true

echo "Restore completed. Some changes may require logout/restart."
EOF
    
    chmod +x "$backup_path/restore.sh"
    
    # Create symlink to latest backup
    ln -sf "backup_$timestamp" "$BACKUP_DIR/latest"
    
    log_success "Backup created: $backup_path"
    log_info "Backed up $backed_up preference domains"
    log_info "To restore: $backup_path/restore.sh"
    
    return 0
}

# Restore from backup
restore_backup() {
    local backup_path="$BACKUP_DIR/latest"
    
    if [[ ! -L "$backup_path" ]]; then
        log_error "No backup found at: $backup_path"
        log_info "Create a backup first with: $(basename "$0") --backup"
        return 1
    fi
    
    local restore_script="$backup_path/restore.sh"
    if [[ ! -x "$restore_script" ]]; then
        log_error "Restore script not found or not executable: $restore_script"
        return 1
    fi
    
    if ! confirm "Restore system preferences from backup?"; then
        log_info "Restore cancelled"
        return 0
    fi
    
    log_info "Restoring from backup..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute: $restore_script"
        return 0
    fi
    
    if "$restore_script"; then
        log_success "Preferences restored from backup"
        log_info "Some changes may require logout/restart to take effect"
    else
        log_error "Restore failed"
        return 1
    fi
}

# Apply a specific configuration category
apply_category() {
    local category="$1"
    local script_path="$SCRIPT_DIR/${category}.sh"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Configuration script not found: $script_path"
        return 1
    fi
    
    log_info "Applying $category preferences..."
    
    # Build arguments for category script
    local args=()
    [[ "$DRY_RUN" == true ]] && args+=("--dry-run")
    [[ "$VERBOSE" == true ]] && args+=("--verbose")
    [[ "$FORCE" == true ]] && args+=("--force")
    [[ "$INTERACTIVE" != true ]] && args+=("--non-interactive")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute: $script_path ${args[*]}"
        return 0
    fi
    
    if bash "$script_path" "${args[@]}"; then
        log_success "$category preferences applied"
        return 0
    else
        log_error "Failed to apply $category preferences"
        return 1
    fi
}

# Kill affected applications to apply changes
restart_affected_apps() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restart: Dock, Finder, SystemUIServer"
        return 0
    fi
    
    log_info "Restarting affected applications..."
    
    # Kill applications that need to restart to pick up changes
    local apps=("Dock" "Finder" "SystemUIServer")
    
    for app in "${apps[@]}"; do
        if pgrep -x "$app" >/dev/null; then
            killall "$app" 2>/dev/null || true
            [[ "$VERBOSE" == true ]] && log_info "Restarted: $app"
        fi
    done
    
    # Give applications time to restart
    sleep 2
    
    log_success "Applications restarted"
}

# Main execution function
main() {
    log_info "Starting macOS system preferences configuration..."
    
    # Check compatibility
    if ! check_compatibility; then
        exit 1
    fi
    
    # Show what will be applied
    if [[ "${CATEGORIES_TO_APPLY[*]}" == "all" ]]; then
        log_info "Categories to apply: ${AVAILABLE_CATEGORIES[*]}"
    else
        log_info "Categories to apply: ${CATEGORIES_TO_APPLY[*]}"
    fi
    
    # Create backup if requested or if interactive
    if [[ "$INTERACTIVE" == true ]] && [[ "$DRY_RUN" != true ]]; then
        if confirm "Create backup before applying changes?"; then
            create_backup || log_warning "Backup failed, continuing anyway..."
        fi
    fi
    
    # Confirm before proceeding
    if [[ "$INTERACTIVE" == true ]] && [[ "$DRY_RUN" != true ]]; then
        if ! confirm "Proceed with applying system preferences?"; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    # Apply configurations
    local failed=0
    local applied=0
    
    if [[ "${CATEGORIES_TO_APPLY[*]}" == "all" ]]; then
        # Apply all categories
        for category in "${AVAILABLE_CATEGORIES[@]}"; do
            if apply_category "$category"; then
                ((applied++))
            else
                ((failed++))
            fi
        done
    else
        # Apply specified categories
        for category in "${CATEGORIES_TO_APPLY[@]}"; do
            if apply_category "$category"; then
                ((applied++))
            else
                ((failed++))
            fi
        done
    fi
    
    # Restart applications to apply changes
    restart_affected_apps
    
    # Show summary
    echo ""
    log_success "Configuration completed!"
    log_info "Applied: $applied categories"
    
    if [[ $failed -gt 0 ]]; then
        log_warning "Failed: $failed categories"
    fi
    
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Some changes may require logout/restart to take full effect"
        log_info "Create a backup anytime with: $(basename "$0") --backup"
    fi
    
    return $([[ $failed -eq 0 ]] && echo 0 || echo 1)
}

# Handle errors
trap 'log_error "Script failed at line $LINENO"' ERR

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi 