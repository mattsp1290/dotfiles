# Installation Guide

This guide covers the installation process for the dotfiles repository.

## Prerequisites

- Git
- A POSIX-compliant shell (bash, zsh, etc.)
- Administrative privileges for installing packages

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles

# Run the bootstrap script
./scripts/bootstrap.sh
```

## Manual Installation

### 1. Install Dependencies

#### macOS
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install GNU Stow
brew install stow
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install stow
```

#### Linux (Fedora)
```bash
sudo dnf install stow
```

#### Linux (Arch)
```bash
sudo pacman -S stow
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
```

### 3. Run Stow

```bash
# Install all configurations
stow -v -R -t ~ */

# Or install specific packages
stow -v -R -t ~ config shell
```

## Configuration

### Environment Variables

Set these in your shell profile:

```bash
export DOTFILES_HOME="$HOME/git/dotfiles"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
```

### Secret Management

This repository uses 1Password CLI for secret management. Install and configure it:

```bash
# Install 1Password CLI
# macOS
brew install 1password-cli

# Linux - see https://developer.1password.com/docs/cli/get-started/

# Sign in
op signin
```

## Uninstallation

To remove the symlinks:

```bash
cd ~/git/dotfiles
stow -D */
```

## Troubleshooting

### Stow Conflicts

If you encounter conflicts:

```bash
# Check what would be changed
stow -n -v -R -t ~ config

# Force restow (backup existing files first!)
stow -v -R -t ~ --adopt config
```

### Missing Dependencies

The bootstrap script will check for and install missing dependencies automatically.

## Next Steps

- Review the [Structure Guide](structure.md)
- Customize configurations in the appropriate directories
- See [Contributing Guide](contributing.md) for making changes
