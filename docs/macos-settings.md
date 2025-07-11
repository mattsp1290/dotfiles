# macOS System Preferences Configuration

This document provides comprehensive documentation for all macOS system preferences configured by the dotfiles automation. Each setting is explained with its purpose, rationale, and impact on development workflows.

## Overview

The macOS system preferences configuration optimizes the system for development workflows while maintaining security and usability. The configuration is modular, with separate scripts for different categories of settings.

### Configuration Categories

- **[Dock Settings](#dock-settings)** - Auto-hide, size, position, Mission Control integration
- **[Finder Settings](#finder-settings)** - Default views, sidebar, extensions, hidden files
- **[Input Settings](#input-settings)** - Keyboard repeat, trackpad gestures, mouse settings
- **[Security Settings](#security-settings)** - Screen lock, privacy, quarantine settings
- **[Appearance Settings](#appearance-settings)** - Dark mode, animations, menu bar
- **[General Settings](#general-settings)** - System-wide preferences and behaviors

## Dock Settings

*Script: `os/macos/dock.sh`*

### Auto-Hide Configuration
```bash
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0.1
defaults write com.apple.dock autohide-time-modifier -float 0.25
```

**Purpose**: Maximizes screen real estate for development while maintaining quick access to the Dock.

**Benefits**:
- More vertical space for code editors and terminal windows
- Reduces visual distractions during focused work
- Fast auto-hide animation (0.25s) maintains productivity

### Icon Size and Appearance
```bash
defaults write com.apple.dock tilesize -int 36
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock show-process-indicators -bool true
```

**Purpose**: Optimal balance between icon visibility and screen space efficiency.

**Rationale**:
- 36px icon size provides clear visibility without wasting space
- Disabled magnification reduces animations and distractions
- Process indicators help identify running applications quickly

### Window Management
```bash
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock launchanim -bool false
```

**Purpose**: Streamlined window management optimized for development workflows.

**Benefits**:
- Minimized windows go to app icon (cleaner Dock)
- Scale effect is less distracting than genie effect
- Disabled launch animations speed up app startup feel

### Mission Control Integration
```bash
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock expose-group-apps -bool false
```

**Purpose**: Predictable workspace organization for development projects.

**Benefits**:
- Spaces maintain manual organization (don't auto-rearrange)
- Applications aren't grouped in Mission Control (easier window identification)
- Better for multi-project development workflows

### Hot Corners
```bash
# Top-left: Mission Control
defaults write com.apple.dock wvous-tl-corner -int 2
# Top-right: Desktop
defaults write com.apple.dock wvous-tr-corner -int 4
# Bottom-left: Application Windows
defaults write com.apple.dock wvous-bl-corner -int 3
# Bottom-right: Launchpad
defaults write com.apple.dock wvous-br-corner -int 11
```

**Purpose**: Quick navigation shortcuts optimized for development workflows.

**Workflow Benefits**:
- **Top-left (Mission Control)**: Quick overview of all open windows and spaces
- **Top-right (Desktop)**: Instant access to desktop files and folders
- **Bottom-left (App Windows)**: Show all windows of current application
- **Bottom-right (Launchpad)**: Quick access to applications

## Finder Settings

*Script: `os/macos/finder.sh`*

### File Visibility
```bash
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
```

**Purpose**: Essential visibility for development work with various file types.

**Developer Benefits**:
- **All Extensions**: Critical for distinguishing file types (.js vs .jsx, .py vs .pyc)
- **Hidden Files**: Access to dotfiles, configuration files, and system files
- **Status Bar**: File count, selection size, and available space information
- **Path Bar**: Always know current directory location (crucial for CLI work)

### Search and Navigation
```bash
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder NewWindowTarget -string "PfHm"
```

**Purpose**: Efficient file navigation and search for development workflows.

**Benefits**:
- **Search Current Folder**: More relevant results when working in project directories
- **List View Default**: Better for viewing file details and timestamps
- **Home Directory Default**: Logical starting point for development work

### Performance Optimizations
```bash
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
defaults write com.apple.frameworks.diskimages skip-verify -bool true
```

**Purpose**: Improved performance and reduced clutter for development environments.

**Benefits**:
- **No .DS_Store on Network/USB**: Cleaner repositories and shared drives
- **Skip Disk Image Verification**: Faster mounting of development tools and images
- **Reduced File System Overhead**: Better performance with large codebases

### Developer-Friendly Warnings
```bash
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder WarnOnEmptyTrash -bool false
```

**Purpose**: Reduce interruptions during development workflows.

**Rationale**:
- Developers frequently work with different file extensions
- Extension change warnings become repetitive and slow down workflows
- Trash warnings are unnecessary for experienced users

## Input Settings

*Script: `os/macos/input.sh`*

### Keyboard Configuration
```bash
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 12
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
```

**Purpose**: Optimized keyboard responsiveness for coding and text editing.

**Developer Benefits**:
- **Ultra-fast Key Repeat**: Essential for efficient code navigation and editing
- **Short Initial Delay**: Quick response when holding keys (arrow keys, delete)
- **Disabled Press-and-Hold**: Favor key repeat over accent character menu

### Text Input Optimizations
```bash
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
```

**Purpose**: Prevent interference with code writing and technical documentation.

**Critical for Development**:
- **No Auto-Capitalization**: Prevents incorrect capitalization in code
- **No Smart Quotes**: Prevents "curly quotes" that break code syntax
- **No Smart Dashes**: Prevents em-dashes that break command-line arguments
- **No Auto-Correct**: Prevents changes to variable names and technical terms

### Function Keys
```bash
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
```

**Purpose**: Standard function key behavior for IDE shortcuts and debugging.

**Benefits**:
- F-keys work as standard function keys by default
- Essential for IDE debugging (F5, F8, F9, F10, F11)
- Consistent with external keyboards and development tools

### Trackpad Configuration
```bash
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
```

**Purpose**: Efficient trackpad interaction for development workflows.

**Productivity Features**:
- **Tap to Click**: Faster than physical click for frequent interactions
- **Two-Finger Right-Click**: Essential for context menus and IDE features
- **Three-Finger Drag**: Efficient window and text selection movement

### Gesture Configuration
```bash
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
defaults write com.apple.dock showAppExposeGestureEnabled -bool true
defaults write com.apple.dock showDesktopGestureEnabled -bool true
```

**Purpose**: Quick navigation between applications and workspaces.

**Workflow Benefits**:
- **Mission Control**: Overview of all windows and spaces
- **App Exposé**: Show all windows of current application
- **Show Desktop**: Quick access to desktop files and folders

## Security Settings

*Script: `os/macos/security.sh`*

### Screen Security
```bash
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
```

**Purpose**: Immediate security protection when stepping away from workstation.

**Security Benefits**:
- **Immediate Password Requirement**: No delay when screen saver activates
- **Essential for Development**: Protects source code, credentials, and client data
- **Compliance**: Meets most corporate security requirements

### Screenshot Configuration
```bash
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
```

**Purpose**: Optimized screenshot settings for documentation and bug reports.

**Developer Benefits**:
- **PNG Format**: Better compression and quality for code screenshots
- **No Shadows**: Cleaner images for documentation and presentations
- **Desktop Location**: Easy access and organization of screenshots

### Privacy Settings
```bash
defaults write com.apple.spotlight LookupEnabled -bool false
defaults write com.apple.spotlight WebSearchEnabled -bool false
```

**Purpose**: Enhanced privacy and reduced data transmission.

**Privacy Benefits**:
- **No Spotlight Suggestions**: Prevents sending search queries to Apple
- **No Web Search**: Keeps local searches private
- **Reduced Network Traffic**: Better for metered or slow connections

### Safari Security
```bash
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
```

**Purpose**: Prevent automatic execution of downloaded files.

**Security Rationale**:
- **No Auto-Open**: Prevents potential malware execution
- **Developer Safety**: Important when downloading development tools and packages
- **Manual Control**: User decides when to open downloaded files

## Appearance Settings

*Script: `os/macos/appearance.sh`*

### Dark Mode Configuration
```bash
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write NSGlobalDomain AppleAccentColor -int 4
```

**Purpose**: Reduced eye strain and professional appearance for development work.

**Developer Benefits**:
- **Dark Mode**: Easier on eyes during long coding sessions
- **Blue Accent**: Professional appearance and good contrast
- **Consistency**: Matches most development tools and IDEs

### Animation and Performance
```bash
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write com.apple.dock expose-animation-duration -float 0.1
```

**Purpose**: Faster interface response and reduced distractions.

**Performance Benefits**:
- **No Window Animations**: Faster window operations
- **Fast Resize**: Nearly instant window resizing
- **Quick Mission Control**: Minimal animation delay

### Menu Bar and Interface
```bash
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"
defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
defaults write NSGlobalDomain AppleICUForce24HourTime -bool true
```

**Purpose**: Consistent interface behavior and precise control.

**Usability Benefits**:
- **Always Show Scrollbars**: Visual feedback for document position
- **Click-to-Position Scrolling**: Precise navigation in long documents
- **24-Hour Time**: International standard, better for logging and timestamps

### Dialog Improvements
```bash
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
```

**Purpose**: Expanded dialogs show more options and context.

**Efficiency Benefits**:
- **Expanded Save Dialogs**: Faster navigation to specific directories
- **Expanded Print Dialogs**: More control over printing options
- **Reduced Clicks**: Fewer dialog expansions needed

## General Settings

*Script: `os/macos/general.sh`*

### Document Handling
```bash
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false
```

**Purpose**: Local-first document storage and predictable application behavior.

**Developer Benefits**:
- **Local Saves**: Documents save to local disk by default (faster, more reliable)
- **No Resume**: Applications start with clean state
- **Predictable Behavior**: Consistent across development tools

### Crash Reporting
```bash
defaults write com.apple.CrashReporter DialogType -string "notification"
```

**Purpose**: Non-disruptive crash reporting during development.

**Benefits**:
- **Notification Mode**: Less intrusive than dialog boxes
- **Continues Workflow**: Doesn't interrupt development with modal dialogs
- **Still Captures Information**: Maintains crash reporting for debugging

### Development Tools
```bash
defaults write com.apple.appstore WebKitDeveloperExtras -bool true
defaults write com.apple.appstore ShowDebugMenu -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
```

**Purpose**: Enhanced development capabilities and up-to-date system.

**Developer Benefits**:
- **App Store Developer Tools**: Useful for web development and debugging
- **Debug Menu**: Additional troubleshooting options
- **Daily Update Checks**: Keeps system secure and current

## Usage and Customization

### Applying Settings

Apply all settings:
```bash
./os/macos/defaults.sh
```

Apply specific categories:
```bash
./os/macos/defaults.sh dock finder input
```

Dry run to see what would change:
```bash
./os/macos/defaults.sh --dry-run
```

### Backup and Restore

Create backup before applying:
```bash
./os/macos/scripts/backup-settings.sh
```

Restore from backup:
```bash
./os/macos/scripts/restore-settings.sh --latest
```

### Individual Scripts

Each category can be run independently:
```bash
./os/macos/dock.sh --verbose
./os/macos/finder.sh --dry-run
./os/macos/input.sh
./os/macos/security.sh
./os/macos/appearance.sh
./os/macos/general.sh
```

## Important Notes

### System Requirements
- macOS 12.0 (Monterey) or later
- Administrator privileges for some settings
- No System Integrity Protection conflicts

### Restart Requirements
Some settings require restart or logout to take full effect:
- Input device settings (trackpad, keyboard)
- Some appearance settings
- Security settings

### Backup Recommendations
Always create a backup before applying system-wide changes:
1. Use the built-in backup script
2. Test with `--dry-run` first
3. Apply settings gradually if concerned

### Reverting Changes
To revert to original settings:
1. Use the restore script with a backup
2. Manually change settings in System Preferences
3. Reset specific domains: `defaults delete com.apple.dock`

## Troubleshooting

### Common Issues

**Settings don't take effect:**
- Try killing affected applications: `killall Dock Finder SystemUIServer`
- Restart the computer for system-level changes
- Check for permission issues with `ls -la` on preference files

**Backup fails:**
- Ensure sufficient disk space
- Check permissions on backup directory
- Some domains may not exist on all systems (normal)

**Restore doesn't work:**
- Verify backup integrity with `--dry-run`
- Check that backup contains expected .plist files
- Try restoring individual domains manually

### Manual Override

To override specific settings, edit the configuration scripts or use:
```bash
# Override after running configuration
defaults write com.apple.dock autohide -bool false
killall Dock
```

### Getting Help

- View current settings: `defaults read com.apple.dock`
- List all domains: `defaults domains | tr ',' '\n' | sort`
- Check system logs: `log show --predicate 'subsystem=="com.apple.preferences"' --last 1h`

For additional customization guidance, see [macOS Customization Guide](macos-customization.md). 