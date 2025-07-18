# Detailed Installation Guide

This guide provides comprehensive installation instructions for all supported platforms and scenarios.

## Prerequisites

**Required for all platforms:**
- Git 2.20+
- A POSIX-compliant shell (bash 3.2+, zsh 5.0+)
- Internet connection for initial setup
- Administrative privileges for package installation

**Platform-specific requirements automatically handled:**
- **macOS**: Xcode Command Line Tools, Homebrew
- **Linux**: Distribution package manager (apt, dnf, pacman)

## Installation Methods

### Method 1: One-Command Install (Recommended)

```bash
# Standard installation
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash

# With custom options
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash -s -- \
  --repo https://github.com/mattsp1290/dotfiles.git \
  --branch main \
  --directory ~/.dotfiles
```

### Method 2: Manual Installation

```bash
# 1. Clone repository
git clone https://github.com/mattsp1290/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles

# 2. Run bootstrap (interactive mode)
./scripts/bootstrap.sh

# 3. Or run with options
./scripts/bootstrap.sh --force --skip-packages --verbose
```

### Method 3: Advanced Installation

```bash
# Custom installation directory
export DOTFILES_DIR="$HOME/.config/dotfiles"
git clone https://github.com/mattsp1290/dotfiles.git "$DOTFILES_DIR"
cd "$DOTFILES_DIR"

# Selective component installation
./scripts/bootstrap.sh --components "shell,git,ssh" --dry-run
./scripts/bootstrap.sh --components "shell,git,ssh"
```

## Installation Options

| Option | Description | Example |
|--------|-------------|---------|
| `--force` | Non-interactive installation | `./bootstrap.sh --force` |
| `--dry-run` | Preview changes without applying | `./bootstrap.sh --dry-run` |
| `--verbose` | Detailed installation logging | `./bootstrap.sh --verbose` |
| `--components` | Install specific components only | `--components "shell,git"` |
| `--skip-packages` | Skip package manager installations | `--skip-packages` |
| `--skip-os-config` | Skip OS-specific configurations | `--skip-os-config` |
| `--backup` | Create backup before installation | `--backup ~/.dotfiles-backup` |

## Post-Installation Setup

### 1. Configure Secrets Management

```bash
# Install 1Password CLI (if not already installed)
# macOS
brew install 1password-cli

# Linux (Ubuntu/Debian)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

# Sign in to 1Password
op signin

# Test secret injection
dotfiles template-test
```

### 2. Customize Your Configuration

```bash
# Edit personal configuration
$EDITOR ~/.config/dotfiles/personal.yml

# Regenerate configurations with your settings
dotfiles regenerate

# Test shell configuration
source ~/.zshrc  # or ~/.bashrc
echo $SHELL_STARTUP_TIME
```

### 3. Verify Installation

```bash
# Run built-in diagnostics
dotfiles doctor

# Run test suite
make test

# Check performance
dotfiles benchmark
```

## Platform-Specific Installation

### macOS Installation

```bash
# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Install using Homebrew (recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash
```

### Linux Installation

#### Ubuntu/Debian
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y git curl zsh

# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash
```

#### Fedora
```bash
# Update system
sudo dnf update -y

# Install prerequisites
sudo dnf install -y git curl zsh

# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash
```

#### Arch Linux
```bash
# Update system
sudo pacman -Syu

# Install prerequisites
sudo pacman -S git curl zsh

# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash
```

## Troubleshooting Installation

### Common Issues

#### Permission Errors
```bash
# Fix permissions and retry
sudo chown -R $(whoami) ~/.dotfiles
chmod +x ~/.dotfiles/scripts/*.sh
./scripts/bootstrap.sh --force
```

#### Network Issues
```bash
# Use offline mode with pre-downloaded repository
git clone https://github.com/mattsp1290/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
./install.sh --offline
```

#### Package Manager Issues
```bash
# macOS: Homebrew issues
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew doctor

# Linux: Package manager cache issues
sudo apt update && sudo apt upgrade  # Ubuntu/Debian
sudo dnf clean all && sudo dnf update  # Fedora
```

### Debug Mode

```bash
# Enable comprehensive debugging
export DOTFILES_DEBUG=1
export SHELL_DEBUG=1
./scripts/bootstrap.sh --verbose 2>&1 | tee install.log
```

## Verification

After installation, verify everything is working:

```bash
# Check shell configuration
echo $SHELL
echo $SHELL_STARTUP_TIME

# Check installed tools
git --version
op --version
brew --version  # macOS
```

For more troubleshooting help, see [troubleshooting.md](troubleshooting.md).