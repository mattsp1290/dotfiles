# Migration Guide

A comprehensive guide for setting up the dotfiles system on new machines, migrating between systems, and ensuring consistent environments across platforms.

## Table of Contents

- [Overview](#overview)
- [Pre-Migration Checklist](#pre-migration-checklist)
- [New Machine Setup](#new-machine-setup)
- [Bootstrap Process](#bootstrap-process)
- [Configuration Migration](#configuration-migration)
- [Secret Transfer](#secret-transfer)
- [Platform-Specific Setup](#platform-specific-setup)
- [Verification Procedures](#verification-procedures)
- [Post-Installation Configuration](#post-installation-configuration)
- [Troubleshooting Migration Issues](#troubleshooting-migration-issues)
- [Advanced Migration Scenarios](#advanced-migration-scenarios)

## Overview

The dotfiles migration process is designed to:
- **Minimize downtime**: Quick setup on new machines
- **Ensure consistency**: Identical configurations across environments
- **Preserve data**: Safe transfer of configurations and secrets
- **Support automation**: Minimal manual intervention required

### Migration Philosophy

- **Infrastructure as Code**: All configurations are version-controlled
- **Secure by Default**: No secrets exposed during migration
- **Platform Agnostic**: Works across macOS, Linux, and WSL
- **Reversible**: Can rollback to previous state if needed

### What Gets Migrated

- Shell configurations (Zsh, Bash)
- Git settings and SSH keys
- Editor configurations (Neovim, VSCode)
- Terminal settings and themes
- Development tool configurations
- Package lists and preferences
- Custom scripts and functions

### Prerequisites

- Git 2.20+
- Internet connection
- Administrative privileges
- 1Password account with existing data

## Pre-Migration Checklist

### Source Machine Preparation

#### 1. Backup Current Configuration
```bash
# Create full backup of existing dotfiles
cd ~/git/dotfiles
./scripts/backup-local.sh

# Commit any uncommitted changes
git add .
git commit -m "Pre-migration backup: $(date)"
git push origin main

# Create migration snapshot
git tag "migration-$(date +%Y%m%d)"
git push origin --tags
```

#### 2. Document Current State
```bash
# Generate system report
./scripts/bootstrap.sh doctor > migration-report.txt
./scripts/generate-system-report.sh >> migration-report.txt

# List installed packages
brew list > brew-packages.txt  # macOS
dpkg --get-selections > packages.txt  # Ubuntu/Debian
rpm -qa > packages.txt  # Fedora/RHEL

# Export current configurations
./scripts/export-current-config.sh
```

#### 3. Verify Secret Management
```bash
# Ensure 1Password is set up and accessible
op whoami
op vault list

# Verify all secrets are accessible
./scripts/verify-secrets.sh --comprehensive

# Export secret references for validation
./scripts/list-secret-references.sh > secret-references.txt
```

### Target Machine Preparation

#### 1. System Requirements Check
```bash
# Check OS compatibility
uname -a
# Ensure: macOS 12+, Ubuntu 20.04+, Fedora 36+, or equivalent

# Check available disk space (minimum 2GB)
df -h ~

# Check internet connectivity
ping -c 3 github.com

# Verify administrative access
sudo -v
```

#### 2. Install Prerequisites
```bash
# macOS: Install Command Line Tools
xcode-select --install

# Linux: Update package manager
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# Fedora
sudo dnf update -y

# Install Git if not present
# macOS: git --version (should be installed with CLT)
# Linux: sudo apt install git / sudo dnf install git
```

## New Machine Setup

### Method 1: One-Command Installation (Recommended)

```bash
# Quick installation from any machine
curl -fsSL https://raw.githubusercontent.com/[username]/dotfiles/main/install.sh | bash
```

### Method 2: Step-by-Step Installation

#### Step 1: Clone Repository
```bash
# Create dotfiles directory
mkdir -p ~/git
cd ~/git

# Clone the repository
git clone https://github.com/[username]/dotfiles.git
cd dotfiles

# Verify repository integrity
git log --oneline -5
git status
```

#### Step 2: Run Bootstrap
```bash
# Make bootstrap executable
chmod +x scripts/bootstrap.sh

# Run installation with verbose output
./scripts/bootstrap.sh --verbose install

# Or run with specific options
./scripts/bootstrap.sh install --skip-packages  # Skip package installation
./scripts/bootstrap.sh install --dry-run        # Preview changes only
```

#### Step 3: Install Additional Tools
```bash
# Install development tools
./scripts/install-tools.sh

# Install platform-specific packages
# macOS
./scripts/brew-install.sh

# Linux
./scripts/linux-packages.sh

# Install terminals and editors
./scripts/setup-terminals.sh
./scripts/setup-editors.sh
```

### Method 3: Automated Migration Script

```bash
#!/bin/bash
# scripts/migrate-to-new-machine.sh

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

main() {
    log "Starting migration to new machine..."
    
    # Step 1: System check
    log "Checking system compatibility..."
    ./scripts/check-system-compatibility.sh
    
    # Step 2: Install prerequisites
    log "Installing prerequisites..."
    ./scripts/install-prerequisites.sh
    
    # Step 3: Bootstrap dotfiles
    log "Running bootstrap installation..."
    ./scripts/bootstrap.sh install --force
    
    # Step 4: Install tools
    log "Installing additional tools..."
    ./scripts/install-tools.sh core
    
    # Step 5: Setup 1Password
    log "Setting up 1Password CLI..."
    ./scripts/setup-1password.sh
    
    # Step 6: Inject secrets
    log "Setting up secret management..."
    echo "Please sign in to 1Password to continue..."
    op signin
    ./scripts/inject-all.sh
    
    # Step 7: Verify installation
    log "Verifying installation..."
    ./scripts/bootstrap.sh doctor
    
    # Step 8: Performance check
    log "Running performance check..."
    exec $SHELL -l
    echo "Shell startup time: ${SHELL_STARTUP_TIME:-unknown}ms"
    
    log "Migration completed successfully!"
    log "Please restart your shell or run: exec \$SHELL"
}

main "$@"
```

## Bootstrap Process

### Understanding Bootstrap Phases

#### Phase 1: Environment Detection
```bash
# OS and architecture detection
detect_os_type     # macOS, Linux, BSD
detect_architecture # x86_64, arm64
detect_linux_distribution  # Ubuntu, Fedora, Arch, etc.
detect_package_manager     # brew, apt, dnf, pacman
```

#### Phase 2: Tool Installation
```bash
# Install package manager (if needed)
install_homebrew   # macOS only
install_package_manager_updates

# Install core tools
install_git        # Git version control
install_stow       # Symlink management
install_1password_cli  # Secret management
```

#### Phase 3: Repository Setup
```bash
# Configure repository
setup_git_config
clone_or_update_repository
setup_symlinks_with_stow
```

#### Phase 4: Configuration Application
```bash
# Apply configurations
setup_shell_config
setup_git_config
setup_ssh_config
inject_secrets_from_templates
```

#### Phase 5: Post-Installation
```bash
# Finalize setup
run_post_install_scripts
setup_cron_jobs
validate_installation
```

### Bootstrap Options and Flags

#### Common Options
```bash
# Installation modes
./scripts/bootstrap.sh install    # Fresh installation
./scripts/bootstrap.sh update     # Update existing installation
./scripts/bootstrap.sh repair     # Fix broken installations
./scripts/bootstrap.sh uninstall  # Remove installation

# Behavior modifiers
--verbose          # Detailed output
--dry-run         # Preview changes without applying
--force           # Skip confirmations
--offline         # Skip network operations
--skip-packages   # Skip package installation
--skip-tools      # Skip tool installation
```

#### Advanced Options
```bash
# Component selection
--components "shell,git,ssh"  # Install specific components only
--exclude "macos"            # Skip platform-specific configs

# Custom paths
--dotfiles-dir ~/.config/dotfiles  # Custom installation directory
--backup-dir ~/.backup            # Custom backup location

# Environment-specific
--profile work     # Use work profile
--context development  # Development context
```

### Bootstrap Customization

#### Custom Bootstrap Configuration
```yaml
# ~/.config/dotfiles/bootstrap.yml
bootstrap:
  components:
    - shell
    - git
    - ssh
    - editors
  
  skip_components:
    - macos_defaults  # Skip on Linux
    - linux_packages  # Skip on macOS
  
  options:
    force: false
    verbose: true
    backup: true
  
  post_install:
    - setup_development_environment
    - configure_custom_tools
    - run_team_specific_setup
```

## Configuration Migration

### Shell Configuration Migration

#### Zsh Configuration
```bash
# Migrate Zsh settings
cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d)

# Apply dotfiles Zsh configuration
./scripts/setup-shell.sh zsh

# Migrate custom aliases and functions
cat >> ~/.config/shell/aliases.local << 'EOF'
# Migrated custom aliases
alias ll='ls -la'
alias gs='git status'
EOF

# Migrate environment variables
cat >> ~/.config/shell/env.local << 'EOF'
# Migrated environment variables
export CUSTOM_VAR="value"
EOF
```

#### Bash Configuration
```bash
# Migrate Bash settings
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d)

# Apply dotfiles Bash configuration
./scripts/setup-shell.sh bash

# Import existing customizations
if [[ -f ~/.bashrc.backup.$(date +%Y%m%d) ]]; then
    grep "^alias\|^export\|^function" ~/.bashrc.backup.$(date +%Y%m%d) >> ~/.config/shell/custom.local
fi
```

### Git Configuration Migration

#### Preserve Existing Git Settings
```bash
# Backup current Git configuration
git config --list --global > git-config-backup.txt

# Key settings to preserve
USER_NAME=$(git config --get user.name)
USER_EMAIL=$(git config --get user.email)
SIGNING_KEY=$(git config --get user.signingkey)

# Apply dotfiles Git configuration
./scripts/git-setup.sh

# Restore personal settings if needed
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
git config --global user.signingkey "$SIGNING_KEY"
```

#### Migration Script for Git
```bash
#!/bin/bash
# scripts/migrate-git-config.sh

backup_git_config() {
    local backup_file="git-config-$(date +%Y%m%d_%H%M%S).backup"
    git config --list --global > "$backup_file"
    echo "Git config backed up to: $backup_file"
}

migrate_git_config() {
    # Extract current user info
    local current_name=$(git config --get user.name 2>/dev/null || echo "")
    local current_email=$(git config --get user.email 2>/dev/null || echo "")
    
    # Apply dotfiles configuration
    ./scripts/git-setup.sh
    
    # Prompt for user info if not in 1Password
    if [[ -z "$current_name" ]]; then
        read -p "Enter your full name: " current_name
        git config --global user.name "$current_name"
    fi
    
    if [[ -z "$current_email" ]]; then
        read -p "Enter your email: " current_email
        git config --global user.email "$current_email"
    fi
}

backup_git_config
migrate_git_config
```

### SSH Configuration Migration

#### SSH Key Migration
```bash
# Backup existing SSH keys
cp -r ~/.ssh ~/.ssh.backup.$(date +%Y%m%d)

# Generate new SSH keys if needed
./scripts/ssh-keygen-helper.sh

# Or migrate existing keys
if [[ -f ~/.ssh.backup.$(date +%Y%m%d)/id_rsa ]]; then
    echo "Existing SSH keys found. Migrate them? (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        cp ~/.ssh.backup.$(date +%Y%m%d)/id_* ~/.ssh/
        chmod 600 ~/.ssh/id_*
        chmod 644 ~/.ssh/id_*.pub
    fi
fi

# Apply SSH configuration
./scripts/ssh-setup.sh
```

#### SSH Config File Migration
```bash
# Merge SSH configurations
if [[ -f ~/.ssh.backup.$(date +%Y%m%d)/config ]]; then
    echo "# Migrated SSH configuration" >> ~/.ssh/config
    echo "" >> ~/.ssh/config
    cat ~/.ssh.backup.$(date +%Y%m%d)/config >> ~/.ssh/config
fi

# Validate SSH configuration
ssh -T git@github.com
```

## Secret Transfer

### 1Password Setup on New Machine

#### Install and Configure 1Password CLI
```bash
# macOS
brew install --cask 1password-cli

# Linux (Ubuntu/Debian)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

# Sign in to 1Password
op signin your-account.1password.com

# Verify access
op whoami
op vault list
```

#### Secret Injection
```bash
# Inject secrets into templates
./scripts/inject-all.sh

# Verify secret injection
./scripts/verify-secrets.sh

# Test configurations
git config --get user.signingkey  # Should show GPG key
ssh -T git@github.com              # Should authenticate
```

### Manual Secret Migration (Emergency)

#### Temporary Secret Export (Use with caution)
```bash
#!/bin/bash
# scripts/emergency-secret-export.sh
# WARNING: Only use when 1Password is not available

temp_file=$(mktemp)
cat > "$temp_file" << EOF
# Emergency secrets - DELETE AFTER MIGRATION
GIT_SIGNING_KEY="[paste GPG key here]"
SSH_PRIVATE_KEY="[paste SSH private key here]"
GITHUB_TOKEN="[paste token here]"
EOF

# Encrypt the temporary file
gpg --symmetric --cipher-algo AES256 --output secrets.gpg "$temp_file"
shred -vfz -n 3 "$temp_file"

echo "Encrypted secrets saved to secrets.gpg"
echo "Transfer this file securely and delete after migration"
```

#### Import Emergency Secrets
```bash
# Decrypt and import secrets
gpg --decrypt secrets.gpg > temp_secrets
source temp_secrets

# Apply secrets manually
git config --global user.signingkey "$GIT_SIGNING_KEY"
echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

# Clean up
shred -vfz -n 3 temp_secrets secrets.gpg
unset GIT_SIGNING_KEY SSH_PRIVATE_KEY GITHUB_TOKEN
```

## Platform-Specific Setup

### macOS-Specific Migration

#### System Preferences
```bash
# Apply macOS system defaults
./os/macos/defaults.sh

# Configure Dock
./os/macos/dock.sh

# Set Finder preferences
./os/macos/finder.sh

# Configure security settings
./os/macos/security.sh

# Install Homebrew packages
./scripts/brew-install.sh
```

#### macOS-Specific Configurations
```bash
# Configure Touch ID for sudo
sudo cat > /etc/pam.d/sudo_local << EOF
auth       sufficient     pam_tid.so
EOF

# Set up Spotlight preferences
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
```

### Linux-Specific Migration

#### Distribution-Specific Setup
```bash
# Ubuntu/Debian
./scripts/linux-packages.sh ubuntu

# Fedora
./scripts/linux-packages.sh fedora

# Arch Linux
./scripts/linux-packages.sh arch

# Configure package manager
./scripts/setup-package-managers.sh
```

#### Linux Desktop Environment
```bash
# GNOME settings
if [[ "$XDG_CURRENT_DESKTOP" == "GNOME" ]]; then
    ./scripts/setup-gnome.sh
fi

# KDE settings
if [[ "$XDG_CURRENT_DESKTOP" == "KDE" ]]; then
    ./scripts/setup-kde.sh
fi

# Configure X11/Wayland settings
./scripts/setup-display-server.sh
```

### WSL-Specific Migration

#### WSL Configuration
```bash
# Configure WSL-specific settings
./scripts/setup-wsl.sh

# Fix file permissions
sudo mount -o remount,metadata /mnt/c

# Configure Windows Terminal integration
./scripts/setup-windows-terminal.sh

# Set up WSL-specific aliases
cat >> ~/.config/shell/aliases.local << 'EOF'
# WSL-specific aliases
alias open='explorer.exe'
alias code='code.exe'
EOF
```

## Verification Procedures

### Post-Installation Verification

#### System Health Check
```bash
# Run comprehensive health check
./scripts/bootstrap.sh doctor

# Verify all components
./scripts/verify-installation.sh

# Check performance
echo "Shell startup time: ${SHELL_STARTUP_TIME:-unknown}ms"
time zsh -i -c exit
```

#### Component Verification
```bash
# Shell verification
echo "Shell: $SHELL"
which zsh bash
zsh --version
bash --version

# Git verification
git --version
git config --get user.name
git config --get user.email
git log --show-signature -1

# SSH verification
ssh-add -l
ssh -T git@github.com

# Editor verification
nvim --version
code --version 2>/dev/null || echo "VSCode not installed"

# Package manager verification
brew --version 2>/dev/null || echo "Homebrew not available"
apt --version 2>/dev/null || echo "APT not available"
```

#### Secret Management Verification
```bash
# 1Password verification
op whoami
op vault list

# Secret injection verification
./scripts/verify-secrets.sh --comprehensive

# Template validation
./scripts/validate-templates.sh
```

### Performance Verification

#### Shell Performance Test
```bash
# Test shell startup time (should be <500ms)
time zsh -i -c exit
time bash -i -c exit

# Profile Zsh startup
zsh -i -c 'zprof' | head -20

# Test common operations
time git status
time ls -la
```

#### System Performance Test
```bash
# Check disk usage
du -sh ~/git/dotfiles
du -sh ~/.config

# Check memory usage
ps aux | grep -E "(zsh|bash)" | head -5

# Network connectivity test
ping -c 3 github.com
curl -I https://github.com
```

### Functional Verification

#### Development Environment Test
```bash
# Test Git workflow
cd /tmp
git clone https://github.com/octocat/Hello-World.git test-repo
cd test-repo
git log --oneline -5
git status
cd /tmp && rm -rf test-repo

# Test SSH connectivity
ssh -T git@github.com

# Test editor
echo "Hello, World!" | nvim -

# Test package manager
brew list | head -5 2>/dev/null || apt list --installed | head -5
```

#### Custom Function Test
```bash
# Test custom shell functions
which dotfiles
dotfiles --version

# Test aliases
alias | grep -E "(ll|la|gs)"

# Test environment variables
env | grep DOTFILES
```

## Post-Installation Configuration

### Personal Customization

#### Create Personal Configuration File
```yaml
# ~/.config/dotfiles/personal.yml
user:
  name: "Your Name"
  email: "your.email@example.com"
  github_username: "yourusername"

shell:
  theme: "powerlevel10k"
  plugins:
    - git
    - docker
    - kubectl

tools:
  editor: "nvim"
  terminal: "alacritty"
  
git:
  default_branch: "main"
  signing_key: "{{ op://Personal/Git GPG Key/private_key }}"
```

#### Apply Personal Customizations
```bash
# Regenerate configurations with personal settings
./scripts/inject-all.sh

# Restart shell to apply changes
exec $SHELL
```

### Team/Work Environment Setup

#### Work Profile Configuration
```yaml
# ~/.config/dotfiles/profiles/work.yml
extends: "base"

git:
  user:
    name: "Your Name"
    email: "your.name@company.com"

ssh:
  hosts:
    work-server:
      hostname: "server.company.com"
      user: "{{ op://Work/SSH/username }}"

tools:
  additional:
    - docker
    - kubectl
    - terraform
```

#### Apply Work Profile
```bash
# Switch to work profile
dotfiles profile work

# Regenerate configurations
./scripts/inject-all.sh --profile work
```

### Development Environment Setup

#### Language-Specific Setup
```bash
# Node.js setup
nvm install --lts
nvm use --lts
npm install -g npm@latest

# Python setup
pyenv install 3.11.0
pyenv global 3.11.0
pip install --upgrade pip

# Go setup
go version

# Rust setup
rustup update
```

#### IDE/Editor Setup
```bash
# Neovim plugin installation
nvim +PlugInstall +qa

# VSCode extension sync (if using)
code --install-extension settings-sync
```

## Troubleshooting Migration Issues

### Common Migration Problems

#### Issue: Bootstrap fails during installation
```bash
# Debug bootstrap process
./scripts/bootstrap.sh --verbose --dry-run install

# Check prerequisites
./scripts/check-prerequisites.sh

# Run with debug logging
CURRENT_LOG_LEVEL=0 ./scripts/bootstrap.sh install
```

#### Issue: Symlink conflicts
```bash
# Check for existing files
stow --simulate --dir=~/git/dotfiles --target=~ home

# Backup existing files
./scripts/backup-existing-configs.sh

# Force symlink creation
stow --dir=~/git/dotfiles --target=~ --adopt home
git checkout -- .
```

#### Issue: Secret injection fails
```bash
# Debug 1Password connection
op signin --force
op whoami

# Check template syntax
./scripts/validate-templates.sh

# Manual secret testing
op item get "Git Identity" --field name
```

#### Issue: Shell performance is slow
```bash
# Profile shell startup
time zsh -i -c exit

# Check for heavy plugins
zsh -i -c 'zprof'

# Optimize shell configuration
./scripts/optimize-shell.sh
```

### Recovery Procedures

#### Reset to Clean State
```bash
# Remove dotfiles installation
./scripts/bootstrap.sh uninstall

# Clean up symlinks
find ~ -type l -exec test ! -e {} \; -delete 2>/dev/null

# Restore backed up files
./scripts/restore-from-backup.sh ~/.config-backup-*

# Start fresh installation
./scripts/bootstrap.sh install
```

#### Partial Migration Recovery
```bash
# Reset specific component
./scripts/reset-component.sh shell
./scripts/setup-shell.sh

# Regenerate specific configurations
./scripts/inject-secrets.sh ~/.gitconfig.template
./scripts/inject-secrets.sh ~/.ssh/config.template
```

## Advanced Migration Scenarios

### Multi-Machine Synchronization

#### Sync Between Existing Machines
```bash
# On source machine
cd ~/git/dotfiles
git add .
git commit -m "Sync: $(date)"
git push origin main

# On target machine
cd ~/git/dotfiles
git pull origin main
./scripts/inject-all.sh
exec $SHELL
```

#### Corporate Environment Migration
```bash
# Use company-specific branch
git checkout -b company-setup
git pull origin company-setup

# Apply corporate policies
./scripts/apply-corporate-policies.sh

# Use internal package mirrors
export HOMEBREW_BOTTLE_DOMAIN="http://internal-mirror.company.com"
```

### Container-Based Migration

#### Docker Development Environment
```dockerfile
# Dockerfile.dotfiles
FROM ubuntu:22.04

# Install prerequisites
RUN apt-get update && apt-get install -y \
    git \
    curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -s /bin/bash developer
USER developer
WORKDIR /home/developer

# Clone and setup dotfiles
RUN git clone https://github.com/username/dotfiles.git git/dotfiles
WORKDIR git/dotfiles
RUN ./scripts/bootstrap.sh install --force --skip-packages

CMD ["/bin/bash"]
```

### Backup-Based Migration

#### Migration from Backup
```bash
# Restore from backup archive
tar xzf dotfiles-backup.tar.gz
cd dotfiles-backup

# Verify backup integrity
./scripts/verify-backup.sh

# Apply configuration
./scripts/restore-from-backup.sh
```

---

## Migration Checklist

### Pre-Migration
- [ ] Backup current configuration
- [ ] Verify 1Password access
- [ ] Document system state
- [ ] Test backup restoration

### During Migration
- [ ] Check system prerequisites
- [ ] Clone dotfiles repository
- [ ] Run bootstrap installation
- [ ] Setup 1Password CLI
- [ ] Inject secrets
- [ ] Verify installation

### Post-Migration
- [ ] Test shell functionality
- [ ] Verify Git and SSH
- [ ] Check development tools
- [ ] Test custom configurations
- [ ] Validate performance
- [ ] Create new backup

---

## Related Documentation

- [Installation Guide](installation.md)
- [Maintenance Procedures](maintenance.md)
- [Backup and Recovery](backup.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Security Documentation](secrets.md) 