# macOS Customization Guide

This guide explains how to customize and extend the macOS system preferences configuration to match your specific workflow needs. The system is designed to be modular and easily customizable.

## Overview

The macOS preferences system consists of:
- **Category Scripts**: Individual scripts for each preference category
- **Master Script**: Orchestrates all category scripts
- **Backup System**: Creates and restores preference backups
- **Documentation**: Comprehensive guides and references

## Quick Customization

### Disabling Categories

To skip specific categories, modify the `AVAILABLE_CATEGORIES` array in `os/macos/defaults.sh`:

```bash
# Remove categories you don't want
AVAILABLE_CATEGORIES=(
    "dock"
    "finder"
    "input"
    # "security"      # Commented out to skip
    "appearance"
    # "general"       # Commented out to skip
)
```

### Overriding Individual Settings

Create a personal override script that runs after the main configuration:

```bash
# Create personal overrides
cat > os/macos/personal-overrides.sh << 'EOF'
#!/usr/bin/env bash
# Personal preference overrides

# Keep menu bar visible (override appearance setting)
defaults write NSGlobalDomain _HIHideMenuBar -bool false

# Use genie effect for minimizing (override dock setting)
defaults write com.apple.dock mineffect -string "genie"

# Enable auto-correct (override input setting)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true

echo "Personal overrides applied"
EOF

chmod +x os/macos/personal-overrides.sh
```

Then add it to your workflow:
```bash
./os/macos/defaults.sh && ./os/macos/personal-overrides.sh
```

## Customizing Individual Categories

### Dock Customization

Common customizations for `os/macos/dock.sh`:

**Change Dock Position:**
```bash
# Left side
defaults write com.apple.dock orientation -string "left"

# Right side  
defaults write com.apple.dock orientation -string "right"

# Bottom (default)
defaults write com.apple.dock orientation -string "bottom"
```

**Adjust Icon Size:**
```bash
# Smaller icons (24px)
defaults write com.apple.dock tilesize -int 24

# Larger icons (48px)
defaults write com.apple.dock tilesize -int 48

# Enable magnification with larger max size
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64
```

**Custom Hot Corners:**
```bash
# Hot corner values:
# 0: No Action
# 2: Mission Control  
# 3: Application Windows
# 4: Desktop
# 5: Start Screen Saver
# 6: Disable Screen Saver
# 7: Dashboard
# 10: Put Display to Sleep
# 11: Launchpad
# 12: Notification Center

# Example: Top-left puts display to sleep
defaults write com.apple.dock wvous-tl-corner -int 10
defaults write com.apple.dock wvous-tl-modifier -int 0
```

### Finder Customization

**Change Default View:**
```bash
# Icon view
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"

# List view (default)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Column view
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Gallery view
defaults write com.apple.finder FXPreferredViewStyle -string "glyv"
```

**Custom New Window Location:**
```bash
# Desktop
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

# Documents folder
defaults write com.apple.finder NewWindowTarget -string "PfDo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Documents/"

# Custom path (e.g., Projects folder)
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Projects/"
```

### Input Customization

**Adjust Keyboard Repeat:**
```bash
# Slower repeat (higher values = slower)
defaults write NSGlobalDomain KeyRepeat -int 6
defaults write NSGlobalDomain InitialKeyRepeat -int 25

# Faster repeat (lower values = faster)
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10
```

**Trackpad Sensitivity:**
```bash
# Slower tracking
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.0

# Faster tracking  
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3.0
```

### Appearance Customization

**Light Mode Instead of Dark:**
```bash
# Remove dark mode setting or override it
# defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"  # Comment this out

# Explicitly set light mode
defaults delete NSGlobalDomain AppleInterfaceStyle 2>/dev/null || true
```

**Different Accent Colors:**
```bash
# Accent color values:
# -1: Graphite
# 0: Red  
# 1: Orange
# 2: Yellow
# 3: Green
# 4: Blue (default)
# 5: Purple
# 6: Pink

# Set to green
defaults write NSGlobalDomain AppleAccentColor -int 3
```

**Menu Bar Auto-Hide:**
```bash
# Auto-hide menu bar
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Keep menu bar visible (default)
defaults write NSGlobalDomain _HIHideMenuBar -bool false
```

## Creating Custom Categories

### New Category Script Template

Create a new category script following the established pattern:

```bash
#!/usr/bin/env bash
# macOS Custom Category Configuration
# Description of what this category configures

set -euo pipefail

# Configuration
DRY_RUN=false
VERBOSE=false
FORCE=false
INTERACTIVE=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[CUSTOM]${NC} $*"; }
log_success() { echo -e "${GREEN}[CUSTOM]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[CUSTOM]${NC} $*" >&2; }
log_error() { echo -e "${RED}[CUSTOM]${NC} $*" >&2; }

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

# Your custom configuration function
apply_custom_config() {
    log_info "Configuring custom preferences..."
    
    # Add your custom defaults here
    apply_default "com.example.app" "CustomSetting" "bool" "true" \
        "Enable custom feature"
    
    log_success "Custom configuration completed"
}

# Main execution
main() {
    log_info "Starting custom configuration..."
    
    apply_custom_config
    
    log_success "Custom preferences applied successfully"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
```

### Integrating Custom Categories

1. **Add to Available Categories:**
   ```bash
   # In os/macos/defaults.sh, add your category
   AVAILABLE_CATEGORIES=(
       "dock"
       "finder"
       "input"
       "security"
       "appearance"
       "general"
       "custom"        # Your new category
   )
   ```

2. **Update Category Descriptions:**
   ```bash
   # In the list_categories function
   echo "${BLUE}custom${RESET}     - Your custom preference descriptions"
   ```

## Environment-Specific Configurations

### Work vs Personal Profiles

Create environment-specific override files:

```bash
# Work environment overrides
cat > os/macos/work-profile.sh << 'EOF'
#!/usr/bin/env bash
# Work environment specific settings

# More conservative security settings
defaults write com.apple.screensaver idleTime -int 300  # 5 minutes

# Disable Dock auto-hide for better visibility
defaults write com.apple.dock autohide -bool false

# Enable file extension warnings for security
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool true
EOF

# Personal environment overrides  
cat > os/macos/personal-profile.sh << 'EOF'
#!/usr/bin/env bash
# Personal environment specific settings

# Longer screen saver delay
defaults write com.apple.screensaver idleTime -int 1200  # 20 minutes

# Enable Dock auto-hide for more screen space
defaults write com.apple.dock autohide -bool true

# Disable file extension warnings
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
EOF
```

Use environment variable to control which profile to apply:
```bash
# Set environment
export MACOS_PROFILE="work"  # or "personal"

# Apply base configuration
./os/macos/defaults.sh

# Apply profile-specific overrides
if [[ -n "${MACOS_PROFILE:-}" ]]; then
    profile_script="os/macos/${MACOS_PROFILE}-profile.sh"
    if [[ -x "$profile_script" ]]; then
        echo "Applying $MACOS_PROFILE profile..."
        "$profile_script"
    fi
fi
```

## Advanced Customization Techniques

### Conditional Settings

Apply settings based on system characteristics:

```bash
# In your custom script
apply_conditional_settings() {
    # Check macOS version
    local os_version=$(sw_vers -productVersion)
    local major_version="${os_version%%.*}"
    
    if [[ $major_version -ge 13 ]]; then
        # Ventura-specific settings
        apply_default "com.apple.dock" "some-new-feature" "bool" "true" \
            "Enable Ventura-specific feature"
    fi
    
    # Check for specific hardware
    if system_profiler SPHardwareDataType | grep -q "MacBook"; then
        # Laptop-specific settings
        apply_default "com.apple.dock" "orientation" "string" "bottom" \
            "Keep Dock at bottom for laptops"
    else
        # Desktop-specific settings
        apply_default "com.apple.dock" "orientation" "string" "left" \
            "Move Dock to left for desktop monitors"
    fi
    
    # Check screen resolution
    local screen_width=$(system_profiler SPDisplaysDataType | grep Resolution | head -1 | awk '{print $2}')
    if [[ $screen_width -gt 2560 ]]; then
        # High-resolution display settings
        apply_default "com.apple.dock" "tilesize" "int" "48" \
            "Larger icons for high-res displays"
    fi
}
```

### User Input for Settings

Create interactive configuration:

```bash
# Interactive customization
interactive_setup() {
    if [[ "$INTERACTIVE" != true ]]; then
        return 0
    fi
    
    echo "Customizing Dock settings..."
    
    # Ask for Dock position
    echo "Dock position:"
    echo "1) Bottom (default)"
    echo "2) Left"
    echo "3) Right"
    echo -n "Choose (1-3): "
    read -r dock_choice
    
    case "$dock_choice" in
        2) dock_position="left" ;;
        3) dock_position="right" ;;
        *) dock_position="bottom" ;;
    esac
    
    apply_default "com.apple.dock" "orientation" "string" "$dock_position" \
        "Set Dock position to $dock_position"
    
    # Ask for icon size
    echo -n "Dock icon size (16-128, default 36): "
    read -r icon_size
    
    if [[ "$icon_size" =~ ^[0-9]+$ ]] && [[ $icon_size -ge 16 ]] && [[ $icon_size -le 128 ]]; then
        apply_default "com.apple.dock" "tilesize" "int" "$icon_size" \
            "Set Dock icon size to $icon_size pixels"
    fi
}
```

### Configuration Files

Use external configuration files for easy customization:

```yaml
# config/macos-preferences.yml
dock:
  autohide: true
  position: "bottom"
  icon_size: 36
  magnification: false

finder:
  show_extensions: true
  show_hidden_files: true
  default_view: "list"
  new_window_target: "home"

input:
  key_repeat: 2
  initial_key_repeat: 12
  tap_to_click: true

appearance:
  interface_style: "dark"
  accent_color: 4  # blue
  show_scrollbars: "always"
```

Then parse the YAML in your scripts:
```bash
# Simple YAML parsing (or use a proper YAML parser)
get_config_value() {
    local key="$1"
    local config_file="config/macos-preferences.yml"
    
    if [[ -f "$config_file" ]]; then
        grep "^[[:space:]]*${key}:" "$config_file" | cut -d':' -f2 | xargs
    fi
}

# Use in your scripts
dock_size=$(get_config_value "icon_size")
if [[ -n "$dock_size" ]]; then
    apply_default "com.apple.dock" "tilesize" "int" "$dock_size" \
        "Set Dock icon size from config"
fi
```

## Testing and Validation

### Dry Run Testing

Always test changes with dry run mode:
```bash
# Test all changes
./os/macos/defaults.sh --dry-run

# Test specific category
./os/macos/dock.sh --dry-run --verbose

# Test custom configurations
./os/macos/custom-category.sh --dry-run
```

### Validation Scripts

Create scripts to validate your configurations:

```bash
#!/usr/bin/env bash
# validate-config.sh
# Validates that settings are applied correctly

validate_setting() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local description="$4"
    
    local current=$(defaults read "$domain" "$key" 2>/dev/null || echo "NOT_SET")
    
    if [[ "$current" == "$expected" ]]; then
        echo "✓ $description"
    else
        echo "✗ $description (expected: $expected, got: $current)"
    fi
}

# Validate key settings
validate_setting "com.apple.dock" "autohide" "1" "Dock auto-hide enabled"
validate_setting "com.apple.finder" "AppleShowAllFiles" "1" "Hidden files visible"
validate_setting "NSGlobalDomain" "KeyRepeat" "2" "Fast key repeat"
```

### Backup Before Customization

Always create backups before making changes:
```bash
# Create backup
./os/macos/scripts/backup-settings.sh

# Apply your customizations
./os/macos/defaults.sh
./os/macos/personal-overrides.sh

# If something goes wrong, restore
./os/macos/scripts/restore-settings.sh --latest
```

## Troubleshooting Customizations

### Common Issues

**Settings Don't Apply:**
- Check domain names: `defaults domains | grep -i keyword`
- Verify key names: `defaults read com.apple.dock | grep -i keyword`
- Try killing affected apps: `killall Dock Finder`

**Wrong Data Types:**
```bash
# Check current type and value
defaults read-type com.apple.dock autohide

# Common types: bool, int, float, string, array, dict
```

**Permission Issues:**
```bash
# Check preference file permissions
ls -la ~/Library/Preferences/com.apple.dock.plist

# Reset if corrupted
defaults delete com.apple.dock
killall Dock
```

### Debugging Tools

**View All Settings for a Domain:**
```bash
defaults read com.apple.dock
```

**Monitor Changes in Real-Time:**
```bash
# Watch preference files
sudo fs_usage | grep plist

# Monitor defaults command usage
sudo dtruss -f -n defaults
```

**Export Current Settings:**
```bash
# Export specific domain
defaults export com.apple.dock ~/dock-settings.plist

# Convert to readable format
plutil -convert xml1 ~/dock-settings.plist
```

## Best Practices

### Script Organization
- Keep category scripts focused and single-purpose
- Use consistent naming conventions
- Include comprehensive logging and error handling
- Support dry-run mode for all changes

### Documentation
- Document the purpose of each setting
- Explain the impact on workflows
- Provide examples and alternatives
- Keep documentation up-to-date

### Version Control
- Commit configuration scripts to version control
- Tag stable configurations
- Use branches for experimental changes
- Include rollback procedures

### Testing
- Test on fresh systems when possible
- Use virtual machines for validation
- Verify settings persist across reboots
- Test interaction between different categories

For more information, see the [main macOS settings documentation](macos-settings.md). 