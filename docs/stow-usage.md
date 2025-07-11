# Stow Usage Guide

This guide explains how to use the GNU Stow-based dotfiles management system.

## Quick Start

```bash
# Install all platform-appropriate packages
./scripts/stow-all.sh

# See what would be stowed (dry run)
./scripts/stow-all.sh --dry-run

# List available packages
./scripts/stow-all.sh --list

# Install specific packages
./scripts/stow-all.sh config/git shell/zsh

# Remove all symlinks
./scripts/unstow-all.sh
```

## Understanding Packages

Our dotfiles are organized into logical packages:

### Package Structure
```
config/           # XDG_CONFIG_HOME applications (~/.config)
├── git/         # Git configuration (.gitconfig, .gitignore_global)
├── nvim/        # Neovim configuration (init.lua)
├── alacritty/   # Alacritty terminal config
└── kitty/       # Kitty terminal config

shell/           # Shell-specific configurations
├── zsh/         # Zsh configuration (.zshrc)
├── bash/        # Bash configuration (.bashrc)
├── fish/        # Fish shell configuration
└── shared/      # Shared shell utilities (aliases.zsh)

os/              # OS-specific configurations
├── macos/       # macOS-specific configs
└── linux/       # Linux-specific configs

home/            # Direct $HOME files (use sparingly)
└── .profile     # Shell-agnostic profile
```

### How Stow Works

When you stow a package, Stow creates symlinks in your home directory:

```bash
# After stowing config/git:
~/.config/git/.gitconfig -> ~/git/dotfiles/config/git/.gitconfig
~/.config/git/.gitignore_global -> ~/git/dotfiles/config/git/.gitignore_global

# After stowing shell/zsh:
~/.zshrc -> ~/git/dotfiles/shell/zsh/.zshrc
```

## Command Reference

### Main Script: `./scripts/stow-all.sh`

```bash
# Basic usage
./scripts/stow-all.sh [OPTIONS] [PACKAGES...]

# Options
-h, --help              Show help message
-n, --dry-run           Simulate operations without making changes
-v, --verbose           Enable verbose output
-f, --force             Force stow (backs up conflicts)
-a, --adopt             Adopt existing files into repository
-l, --list              List available packages and exit
-m, --mode MODE         Stow mode: auto (default), all, select
-t, --target DIR        Set target directory (default: $HOME)
-d, --dir DIR           Set stow directory (default: repository root)
```

### Stow Modes

1. **Auto Mode (default)**: Stows platform-appropriate packages
   ```bash
   ./scripts/stow-all.sh
   ```

2. **All Mode**: Stows all available packages
   ```bash
   ./scripts/stow-all.sh -m all
   ```

3. **Select Mode**: Interactive package selection
   ```bash
   ./scripts/stow-all.sh -m select
   ```

## Common Operations

### First-Time Installation

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles

# 2. Run bootstrap (installs Stow and dependencies)
./scripts/bootstrap.sh

# 3. Install dotfiles
./scripts/stow-all.sh
```

### Adding Existing Configuration

If you already have dotfiles, you can adopt them:

```bash
# Adopt existing configurations
./scripts/stow-all.sh --adopt config/git

# This will move your existing ~/.gitconfig into the repository
# and create a symlink pointing to it
```

### Selective Installation

```bash
# Install only specific packages
./scripts/stow-all.sh config/git config/nvim shell/zsh

# Interactive selection
./scripts/stow-all.sh -m select

# Install all packages
./scripts/stow-all.sh -m all
```

### Handling Conflicts

When Stow detects existing files that would conflict:

```bash
# Check for conflicts without making changes
./scripts/stow-all.sh --dry-run

# Force stow (backs up existing files first)
./scripts/stow-all.sh --force

# Adopt existing files into the repository
./scripts/stow-all.sh --adopt
```

### Updating Configurations

After making changes to your dotfiles:

```bash
# Changes are immediately reflected (files are symlinked)
# Just commit your changes:
git add -A
git commit -m "Update configurations"
git push
```

### Removing Dotfiles

```bash
# Remove all symlinks
./scripts/unstow-all.sh

# Remove specific packages
./scripts/unstow-all.sh config/git shell/zsh

# Dry run to see what would be removed
./scripts/unstow-all.sh --dry-run
```

## Package Development

### Creating a New Package

1. **Create the package directory**:
   ```bash
   mkdir -p config/myapp
   ```

2. **Add configuration files**:
   ```bash
   # For ~/.config/myapp/config.yaml
   echo "setting: value" > config/myapp/config.yaml
   ```

3. **Test the package**:
   ```bash
   ./scripts/stow-all.sh --dry-run config/myapp
   ```

4. **Stow the package**:
   ```bash
   ./scripts/stow-all.sh config/myapp
   ```

### Package Guidelines

- **Use XDG locations**: Prefer `config/` over `home/`
- **Group related files**: Keep all Git configs in `config/git`
- **Platform-specific**: Use `os/macos/` or `os/linux/` for OS-specific files
- **Shell-agnostic**: Put shared shell utilities in `shell/shared/`

### Migrating Existing Dotfiles

1. **Backup existing files**:
   ```bash
   cp ~/.gitconfig ~/.gitconfig.backup
   ```

2. **Move to package structure**:
   ```bash
   mv ~/.gitconfig config/git/.gitconfig
   ```

3. **Stow with adoption**:
   ```bash
   ./scripts/stow-all.sh --adopt config/git
   ```

## Troubleshooting

### Common Issues

1. **Conflicts with existing files**:
   ```bash
   # Use --adopt to incorporate existing files
   ./scripts/stow-all.sh --adopt config/git
   
   # Or force stow to backup conflicts
   ./scripts/stow-all.sh --force config/git
   ```

2. **Broken symlinks**:
   ```bash
   # Remove and re-stow
   ./scripts/unstow-all.sh config/git
   ./scripts/stow-all.sh config/git
   ```

3. **Package not found**:
   ```bash
   # Check available packages
   ./scripts/stow-all.sh --list
   ```

### Debug Mode

```bash
# Enable verbose output
./scripts/stow-all.sh --verbose --dry-run

# Check what Stow would do directly
stow -n -v -d config -t ~ git
```

### Validation

```bash
# Test the system
./scripts/test-dotfiles.sh

# Check for broken symlinks
find ~ -type l -exec test ! -e {} \; -print 2>/dev/null
```

## Environment Variables

```bash
# Override default directories
export STOW_DIR="$HOME/my-dotfiles"
export STOW_TARGET="$HOME"

# Enable verbose mode
export STOW_VERBOSE=1

# Enable dry-run mode
export STOW_SIMULATE=1
```

## Best Practices

1. **Always test first**: Use `--dry-run` before actual operations
2. **Backup important files**: Before adopting or forcing
3. **Use version control**: Commit changes regularly
4. **Test on clean systems**: Validate your dotfiles work from scratch
5. **Document custom packages**: Add README files for complex configurations
6. **Handle secrets properly**: Never commit secrets to the repository

## Examples

### Daily Workflow

```bash
# Morning: Update dotfiles
cd ~/git/dotfiles
git pull

# Make changes to configurations
vim config/nvim/init.lua

# Test changes
./scripts/stow-all.sh --dry-run

# Commit changes
git add -A
git commit -m "Update Neovim config"
git push
```

### Setting Up New Machine

```bash
# 1. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/git/dotfiles

# 2. Bootstrap system
cd ~/git/dotfiles
./scripts/bootstrap.sh

# 3. Install dotfiles
./scripts/stow-all.sh

# 4. Reload shell
exec $SHELL
```

### Sharing Configurations

```bash
# Export specific package
tar -czf vim-config.tar.gz config/nvim

# Import on another system
tar -xzf vim-config.tar.gz
./scripts/stow-all.sh config/nvim
``` 