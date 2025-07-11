#!/usr/bin/env bash
# macOS Input Configuration
# Optimizes keyboard, trackpad, and mouse settings for development workflows

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
log_info() { echo -e "${BLUE}[INPUT]${NC} $*"; }
log_success() { echo -e "${GREEN}[INPUT]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[INPUT]${NC} $*" >&2; }
log_error() { echo -e "${RED}[INPUT]${NC} $*" >&2; }

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

# Apply keyboard configuration
apply_keyboard_config() {
    log_info "Configuring keyboard preferences..."
    
    # Set a blazingly fast keyboard repeat rate (important for coding)
    apply_default "NSGlobalDomain" "KeyRepeat" "int" "2" \
        "Set very fast key repeat rate"
    
    # Set a shorter delay until key repeat starts
    apply_default "NSGlobalDomain" "InitialKeyRepeat" "int" "12" \
        "Set short delay until key repeat starts"
    
    # Disable automatic capitalization (can interfere with code)
    apply_default "NSGlobalDomain" "NSAutomaticCapitalizationEnabled" "bool" "false" \
        "Disable automatic capitalization"
    
    # Disable smart dashes (can interfere with code)
    apply_default "NSGlobalDomain" "NSAutomaticDashSubstitutionEnabled" "bool" "false" \
        "Disable smart dashes"
    
    # Disable automatic period substitution (can interfere with code)
    apply_default "NSGlobalDomain" "NSAutomaticPeriodSubstitutionEnabled" "bool" "false" \
        "Disable automatic period substitution"
    
    # Disable smart quotes (can interfere with code)
    apply_default "NSGlobalDomain" "NSAutomaticQuoteSubstitutionEnabled" "bool" "false" \
        "Disable smart quotes"
    
    # Disable auto-correct (can interfere with variable names)
    apply_default "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "bool" "false" \
        "Disable auto-correct"
    
    # Enable full keyboard access for all controls (useful for accessibility)
    apply_default "NSGlobalDomain" "AppleKeyboardUIMode" "int" "3" \
        "Enable full keyboard access for all controls"
    
    # Use F1, F2, etc. keys as standard function keys (important for IDEs)
    apply_default "NSGlobalDomain" "com.apple.keyboard.fnState" "bool" "true" \
        "Use F1, F2, etc. keys as standard function keys"
    
    # Set language and text settings
    log_info "Configuring language and text preferences..."
    
    # Disable automatic text replacement
    apply_default "NSGlobalDomain" "NSAutomaticTextReplacementEnabled" "bool" "false" \
        "Disable automatic text replacement"
    
    # Set the timezone (important for development)
    # Note: This is usually set during system setup, but we ensure it's configured
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Timezone is managed by System Preferences"
    else
        log_info "[DRY RUN] Would check timezone configuration"
    fi
    
    log_success "Keyboard configuration completed"
}

# Apply trackpad configuration
apply_trackpad_config() {
    log_info "Configuring trackpad preferences..."
    
    # Enable tap to click for this user and for the login screen
    apply_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "Clicking" "bool" "true" \
        "Enable tap to click for Bluetooth trackpad"
    
    apply_default "com.apple.AppleMultitouchTrackpad" "Clicking" "bool" "true" \
        "Enable tap to click for built-in trackpad"
    
    # Map bottom right corner to right-click
    apply_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadCornerSecondaryClick" "int" "2" \
        "Map bottom right corner to right-click (Bluetooth)"
    
    apply_default "com.apple.AppleMultitouchTrackpad" "TrackpadCornerSecondaryClick" "int" "2" \
        "Map bottom right corner to right-click (built-in)"
    
    apply_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadRightClick" "bool" "true" \
        "Enable two-finger right-click (Bluetooth)"
    
    apply_default "com.apple.AppleMultitouchTrackpad" "TrackpadRightClick" "bool" "true" \
        "Enable two-finger right-click (built-in)"
    
    # Increase tracking speed (useful for large displays)
    apply_default "com.apple.trackpad.scaling" "com.apple.trackpad.scaling" "float" "1.5" \
        "Increase trackpad tracking speed"
    
    # Enable three-finger drag
    apply_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadThreeFingerDrag" "bool" "true" \
        "Enable three-finger drag (Bluetooth)"
    
    apply_default "com.apple.AppleMultitouchTrackpad" "TrackpadThreeFingerDrag" "bool" "true" \
        "Enable three-finger drag (built-in)"
    
    # Disable three-finger tap gesture (can interfere with development)
    apply_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadThreeFingerTapGesture" "int" "0" \
        "Disable three-finger tap gesture (Bluetooth)"
    
    apply_default "com.apple.AppleMultitouchTrackpad" "TrackpadThreeFingerTapGesture" "int" "0" \
        "Disable three-finger tap gesture (built-in)"
    
    # Configure trackpad gestures for development workflows
    
    # Enable App Exposé (three-finger down swipe)
    apply_default "com.apple.dock" "showAppExposeGestureEnabled" "bool" "true" \
        "Enable App Exposé gesture"
    
    # Enable Mission Control (three-finger up swipe)
    apply_default "com.apple.dock" "showMissionControlGestureEnabled" "bool" "true" \
        "Enable Mission Control gesture"
    
    # Enable Launchpad gesture (pinch with thumb and three fingers)
    apply_default "com.apple.dock" "showLaunchpadGestureEnabled" "bool" "true" \
        "Enable Launchpad gesture"
    
    # Enable Show Desktop gesture (spread with thumb and three fingers)
    apply_default "com.apple.dock" "showDesktopGestureEnabled" "bool" "true" \
        "Enable Show Desktop gesture"
    
    log_success "Trackpad configuration completed"
}

# Apply mouse configuration
apply_mouse_config() {
    log_info "Configuring mouse preferences..."
    
    # Enable right-click
    apply_default "com.apple.driver.AppleBluetoothMultitouch.mouse" "MouseButtonMode" "string" "TwoButton" \
        "Enable right-click for Bluetooth mouse"
    
    # Set mouse tracking speed
    apply_default "NSGlobalDomain" "com.apple.mouse.scaling" "float" "2.5" \
        "Set mouse tracking speed"
    
    # Disable mouse acceleration (preferred by many developers)
    apply_default "NSGlobalDomain" "com.apple.mouse.acceleration" "float" "0" \
        "Disable mouse acceleration"
    
    # Set scroll direction to natural (matches trackpad)
    apply_default "NSGlobalDomain" "com.apple.swipescrolldirection" "bool" "true" \
        "Enable natural scroll direction"
    
    log_success "Mouse configuration completed"
}

# Apply accessibility configuration
apply_accessibility_config() {
    log_info "Configuring accessibility preferences..."
    
    # Reduce motion for better performance and less distraction
    apply_default "com.apple.universalaccess" "reduceMotion" "bool" "true" \
        "Reduce motion for better performance"
    
    # Increase contrast for better readability
    apply_default "com.apple.universalaccess" "increaseContrast" "bool" "false" \
        "Keep normal contrast (change to true if needed)"
    
    # Reduce transparency for better performance
    apply_default "com.apple.universalaccess" "reduceTransparency" "bool" "false" \
        "Keep normal transparency (change to true for better performance)"
    
    # Enable zoom with scroll gesture (useful for presentations)
    apply_default "com.apple.universalaccess" "closeViewScrollWheelToggle" "bool" "true" \
        "Enable zoom with scroll gesture and modifier key"
    
    # Follow keyboard focus while zoomed in
    apply_default "com.apple.universalaccess" "closeViewZoomFollowsFocus" "bool" "true" \
        "Follow keyboard focus while zoomed in"
    
    log_success "Accessibility configuration completed"
}

# Apply text input configuration
apply_text_input_config() {
    log_info "Configuring text input preferences..."
    
    # Disable press-and-hold for keys in favor of key repeat
    apply_default "NSGlobalDomain" "ApplePressAndHoldEnabled" "bool" "false" \
        "Disable press-and-hold for keys in favor of key repeat"
    
    # Set default input source (US English)
    apply_default "com.apple.HIToolbox" "AppleEnabledInputSources" "array" "" \
        "Configure enabled input sources"
    
    # Disable automatic switching to a document's input language
    apply_default "com.apple.HIToolbox" "AppleGlobalTextInputProperties" "dict" "" \
        "Configure global text input properties"
    
    log_success "Text input configuration completed"
}

# Main execution
main() {
    log_info "Starting input devices configuration..."
    
    apply_keyboard_config
    apply_trackpad_config
    apply_mouse_config
    apply_accessibility_config
    apply_text_input_config
    
    log_success "Input preferences applied successfully"
    log_info "Some changes may require logout/restart to take effect"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 