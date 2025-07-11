# Backup and Recovery

A comprehensive guide to backing up and restoring your dotfiles system, ensuring data protection and quick recovery from failures.

## Table of Contents

- [Overview](#overview)
- [Backup Strategies](#backup-strategies)
- [Configuration Backup](#configuration-backup)
- [Secret Backup](#secret-backup)
- [Automated Backup Setup](#automated-backup-setup)
- [Cloud Backup Integration](#cloud-backup-integration)
- [Restoration Procedures](#restoration-procedures)
- [Backup Verification](#backup-verification)
- [Recovery Scenarios](#recovery-scenarios)
- [Best Practices](#best-practices)

## Overview

The dotfiles system employs a multi-layered backup strategy to protect against:
- **Hardware Failures**: Complete system loss or corruption
- **Accidental Changes**: Mistaken modifications or deletions
- **Software Issues**: Package conflicts or system updates
- **Migration Needs**: Moving to new machines or environments

### Backup Philosophy

- **3-2-1 Rule**: 3 copies, 2 different media types, 1 offsite
- **Incremental**: Regular automated backups with minimal overhead
- **Versioned**: Multiple restore points for different scenarios
- **Secure**: Encrypted backups with proper access controls

### What Gets Backed Up

- Configuration files and templates
- Custom shell functions and aliases
- SSH keys and certificates (encrypted)
- Application settings and preferences
- Package lists and tool versions
- Custom scripts and modifications

### What's NOT Backed Up

- Secrets (stored in 1Password)
- Cache files and temporary data
- Downloaded packages and binaries
- Log files and system state

## Backup Strategies

### Strategy 1: Git-Based Backup (Primary)

The dotfiles repository itself serves as the primary backup mechanism:

```bash
# Ensure all changes are committed
cd ~/git/dotfiles
git add .
git commit -m "Backup: $(date +'%Y-%m-%d %H:%M:%S')"
git push origin main

# Create backup branch
git checkout -b backup-$(date +%Y%m%d)
git push origin backup-$(date +%Y%m%d)
```

### Strategy 2: Local File System Backup

#### Create Complete Local Backup
```bash
#!/bin/bash
# scripts/backup-local.sh

BACKUP_DIR="$HOME/.dotfiles-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/dotfiles-$TIMESTAMP"

mkdir -p "$BACKUP_PATH"

# Backup dotfiles repository
rsync -av --exclude='.git' ~/git/dotfiles/ "$BACKUP_PATH/dotfiles/"

# Backup current configurations
mkdir -p "$BACKUP_PATH/current-config"
rsync -av ~/.config/ "$BACKUP_PATH/current-config/" --exclude='cache'
rsync -av ~/.ssh/ "$BACKUP_PATH/ssh/" --exclude='known_hosts'

# Backup shell configurations
cp ~/.zshrc "$BACKUP_PATH/" 2>/dev/null || true
cp ~/.bashrc "$BACKUP_PATH/" 2>/dev/null || true
cp ~/.gitconfig "$BACKUP_PATH/" 2>/dev/null || true

# Create manifest
cat > "$BACKUP_PATH/manifest.txt" << EOF
Backup created: $(date)
System: $(uname -a)
User: $(whoami)
Shell: $SHELL
Dotfiles commit: $(cd ~/git/dotfiles && git rev-parse HEAD)
EOF

echo "Backup created: $BACKUP_PATH"
```

### Strategy 3: Cloud Storage Backup

#### Rsync to Cloud Storage
```bash
#!/bin/bash
# scripts/backup-cloud.sh

CLOUD_BACKUP_DIR="$HOME/Dropbox/Backups/dotfiles"  # or Google Drive, etc.
LOCAL_BACKUP_DIR="$HOME/.dotfiles-backups"

# Create local backup first
./scripts/backup-local.sh

# Sync to cloud storage
if [[ -d "$CLOUD_BACKUP_DIR" ]]; then
    rsync -av --delete "$LOCAL_BACKUP_DIR/" "$CLOUD_BACKUP_DIR/"
    echo "Backup synced to cloud storage: $CLOUD_BACKUP_DIR"
else
    echo "Cloud storage directory not found: $CLOUD_BACKUP_DIR"
    exit 1
fi
```

### Strategy 4: Compressed Archive Backup

#### Create Compressed Backup
```bash
#!/bin/bash
# scripts/backup-archive.sh

BACKUP_NAME="dotfiles-$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/$BACKUP_NAME"
OUTPUT_DIR="$HOME/Backups"

mkdir -p "$TEMP_DIR" "$OUTPUT_DIR"

# Copy dotfiles
cp -r ~/git/dotfiles "$TEMP_DIR/"

# Copy current configurations
mkdir -p "$TEMP_DIR/active-configs"
rsync -av ~/.config/ "$TEMP_DIR/active-configs/" --exclude='cache'

# Create encrypted archive
tar czf "$OUTPUT_DIR/$BACKUP_NAME.tar.gz" -C /tmp "$BACKUP_NAME"

# Optional: encrypt the archive
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
    --output "$OUTPUT_DIR/$BACKUP_NAME.tar.gz.gpg" \
    "$OUTPUT_DIR/$BACKUP_NAME.tar.gz"

# Cleanup
rm -rf "$TEMP_DIR" "$OUTPUT_DIR/$BACKUP_NAME.tar.gz"

echo "Encrypted backup created: $OUTPUT_DIR/$BACKUP_NAME.tar.gz.gpg"
```

## Configuration Backup

### Pre-Installation Backup

Before making any changes, create a backup of existing configurations:

```bash
#!/bin/bash
# scripts/backup-existing-configs.sh

BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# List of files to backup
FILES_TO_BACKUP=(
    ~/.bashrc
    ~/.zshrc
    ~/.gitconfig
    ~/.ssh/config
    ~/.tmux.conf
    ~/.vimrc
    ~/.config/git/
    ~/.config/nvim/
    ~/.config/tmux/
)

for file in "${FILES_TO_BACKUP[@]}"; do
    if [[ -e "$file" ]]; then
        # Create directory structure
        target_dir="$BACKUP_DIR/$(dirname "${file#$HOME/}")"
        mkdir -p "$target_dir"
        
        # Copy file or directory
        cp -r "$file" "$target_dir/"
        echo "Backed up: $file"
    fi
done

echo "Existing configuration backed up to: $BACKUP_DIR"
```

### Selective Configuration Backup

#### Backup Specific Components
```bash
#!/bin/bash
# scripts/backup-component.sh

component="$1"
timestamp=$(date +%Y%m%d_%H%M%S)

backup_component() {
    local comp="$1"
    local backup_dir="$HOME/.component-backups/$comp-$timestamp"
    
    mkdir -p "$backup_dir"
    
    case "$comp" in
        shell)
            cp ~/.zshrc "$backup_dir/" 2>/dev/null || true
            cp ~/.bashrc "$backup_dir/" 2>/dev/null || true
            cp -r ~/git/dotfiles/shell/ "$backup_dir/"
            ;;
        git)
            cp ~/.gitconfig "$backup_dir/" 2>/dev/null || true
            cp -r ~/.config/git/ "$backup_dir/" 2>/dev/null || true
            cp -r ~/git/dotfiles/config/git/ "$backup_dir/"
            ;;
        ssh)
            cp -r ~/.ssh/ "$backup_dir/" 2>/dev/null || true
            cp -r ~/git/dotfiles/config/ssh/ "$backup_dir/"
            ;;
        nvim)
            cp -r ~/.config/nvim/ "$backup_dir/" 2>/dev/null || true
            cp -r ~/git/dotfiles/config/nvim/ "$backup_dir/"
            ;;
        *)
            echo "Unknown component: $comp"
            return 1
            ;;
    esac
    
    echo "Component backup created: $backup_dir"
}

if [[ -z "$component" ]]; then
    echo "Usage: $0 <component>"
    echo "Components: shell, git, ssh, nvim"
    exit 1
fi

backup_component "$component"
```

## Secret Backup

### 1Password Export (Manual)

Since secrets are stored in 1Password, backup involves ensuring 1Password data is secure:

```bash
#!/bin/bash
# scripts/backup-secret-references.sh

# Extract secret references from templates
find ~/git/dotfiles -name "*.tmpl" -o -name "*.j2" -o -name "*.template" | \
    xargs grep -h "op://" | \
    sort -u > ~/.dotfiles-secret-references.txt

echo "Secret references backed up to: ~/.dotfiles-secret-references.txt"

# Verify all references are accessible
./scripts/verify-secrets.sh --list-only
```

### Emergency Secret Backup

For emergency situations, create encrypted backup of essential secrets:

```bash
#!/bin/bash
# scripts/emergency-secret-backup.sh

# WARNING: Only use in emergency situations
# This temporarily exposes secrets to disk

BACKUP_FILE="$HOME/.emergency-secrets-$(date +%Y%m%d).gpg"

# Create temporary file with essential secrets
temp_file=$(mktemp)
cat > "$temp_file" << EOF
# Emergency Secret Backup - $(date)
# WARNING: This file contains sensitive information

# Git Configuration
GIT_NAME="$(op read 'op://Personal/Git Identity/name')"
GIT_EMAIL="$(op read 'op://Personal/Git Identity/email')"
GIT_SIGNING_KEY="$(op read 'op://Personal/Git Identity/signing_key')"

# SSH Configuration
SSH_KEY="$(op read 'op://Personal/SSH Keys/private_key')"

# Essential API Keys
GITHUB_TOKEN="$(op read 'op://Personal/GitHub/token')"
EOF

# Encrypt the file
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
    --output "$BACKUP_FILE" "$temp_file"

# Securely delete temporary file
shred -vfz -n 3 "$temp_file"

echo "Emergency secret backup created: $BACKUP_FILE"
echo "WARNING: Store this file securely and delete when no longer needed"
```

## Automated Backup Setup

### Cron-Based Automation

#### Daily Backup
```bash
# Add to crontab: crontab -e
# Daily backup at 2 AM
0 2 * * * /bin/bash ~/git/dotfiles/scripts/daily-backup.sh

# scripts/daily-backup.sh
#!/bin/bash
cd ~/git/dotfiles

# Check for changes
if [[ -n $(git status --porcelain) ]]; then
    # Commit changes
    git add .
    git commit -m "Auto-backup: $(date +'%Y-%m-%d %H:%M:%S')"
    git push origin main
fi

# Create local backup
./scripts/backup-local.sh

# Clean old backups (keep last 7 days)
find ~/.dotfiles-backups -name "dotfiles-*" -mtime +7 -delete
```

#### Weekly Cloud Sync
```bash
# Weekly cloud backup on Sundays at 3 AM
0 3 * * 0 /bin/bash ~/git/dotfiles/scripts/weekly-cloud-backup.sh

# scripts/weekly-cloud-backup.sh
#!/bin/bash
./scripts/backup-cloud.sh

# Clean old cloud backups (keep last 4 weeks)
find "$HOME/Dropbox/Backups/dotfiles" -name "dotfiles-*" -mtime +28 -delete
```

### Git Hooks for Automatic Backup

#### Pre-Push Hook
```bash
# .git/hooks/pre-push
#!/bin/bash
# Create backup before pushing changes

echo "Creating pre-push backup..."
~/git/dotfiles/scripts/backup-local.sh

exit 0
```

### Launchd (macOS) Integration

#### Daily Backup Service
```xml
<!-- ~/Library/LaunchAgents/com.dotfiles.backup.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dotfiles.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/username/git/dotfiles/scripts/daily-backup.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

```bash
# Load the service
launchctl load ~/Library/LaunchAgents/com.dotfiles.backup.plist
```

## Cloud Backup Integration

### Dropbox Integration

```bash
#!/bin/bash
# scripts/setup-dropbox-backup.sh

DROPBOX_DIR="$HOME/Dropbox/Backups/dotfiles"
mkdir -p "$DROPBOX_DIR"

# Create backup script
cat > "$DROPBOX_DIR/sync-dotfiles.sh" << 'EOF'
#!/bin/bash
# Sync dotfiles to Dropbox

DOTFILES_DIR="$HOME/git/dotfiles"
BACKUP_DIR="$HOME/Dropbox/Backups/dotfiles"

cd "$DOTFILES_DIR"

# Create archive
tar czf "$BACKUP_DIR/dotfiles-$(date +%Y%m%d).tar.gz" \
    --exclude='.git' \
    --exclude='cache' \
    --exclude='logs' .

# Keep only last 10 backups
ls -t "$BACKUP_DIR"/dotfiles-*.tar.gz | tail -n +11 | xargs rm -f

echo "Dotfiles synced to Dropbox: $(date)"
EOF

chmod +x "$DROPBOX_DIR/sync-dotfiles.sh"
```

### Google Drive Integration

```bash
#!/bin/bash
# scripts/setup-gdrive-backup.sh

# Requires rclone setup: https://rclone.org/

# Configure rclone for Google Drive
if ! rclone listremotes | grep -q "gdrive:"; then
    echo "Setting up Google Drive remote..."
    rclone config create gdrive drive
fi

# Create backup function
backup_to_gdrive() {
    local backup_name="dotfiles-$(date +%Y%m%d_%H%M%S).tar.gz"
    local temp_file="/tmp/$backup_name"
    
    # Create archive
    tar czf "$temp_file" -C ~/git/dotfiles \
        --exclude='.git' \
        --exclude='cache' .
    
    # Upload to Google Drive
    rclone copy "$temp_file" gdrive:Backups/dotfiles/
    
    # Cleanup
    rm -f "$temp_file"
    
    echo "Backup uploaded to Google Drive: $backup_name"
}

backup_to_gdrive
```

### iCloud Integration (macOS)

```bash
#!/bin/bash
# scripts/setup-icloud-backup.sh

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/dotfiles"
mkdir -p "$ICLOUD_DIR"

# Create backup script
backup_to_icloud() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$ICLOUD_DIR/dotfiles-$timestamp"
    
    mkdir -p "$backup_dir"
    
    # Copy dotfiles
    rsync -av --exclude='.git' ~/git/dotfiles/ "$backup_dir/"
    
    # Create manifest
    cat > "$backup_dir/manifest.txt" << EOF
Backup created: $(date)
System: $(uname -a)
Git commit: $(cd ~/git/dotfiles && git rev-parse HEAD)
EOF
    
    echo "Backup created in iCloud: $backup_dir"
}

backup_to_icloud
```

## Restoration Procedures

### Complete System Restoration

#### Restore from Git Repository
```bash
#!/bin/bash
# scripts/restore-from-git.sh

set -euo pipefail

# Remove existing dotfiles
if [[ -d ~/git/dotfiles ]]; then
    mv ~/git/dotfiles ~/git/dotfiles.bak.$(date +%Y%m%d_%H%M%S)
fi

# Clone repository
git clone https://github.com/username/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles

# Run installation
./scripts/bootstrap.sh install

echo "System restored from Git repository"
```

#### Restore from Local Backup
```bash
#!/bin/bash
# scripts/restore-from-backup.sh

backup_path="$1"

if [[ -z "$backup_path" || ! -d "$backup_path" ]]; then
    echo "Usage: $0 <backup_path>"
    echo "Available backups:"
    ls -la ~/.dotfiles-backups/
    exit 1
fi

# Backup current state
current_backup="$HOME/.dotfiles-current-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$current_backup"
cp -r ~/git/dotfiles "$current_backup/" 2>/dev/null || true

# Restore from backup
if [[ -d "$backup_path/dotfiles" ]]; then
    rm -rf ~/git/dotfiles
    cp -r "$backup_path/dotfiles" ~/git/dotfiles
fi

# Restore configurations
if [[ -d "$backup_path/current-config" ]]; then
    rsync -av "$backup_path/current-config/" ~/.config/
fi

# Restore SSH keys
if [[ -d "$backup_path/ssh" ]]; then
    rsync -av "$backup_path/ssh/" ~/.ssh/
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/*
fi

echo "System restored from backup: $backup_path"
echo "Previous state backed up to: $current_backup"
```

### Selective Restoration

#### Restore Single Component
```bash
#!/bin/bash
# scripts/restore-component.sh

component="$1"
backup_path="$2"

if [[ -z "$component" || -z "$backup_path" ]]; then
    echo "Usage: $0 <component> <backup_path>"
    exit 1
fi

case "$component" in
    shell)
        cp "$backup_path/.zshrc" ~/ 2>/dev/null || true
        cp "$backup_path/.bashrc" ~/ 2>/dev/null || true
        ;;
    git)
        cp "$backup_path/.gitconfig" ~/ 2>/dev/null || true
        rsync -av "$backup_path/git/" ~/.config/git/ 2>/dev/null || true
        ;;
    ssh)
        rsync -av "$backup_path/ssh/" ~/.ssh/ 2>/dev/null || true
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/* 2>/dev/null || true
        ;;
    *)
        echo "Unknown component: $component"
        exit 1
        ;;
esac

echo "Component '$component' restored from: $backup_path"
```

## Backup Verification

### Automated Verification

```bash
#!/bin/bash
# scripts/verify-backup.sh

backup_path="$1"

if [[ ! -d "$backup_path" ]]; then
    echo "Backup path not found: $backup_path"
    exit 1
fi

echo "Verifying backup: $backup_path"

# Check manifest
if [[ -f "$backup_path/manifest.txt" ]]; then
    echo "✓ Manifest found"
    cat "$backup_path/manifest.txt"
else
    echo "✗ Manifest missing"
fi

# Check critical files
critical_files=(
    "dotfiles/README.md"
    "dotfiles/scripts/bootstrap.sh"
    "dotfiles/shell/zsh/zshrc"
)

for file in "${critical_files[@]}"; do
    if [[ -f "$backup_path/$file" ]]; then
        echo "✓ $file"
    else
        echo "✗ $file missing"
    fi
done

# Check backup integrity
if [[ -f "$backup_path.tar.gz" ]]; then
    if tar tzf "$backup_path.tar.gz" >/dev/null 2>&1; then
        echo "✓ Archive integrity verified"
    else
        echo "✗ Archive corrupted"
    fi
fi

echo "Backup verification completed"
```

### Restoration Testing

```bash
#!/bin/bash
# scripts/test-restoration.sh

# Test restoration in temporary environment
test_dir="/tmp/dotfiles-restore-test-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$test_dir"

# Create mock home directory
export HOME="$test_dir"
mkdir -p "$HOME/.config"

# Test restoration
backup_path="$1"
if ./scripts/restore-from-backup.sh "$backup_path"; then
    echo "✓ Restoration test passed"
    
    # Test basic functionality
    if [[ -f "$HOME/git/dotfiles/scripts/bootstrap.sh" ]]; then
        echo "✓ Bootstrap script found"
    else
        echo "✗ Bootstrap script missing"
    fi
    
else
    echo "✗ Restoration test failed"
fi

# Cleanup
rm -rf "$test_dir"
```

## Recovery Scenarios

### Scenario 1: Corrupted Shell Configuration

```bash
# Quick recovery from shell issues
# 1. Reset shell to default
export PS1='$ '
unalias -a

# 2. Restore from backup
cd ~/git/dotfiles
git checkout HEAD -- shell/
./scripts/inject-all.sh

# 3. Reload shell
exec $SHELL
```

### Scenario 2: Broken Symlinks

```bash
# Fix broken symlinks
./scripts/bootstrap.sh repair

# Or manual fix
find ~ -type l -exec test ! -e {} \; -delete 2>/dev/null
./scripts/stow-all.sh
```

### Scenario 3: Lost SSH Keys

```bash
# 1. Restore SSH keys from backup
./scripts/restore-component.sh ssh ~/.dotfiles-backups/latest/

# 2. Or regenerate from 1Password
./scripts/ssh-setup.sh --restore-from-1password

# 3. Update SSH agent
ssh-add ~/.ssh/id_ed25519
```

### Scenario 4: Complete System Loss

```bash
# 1. Install essential tools
# macOS: Install Xcode Command Line Tools
xcode-select --install

# 2. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Install Git
brew install git

# 4. Restore dotfiles
git clone https://github.com/username/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
./scripts/bootstrap.sh install

# 5. Sign in to 1Password and inject secrets
op signin
./scripts/inject-all.sh
```

## Best Practices

### Backup Frequency
- **Critical changes**: Immediate backup before/after
- **Daily**: Automated local backup
- **Weekly**: Cloud sync and verification
- **Monthly**: Archive and deep verification

### Storage Recommendations
- **Local**: Fast SSD or NVMe for quick access
- **Cloud**: Encrypted cloud storage for offsite backup
- **Archive**: Long-term storage for compliance

### Security Guidelines
- Always encrypt sensitive backups
- Use strong passphrases for encryption
- Regularly test backup integrity
- Store encryption keys separately
- Follow the 3-2-1 backup rule

### Maintenance Tasks
- Regular backup verification
- Cleanup old backups
- Test restoration procedures
- Update backup scripts
- Monitor backup health

---

## Related Documentation

- [Maintenance Procedures](maintenance.md)
- [Migration Guide](migration.md)
- [Troubleshooting](troubleshooting.md)
- [Security Management](secrets.md) 