#!/usr/bin/env bash
# macOS Settings Restore Script
# Restores system preferences from a backup

set -euo pipefail

# Script information
readonly SCRIPT_NAME="macOS Settings Restore"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
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
log_info() { echo "${BLUE}[RESTORE]${RESET} $*"; }
log_success() { echo "${GREEN}[RESTORE]${RESET} $*"; }
log_warning() { echo "${YELLOW}[RESTORE]${RESET} $*" >&2; }
log_error() { echo "${RED}[RESTORE]${RESET} $*" >&2; }

# Configuration
BACKUP_DIR="$SCRIPT_DIR/../backup"
DRY_RUN=false
VERBOSE=false
FORCE=false
BACKUP_PATH=""

# Show usage
usage() {
    cat << EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${RESET}

Restore macOS system preferences from a backup.

${BOLD}USAGE:${RESET}
    $(basename "$0") [OPTIONS] [BACKUP_PATH]

${BOLD}OPTIONS:${RESET}
    -h, --help              Show this help message
    -d, --dry-run          Show what would be restored without making changes
    -v, --verbose          Enable verbose output
    -f, --force            Skip confirmation prompts
    -l, --list             List available backups
    --latest               Restore from latest backup

${BOLD}ARGUMENTS:${RESET}
    BACKUP_PATH             Path to backup directory (optional)
                           If not specified, will use latest backup

${BOLD}EXAMPLES:${RESET}
    # Restore from latest backup
    $(basename "$0") --latest
    
    # List available backups
    $(basename "$0") --list
    
    # Restore from specific backup
    $(basename "$0") ~/backups/backup_20231201_143022
    
    # Dry run to see what would be restored
    $(basename "$0") --dry-run --latest

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
                shift
                ;;
            -l|--list)
                list_backups
                exit 0
                ;;
            --latest)
                BACKUP_PATH="$BACKUP_DIR/latest"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                BACKUP_PATH="$1"
                shift
                ;;
        esac
    done
}

# List available backups
list_backups() {
    log_info "Available backups in $BACKUP_DIR:"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warning "No backup directory found at: $BACKUP_DIR"
        return 1
    fi
    
    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$backup")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -name "backup_*" -type d -print0 | sort -z)
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warning "No backups found in $BACKUP_DIR"
        log_info "Create a backup first with: backup-settings.sh"
        return 1
    fi
    
    for backup in "${backups[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_date=""
        local backup_info="$backup/backup-info.txt"
        
        if [[ -f "$backup_info" ]]; then
            backup_date=$(grep "Created:" "$backup_info" 2>/dev/null | cut -d' ' -f2- || echo "Unknown")
        fi
        
        # Check if this is the latest backup
        local latest_marker=""
        if [[ -L "$BACKUP_DIR/latest" ]] && [[ "$(readlink "$BACKUP_DIR/latest")" == "$backup_name" ]]; then
            latest_marker=" ${GREEN}(latest)${RESET}"
        fi
        
        echo "  ${BLUE}$backup_name${RESET}$latest_marker"
        [[ -n "$backup_date" ]] && echo "    Created: $backup_date"
        
        # Show backup contents if verbose
        if [[ "$VERBOSE" == true ]] && [[ -f "$backup_info" ]]; then
            local plist_count=$(find "$backup" -name "*.plist" | wc -l)
            echo "    Contains: $plist_count preference domains"
        fi
        echo ""
    done
    
    log_info "To restore from a backup:"
    log_info "  $(basename "$0") --latest"
    log_info "  $(basename "$0") $BACKUP_DIR/backup_YYYYMMDD_HHMMSS"
}

# Validate backup path
validate_backup() {
    local backup_path="$1"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    # Check if it's a symlink and resolve it
    if [[ -L "$backup_path" ]]; then
        local target=$(readlink "$backup_path")
        if [[ "$target" =~ ^/ ]]; then
            backup_path="$target"
        else
            backup_path="$(dirname "$backup_path")/$target"
        fi
        
        if [[ ! -d "$backup_path" ]]; then
            log_error "Backup symlink target not found: $backup_path"
            return 1
        fi
        
        log_info "Following symlink to: $backup_path"
    fi
    
    # Check for backup metadata
    local backup_info="$backup_path/backup-info.txt"
    if [[ -f "$backup_info" ]]; then
        log_info "Backup information:"
        grep -E "^(Created|Host|User|macOS Version):" "$backup_info" | sed 's/^/  /'
    else
        log_warning "No backup metadata found, but proceeding anyway"
    fi
    
    # Count available plist files
    local plist_count=$(find "$backup_path" -name "*.plist" | wc -l)
    if [[ $plist_count -eq 0 ]]; then
        log_error "No preference files found in backup: $backup_path"
        return 1
    fi
    
    log_info "Found $plist_count preference domains to restore"
    return 0
}

# Confirm restoration
confirm_restore() {
    if [[ "$FORCE" == true ]] || [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    echo ""
    log_warning "${BOLD}WARNING: This will overwrite your current system preferences!${RESET}"
    echo ""
    log_info "This will restore macOS system preferences from the backup:"
    log_info "  Source: $BACKUP_PATH"
    echo ""
    log_info "Current settings will be replaced with backed up settings for:"
    log_info "  • Dock preferences"
    log_info "  • Finder settings"
    log_info "  • Input device settings"
    log_info "  • Security preferences"
    log_info "  • Appearance settings"
    log_info "  • General system preferences"
    echo ""
    log_warning "Some changes will require logout/restart to take effect"
    echo ""
    
    local response
    echo -n "${YELLOW}Are you sure you want to restore from this backup? (y/N): ${RESET}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Restore from backup
restore_from_backup() {
    local backup_path="$1"
    local restore_script="$backup_path/restore.sh"
    
    # Check if backup has its own restore script
    if [[ -x "$restore_script" ]]; then
        log_info "Using backup's restore script: $restore_script"
        
        local args=()
        [[ "$DRY_RUN" == true ]] && args+=("--dry-run")
        [[ "$VERBOSE" == true ]] && args+=("--verbose")
        
        if "$restore_script" "${args[@]}"; then
            return 0
        else
            log_error "Backup restore script failed"
            return 1
        fi
    else
        # Fallback: manual restore
        log_info "No restore script found, performing manual restore..."
        manual_restore "$backup_path"
    fi
}

# Manual restore function
manual_restore() {
    local backup_path="$1"
    local restored=0
    local failed=0
    
    log_info "Restoring preferences manually..."
    
    while IFS= read -r -d '' plist_file; do
        local domain=$(basename "$plist_file" .plist)
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would restore: $domain"
            ((restored++))
        else
            [[ "$VERBOSE" == true ]] && log_info "Restoring: $domain"
            
            # Delete current settings and import backup
            if defaults delete "$domain" 2>/dev/null || true; then
                if defaults import "$domain" "$plist_file" 2>/dev/null; then
                    ((restored++))
                else
                    log_warning "Failed to import: $domain"
                    ((failed++))
                fi
            else
                log_warning "Failed to delete existing settings for: $domain"
                ((failed++))
            fi
        fi
    done < <(find "$backup_path" -name "*.plist" -print0)
    
    if [[ "$DRY_RUN" != true ]]; then
        # Restart affected applications
        log_info "Restarting affected applications..."
        killall "Dock" "Finder" "SystemUIServer" 2>/dev/null || true
        sleep 2
    fi
    
    echo ""
    log_success "Manual restore completed!"
    log_info "Restored: $restored domains"
    [[ $failed -gt 0 ]] && log_warning "Failed: $failed domains"
}

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Check macOS compatibility
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # If no backup path specified, try to use latest
    if [[ -z "$BACKUP_PATH" ]]; then
        local latest_backup="$BACKUP_DIR/latest"
        if [[ -L "$latest_backup" ]]; then
            BACKUP_PATH="$latest_backup"
            log_info "Using latest backup: $BACKUP_PATH"
        else
            log_error "No backup path specified and no latest backup found"
            log_info "Use --list to see available backups"
            log_info "Use --latest to restore from most recent backup"
            exit 1
        fi
    fi
    
    # Validate the backup
    if ! validate_backup "$BACKUP_PATH"; then
        exit 1
    fi
    
    # Get user confirmation
    if ! confirm_restore; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    # Perform the restore
    if restore_from_backup "$BACKUP_PATH"; then
        echo ""
        log_success "Settings restored successfully!"
        
        if [[ "$DRY_RUN" != true ]]; then
            log_info "Some changes may require logout/restart to take full effect"
            log_info "Check System Preferences to verify settings"
        fi
    else
        log_error "Restore failed"
        exit 1
    fi
    
    return 0
}

# Handle errors
trap 'log_error "Restore script failed at line $LINENO"' ERR

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi 