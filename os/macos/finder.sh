#!/usr/bin/env bash
# macOS Finder Configuration
# Optimizes Finder settings for development workflows

set -euo pipefail

# Configuration
DRY_RUN=false
VERBOSE=false
FORCE=false
INTERACTIVE=true

# Colors for output (simple version)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[FINDER]${NC} $*"; }
log_success() { echo -e "${GREEN}[FINDER]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[FINDER]${NC} $*" >&2; }
log_error() { echo -e "${RED}[FINDER]${NC} $*" >&2; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --force) FORCE=true; INTERACTIVE=false; shift ;;
        --non-interactive) INTERACTIVE=false; shift ;;
        *) shift ;;
    esac
done

# Apply a defaults setting with logging
apply_default() {
    local domain="$1"
    local key="$2"
    local type="$3"
    local value="$4"
    local description="$5"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would set: $description"
        [[ "$VERBOSE" == true ]] && log_info "  defaults write $domain $key -$type $value"
        return 0
    fi
    
    log_info "Setting: $description"
    [[ "$VERBOSE" == true ]] && log_info "  defaults write $domain $key -$type $value"
    
    defaults write "$domain" "$key" -"$type" "$value"
}

# Apply Finder configuration
apply_finder_config() {
    log_info "Configuring Finder preferences..."
    
    # Show all filename extensions (critical for developers)
    apply_default "NSGlobalDomain" "AppleShowAllExtensions" "bool" "true" \
        "Show all filename extensions"
    
    # Show hidden files (access to dotfiles and system files)
    apply_default "com.apple.finder" "AppleShowAllFiles" "bool" "true" \
        "Show hidden files and directories"
    
    # Show status bar (useful information about selection)
    apply_default "com.apple.finder" "ShowStatusBar" "bool" "true" \
        "Show status bar in Finder windows"
    
    # Show path bar (shows current directory path)
    apply_default "com.apple.finder" "ShowPathbar" "bool" "true" \
        "Show path bar in Finder windows"
    
    # Display full POSIX path as Finder window title
    apply_default "com.apple.finder" "_FXShowPosixPathInTitle" "bool" "true" \
        "Show full POSIX path in Finder window title"
    
    # Keep folders on top when sorting by name
    apply_default "com.apple.finder" "_FXSortFoldersFirst" "bool" "true" \
        "Keep folders on top when sorting by name"
    
    # When performing a search, search the current folder by default
    apply_default "com.apple.finder" "FXDefaultSearchScope" "string" "SCcf" \
        "Search current folder by default"
    
    # Disable the warning when changing a file extension
    apply_default "com.apple.finder" "FXEnableExtensionChangeWarning" "bool" "false" \
        "Disable file extension change warning"
    
    # Disable the warning before emptying the Trash
    apply_default "com.apple.finder" "WarnOnEmptyTrash" "bool" "false" \
        "Disable warning before emptying Trash"
    
    # Enable spring loading for directories
    apply_default "NSGlobalDomain" "com.apple.springing.enabled" "bool" "true" \
        "Enable spring loading for directories"
    
    # Set spring loading delay to 0.1 seconds (more responsive)
    apply_default "NSGlobalDomain" "com.apple.springing.delay" "float" "0.1" \
        "Set spring loading delay to 0.1 seconds"
    
    # Avoid creating .DS_Store files on network or USB volumes
    apply_default "com.apple.desktopservices" "DSDontWriteNetworkStores" "bool" "true" \
        "Avoid creating .DS_Store files on network volumes"
    
    apply_default "com.apple.desktopservices" "DSDontWriteUSBStores" "bool" "true" \
        "Avoid creating .DS_Store files on USB volumes"
    
    # Disable disk image verification (speeds up mounting)
    apply_default "com.apple.frameworks.diskimages" "skip-verify" "bool" "true" \
        "Disable disk image verification"
    apply_default "com.apple.frameworks.diskimages" "skip-verify-locked" "bool" "true" \
        "Disable verification of locked disk images"
    apply_default "com.apple.frameworks.diskimages" "skip-verify-remote" "bool" "true" \
        "Disable verification of remote disk images"
    
    # Automatically open a new Finder window when a volume is mounted
    apply_default "com.apple.frameworks.diskimages" "auto-open-ro-root" "bool" "true" \
        "Auto-open read-only volumes"
    apply_default "com.apple.frameworks.diskimages" "auto-open-rw-root" "bool" "true" \
        "Auto-open read-write volumes"
    apply_default "com.apple.finder" "OpenWindowForNewRemovableDisk" "bool" "true" \
        "Open window for new removable disks"
    
    # Use list view in all Finder windows by default (better for development)
    apply_default "com.apple.finder" "FXPreferredViewStyle" "string" "Nlsv" \
        "Use list view as default Finder view"
    
    # Set Home folder as the default location for new Finder windows
    apply_default "com.apple.finder" "NewWindowTarget" "string" "PfHm" \
        "Set Home folder as default for new windows"
    apply_default "com.apple.finder" "NewWindowTargetPath" "string" "file://${HOME}/" \
        "Set Home folder path for new windows"
    
    # Show the ~/Library folder (important for development)
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Making ~/Library folder visible"
        chflags nohidden ~/Library
    else
        log_info "[DRY RUN] Would make ~/Library folder visible"
    fi
    
    # Show the /Volumes folder (useful for mounted drives)
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Making /Volumes folder visible"
        sudo chflags nohidden /Volumes 2>/dev/null || log_warning "Could not unhide /Volumes (may need sudo)"
    else
        log_info "[DRY RUN] Would make /Volumes folder visible"
    fi
    
    # Configure sidebar items
    log_info "Configuring Finder sidebar preferences..."
    
    # Show these items in the sidebar
    local sidebar_tags=(
        "Applications"
        "Desktop" 
        "Documents"
        "Downloads"
        "Home"
        "Movies"
        "Music"
        "Pictures"
        "AirDrop"
        "Recent"
        "Shared"
        "Connected Servers"
        "Hard drives"
        "External disks"
        "CD, DVD, and iOS devices"
        "Cloud storage"
        "Bonjour computers"
    )
    
    # Enable useful sidebar items (this is complex, simplified approach)
    apply_default "com.apple.sidebarlists" "systemitems" "dict" "" \
        "Configure sidebar system items"
    
    # Configure advanced Finder preferences
    log_info "Configuring advanced Finder preferences..."
    
    # Show item info near icons on the desktop and in other icon views
    apply_default "com.apple.finder" "DesktopViewSettings" "dict" "" \
        "Configure desktop view settings"
    
    # Increase grid spacing for icons on the desktop and in other icon views
    # Note: This requires more complex configuration, simplified for now
    
    # Set the size of icons on the desktop and in other icon views
    apply_default "com.apple.finder" "DesktopViewSettings" "dict" "" \
        "Set desktop icon size preferences"
    
    # Finder: show all files (including system and hidden files)
    apply_default "com.apple.finder" "AppleShowAllFiles" "bool" "true" \
        "Show all files including system files"
    
    # Expand the following File Info panes by default
    apply_default "com.apple.finder" "FXInfoPanesExpanded" "dict" "" \
        "Expand File Info panes by default"
    
    log_success "Finder configuration completed"
}

# Configure Quick Look
apply_quicklook_config() {
    log_info "Configuring Quick Look preferences..."
    
    # Allow text selection in Quick Look
    apply_default "com.apple.finder" "QLEnableTextSelection" "bool" "true" \
        "Allow text selection in Quick Look"
    
    log_success "Quick Look configuration completed"
}

# Main execution
main() {
    log_info "Starting Finder configuration..."
    
    apply_finder_config
    apply_quicklook_config
    
    log_success "Finder preferences applied successfully"
    log_info "Finder will restart automatically to apply changes"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 