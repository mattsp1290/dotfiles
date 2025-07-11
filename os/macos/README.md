# macOS System Preferences

Comprehensive macOS system preferences configuration optimized for development workflows. This system automates the setup of Dock, Finder, input devices, security, appearance, and general system settings to create a consistent and productive development environment.

## Quick Start

```bash
# Apply all macOS system preferences (interactive)
./defaults.sh

# Apply specific categories only
./defaults.sh dock finder input

# See what would be changed without applying
./defaults.sh --dry-run

# Apply all settings without prompts
./defaults.sh --force --non-interactive
```

## What Gets Configured

### 🎯 Dock Settings (`dock.sh`)
- **Auto-hide with fast animation** (0.25s) for maximum screen space
- **36px icon size** - optimal balance of visibility and space efficiency
- **Hot corners** configured for development workflows:
  - Top-left: Mission Control (window overview)
  - Top-right: Desktop (file access)
  - Bottom-left: Application Windows (current app focus)
  - Bottom-right: Launchpad (app launcher)
- **Minimization to app icon** with scale effect (cleaner, faster)
- **Spaces don't auto-rearrange** (maintain project organization)

### 📁 Finder Settings (`finder.sh`)
- **Show all file extensions** (critical for development)
- **Show hidden files** (access to dotfiles and system files)
- **Show path bar and status bar** (navigation context)
- **List view as default** (better for file details)
- **Home directory as default location** (logical starting point)
- **No .DS_Store files** on network/USB volumes (cleaner repos)
- **Fast disk image mounting** (skip verification)

### ⌨️ Input Settings (`input.sh`)
- **Ultra-fast key repeat** (essential for code navigation)
- **Tap to click** trackpad setting (faster interaction)
- **Three-finger drag** enabled (efficient text/window manipulation)
- **Function keys work as F1-F12** by default (IDE compatibility)
- **Disabled smart quotes/dashes** (prevents code syntax issues)
- **No auto-correct** (preserves variable names and technical terms)

### 🔒 Security Settings (`security.sh`)
- **Immediate password requirement** when screen saver activates
- **PNG screenshots** without shadows (better for documentation)
- **Disabled Spotlight suggestions** (enhanced privacy)
- **Secure empty trash** (overwrite deleted files)
- **No auto-open of "safe" downloads** (security best practice)

### 🎨 Appearance Settings (`appearance.sh`)
- **Dark mode interface** (easier on eyes, matches dev tools)
- **Blue accent color** (professional, good contrast)
- **Always show scrollbars** (better navigation feedback)
- **Fast/minimal animations** (responsive interface)
- **24-hour time format** (international standard, better for logs)
- **Expanded save/print dialogs** (faster file operations)

### ⚙️ General Settings (`general.sh`)
- **Save to disk by default** (not iCloud - faster, more reliable)
- **No application resume** (clean startup state)
- **Daily software update checks** (security and features)
- **App Store developer tools enabled** (web development)
- **Notification-mode crash reporting** (less disruptive)

## Individual Scripts

Each category can be run independently for targeted configuration:

```bash
./dock.sh --verbose       # Configure Dock settings with detailed output
./finder.sh --dry-run     # Preview Finder changes without applying
./input.sh               # Apply keyboard/trackpad settings
./security.sh            # Configure security preferences  
./appearance.sh          # Set up dark mode and interface
./general.sh             # Apply general system settings
```

All scripts support the same command-line options:
- `--dry-run`: Show what would be changed without applying
- `--verbose`: Detailed output of each setting being applied
- `--force`: Skip confirmation prompts
- `--non-interactive`: Run without user interaction

## Backup and Restore

### Creating Backups

Always create a backup before applying system changes:

```bash
# Create timestamped backup
./scripts/backup-settings.sh

# Create backup with verbose output
./scripts/backup-settings.sh --verbose

# Create backup in custom location
./scripts/backup-settings.sh --output ~/my-backups
```

### Restoring from Backups

```bash
# List available backups
./scripts/restore-settings.sh --list

# Restore from latest backup
./scripts/restore-settings.sh --latest

# Restore from specific backup
./scripts/restore-settings.sh ~/backups/backup_20231201_143022

# Preview restore without applying
./scripts/restore-settings.sh --latest --dry-run
```

## Integration with Bootstrap

The macOS preferences are automatically configured during the main dotfiles installation:

```bash
# Full dotfiles installation (includes macOS preferences)
./install.sh

# Bootstrap with macOS setup
./scripts/bootstrap.sh install
```

The setup script (`scripts/setup/macos-defaults.sh`) is called automatically during bootstrap and:
- Checks for macOS compatibility (12.0+ required)
- Prompts for confirmation before making changes
- Sets up script permissions
- Runs the main configuration
- Provides completion information and next steps

## Customization

### Quick Overrides

Create personal preference overrides:

```bash
# Create override script
cat > personal-overrides.sh << 'EOF'
#!/usr/bin/env bash
# My personal preference overrides

# Keep menu bar visible (override auto-hide)
defaults write NSGlobalDomain _HIHideMenuBar -bool false

# Use larger Dock icons
defaults write com.apple.dock tilesize -int 48

# Enable auto-correct (if desired)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true
EOF

chmod +x personal-overrides.sh

# Apply main config then personal overrides
./defaults.sh && ./personal-overrides.sh
```

### Selective Categories

Apply only specific categories by modifying the `AVAILABLE_CATEGORIES` array in `defaults.sh`:

```bash
# Edit defaults.sh to comment out unwanted categories
AVAILABLE_CATEGORIES=(
    "dock"
    "finder"
    "input"
    # "security"      # Skip security settings
    "appearance"
    # "general"       # Skip general settings
)
```

### Environment Profiles

Create environment-specific configurations:

```bash
# Work profile (more security-focused)
cat > work-profile.sh << 'EOF'
#!/usr/bin/env bash
defaults write com.apple.screensaver idleTime -int 300  # 5 min timeout
defaults write com.apple.dock autohide -bool false      # Always show Dock
EOF

# Personal profile (more screen space)  
cat > personal-profile.sh << 'EOF'
#!/usr/bin/env bash
defaults write com.apple.screensaver idleTime -int 1200 # 20 min timeout
defaults write com.apple.dock autohide -bool true       # Auto-hide Dock
EOF

# Use environment variable to control profile
export MACOS_PROFILE="work"  # or "personal"
./defaults.sh && ./${MACOS_PROFILE}-profile.sh
```

## System Requirements

- **macOS 12.0 (Monterey) or later**
- **Administrator privileges** for some settings
- **No System Integrity Protection conflicts**

Some settings may require:
- Logout/restart to take full effect
- Killing affected applications (`killall Dock Finder SystemUIServer`)
- Manual configuration through System Preferences (documented in scripts)

## Files and Structure

```
os/macos/
├── README.md              # This file
├── defaults.sh            # Master configuration script
├── dock.sh               # Dock preferences
├── finder.sh             # Finder preferences  
├── input.sh              # Keyboard/trackpad/mouse settings
├── security.sh           # Security and privacy settings
├── appearance.sh         # Interface appearance settings
├── general.sh            # General system preferences
├── scripts/
│   ├── backup-settings.sh    # Create preference backups
│   └── restore-settings.sh   # Restore from backups
└── backup/               # Backup storage directory
    ├── latest -> backup_YYYYMMDD_HHMMSS  # Symlink to latest
    └── backup_YYYYMMDD_HHMMSS/           # Timestamped backups
        ├── backup-info.txt               # Backup metadata
        ├── restore.sh                    # Auto-generated restore script
        └── *.plist                       # Preference domain backups
```

## Troubleshooting

### Settings Don't Apply

```bash
# Kill affected applications to force reload
killall Dock Finder SystemUIServer

# Check if setting was actually applied
defaults read com.apple.dock autohide

# Verify domain exists
defaults domains | grep -i dock
```

### Permission Issues

```bash
# Check preference file permissions
ls -la ~/Library/Preferences/com.apple.dock.plist

# Reset corrupted preferences
defaults delete com.apple.dock
killall Dock
```

### Restore Problems

```bash
# List backup contents
ls -la backup/latest/

# Test restore without applying
./scripts/restore-settings.sh --latest --dry-run

# Manual restore of specific domain
defaults import com.apple.dock backup/latest/com.apple.dock.plist
```

### Debugging

```bash
# View all settings for a domain
defaults read com.apple.dock

# Monitor preference changes
log stream --predicate 'subsystem=="com.apple.preferences"'

# Export current settings for comparison
defaults export com.apple.dock current-dock-settings.plist
```

## Documentation

For detailed information about each setting and customization options:

- **[macOS Settings Documentation](../../docs/macos-settings.md)** - Comprehensive documentation of all settings and their purposes
- **[macOS Customization Guide](../../docs/macos-customization.md)** - Guide for customizing and extending the configuration

## Safety and Best Practices

### Before Making Changes
1. **Create a backup**: `./scripts/backup-settings.sh`
2. **Test with dry-run**: `./defaults.sh --dry-run`
3. **Apply gradually**: Run individual category scripts first
4. **Have recovery plan**: Know how to restore from backup

### After Making Changes
1. **Verify settings**: Check that applications behave as expected
2. **Test restart**: Ensure settings persist across logout/restart
3. **Document customizations**: Keep track of personal overrides
4. **Update backups**: Create new backup after successful configuration

### Recovery Options
1. **Use restore script**: `./scripts/restore-settings.sh --latest`
2. **Manual System Preferences**: Change settings through GUI
3. **Reset specific domains**: `defaults delete com.apple.dock && killall Dock`
4. **Fresh install**: Reset macOS user preferences entirely

## Performance Notes

- **Fast execution**: Category scripts run in 1-5 seconds each
- **Minimal system impact**: Only changes specified preferences
- **Efficient backups**: Only backs up domains that actually exist
- **Quick restore**: Restore process takes 10-30 seconds

The configuration is designed to enhance rather than hinder system performance, with most changes focused on reducing animations and streamlining workflows.

## Support

For questions, issues, or contributions:

1. **Check documentation**: Review the detailed guides linked above
2. **Search existing issues**: Look for similar problems in the repository
3. **Create detailed issue**: Include system info, error messages, and steps to reproduce
4. **Test thoroughly**: Use dry-run mode and backups when troubleshooting

The macOS preferences system is designed to be safe, reversible, and thoroughly documented to support productive development workflows across different macOS versions and hardware configurations. 