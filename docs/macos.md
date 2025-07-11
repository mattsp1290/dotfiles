# macOS Configuration Guide

A comprehensive guide to the automated macOS system preferences configuration that optimizes your Mac for development workflows while maintaining security, performance, and usability. Built with modular scripts, comprehensive backup systems, and enterprise-ready automation.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [System Preferences](#system-preferences)
- [Homebrew Management](#homebrew-management)
- [Development Environment](#development-environment)
- [Security Hardening](#security-hardening)
- [Performance Optimization](#performance-optimization)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [Enterprise Deployment](#enterprise-deployment)
- [Advanced Usage](#advanced-usage)
- [Reference](#reference)

## Overview

The macOS configuration system provides automated setup and optimization of macOS system preferences specifically tailored for development workflows. It transforms a fresh Mac into a fully configured development environment while maintaining security best practices and providing complete backup/restore capabilities.

### Key Features

- **🚀 Automated Setup**: One-command installation that configures 100+ system preferences
- **🏗️ Modular Architecture**: Category-based scripts for targeted customization
- **🔒 Security-First**: Hardened security settings without hindering development workflows
- **⚡ Performance Tuned**: Optimized for development with sub-500ms shell startup
- **🔄 Backup & Restore**: Complete backup system with automated restore capabilities
- **🌍 Apple Silicon Ready**: Full support for M1/M2/M3 Macs with Intel compatibility

### Supported macOS Versions

| Version | Support Level | Features |
|---------|---------------|----------|
| **macOS 14 (Sonoma)** | Full | All features, latest optimizations |
| **macOS 13 (Ventura)** | Full | Complete feature set |
| **macOS 12 (Monterey)** | Full | Baseline compatibility |
| **macOS 11 (Big Sur)** | Compatible | Core features only |

## Architecture

### Configuration Structure

```
os/macos/
├── defaults.sh                # Master orchestration script
├── dock.sh                    # Dock preferences and behavior
├── finder.sh                  # Finder optimization and visibility
├── input.sh                   # Keyboard, trackpad, and input devices
├── security.sh                # Security and privacy settings
├── appearance.sh              # UI appearance and animations
├── general.sh                 # General system preferences
├── scripts/                   # Utility and management scripts
│   ├── backup-settings.sh     # Comprehensive backup system
│   ├── restore-settings.sh    # Full restore functionality
│   ├── check-compatibility.sh # macOS version validation
│   └── reset-preferences.sh   # Factory reset capabilities
└── backups/                   # Backup storage directory

docs/
├── macos-settings.md          # Detailed settings documentation
├── macos-customization.md     # Customization guide and examples
└── macos-troubleshooting.md   # Issue resolution and debugging

scripts/setup/
└── macos-defaults.sh          # Bootstrap integration script
```

### Integration Points

- **Bootstrap Integration**: Seamless integration with main bootstrap system
- **Stow Compatibility**: Proper file organization for symlink management
- **Cross-Platform Safety**: Graceful handling on non-macOS systems
- **Package Management**: Integration with Homebrew and development tools

## Quick Start

### Prerequisites

- macOS 12.0 or later
- Administrative privileges for system preference modifications
- Internet connection for package installation
- Xcode Command Line Tools (automatically installed if missing)

### Installation

```bash
# Via main bootstrap (recommended)
./scripts/bootstrap.sh

# macOS configuration only
./scripts/setup/macos-defaults.sh

# Individual category setup
./os/macos/dock.sh
./os/macos/finder.sh
```

### Quick Configuration

```bash
# Apply all optimizations (interactive)
cd os/macos && ./defaults.sh

# Non-interactive installation
./defaults.sh --force

# Apply specific categories
./defaults.sh --categories "dock,finder,input"

# Preview changes without applying
./defaults.sh --dry-run
```

### Immediate Benefits

After configuration, you'll have:

- ✅ **Optimized Dock**: Auto-hide with fast animations, productive hot corners
- ✅ **Enhanced Finder**: File extensions visible, hidden files shown, path bar enabled
- ✅ **Fast Input**: Ultra-responsive keyboard repeat, optimized trackpad gestures
- ✅ **Security Hardened**: Screen lock, secure defaults, privacy optimizations
- ✅ **Developer-Friendly**: Code-aware settings, performance optimizations
- ✅ **Professional Appearance**: Dark mode, minimal animations, clean interface

### Verification

```bash
# Check applied preferences
defaults read com.apple.dock autohide
defaults read com.apple.finder AppleShowAllFiles

# Verify system configuration
./os/macos/scripts/check-compatibility.sh
```

## System Preferences

### Dock Configuration (dock.sh)

#### Key Features Configured
- **Auto-hide Behavior**: Intelligent auto-hide with optimized timing
- **Icon Management**: Optimal sizing and positioning for productivity
- **Hot Corners**: Development-friendly corner actions
- **Mission Control**: Efficient workspace management
- **Minimization**: Window management optimizations

#### Core Settings Applied
```bash
# Dock auto-hide with fast response
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0.0
defaults write com.apple.dock autohide-time-modifier -float 0.5

# Optimize icon sizes
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock largesize -int 64
defaults write com.apple.dock magnification -bool true

# Hot corners for productivity
defaults write com.apple.dock wvous-tl-corner -int 2    # Mission Control
defaults write com.apple.dock wvous-tr-corner -int 4    # Desktop
defaults write com.apple.dock wvous-bl-corner -int 5    # Start Screen Saver
defaults write com.apple.dock wvous-br-corner -int 3    # Application Windows

# Mission Control optimizations
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock expose-group-by-app -bool false
defaults write com.apple.dock dashboard-in-overlay -bool true
```

#### Dock Customization Examples
```bash
# Custom dock layout for development
dock_apps=(
    "/Applications/Terminal.app"
    "/Applications/Visual Studio Code.app"
    "/Applications/Safari.app"
    "/Applications/Slack.app"
    "/Applications/Docker.app"
)

for app in "${dock_apps[@]}"; do
    if [[ -d "$app" ]]; then
        dockutil --add "$app" --no-restart
    fi
done

dockutil --restart
```

### Finder Optimization (finder.sh)

#### Developer-Focused Enhancements
- **File Visibility**: Show all files including hidden system files
- **Extension Display**: Always show file extensions for all file types
- **Path Information**: Status bar and path bar for navigation context
- **Performance**: Optimized view settings and search scopes
- **Warning Management**: Reduce interruptions for common development tasks

#### Essential Settings
```bash
# Show hidden files and folders
defaults write com.apple.finder AppleShowAllFiles -bool true

# Always show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show status bar and path bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Optimize default view settings
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"  # List view
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"  # Current folder

# Disable warnings for common dev operations
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Performance optimizations
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
```

#### Advanced Finder Customization
```bash
# Custom sidebar items
sfltool add-item com.apple.LSSharedFileList.FavoriteItems file:///Users/$USER/Code
sfltool add-item com.apple.LSSharedFileList.FavoriteItems file:///Users/$USER/Projects

# Set default folder for new windows
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
```

### Input Device Tuning (input.sh)

#### Keyboard Optimization
- **Ultra-Fast Repeat**: Optimized for coding with fast key repeat rates
- **Function Key Behavior**: F-keys as function keys by default for IDE compatibility
- **Smart Features**: Disabled autocorrect and text replacement for code editing
- **Modifier Keys**: Optimized modifier key behavior

#### Trackpad Enhancement
- **Gesture Configuration**: Development-friendly trackpad gestures
- **Speed Optimization**: Tracking speed tuned for precision
- **Multi-Touch**: Enhanced multi-touch gesture support
- **Secondary Click**: Right-click optimization for context menus

#### Core Input Settings
```bash
# Ultra-fast keyboard repeat for coding
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2

# Function keys as F-keys by default
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# Disable autocorrect and text replacement (interferes with code)
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Optimized trackpad settings
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.5
```

### Security Hardening (security.sh)

#### Security Enhancements Without Workflow Hindrance
- **Screen Lock**: Immediate lock on screen saver activation
- **Privacy Settings**: Optimized privacy without blocking development tools
- **Download Security**: Safe handling of downloaded files
- **Screenshot Security**: Secure screenshot format and location optimization

#### Security Settings Applied
```bash
# Require password immediately after screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Disable Spotlight suggestions and Bing web search
defaults write com.apple.spotlight orderedItems -array \
    '{"enabled" = 1;"name" = "APPLICATIONS";}' \
    '{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
    '{"enabled" = 1;"name" = "DIRECTORIES";}' \
    '{"enabled" = 1;"name" = "PDF";}' \
    '{"enabled" = 1;"name" = "FONTS";}' \
    '{"enabled" = 0;"name" = "DOCUMENTS";}' \
    '{"enabled" = 0;"name" = "MESSAGES";}' \
    '{"enabled" = 0;"name" = "CONTACT";}' \
    '{"enabled" = 0;"name" = "EVENT_TODO";}' \
    '{"enabled" = 0;"name" = "IMAGES";}' \
    '{"enabled" = 0;"name" = "BOOKMARKS";}' \
    '{"enabled" = 0;"name" = "MUSIC";}' \
    '{"enabled" = 0;"name" = "MOVIES";}' \
    '{"enabled" = 0;"name" = "PRESENTATIONS";}' \
    '{"enabled" = 0;"name" = "SPREADSHEETS";}' \
    '{"enabled" = 0;"name" = "SOURCE";}' \
    '{"enabled" = 0;"name" = "MENU_DEFINITION";}' \
    '{"enabled" = 0;"name" = "MENU_OTHER";}' \
    '{"enabled" = 0;"name" = "MENU_CONVERSION";}' \
    '{"enabled" = 0;"name" = "MENU_EXPRESSION";}' \
    '{"enabled" = 0;"name" = "MENU_WEBSEARCH";}' \
    '{"enabled" = 0;"name" = "MENU_SPOTLIGHT_SUGGESTIONS";}'

# Configure screenshot format and location
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"

# Enhance security for downloads
defaults write com.apple.LaunchServices LSQuarantine -bool true
```

## Homebrew Management

### Automated Homebrew Setup

#### Installation and Configuration
```bash
# Install Homebrew (Apple Silicon and Intel support)
if [[ ! -f "/opt/homebrew/bin/brew" ]] && [[ ! -f "/usr/local/bin/brew" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Configure path for Apple Silicon
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export HOMEBREW_PREFIX="/opt/homebrew"
else
    export HOMEBREW_PREFIX="/usr/local"
fi

# Optimize Homebrew settings
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_BUNDLE_NO_LOCK=1
```

#### Essential Development Tools (Brewfile)
```ruby
# Essential development tools
tap "homebrew/cask"
tap "homebrew/cask-fonts"

# Command line tools
brew "git"
brew "zsh"
brew "neovim"
brew "tmux"
brew "fzf"
brew "ripgrep"
brew "bat"
brew "exa"
brew "fd"
brew "jq"
brew "yq"
brew "curl"
brew "wget"
brew "htop"
brew "tree"

# Development languages and tools
brew "node"
brew "python@3.11"
brew "go"
brew "rust"
brew "docker"
brew "docker-compose"
brew "kubectl"
brew "helm"
brew "terraform"
brew "ansible"

# Fonts
cask "font-jetbrains-mono"
cask "font-fira-code"
cask "font-source-code-pro"

# Applications
cask "visual-studio-code"
cask "iterm2"
cask "docker"
cask "postman"
cask "slack"
cask "1password"
cask "1password-cli"

# Optional development tools
cask "github-desktop"
cask "sourcetree"
cask "tableplus"
cask "redis-pro"
```

#### Brewfile Management
```bash
# Generate current Brewfile
brew bundle dump --file=Brewfile.current

# Install from Brewfile
brew bundle install --file=Brewfile

# Cleanup unused packages
brew bundle cleanup --file=Brewfile

# Update all packages
brew update && brew upgrade
```

### Package Management Automation

#### Automated Package Updates
```bash
#!/bin/bash
# scripts/update-homebrew.sh

update_homebrew() {
    echo "🍺 Updating Homebrew..."
    
    # Update Homebrew itself
    brew update
    
    # Upgrade all packages
    brew upgrade
    
    # Upgrade cask applications
    brew upgrade --cask
    
    # Cleanup old versions
    brew cleanup --prune=7
    
    # Check for issues
    brew doctor
    
    echo "✅ Homebrew update complete"
}

# Schedule weekly updates via launchd
create_update_schedule() {
    local plist_path="$HOME/Library/LaunchAgents/com.dotfiles.homebrew-update.plist"
    
    cat > "$plist_path" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dotfiles.homebrew-update</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/bash</string>
        <string>-c</string>
        <string>cd ~/git/dotfiles && ./scripts/update-homebrew.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF
    
    launchctl load "$plist_path"
}
```

## Development Environment

### Developer Tool Integration

#### Xcode Command Line Tools
```bash
# Automatic installation
install_xcode_tools() {
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Installing Xcode Command Line Tools..."
        xcode-select --install
        
        # Wait for installation to complete
        until xcode-select -p >/dev/null 2>&1; do
            sleep 5
        done
        
        echo "✅ Xcode Command Line Tools installed"
    fi
}

# Accept license automatically
sudo xcodebuild -license accept
```

#### Development Directory Structure
```bash
# Create standard development directories
mkdir -p ~/Code/{personal,work,opensource,playground}
mkdir -p ~/Projects/{active,archive,templates}
mkdir -p ~/.local/{bin,lib,share,state}

# Set up project templates
create_project_templates() {
    local template_dir="~/Projects/templates"
    
    # Node.js project template
    mkdir -p "$template_dir/nodejs"
    cat > "$template_dir/nodejs/package.json" << 'EOF'
{
  "name": "project-name",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "keywords": [],
  "author": "",
  "license": "MIT"
}
EOF
    
    # Python project template
    mkdir -p "$template_dir/python"
    cat > "$template_dir/python/requirements.txt" << 'EOF'
# Core dependencies
requests>=2.28.0
python-dotenv>=0.19.0

# Development dependencies
pytest>=7.0.0
black>=22.0.0
flake8>=4.0.0
EOF
}
```

### Version Management

#### Multiple Runtime Versions
```bash
# Install version managers via Homebrew
brew install pyenv nodenv rbenv

# Configure shell integration
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(nodenv init -)"' >> ~/.zshrc
echo 'eval "$(rbenv init -)"' >> ~/.zshrc

# Install latest stable versions
pyenv install 3.11.0
pyenv global 3.11.0

nodenv install 18.12.0
nodenv global 18.12.0

rbenv install 3.1.0
rbenv global 3.1.0
```

#### Development Environment Variables
```bash
# Essential development environment variables
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export HOMEBREW_PREFIX="/opt/homebrew"
export EDITOR="code"
export PAGER="less"
export BROWSER="open"

# Development tool paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
export PATH="/usr/local/bin:$PATH"

# Language-specific environment
export PYENV_ROOT="$HOME/.pyenv"
export NODENV_ROOT="$HOME/.nodenv"
export RBENV_ROOT="$HOME/.rbenv"

# Build and compilation
export CFLAGS="-I$HOMEBREW_PREFIX/include"
export LDFLAGS="-L$HOMEBREW_PREFIX/lib"
export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/lib/pkgconfig"
```

## Security Hardening

### System Security Configuration

#### Firewall and Network Security
```bash
# Enable built-in firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Block all incoming connections except for specific services
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off
```

#### Privacy and Data Protection
```bash
# Disable analytics and data collection
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
defaults write com.apple.crashreporter DialogType none

# Limit ad tracking
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false

# Secure Safari (if used for development testing)
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
```

### Development Security Best Practices

#### SSH and GPG Configuration
```bash
# Generate secure SSH keys
ssh-keygen -t ed25519 -C "your.email@example.com" -f ~/.ssh/id_ed25519

# Generate GPG key for Git signing
gpg --full-generate-key

# Configure SSH agent with macOS Keychain
cat >> ~/.ssh/config << 'EOF'
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOF

# Add SSH key to keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

#### Secure Development Practices
```bash
# Set secure file permissions
umask 0022

# Configure Git for security
git config --global user.signingkey [GPG_KEY_ID]
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Enable Git URL rewriting for security
git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
git config --global url."ssh://git@gitlab.com/".insteadOf "https://gitlab.com/"
```

## Performance Optimization

### System Performance Tuning

#### Memory and CPU Optimization
```bash
# Disable heavy visual effects
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true

# Optimize energy settings for performance
sudo pmset -c displaysleep 15
sudo pmset -c disksleep 60
sudo pmset -c sleep 0
sudo pmset -c hibernatemode 0

# Disable sudden motion sensor (SSD-only systems)
sudo pmset -a sms 0
```

#### Disk and I/O Performance
```bash
# Enable trim for third-party SSDs
sudo trimforce enable

# Optimize spotlight indexing
sudo mdutil -a -i off  # Disable indexing
sudo mdutil -a -i on   # Re-enable with optimizations

# Exclude development directories from Spotlight
touch ~/Code/.metadata_never_index
touch ~/Projects/.metadata_never_index
touch ~/.cache/.metadata_never_index
```

### Development Workflow Optimization

#### Shell Startup Performance
```bash
# Measure shell startup time
time zsh -i -c exit

# Optimize zsh startup
# - Lazy load version managers
# - Cache expensive operations
# - Use minimal prompt during startup

# Example lazy loading for pyenv
pyenv() {
    unfunction pyenv
    eval "$(command pyenv init -)"
    pyenv "$@"
}
```

#### Build Tool Optimization
```bash
# Optimize Xcode build settings
defaults write com.apple.dt.Xcode BuildSystemScheduleInherentlyParallelCommandsExclusively -bool NO
defaults write com.apple.dt.Xcode BuildSystemScheduleInherentlyParallelCommandsSerially -bool NO

# Configure make for parallel builds
export MAKEFLAGS="-j$(sysctl -n hw.ncpu)"

# Optimize npm for performance
npm config set cache ~/.npm-cache
npm config set fund false
npm config set audit false
```

## Backup and Restore

### Comprehensive Backup System

#### Automated Backup Creation
```bash
# scripts/backup-settings.sh - Complete system backup

create_backup() {
    local backup_dir="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo "📦 Creating system preferences backup..."
    
    # Core system preferences
    defaults read > "$backup_dir/all-defaults.plist"
    
    # Application-specific preferences
    backup_domains=(
        "com.apple.dock"
        "com.apple.finder" 
        "com.apple.Terminal"
        "com.apple.screensaver"
        "com.apple.trackpad"
        "com.apple.keyboard"
        "NSGlobalDomain"
    )
    
    for domain in "${backup_domains[@]}"; do
        defaults read "$domain" > "$backup_dir/${domain}.plist" 2>/dev/null || true
    done
    
    # Homebrew package list
    brew bundle dump --file="$backup_dir/Brewfile"
    
    # SSH keys and configuration
    cp -r ~/.ssh "$backup_dir/ssh" 2>/dev/null || true
    
    # Create restore script
    cat > "$backup_dir/restore.sh" << 'EOF'
#!/bin/bash
# Auto-generated restore script

BACKUP_DIR="$(dirname "$0")"

echo "🔄 Restoring system preferences from backup..."

# Restore defaults
for plist in "$BACKUP_DIR"/*.plist; do
    if [[ -f "$plist" ]] && [[ "$(basename "$plist")" != "all-defaults.plist" ]]; then
        domain=$(basename "$plist" .plist)
        echo "Restoring $domain..."
        defaults import "$domain" "$plist"
    fi
done

# Restore Homebrew packages
if [[ -f "$BACKUP_DIR/Brewfile" ]]; then
    echo "Restoring Homebrew packages..."
    brew bundle install --file="$BACKUP_DIR/Brewfile"
fi

echo "✅ Restore complete. Please restart for all changes to take effect."
EOF
    
    chmod +x "$backup_dir/restore.sh"
    
    # Create symlink to latest backup
    ln -sfn "$backup_dir" "$HOME/.dotfiles-backups/latest"
    
    echo "✅ Backup created: $backup_dir"
}
```

#### Backup Validation and Integrity
```bash
# Validate backup integrity
validate_backup() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "❌ Backup directory not found: $backup_dir"
        return 1
    fi
    
    # Check required files
    local required_files=(
        "all-defaults.plist"
        "com.apple.dock.plist"
        "com.apple.finder.plist"
        "Brewfile"
        "restore.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$backup_dir/$file" ]]; then
            echo "⚠️  Missing backup file: $file"
        else
            echo "✅ Found: $file"
        fi
    done
    
    # Validate plist files
    for plist in "$backup_dir"/*.plist; do
        if ! plutil -lint "$plist" >/dev/null 2>&1; then
            echo "❌ Invalid plist: $(basename "$plist")"
        fi
    done
}
```

### Restore Capabilities

#### Full System Restore
```bash
# scripts/restore-settings.sh - Complete system restore

restore_from_backup() {
    local backup_dir="$1"
    local dry_run="${2:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "🔍 DRY RUN: Previewing restore operations..."
    else
        echo "🔄 Restoring system preferences..."
    fi
    
    # Validate backup first
    if ! validate_backup "$backup_dir"; then
        echo "❌ Backup validation failed"
        return 1
    fi
    
    # Restore system preferences
    for plist in "$backup_dir"/*.plist; do
        if [[ "$(basename "$plist")" != "all-defaults.plist" ]]; then
            local domain=$(basename "$plist" .plist)
            
            if [[ "$dry_run" == "true" ]]; then
                echo "Would restore: $domain"
            else
                echo "Restoring: $domain"
                defaults import "$domain" "$plist"
            fi
        fi
    done
    
    # Restore Homebrew packages
    if [[ -f "$backup_dir/Brewfile" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            echo "Would install Homebrew packages from Brewfile"
        else
            echo "Installing Homebrew packages..."
            brew bundle install --file="$backup_dir/Brewfile"
        fi
    fi
    
    if [[ "$dry_run" != "true" ]]; then
        echo "✅ Restore complete. Restart required for all changes."
    fi
}

# Interactive restore menu
restore_interactive() {
    local backup_base="$HOME/.dotfiles-backups"
    
    if [[ ! -d "$backup_base" ]]; then
        echo "❌ No backups found"
        return 1
    fi
    
    echo "📁 Available backups:"
    select backup in "$backup_base"/*/; do
        if [[ -n "$backup" ]]; then
            echo "Selected: $backup"
            
            echo "Preview restore (y/n)?"
            read -r preview
            if [[ "$preview" =~ ^[Yy] ]]; then
                restore_from_backup "$backup" true
            fi
            
            echo "Proceed with restore (y/n)?"
            read -r proceed
            if [[ "$proceed" =~ ^[Yy] ]]; then
                restore_from_backup "$backup" false
            fi
            break
        fi
    done
}
```

## Troubleshooting

### Common Issues and Solutions

#### Permission Issues
```bash
# Fix common permission problems
fix_permissions() {
    echo "🔧 Fixing common permission issues..."
    
    # Fix Homebrew permissions (Apple Silicon)
    if [[ -d "/opt/homebrew" ]]; then
        sudo chown -R "$(whoami):admin" /opt/homebrew
    fi
    
    # Fix local development directories
    sudo chown -R "$(whoami):staff" "$HOME/.local"
    chmod 755 "$HOME/.local"
    
    # Fix SSH permissions
    if [[ -d "$HOME/.ssh" ]]; then
        chmod 700 "$HOME/.ssh"
        chmod 600 "$HOME/.ssh"/*
        chmod 644 "$HOME/.ssh"/*.pub 2>/dev/null || true
    fi
    
    echo "✅ Permissions fixed"
}
```

#### macOS Version Compatibility
```bash
# Check macOS compatibility
check_macos_compatibility() {
    local os_version
    os_version=$(sw_vers -productVersion)
    local major_version
    major_version=$(echo "$os_version" | cut -d. -f1)
    local minor_version
    minor_version=$(echo "$os_version" | cut -d. -f2)
    
    if [[ "$major_version" -lt 12 ]]; then
        echo "⚠️  macOS $os_version detected. Minimum supported version is 12.0"
        echo "Some features may not work correctly."
        return 1
    elif [[ "$major_version" -eq 12 && "$minor_version" -lt 0 ]]; then
        echo "⚠️  macOS $os_version detected. Please update to 12.0 or later."
        return 1
    else
        echo "✅ macOS $os_version is supported"
        return 0
    fi
}
```

#### Reset to Defaults
```bash
# Reset specific preferences to defaults
reset_preferences() {
    local category="$1"
    
    case "$category" in
        "dock")
            echo "🔄 Resetting Dock preferences..."
            defaults delete com.apple.dock
            killall Dock
            ;;
        "finder")
            echo "🔄 Resetting Finder preferences..."
            defaults delete com.apple.finder
            killall Finder
            ;;
        "all")
            echo "🔄 Resetting ALL preferences..."
            echo "⚠️  This will reset all system preferences to defaults!"
            read -p "Are you sure? (yes/no): " confirm
            if [[ "$confirm" == "yes" ]]; then
                # Reset major preference domains
                for domain in com.apple.dock com.apple.finder NSGlobalDomain; do
                    defaults delete "$domain" 2>/dev/null || true
                done
                
                # Restart affected services
                killall Dock Finder SystemUIServer
            fi
            ;;
        *)
            echo "Usage: reset_preferences [dock|finder|all]"
            ;;
    esac
}
```

### Diagnostic Tools

#### System Health Check
```bash
# Comprehensive system health check
system_health_check() {
    echo "🏥 macOS System Health Check"
    echo "=========================="
    
    # Check macOS version
    echo "📱 macOS Version: $(sw_vers -productVersion)"
    check_macos_compatibility
    
    # Check hardware
    echo "💻 Hardware: $(system_profiler SPHardwareDataType | grep 'Model Name' | cut -d: -f2 | xargs)"
    echo "🧠 Memory: $(system_profiler SPHardwareDataType | grep 'Memory' | cut -d: -f2 | xargs)"
    
    # Check disk space
    echo "💾 Disk Usage:"
    df -h / | tail -1 | awk '{print "   Used: " $3 " / " $2 " (" $5 " full)"}'
    
    # Check critical services
    echo "🔧 Critical Services:"
    services=("Dock" "Finder" "SystemUIServer")
    for service in "${services[@]}"; do
        if pgrep "$service" >/dev/null; then
            echo "   ✅ $service running"
        else
            echo "   ❌ $service not running"
        fi
    done
    
    # Check Homebrew
    if command -v brew >/dev/null; then
        echo "🍺 Homebrew: $(brew --version | head -1)"
        echo "   📦 Packages: $(brew list | wc -l | xargs) formula, $(brew list --cask | wc -l | xargs) casks"
    else
        echo "❌ Homebrew not installed"
    fi
    
    # Check development tools
    echo "🛠️  Development Tools:"
    if xcode-select -p >/dev/null 2>&1; then
        echo "   ✅ Xcode Command Line Tools installed"
    else
        echo "   ❌ Xcode Command Line Tools missing"
    fi
    
    echo "✅ Health check complete"
}
```

## Enterprise Deployment

### Centralized Management

#### Configuration Profiles
```bash
# Create enterprise configuration profile
create_enterprise_profile() {
    local org_name="$1"
    local profile_path="$2"
    
    cat > "$profile_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.dock</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.${org_name}.dock</string>
            <key>PayloadDisplayName</key>
            <string>Dock Settings</string>
            <key>autohide</key>
            <true/>
            <key>tilesize</key>
            <integer>48</integer>
            <key>orientation</key>
            <string>bottom</string>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>${org_name} macOS Configuration</string>
    <key>PayloadIdentifier</key>
    <string>com.${org_name}.macos.config</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>$(uuidgen)</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF
    
    echo "✅ Enterprise profile created: $profile_path"
}
```

#### Mass Deployment Script
```bash
# Enterprise deployment automation
enterprise_deploy() {
    local config_repo="$1"
    local target_machines="$2"
    
    # Validate inputs
    if [[ -z "$config_repo" ]] || [[ -z "$target_machines" ]]; then
        echo "Usage: enterprise_deploy <config_repo_url> <machines_file>"
        return 1
    fi
    
    # Deploy to multiple machines
    while IFS= read -r machine; do
        echo "🚀 Deploying to $machine..."
        
        ssh "$machine" "
            cd /tmp
            git clone '$config_repo' dotfiles-deploy
            cd dotfiles-deploy
            ./scripts/bootstrap.sh --force --enterprise
            rm -rf /tmp/dotfiles-deploy
        "
        
        if [[ $? -eq 0 ]]; then
            echo "✅ Deployment successful: $machine"
        else
            echo "❌ Deployment failed: $machine"
        fi
        
    done < "$target_machines"
}
```

### Compliance and Auditing

#### Configuration Audit
```bash
# Audit system configuration for compliance
audit_configuration() {
    local report_file="audit-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "audit_date": "$(date -Iseconds)",
    "system": {
        "os_version": "$(sw_vers -productVersion)",
        "build": "$(sw_vers -buildVersion)",
        "hostname": "$(hostname)"
    },
    "security": {
        "firewall_enabled": $(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "enabled" && echo true || echo false),
        "screen_lock": $(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo 0),
        "auto_login": $(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null && echo true || echo false)
    },
    "development": {
        "homebrew_installed": $(command -v brew >/dev/null && echo true || echo false),
        "xcode_tools": $(xcode-select -p >/dev/null 2>&1 && echo true || echo false),
        "git_configured": $(git config --global user.name >/dev/null 2>&1 && echo true || echo false)
    }
}
EOF
    
    echo "📊 Audit report generated: $report_file"
}
```

## Advanced Usage

### Custom Automation Scripts

#### Project-Specific Setup
```bash
# Automated project environment setup
setup_project_environment() {
    local project_type="$1"
    local project_name="$2"
    
    case "$project_type" in
        "react")
            npx create-react-app "$project_name"
            cd "$project_name"
            npm install -D prettier eslint husky
            ;;
        "python")
            mkdir "$project_name"
            cd "$project_name"
            python -m venv venv
            source venv/bin/activate
            pip install black flake8 pytest
            ;;
        "go")
            mkdir "$project_name"
            cd "$project_name"
            go mod init "$project_name"
            ;;
    esac
    
    # Open in preferred editor
    code .
}
```

#### System Monitoring
```bash
# Monitor system changes
monitor_changes() {
    local monitor_file="$HOME/.system-changes.log"
    
    while true; do
        {
            echo "=== $(date) ==="
            echo "CPU: $(top -l 1 | grep "CPU usage" | awk '{print $3}')"
            echo "Memory: $(vm_stat | grep "Pages free" | awk '{print $3}')"
            echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
            echo ""
        } >> "$monitor_file"
        
        sleep 300  # 5 minutes
    done
}
```

## Reference

### Configuration Files

| File | Purpose | Category |
|------|---------|----------|
| `os/macos/defaults.sh` | Master orchestration script | Core |
| `os/macos/dock.sh` | Dock preferences | UI |
| `os/macos/finder.sh` | Finder optimization | UI |
| `os/macos/input.sh` | Input device settings | Hardware |
| `os/macos/security.sh` | Security hardening | Security |

### Key System Preferences

| Preference | Default | Optimized | Impact |
|------------|---------|-----------|---------|
| Key Repeat | 6 | 2 | Much faster coding |
| Initial Delay | 25 | 15 | Faster initial repeat |
| Dock Auto-hide | false | true | More screen space |
| Show File Extensions | false | true | Better file visibility |

### Performance Targets

| Metric | Target | Typical Result |
|--------|--------|----------------|
| Configuration Time | <2 minutes | ~90 seconds |
| Shell Startup | <500ms | ~300ms |
| Application Launch | <3 seconds | ~2 seconds |
| File Operations | Instant | Instant |

### Supported Hardware

| Mac Model | Support Level | Notes |
|-----------|---------------|-------|
| **Apple Silicon (M1/M2/M3)** | Full | Native Homebrew support |
| **Intel (2015+)** | Full | Complete compatibility |
| **Intel (Pre-2015)** | Limited | Core features only |

This macOS configuration system provides a comprehensive, automated, and maintainable approach to Mac setup that transforms any Mac into a powerful development environment while maintaining security, performance, and usability standards. 