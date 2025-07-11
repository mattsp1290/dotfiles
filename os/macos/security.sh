#!/usr/bin/env bash
# macOS Security Configuration
# Optimizes security and privacy settings for development workflows

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
log_info() { echo -e "${BLUE}[SECURITY]${NC} $*"; }
log_success() { echo -e "${GREEN}[SECURITY]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[SECURITY]${NC} $*" >&2; }
log_error() { echo -e "${RED}[SECURITY]${NC} $*" >&2; }

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

# Apply security settings
apply_security_settings() {
    log_info "Configuring security preferences..."
    
    # Require password immediately after sleep or screen saver begins
    apply_default "com.apple.screensaver" "askForPassword" "int" "1" \
        "Require password after sleep or screen saver"
    
    # Set delay to 0 seconds (immediate)
    apply_default "com.apple.screensaver" "askForPasswordDelay" "int" "0" \
        "Set password delay to 0 seconds (immediate)"
    
    # Save screenshots in PNG format (better for code snippets)
    apply_default "com.apple.screencapture" "type" "string" "png" \
        "Save screenshots in PNG format"
    
    # Disable shadow in screenshots (cleaner appearance)
    apply_default "com.apple.screencapture" "disable-shadow" "bool" "true" \
        "Disable shadow in screenshots"
    
    # Disable Spotlight suggestions (privacy)
    apply_default "com.apple.spotlight" "LookupEnabled" "bool" "false" \
        "Disable Spotlight suggestions"
    
    # Disable Bing web searches in Spotlight
    apply_default "com.apple.spotlight" "WebSearchEnabled" "bool" "false" \
        "Disable Bing web searches in Spotlight"
    
    # Secure empty trash (overwrite deleted files)
    apply_default "com.apple.finder" "EmptyTrashSecurely" "bool" "true" \
        "Enable secure empty trash"
    
    # Disable the automatic run of safe files in Safari (security)
    apply_default "com.apple.Safari" "AutoOpenSafeDownloads" "bool" "false" \
        "Disable automatic opening of safe downloads in Safari"
    
    log_success "Security configuration completed"
}

# Main execution
main() {
    log_info "Starting security configuration..."
    
    apply_security_settings
    
    log_success "Security preferences applied successfully"
    
    # Provide manual configuration reminders
    echo ""
    log_info "Manual Configuration Reminders:"
    log_info "  1. System Preferences > Security & Privacy > Firewall: Enable and configure"
    log_info "  2. System Preferences > Security & Privacy > FileVault: Enable disk encryption"
    log_info "  3. System Preferences > Security & Privacy > Privacy: Review app permissions"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
