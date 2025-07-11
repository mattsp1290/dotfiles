#!/usr/bin/env bash
# macOS Appearance Configuration
# Optimizes visual appearance and interface settings for development workflows

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
log_info() { echo -e "${BLUE}[APPEARANCE]${NC} $*"; }
log_success() { echo -e "${GREEN}[APPEARANCE]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[APPEARANCE]${NC} $*" >&2; }
log_error() { echo -e "${RED}[APPEARANCE]${NC} $*" >&2; }

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

# Apply dark mode and interface settings
apply_interface_settings() {
    log_info "Configuring interface appearance..."
    
    # Set appearance to Dark mode (better for development, easier on eyes)
    apply_default "NSGlobalDomain" "AppleInterfaceStyle" "string" "Dark" \
        "Set interface to Dark mode"
    
    # Set accent color to blue (default, professional appearance)
    apply_default "NSGlobalDomain" "AppleAccentColor" "int" "4" \
        "Set accent color to blue"
    
    # Set highlight color to blue
    apply_default "NSGlobalDomain" "AppleHighlightColor" "string" "0.698039 0.843137 1.000000 Blue" \
        "Set highlight color to blue"
    
    # Always show scrollbars (helpful for development)
    apply_default "NSGlobalDomain" "AppleShowScrollBars" "string" "Always" \
        "Always show scrollbars"
    
    # Click in the scroll bar to: jump to the spot that's clicked
    apply_default "NSGlobalDomain" "AppleScrollerPagingBehavior" "bool" "true" \
        "Click in scroll bar jumps to clicked spot"
    
    # Increase window resize speed for Cocoa applications
    apply_default "NSGlobalDomain" "NSWindowResizeTime" "float" "0.001" \
        "Increase window resize speed"
    
    # Expand save panel by default
    apply_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode" "bool" "true" \
        "Expand save panel by default"
    apply_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode2" "bool" "true" \
        "Expand save panel by default (NSNavPanelExpandedStateForSaveMode2)"
    
    # Expand print panel by default
    apply_default "NSGlobalDomain" "PMPrintingExpandedStateForPrint" "bool" "true" \
        "Expand print panel by default"
    apply_default "NSGlobalDomain" "PMPrintingExpandedStateForPrint2" "bool" "true" \
        "Expand print panel by default (PMPrintingExpandedStateForPrint2)"
    
    log_success "Interface appearance configuration completed"
}

# Apply menu bar settings
apply_menubar_settings() {
    log_info "Configuring menu bar preferences..."
    
    # Set menu bar to auto-hide (more screen space for development)
    apply_default "NSGlobalDomain" "_HIHideMenuBar" "bool" "false" \
        "Keep menu bar visible (change to true for auto-hide)"
    
    # Show remaining battery time; hide percentage
    apply_default "com.apple.menuextra.battery" "ShowPercent" "string" "NO" \
        "Hide battery percentage in menu bar"
    apply_default "com.apple.menuextra.battery" "ShowTime" "string" "YES" \
        "Show battery time in menu bar"
    
    # Show date and time in menu bar
    apply_default "com.apple.menuextra.clock" "DateFormat" "string" "EEE MMM d  H:mm" \
        "Show date and time in menu bar"
    
    # Flash clock separators (visual feedback)
    apply_default "com.apple.menuextra.clock" "FlashDateSeparators" "bool" "false" \
        "Don't flash clock separators"
    
    # Use a 24-hour clock
    apply_default "NSGlobalDomain" "AppleICUForce24HourTime" "bool" "true" \
        "Use 24-hour time format"
    
    log_success "Menu bar configuration completed"
}

# Apply sidebar and finder appearance
apply_sidebar_settings() {
    log_info "Configuring sidebar appearance..."
    
    # Sidebar icon size: Medium
    apply_default "NSGlobalDomain" "NSTableViewDefaultSizeMode" "int" "2" \
        "Set sidebar icon size to medium"
    
    # Show scroll bars: Always
    apply_default "NSGlobalDomain" "AppleShowScrollBars" "string" "Always" \
        "Always show scroll bars"
    
    log_success "Sidebar configuration completed"
}

# Apply font and text settings
apply_font_settings() {
    log_info "Configuring font and text preferences..."
    
    # Set the system font (SF Pro is default, this ensures it's set)
    # Note: Changing system font is complex and not recommended
    log_info "System font is managed by macOS (SF Pro Display/Text)"
    
    # Enable subpixel font rendering on non-Apple LCDs
    apply_default "NSGlobalDomain" "AppleFontSmoothing" "int" "1" \
        "Enable subpixel font rendering on external displays"
    
    # Enable HiDPI display modes (requires a restart)
    if [[ "$DRY_RUN" != true ]]; then
        log_info "HiDPI modes are configured automatically by macOS"
    else
        log_info "[DRY RUN] Would ensure HiDPI modes are available"
    fi
    
    log_success "Font and text configuration completed"
}

# Apply window and animation settings
apply_animation_settings() {
    log_info "Configuring window and animation preferences..."
    
    # Disable window animations (faster interface)
    apply_default "NSGlobalDomain" "NSAutomaticWindowAnimationsEnabled" "bool" "false" \
        "Disable window animations"
    
    # Speed up Mission Control animations
    apply_default "com.apple.dock" "expose-animation-duration" "float" "0.1" \
        "Speed up Mission Control animations"
    
    # Disable the over-the-top focus ring animation
    apply_default "NSGlobalDomain" "NSUseAnimatedFocusRing" "bool" "false" \
        "Disable animated focus ring"
    
    # Accelerated playback when adjusting the window size
    apply_default "NSGlobalDomain" "NSWindowResizeTime" "float" "0.001" \
        "Accelerate window resize animations"
    
    log_success "Animation configuration completed"
}

# Apply accessibility and usability improvements
apply_accessibility_settings() {
    log_info "Configuring accessibility and usability preferences..."
    
    # Increase contrast (can be helpful for long coding sessions)
    apply_default "com.apple.universalaccess" "increaseContrast" "bool" "false" \
        "Keep normal contrast (change to true if needed)"
    
    # Reduce transparency (can improve performance)
    apply_default "com.apple.universalaccess" "reduceTransparency" "bool" "false" \
        "Keep normal transparency (change to true for better performance)"
    
    # Reduce motion (can improve performance and reduce distraction)
    apply_default "com.apple.universalaccess" "reduceMotion" "bool" "false" \
        "Keep normal motion (change to true to reduce animations)"
    
    # Differentiate without color (accessibility)
    apply_default "com.apple.universalaccess" "differentiateWithoutColor" "bool" "false" \
        "Keep color differentiation (change to true for accessibility)"
    
    log_success "Accessibility configuration completed"
}

# Main execution
main() {
    log_info "Starting appearance configuration..."
    
    apply_interface_settings
    apply_menubar_settings
    apply_sidebar_settings
    apply_font_settings
    apply_animation_settings
    apply_accessibility_settings
    
    log_success "Appearance preferences applied successfully"
    log_info "Some changes may require logout/restart to take full effect"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 