# Troubleshooting Guide

A comprehensive troubleshooting guide for common issues with the dotfiles system, including diagnostic procedures, solutions, and preventive measures.

## Table of Contents

- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Installation Issues](#installation-issues)
- [Platform-Specific Problems](#platform-specific-problems)
- [Secret Management Issues](#secret-management-issues)
- [Shell Configuration Problems](#shell-configuration-problems)
- [Editor and Tool Issues](#editor-and-tool-issues)
- [Network and Connectivity](#network-and-connectivity)
- [Permission Problems](#permission-problems)
- [Performance Issues](#performance-issues)
- [Debugging Procedures](#debugging-procedures)
- [Recovery Procedures](#recovery-procedures)
- [Common Error Messages](#common-error-messages)

## Quick Diagnostic Commands

### System Health Check
```bash
# Run comprehensive diagnostics
./scripts/bootstrap.sh doctor

# Quick health check
./scripts/quick-health-check.sh

# Check system compatibility
./scripts/check-system-compatibility.sh
```

### Component-Specific Diagnostics
```bash
# Shell diagnostics
echo "Shell: $SHELL"
echo "Startup time: ${SHELL_STARTUP_TIME:-unknown}ms"
zsh -i -c 'zprof' | head -10

# Package manager health
./scripts/validate-package-managers.sh

# Secret management check
./scripts/verify-secrets.sh --verbose

# Symlink validation
./scripts/validate-symlinks.sh

# Terminal configuration check
./scripts/validate-terminals.sh
```

### Environment Information
```bash
# System information
uname -a
echo "OS: $(./scripts/lib/detect-os.sh && detect_os_type)"
echo "Architecture: $(./scripts/lib/detect-os.sh && detect_architecture)"
echo "Package Manager: $(./scripts/lib/detect-os.sh && detect_package_manager)"

# Tool versions
git --version
stow --version
op --version 2>/dev/null || echo "1Password CLI not installed"
```

## Installation Issues

### Bootstrap Failures

#### Issue: Bootstrap script fails to start
```bash
# Check script permissions
ls -la scripts/bootstrap.sh
# Fix permissions if needed
chmod +x scripts/bootstrap.sh

# Check shell compatibility
bash --version
# Ensure bash 3.2+ or zsh 5.0+

# Run with verbose output
./scripts/bootstrap.sh --verbose install
```

#### Issue: Git clone failures
```bash
# Check Git installation
git --version || {
    echo "Git not installed"
    # macOS: xcode-select --install
    # Linux: sudo apt install git / sudo dnf install git
}

# Check network connectivity
ping -c 3 github.com

# Use HTTPS instead of SSH if needed
git config --global url."https://github.com/".insteadOf git@github.com:
```

#### Issue: Permission denied during installation
```bash
# Check write permissions
ls -la ~/git/
mkdir -p ~/git/ 2>/dev/null || {
    echo "Cannot create ~/git/ directory"
    sudo chown -R $(whoami) ~/git/
}

# Check sudo access for package installation
sudo -v || echo "Sudo access required for package installation"
```

### Package Manager Issues

#### Issue: Homebrew installation fails (macOS)
```bash
# Check Xcode Command Line Tools
xcode-select -p || xcode-select --install

# Check disk space
df -h / | awk 'NR==2 {print $4}'

# Manual Homebrew installation
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH
if [[ $(uname -m) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi
```

#### Issue: Linux package manager fails
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y
sudo apt install -f  # Fix broken packages

# Fedora
sudo dnf clean all
sudo dnf update -y

# Check for conflicting packages
./scripts/check-package-conflicts.sh

# Repository issues
sudo apt update --fix-missing  # Ubuntu/Debian
sudo dnf clean metadata && sudo dnf makecache  # Fedora
```

#### Issue: GNU Stow installation problems
```bash
# Check if Stow is available in package manager
brew info stow  # macOS
apt policy stow  # Ubuntu/Debian
dnf info stow   # Fedora

# Compile from source if needed
wget http://ftp.gnu.org/gnu/stow/stow-latest.tar.gz
tar xzf stow-latest.tar.gz
cd stow-*
./configure --prefix=$HOME/.local
make && make install
export PATH="$HOME/.local/bin:$PATH"
```

### Symlink Creation Issues

#### Issue: Stow conflicts with existing files
```bash
# Check for conflicts
stow --simulate --dir=~/git/dotfiles --target=~ home

# Backup existing files
./scripts/backup-existing-configs.sh

# Force stow (after backup)
stow --dir=~/git/dotfiles --target=~ --adopt home
git checkout -- .  # Restore original files
```

#### Issue: Broken symlinks
```bash
# Find broken symlinks
find ~ -type l -exec test ! -e {} \; -print 2>/dev/null

# Remove broken symlinks
find ~ -type l -exec test ! -e {} \; -delete 2>/dev/null

# Recreate symlinks
./scripts/bootstrap.sh repair
```

## Platform-Specific Problems

### macOS Issues

#### Issue: Apple Silicon compatibility
```bash
# Check architecture
uname -m  # Should show arm64 for Apple Silicon

# Use correct Homebrew path
if [[ $(uname -m) == "arm64" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
else
    export PATH="/usr/local/bin:$PATH"
fi

# Install Rosetta 2 if needed
sudo softwareupdate --install-rosetta
```

#### Issue: macOS System Integrity Protection (SIP)
```bash
# Check SIP status
csrutil status

# Some operations may require SIP disabled for system directories
# WARNING: Only disable SIP if absolutely necessary
# Boot to Recovery Mode: Command+R during startup
# csrutil disable  # In Recovery Mode terminal
```

#### Issue: macOS Gatekeeper blocking scripts
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine scripts/bootstrap.sh

# Or allow in System Preferences > Security & Privacy
```

#### Issue: macOS defaults not applying
```bash
# Check defaults domain
defaults domains | grep -o '[a-zA-Z0-9.]*' | sort

# Apply with elevated privileges if needed
sudo ./os/macos/defaults.sh

# Restart required for some changes
sudo reboot
```

### Linux Distribution Issues

#### Issue: Ubuntu/Debian package conflicts
```bash
# Fix broken packages
sudo apt --fix-broken install

# Remove conflicting packages
sudo apt remove --purge conflicting-package

# Update package database
sudo apt update && sudo apt upgrade

# Check PPA issues
sudo apt-key list
sudo add-apt-repository --remove ppa:problematic/ppa
```

#### Issue: Fedora/RHEL package issues
```bash
# Clean package cache
sudo dnf clean all

# Update package database
sudo dnf makecache

# Fix dependency issues
sudo dnf distro-sync

# Enable additional repositories
sudo dnf install epel-release  # RHEL/CentOS
```

#### Issue: Arch Linux package conflicts
```bash
# Update system
sudo pacman -Syu

# Fix keyring issues
sudo pacman -S archlinux-keyring

# Check for partial upgrades
pacman -Qkk

# Rebuild package database
sudo pacman-db-upgrade
```

### WSL (Windows Subsystem for Linux) Issues

#### Issue: WSL filesystem permissions
```bash
# Fix WSL mount options
sudo umount /mnt/c
sudo mount -t drvfs C: /mnt/c -o metadata,umask=22,fmask=11

# Or add to /etc/fstab
echo "C: /mnt/c drvfs rw,noatime,uid=1000,gid=1000,metadata,umask=22,fmask=11 0 0" | sudo tee -a /etc/fstab
```

#### Issue: WSL network connectivity
```bash
# Reset WSL network
wsl --shutdown  # From Windows PowerShell
# Restart WSL

# Check DNS resolution
nslookup github.com
cat /etc/resolv.conf

# Fix DNS if needed
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

## Secret Management Issues

### 1Password CLI Problems

#### Issue: 1Password CLI not authenticated
```bash
# Check authentication status
op whoami || echo "Not authenticated"

# Sign in
op signin

# Check account configuration
op account list

# Force re-authentication
op signin --force
```

#### Issue: 1Password CLI installation problems
```bash
# macOS installation
brew install --cask 1password-cli

# Linux installation (Ubuntu/Debian)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list

sudo apt update && sudo apt install 1password-cli

# Verify installation
op --version
```

#### Issue: Secret injection failures
```bash
# Debug secret access
./scripts/verify-secrets.sh --verbose

# Check template syntax
./scripts/validate-templates.sh

# Manual secret testing
op item get "Git Identity" --field name

# Re-inject with debugging
CURRENT_LOG_LEVEL=0 ./scripts/inject-secrets.sh config.template
```

#### Issue: 1Password vault access denied
```bash
# List available vaults
op vault list

# Check vault permissions
op item list --vault "Personal"

# Switch accounts if needed
op account list
op signin --account work
```

### Template Processing Issues

#### Issue: Template syntax errors
```bash
# Validate template syntax
./scripts/validate-templates.sh config.template

# Check for common issues
grep -n "{{" config.template  # Look for malformed references
grep -n "}}" config.template

# Test with debug output
./scripts/inject-secrets.sh --dry-run --verbose config.template
```

#### Issue: Secret references not found
```bash
# List all secret references
./scripts/list-secret-references.sh

# Check if secret exists in 1Password
op item get "Secret Name"

# Update secret reference
op item edit "Secret Name" --field "field_name=new_value"
```

## Shell Configuration Problems

### Zsh Issues

#### Issue: Slow shell startup
```bash
# Profile startup time
time zsh -i -c exit

# Check startup time details
zsh -xvs

# Profile with zprof
zsh -i -c 'zprof' | head -20

# Disable plugins one by one
# Edit ~/.zshrc and comment out plugins
```

#### Issue: Oh My Zsh problems
```bash
# Update Oh My Zsh
$ZSH/tools/upgrade.sh

# Reset Oh My Zsh configuration
cp $ZSH/templates/zshrc.zsh-template ~/.zshrc

# Fix permissions
chmod 755 $ZSH
chmod 644 $ZSH/oh-my-zsh.sh
```

#### Issue: Plugin conflicts
```bash
# Disable all plugins
sed -i 's/^plugins=.*/plugins=()/' ~/.zshrc

# Test with minimal config
zsh --no-rcs

# Enable plugins one by one
plugins=(git)  # Start with essential plugins only
```

### Bash Issues

#### Issue: Bash compatibility problems
```bash
# Check Bash version
bash --version

# Use POSIX mode for compatibility
set +o posix

# Check for bash-specific features
grep -n "bash" ~/.bashrc
```

#### Issue: Environment variable issues
```bash
# Check variable loading
set | grep DOTFILES

# Debug variable expansion
set -x
source ~/.bashrc
set +x

# Check for variable conflicts
env | sort | uniq -c | sort -nr
```

## Editor and Tool Issues

### Neovim Issues

#### Issue: Neovim configuration errors
```bash
# Check Neovim health
nvim +checkhealth +qa

# Test with minimal config
nvim -u NONE

# Check plugin manager
nvim +PlugStatus +qa

# Reinstall plugins
nvim +PlugClean! +PlugInstall +qa
```

#### Issue: LSP (Language Server Protocol) problems
```bash
# Check LSP server installation
which pyright  # Python
which typescript-language-server  # TypeScript
which lua-language-server  # Lua

# Check LSP logs
tail -f ~/.local/share/nvim/lsp.log

# Restart LSP
nvim +LspRestart
```

### Git Issues

#### Issue: Git configuration problems
```bash
# Check Git configuration
git config --list --show-origin

# Verify GPG signing
git config --get user.signingkey
gpg --list-secret-keys

# Test Git operations
git status
git log --oneline -5
```

#### Issue: SSH key authentication
```bash
# Test SSH connection
ssh -T git@github.com

# Check SSH key
ssh-add -l

# Add SSH key
ssh-add ~/.ssh/id_ed25519

# Check SSH config
cat ~/.ssh/config
```

### Development Tool Issues

#### Issue: Node.js version manager problems
```bash
# Check nvm installation
command -v nvm

# Reload nvm
source ~/.nvm/nvm.sh

# List installed versions
nvm list

# Install latest LTS
nvm install --lts
nvm use --lts
```

#### Issue: Python environment issues
```bash
# Check Python installation
python3 --version
which python3

# Check pip
pip3 --version

# Virtual environment issues
python3 -m venv test-env
source test-env/bin/activate
```

## Network and Connectivity

### General Network Issues

#### Issue: Package download failures
```bash
# Check internet connectivity
ping -c 3 8.8.8.8

# Check DNS resolution
nslookup github.com

# Test specific package sources
curl -I https://github.com
curl -I https://raw.githubusercontent.com
```

#### Issue: Proxy configuration
```bash
# Check proxy settings
echo $HTTP_PROXY
echo $HTTPS_PROXY
echo $NO_PROXY

# Configure Git for proxy
git config --global http.proxy http://proxy.company.com:8080
git config --global https.proxy https://proxy.company.com:8080

# Configure package managers for proxy
# For apt: edit /etc/apt/apt.conf
# For brew: export ALL_PROXY=proxy.company.com:8080
```

#### Issue: SSL/TLS certificate problems
```bash
# Check certificate bundle
curl --version

# Update certificates
# macOS: brew install ca-certificates
# Ubuntu: sudo apt update && sudo apt install ca-certificates
# Fedora: sudo dnf update ca-certificates

# Test specific URL
curl -v https://github.com
```

### Corporate Environment Issues

#### Issue: Firewall blocking downloads
```bash
# Use corporate package mirror
# Configure package manager to use internal mirrors

# For Ubuntu/Debian
sudo sed -i 's|http://archive.ubuntu.com|http://internal-mirror.company.com|g' /etc/apt/sources.list

# For Homebrew
export HOMEBREW_BOTTLE_DOMAIN=http://internal-mirror.company.com/homebrew
```

#### Issue: VPN connectivity
```bash
# Check VPN connection
ip route show
ifconfig | grep tun  # Look for VPN interface

# Test internal resources
ping internal.company.com

# Check split tunneling
traceroute github.com
```

## Permission Problems

### File Permission Issues

#### Issue: Permission denied errors
```bash
# Check file permissions
ls -la ~/.ssh/
ls -la ~/.config/

# Fix SSH permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub
chmod 644 ~/.ssh/config

# Fix config permissions
find ~/.config -type d -exec chmod 755 {} \;
find ~/.config -type f -exec chmod 644 {} \;
```

#### Issue: Sudo permission problems
```bash
# Check sudo access
sudo -v

# Check sudoers configuration
sudo visudo -c

# Add user to sudo group
sudo usermod -aG sudo $USER  # Ubuntu/Debian
sudo usermod -aG wheel $USER # Fedora/RHEL
```

#### Issue: Ownership problems
```bash
# Check ownership
ls -la ~/git/dotfiles

# Fix ownership
sudo chown -R $(whoami):$(id -gn) ~/git/dotfiles

# Fix group permissions
find ~/git/dotfiles -type d -exec chmod g+s {} \;
```

## Performance Issues

### Shell Performance

#### Issue: Slow shell startup (>500ms)
```bash
# Measure startup time
time zsh -i -c exit

# Profile startup
zsh -xvs 2>&1 | head -50

# Common fixes:
# 1. Reduce number of plugins
# 2. Use lazy loading for plugins
# 3. Clean up PATH
echo $PATH | tr ':' '\n' | nl

# 4. Remove duplicate entries
export PATH=$(echo "$PATH" | awk -v RS=':' '!a[$1]++' | paste -sd:)
```

#### Issue: High memory usage
```bash
# Check shell memory usage
ps aux | grep -E "(zsh|bash)" | head -10

# Check for memory leaks
valgrind --tool=memcheck zsh -i -c exit

# Profile shell functions
./scripts/profile-shell-functions.sh
```

### System Performance

#### Issue: High disk usage
```bash
# Check disk usage
du -sh ~/git/dotfiles
du -sh ~/.config
du -sh ~/.cache

# Clean up
./scripts/clean-temp-files.sh
./scripts/cleanup-old-backups.sh

# Check for large files
find ~ -size +100M -type f 2>/dev/null | head -10
```

#### Issue: Network latency affecting operations
```bash
# Check network latency
ping -c 10 github.com

# Use offline mode when possible
./scripts/bootstrap.sh --offline update

# Enable caching
export HOMEBREW_NO_AUTO_UPDATE=1
```

## Debugging Procedures

### Systematic Debugging Approach

#### Step 1: Gather Information
```bash
# Create debug report
./scripts/create-debug-report.sh > debug-report.txt

# Check system state
./scripts/bootstrap.sh doctor > doctor-report.txt

# Check recent changes
git log --oneline -10
```

#### Step 2: Isolate the Problem
```bash
# Test minimal configuration
mv ~/.zshrc ~/.zshrc.bak
echo 'export PS1="$ "' > ~/.zshrc
exec zsh

# Test individual components
./scripts/test-component.sh shell
./scripts/test-component.sh git
./scripts/test-component.sh ssh
```

#### Step 3: Enable Debug Mode
```bash
# Shell debugging
set -x
source ~/.zshrc
set +x

# Script debugging
CURRENT_LOG_LEVEL=0 ./scripts/bootstrap.sh doctor

# Verbose output
./scripts/bootstrap.sh --verbose doctor
```

#### Step 4: Check Logs
```bash
# Check system logs
# macOS: Console.app or /var/log/system.log
# Linux: journalctl or /var/log/syslog

# Check application logs
tail -f ~/.local/share/nvim/lsp.log
tail -f ~/.cache/dotfiles/error.log
```

### Advanced Debugging Techniques

#### Network Debugging
```bash
# Trace network calls
strace -e trace=network command

# Monitor DNS queries
sudo tcpdump -i any port 53

# Check open connections
netstat -an | grep ESTABLISHED
```

#### File System Debugging
```bash
# Trace file operations
strace -e trace=file command

# Monitor file changes
fswatch ~/.config | head -20

# Check inode usage
df -i
```

## Recovery Procedures

### Emergency Recovery

#### Step 1: Minimal Shell Recovery
```bash
# Reset to basic shell
export PS1='$ '
export PATH="/usr/local/bin:/usr/bin:/bin"
unalias -a
```

#### Step 2: Restore from Backup
```bash
# Quick backup restoration
./scripts/restore-from-backup.sh ~/.dotfiles-backups/latest

# Git reset to known good state
cd ~/git/dotfiles
git status
git stash
git reset --hard origin/main
```

#### Step 3: Rebuild from Scratch
```bash
# Complete rebuild
./scripts/bootstrap.sh uninstall
rm -rf ~/git/dotfiles
git clone https://github.com/username/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
./scripts/bootstrap.sh install
```

### Safe Mode Operations

#### Minimal Environment Setup
```bash
# Create safe environment
export DOTFILES_SAFE_MODE=1
export PATH="/usr/local/bin:/usr/bin:/bin"
export PS1='[SAFE] $ '

# Test basic operations
which git
which stow
git --version
```

## Common Error Messages

### Error: "command not found"
```bash
# Solution: Check PATH and install missing tools
echo $PATH
which command-name
./scripts/install-tools.sh

# For specific tools:
# Git: xcode-select --install (macOS) or sudo apt install git
# Stow: brew install stow or sudo apt install stow
# 1Password CLI: brew install 1password-cli
```

### Error: "Permission denied"
```bash
# Solution: Fix file permissions
chmod +x scripts/bootstrap.sh
sudo chown -R $(whoami) ~/git/dotfiles

# For SSH keys:
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
```

### Error: "No such file or directory"
```bash
# Solution: Check file paths and symlinks
ls -la target-file
find . -name "filename"
./scripts/validate-symlinks.sh
```

### Error: "Operation not permitted"
```bash
# Solution: Check system protection settings
# macOS SIP: csrutil status
# SELinux: getenforce
# File attributes: lsattr filename
```

### Error: "Network unreachable"
```bash
# Solution: Check network connectivity
ping -c 3 8.8.8.8
curl -I https://github.com
# Check proxy settings and firewall
```

### Error: "Authentication failed"
```bash
# Solution: Re-authenticate services
op signin --force
ssh-add ~/.ssh/id_ed25519
git config --get user.email
```

---

## Getting Help

### Debug Information to Collect

When seeking help, provide:
```bash
# System information
uname -a
./scripts/bootstrap.sh doctor

# Error details
command 2>&1 | tee error.log

# Configuration state
git status
git log --oneline -5

# Tool versions
git --version
stow --version
op --version
```

### Support Channels

1. **Self-diagnosis**: Use built-in doctor mode
2. **Documentation**: Check relevant docs in `docs/`
3. **GitHub Issues**: Create issue with debug information
4. **Community**: Check existing issues and discussions

---

## Related Documentation

- [Maintenance Procedures](maintenance.md)
- [Backup and Recovery](backup.md)
- [Migration Guide](migration.md)
- [Security Documentation](secrets.md)
- [Installation Guide](installation.md) 