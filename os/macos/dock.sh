#!/usr/bin/env bash
# macOS Dock Configuration
# Optimizes Dock settings for development workflows

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
log_info() { echo -e "${BLUE}[DOCK]${NC} $*"; }
log_success() { echo -e "${GREEN}[DOCK]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[DOCK]${NC} $*" >&2; }
log_error() { echo -e "${RED}[DOCK]${NC} $*" >&2; }

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

# Apply Dock configuration
apply_dock_config() {
    log_info "Configuring Dock preferences..."
    
    # Enable auto-hide (saves screen space for development)
    apply_default "com.apple.dock" "autohide" "bool" "true" \
        "Enable Dock auto-hide"
    
    # Reduce auto-hide delay to make it more responsive
    apply_default "com.apple.dock" "autohide-delay" "float" "0.1" \
        "Reduce auto-hide delay to 0.1 seconds"
    
    # Speed up auto-hide animation
    apply_default "com.apple.dock" "autohide-time-modifier" "float" "0.25" \
        "Speed up auto-hide animation"
    
    # Set Dock icon size to optimal for productivity (36 pixels)
    apply_default "com.apple.dock" "tilesize" "int" "36" \
        "Set Dock icon size to 36 pixels"
    
    # Disable magnification (can be distracting)
    apply_default "com.apple.dock" "magnification" "bool" "false" \
        "Disable Dock magnification"
    
    # Position Dock at bottom (most common preference)
    apply_default "com.apple.dock" "orientation" "string" "bottom" \
        "Position Dock at bottom of screen"
    
    # Minimize windows into their application icon (cleaner appearance)
    apply_default "com.apple.dock" "minimize-to-application" "bool" "true" \
        "Minimize windows into application icon"
    
    # Use scale effect for minimizing (less distracting than genie)
    apply_default "com.apple.dock" "mineffect" "string" "scale" \
        "Use scale effect for minimizing windows"
    
    # Don't animate opening applications (faster startup feel)
    apply_default "com.apple.dock" "launchanim" "bool" "false" \
        "Disable application opening animation"
    
    # Show indicator lights for open applications
    apply_default "com.apple.dock" "show-process-indicators" "bool" "true" \
        "Show indicator lights for open applications"
    
    # Don't show recent applications in Dock (keeps it clean)
    apply_default "com.apple.dock" "show-recents" "bool" "false" \
        "Hide recent applications in Dock"
    
    # Enable spring loading for all Dock items (useful for drag & drop)
    apply_default "com.apple.dock" "enable-spring-load-actions-on-all-items" "bool" "true" \
        "Enable spring loading for all Dock items"
    
    # Make Dock icons of hidden applications translucent
    apply_default "com.apple.dock" "showhidden" "bool" "true" \
        "Make hidden application icons translucent"
    
    # Remove the auto-hiding dock delay (immediate response)
    apply_default "com.apple.dock" "autohide-delay" "float" "0" \
        "Remove auto-hide delay for immediate response"
    
    # Mission Control settings
    log_info "Configuring Mission Control preferences..."
    
    # Don't automatically rearrange Spaces (maintain manual organization)
    apply_default "com.apple.dock" "mru-spaces" "bool" "false" \
        "Don't automatically rearrange Spaces based on most recent use"
    
    # Don't group windows by application in Mission Control
    apply_default "com.apple.dock" "expose-group-apps" "bool" "false" \
        "Don't group windows by application in Mission Control"
    
    # Disable Dashboard (not commonly used by developers)
    apply_default "com.apple.dashboard" "mcx-disabled" "bool" "true" \
        "Disable Dashboard"
    
    # Hot Corners configuration (useful for development workflows)
    log_info "Configuring Hot Corners..."
    
    # Top-left: Mission Control (quick overview of all windows)
    apply_default "com.apple.dock" "wvous-tl-corner" "int" "2" \
        "Set top-left hot corner to Mission Control"
    
    # Top-right: Desktop (quick access to desktop files)
    apply_default "com.apple.dock" "wvous-tr-corner" "int" "4" \
        "Set top-right hot corner to Desktop"
    
    # Bottom-left: Application windows (show all windows of current app)
    apply_default "com.apple.dock" "wvous-bl-corner" "int" "3" \
        "Set bottom-left hot corner to Application Windows"
    
    # Bottom-right: Launchpad (quick app access)
    apply_default "com.apple.dock" "wvous-br-corner" "int" "11" \
        "Set bottom-right hot corner to Launchpad"
    
    # Set modifiers for hot corners (no modifier required)
    for corner in tl tr bl br; do
        apply_default "com.apple.dock" "wvous-${corner}-modifier" "int" "0" \
            "No modifier required for ${corner} hot corner"
    done
    
    log_success "Dock configuration completed"
}

# Main execution
main() {
    log_info "Starting Dock configuration..."
    
    apply_dock_config
    
    log_success "Dock preferences applied successfully"
    log_info "Dock will restart automatically to apply changes"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 