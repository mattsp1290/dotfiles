#!/usr/bin/env bash
# macOS Settings Backup Script
# Creates backups of current system preferences before applying changes

set -euo pipefail

# Script information
readonly SCRIPT_NAME="macOS Settings Backup"
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
log_info() { echo "${BLUE}[BACKUP]${RESET} $*"; }
log_success() { echo "${GREEN}[BACKUP]${RESET} $*"; }
log_warning() { echo "${YELLOW}[BACKUP]${RESET} $*" >&2; }
log_error() { echo "${RED}[BACKUP]${RESET} $*" >&2; }

# Configuration
BACKUP_DIR="$SCRIPT_DIR/../backup"
DRY_RUN=false
VERBOSE=false
FORCE=false

# Show usage
usage() {
    cat << EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${RESET}

Create backups of macOS system preferences.

${BOLD}USAGE:${RESET}
    $(basename "$0") [OPTIONS]

${BOLD}OPTIONS:${RESET}
    -h, --help              Show this help message
    -d, --dry-run          Show what would be backed up without making changes
    -v, --verbose          Enable verbose output
    -f, --force            Overwrite existing backups
    -o, --output DIR       Specify backup directory (default: $BACKUP_DIR)

${BOLD}EXAMPLES:${RESET}
    # Create backup with timestamp
    $(basename "$0")
    
    # Dry run to see what would be backed up
    $(basename "$0") --dry-run
    
    # Force overwrite existing backup
    $(basename "$0") --force
    
    # Custom backup location
    $(basename "$0") --output ~/my-backups

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
            -o|--output)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Get list of preference domains to backup
get_backup_domains() {
    local domains=(
        # System and global preferences
        "NSGlobalDomain"
        
        # Dock and desktop
        "com.apple.dock"
        "com.apple.dashboard"
        "com.apple.spaces"
        
        # Finder and file system
        "com.apple.finder"
        "com.apple.desktopservices"
        "com.apple.frameworks.diskimages"
        "com.apple.LaunchServices"
        
        # Input devices
        "com.apple.trackpad"
        "com.apple.AppleMultitouchTrackpad"
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
        "com.apple.driver.AppleBluetoothMultitouch.mouse"
        "com.apple.keyboard"
        "com.apple.HIToolbox"
        
        # Screen and display
        "com.apple.screensaver"
        "com.apple.screencapture"
        "com.apple.universalaccess"
        
        # Security and privacy
        "com.apple.spotlight"
        "com.apple.CrashReporter"
        
        # Applications
        "com.apple.Safari"
        "com.apple.appstore"
        "com.apple.print.PrintingPrefs"
        "com.apple.systempreferences"
        "com.apple.loginwindow"
        "com.apple.helpviewer"
        "com.apple.SoftwareUpdate"
        
        # Menu bar and system UI
        "com.apple.menuextra.battery"
        "com.apple.menuextra.clock"
        "com.apple.sidebarlists"
        
        # Network and connectivity
        "com.apple.mDNSResponder"
    )
    
    printf '%s\n' "${domains[@]}"
}

# Create backup of a preference domain
backup_domain() {
    local domain="$1"
    local backup_path="$2"
    local backup_file="$backup_path/${domain}.plist"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would backup: $domain"
        return 0
    fi
    
    if defaults read "$domain" > "$backup_file" 2>/dev/null; then
        [[ "$VERBOSE" == true ]] && log_info "Backed up: $domain"
        return 0
    else
        [[ "$VERBOSE" == true ]] && log_warning "Could not backup: $domain (may not exist)"
        rm -f "$backup_file"
        return 1
    fi
}

# Create metadata file with backup information
create_metadata() {
    local backup_path="$1"
    local metadata_file="$backup_path/backup-info.txt"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create metadata file"
        return 0
    fi
    
    cat > "$metadata_file" << EOF
macOS System Preferences Backup
==============================

Created: $(date)
Host: $(hostname)
User: $(whoami)
macOS Version: $(sw_vers -productVersion)
Build: $(sw_vers -buildVersion)
Script: $SCRIPT_NAME v$SCRIPT_VERSION

Backup Contents:
$(find "$backup_path" -name "*.plist" -exec basename {} \; | sort)

Notes:
- This backup contains macOS system preferences
- Use restore-settings.sh to restore from this backup
- Some settings may require logout/restart to take effect after restore
EOF
    
    log_info "Created metadata file: $metadata_file"
}

# Create restore script
create_restore_script() {
    local backup_path="$1"
    local restore_script="$backup_path/restore.sh"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create restore script"
        return 0
    fi
    
    cat > "$restore_script" << 'EOF'
#!/usr/bin/env bash
# Auto-generated restore script
# Created by macOS Settings Backup Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[RESTORE]${NC} $*"; }
log_success() { echo -e "${GREEN}[RESTORE]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[RESTORE]${NC} $*" >&2; }
log_error() { echo -e "${RED}[RESTORE]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        *) shift ;;
    esac
done

log_info "Restoring macOS system preferences..."

# Find all plist files and restore them
restored=0
failed=0

while IFS= read -r -d '' plist_file; do
    domain=$(basename "$plist_file" .plist)
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restore: $domain"
        ((restored++))
    else
        log_info "Restoring: $domain"
        
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
done < <(find "$SCRIPT_DIR" -name "*.plist" -print0)

if [[ "$DRY_RUN" != true ]]; then
    # Restart affected applications
    log_info "Restarting affected applications..."
    killall "Dock" "Finder" "SystemUIServer" 2>/dev/null || true
    sleep 2
fi

echo ""
log_success "Restore completed!"
log_info "Restored: $restored domains"
[[ $failed -gt 0 ]] && log_warning "Failed: $failed domains"

if [[ "$DRY_RUN" != true ]]; then
    log_info "Some changes may require logout/restart to take full effect"
fi
EOF
    
    chmod +x "$restore_script"
    log_info "Created restore script: $restore_script"
}

# Main backup function
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$timestamp"
    
    log_info "Creating backup of macOS system preferences..."
    
    # Create backup directory
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create backup directory: $backup_path"
    else
        mkdir -p "$backup_path"
        log_info "Backup directory: $backup_path"
    fi
    
    # Backup each domain
    local domains=($(get_backup_domains))
    local backed_up=0
    local failed=0
    
    for domain in "${domains[@]}"; do
        if backup_domain "$domain" "$backup_path"; then
            ((backed_up++))
        else
            ((failed++))
        fi
    done
    
    # Create metadata and restore script
    create_metadata "$backup_path"
    create_restore_script "$backup_path"
    
    # Create symlink to latest backup
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create symlink to latest backup"
    else
        local latest_link="$BACKUP_DIR/latest"
        rm -f "$latest_link"
        ln -sf "backup_$timestamp" "$latest_link"
        log_info "Latest backup link: $latest_link"
    fi
    
    # Show summary
    echo ""
    log_success "Backup completed!"
    log_info "Successfully backed up: $backed_up domains"
    [[ $failed -gt 0 ]] && log_warning "Failed to backup: $failed domains"
    
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Backup location: $backup_path"
        log_info "To restore: $backup_path/restore.sh"
        log_info "To restore (dry-run): $backup_path/restore.sh --dry-run"
    fi
    
    return 0
}

# Check if backup directory exists and handle conflicts
check_backup_directory() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would create backup directory: $BACKUP_DIR"
        else
            mkdir -p "$BACKUP_DIR"
            log_info "Created backup directory: $BACKUP_DIR"
        fi
    fi
    
    # Check for existing backups
    local existing_backups
    existing_backups=$(find "$BACKUP_DIR" -maxdepth 1 -name "backup_*" -type d 2>/dev/null | wc -l)
    
    if [[ $existing_backups -gt 0 ]]; then
        log_info "Found $existing_backups existing backup(s) in $BACKUP_DIR"
    fi
}

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Check macOS compatibility
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Check backup directory
    check_backup_directory
    
    # Create the backup
    create_backup
    
    return 0
}

# Handle errors
trap 'log_error "Backup script failed at line $LINENO"' ERR

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi 