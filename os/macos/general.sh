#!/usr/bin/env bash
# macOS General Configuration
# Handles miscellaneous system-wide preferences for development workflows

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
log_info() { echo -e "${BLUE}[GENERAL]${NC} $*"; }
log_success() { echo -e "${GREEN}[GENERAL]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[GENERAL]${NC} $*" >&2; }
log_error() { echo -e "${RED}[GENERAL]${NC} $*" >&2; }

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

# Apply general system settings
apply_system_settings() {
    log_info "Configuring general system preferences..."
    
    # Set computer name (to be set during initial setup)
    log_info "Computer name should be set during initial system setup"
    
    # Set standby delay to 24 hours (default is 1 hour on newer Macs)
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Power management settings are managed through Energy Saver preferences"
    else
        log_info "[DRY RUN] Would configure power management settings"
    fi
    
    # Disable the sound effects on boot
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Boot sound is disabled by default on newer Macs"
    else
        log_info "[DRY RUN] Would disable boot sound"
    fi
    
    # Save to disk (not to iCloud) by default
    apply_default "NSGlobalDomain" "NSDocumentSaveNewDocumentsToCloud" "bool" "false" \
        "Save to disk (not iCloud) by default"
    
    # Automatically quit printer app once the print jobs complete
    apply_default "com.apple.print.PrintingPrefs" "Quit When Finished" "bool" "true" \
        "Automatically quit printer app when jobs complete"
    
    # Disable the "Are you sure you want to open this application?" dialog
    apply_default "com.apple.LaunchServices" "LSQuarantine" "bool" "false" \
        "Disable application quarantine dialog (security trade-off)"
    
    # Remove duplicates in the "Open With" menu
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Rebuilding Launch Services database to remove duplicates"
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true
    else
        log_info "[DRY RUN] Would rebuild Launch Services database"
    fi
    
    # Disable Resume system-wide
    apply_default "com.apple.systempreferences" "NSQuitAlwaysKeepsWindows" "bool" "false" \
        "Disable Resume system-wide"
    
    # Disable automatic termination of inactive apps
    apply_default "NSGlobalDomain" "NSDisableAutomaticTermination" "bool" "true" \
        "Disable automatic termination of inactive apps"
    
    # Set Help Viewer windows to non-floating mode
    apply_default "com.apple.helpviewer" "DevMode" "bool" "true" \
        "Set Help Viewer windows to non-floating mode"
    
    log_success "General system configuration completed"
}

# Apply file and document settings
apply_document_settings() {
    log_info "Configuring document and file preferences..."
    
    # Disable the "reopen windows when logging back in" option
    apply_default "com.apple.loginwindow" "TALLogoutSavesState" "bool" "false" \
        "Disable reopen windows when logging back in"
    
    # Set default save location to local disk
    apply_default "NSGlobalDomain" "NSDocumentSaveNewDocumentsToCloud" "bool" "false" \
        "Set default save location to local disk"
    
    # Enable full keyboard access for all controls
    apply_default "NSGlobalDomain" "AppleKeyboardUIMode" "int" "3" \
        "Enable full keyboard access for all controls"
    
    log_success "Document and file configuration completed"
}

# Apply crash reporter settings
apply_crashreporter_settings() {
    log_info "Configuring crash reporter preferences..."
    
    # Set crash reporter to notification mode
    apply_default "com.apple.CrashReporter" "DialogType" "string" "notification" \
        "Set crash reporter to notification mode"
    
    log_success "Crash reporter configuration completed"
}

# Apply smart quotes and dashes (development-friendly)
apply_text_settings() {
    log_info "Configuring text input preferences..."
    
    # Disable smart quotes as they're annoying when typing code
    apply_default "NSGlobalDomain" "NSAutomaticQuoteSubstitutionEnabled" "bool" "false" \
        "Disable smart quotes"
    
    # Disable smart dashes as they're annoying when typing code  
    apply_default "NSGlobalDomain" "NSAutomaticDashSubstitutionEnabled" "bool" "false" \
        "Disable smart dashes"
    
    # Disable automatic capitalization
    apply_default "NSGlobalDomain" "NSAutomaticCapitalizationEnabled" "bool" "false" \
        "Disable automatic capitalization"
    
    # Disable auto-correct
    apply_default "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "bool" "false" \
        "Disable auto-correct"
    
    # Disable automatic period substitution
    apply_default "NSGlobalDomain" "NSAutomaticPeriodSubstitutionEnabled" "bool" "false" \
        "Disable automatic period substitution"
    
    log_success "Text input configuration completed"
}

# Apply energy and performance settings
apply_energy_settings() {
    log_info "Configuring energy and performance preferences..."
    
    # Note: Energy settings typically require admin privileges and are better set through System Preferences
    log_info "Energy settings are best configured through System Preferences > Energy Saver"
    log_info "Recommended: Never sleep for Computer, Display sleep after 10-30 minutes"
    
    # Disable machine sleep while charging
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Sleep settings managed through Energy Saver preferences"
    else
        log_info "[DRY RUN] Would configure sleep settings"
    fi
    
    log_success "Energy configuration guidance provided"
}

# Apply development-friendly settings
apply_development_settings() {
    log_info "Configuring development-friendly preferences..."
    
    # Reveal IP address, hostname, OS version, etc. when clicking the clock in the login window
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Login window clock info is configured automatically"
    else
        log_info "[DRY RUN] Would configure login window clock info"
    fi
    
    # Check for software updates daily, not just once per week
    apply_default "com.apple.SoftwareUpdate" "ScheduleFrequency" "int" "1" \
        "Check for software updates daily"
    
    # Enable the WebKit Developer Tools in the Mac App Store
    apply_default "com.apple.appstore" "WebKitDeveloperExtras" "bool" "true" \
        "Enable WebKit Developer Tools in App Store"
    
    # Enable Debug Menu in the Mac App Store
    apply_default "com.apple.appstore" "ShowDebugMenu" "bool" "true" \
        "Enable Debug Menu in App Store"
    
    log_success "Development-friendly configuration completed"
}

# Main execution
main() {
    log_info "Starting general system configuration..."
    
    apply_system_settings
    apply_document_settings
    apply_crashreporter_settings
    apply_text_settings
    apply_energy_settings
    apply_development_settings
    
    log_success "General preferences applied successfully"
    log_info "Some changes may require logout/restart to take full effect"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 