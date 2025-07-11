# GNU Stow Guide for Dotfiles Management

This guide explains how we use GNU Stow to manage dotfiles in this repository, providing a clean and maintainable approach to symlink management.

## Table of Contents

- [Overview](#overview)
- [How Stow Works](#how-stow-works)
- [Repository Structure](#repository-structure)
- [Basic Usage](#basic-usage)
- [Common Operations](#common-operations)
- [Adding New Packages](#adding-new-packages)
- [Platform-Specific Configurations](#platform-specific-configurations)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Advanced Topics](#advanced-topics)

## Overview

GNU Stow is a symlink farm manager that provides an elegant solution for managing dotfiles. It works by creating symlinks from a "stow directory" (our repository) to a "target directory" (usually `$HOME`).

### Benefits of Using Stow

- **Simplicity**: Single command to install/remove configurations
- **Transparency**: Clear 1:1 mapping between repository and home directory
- **Flexibility**: Selective installation of configuration packages
- **Safety**: Built-in conflict detection prevents accidental overwrites
- **Version Control**: Keep all configs in git while deployed files are just symlinks

## How Stow Works

Stow treats each subdirectory in your repository as a "package" that can be independently managed. When you "stow" a package, it creates symlinks in the target directory that mirror the structure within the package.

### Example

If you have this structure in your repository:
```
dotfiles/
└── config/
    └── nvim/
        └── init.lua
```

Running `stow config` from the dotfiles directory will create:
```
~/.config/nvim/init.lua -> ~/dotfiles/config/nvim/init.lua
```

### Tree Folding

Stow uses an optimization called "tree folding" - if a directory only contains symlinks to files from the same package, Stow will replace it with a single symlink to the directory.

## Repository Structure

Our repository is organized into logical packages:

```
dotfiles/
├── config/          # XDG_CONFIG_HOME applications (~/.config)
│   ├── alacritty/   # Terminal emulator config
│   ├── git/         # Git configuration
│   ├── kitty/       # Kitty terminal config
│   └── nvim/        # Neovim configuration
├── home/            # Direct $HOME files (dotfiles in ~/)
├── shell/           # Shell-specific configurations
│   ├── bash/        # Bash configuration
│   ├── fish/        # Fish shell configuration
│   ├── shared/      # Shared shell utilities
│   └── zsh/         # Zsh configuration
└── os/              # OS-specific configurations
    ├── linux/       # Linux-specific configs
    └── macos/       # macOS-specific configs
```

### Package Naming Convention

- `config/` - For applications following XDG Base Directory spec
- `home/` - For traditional dotfiles that go directly in $HOME
- `shell/<name>/` - Shell-specific configurations
- `os/<platform>/` - Platform-specific configurations

## Basic Usage

### Installation (Stowing)

The primary script for installing dotfiles:

```bash
# Auto-detect and install platform-appropriate packages
./scripts/stow-all.sh

# Dry run to see what would happen
./scripts/stow-all.sh -n

# Install specific packages
./scripts/stow-all.sh config shell/zsh

# Force installation (backs up conflicts)
./scripts/stow-all.sh -f

# Adopt existing files into the repository
./scripts/stow-all.sh -a config
```

### Removal (Unstowing)

To remove installed symlinks:

```bash
# Remove all currently stowed packages
./scripts/unstow-all.sh

# Dry run
./scripts/unstow-all.sh -n

# Remove specific packages
./scripts/unstow-all.sh config shell/zsh

# List what's currently stowed
./scripts/unstow-all.sh -l
```

## Common Operations

### 1. First-Time Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Run bootstrap (installs Stow and other tools)
./scripts/bootstrap.sh

# Install dotfiles
./scripts/stow-all.sh
```

### 2. Updating Configurations

After making changes to your dotfiles:

```bash
# No need to restow - changes are reflected immediately
# Just commit your changes
git add -A
git commit -m "Update configurations"
git push
```

### 3. Adding Existing Configurations

To adopt existing dotfiles into the repository:

```bash
# Move existing config into repository structure
mv ~/.config/app ~/dotfiles/config/app

# Stow with adopt mode
./scripts/stow-all.sh -a config

# The original files are now adopted and symlinked
```

### 4. Selective Installation

Install only what you need:

```bash
# Interactive selection
./scripts/stow-all.sh -m select

# List available packages
./scripts/stow-all.sh -l

# Install specific packages
./scripts/stow-all.sh config/nvim shell/zsh
```

### 5. Handling Conflicts

When Stow detects existing files:

```bash
# Check for conflicts without making changes
./scripts/stow-all.sh -n

# Force stow (backs up existing files first)
./scripts/stow-all.sh -f

# Adopt existing files
./scripts/stow-all.sh -a
```

## Adding New Packages

### Step 1: Create Package Directory

```bash
# For a new application config
mkdir -p config/newapp

# For a home directory dotfile
mkdir -p home
```

### Step 2: Add Configuration Files

Place files in the package following the target structure:

```bash
# For ~/.config/newapp/config.yaml
echo "config: value" > config/newapp/config.yaml

# For ~/.bashrc
cp ~/.bashrc home/.bashrc
```

### Step 3: Stow the Package

```bash
# Stow just the new package
./scripts/stow-all.sh config/newapp

# Or restow everything
./scripts/stow-all.sh
```

### Step 4: Commit Changes

```bash
git add -A
git commit -m "Add newapp configuration"
```

## Platform-Specific Configurations

### Structure

Platform-specific configs are organized under `os/`:

```
os/
├── linux/
│   ├── .Xresources
│   └── .xinitrc
└── macos/
    ├── .config/
    │   └── karabiner/
    └── Library/
        └── Preferences/
```

### Automatic Detection

The stow scripts automatically detect your platform and install appropriate packages:

- On macOS: Installs `os/macos` if present
- On Linux: Installs `os/linux` if present

### Manual Control

```bash
# Install only macOS configs
./scripts/stow-all.sh os/macos

# Skip OS-specific configs
./scripts/stow-all.sh config shell/zsh
```

## Troubleshooting

### Common Issues

#### 1. "Conflict: existing target is not a symlink"

**Cause**: A real file exists where Stow wants to create a symlink.

**Solutions**:
```bash
# Option 1: Force stow (backs up existing)
./scripts/stow-all.sh -f

# Option 2: Adopt existing file
./scripts/stow-all.sh -a

# Option 3: Manually backup and remove
mv ~/.config/app ~/.config/app.backup
./scripts/stow-all.sh
```

#### 2. "Cannot stow: directory exists"

**Cause**: Target directory exists and contains non-stowable files.

**Solution**: Clean up the target directory or adopt files.

#### 3. Broken Symlinks

**Detection**:
```bash
# Find broken symlinks
find ~ -maxdepth 3 -type l ! -exec test -e {} \; -print
```

**Fix**:
```bash
# Restow packages
./scripts/stow-all.sh -f
```

#### 4. Permission Errors

**Cause**: Trying to stow to directories without write permission.

**Solution**: Fix permissions or use sudo (not recommended).

### Debug Mode

For detailed output:

```bash
# Verbose mode
./scripts/stow-all.sh -v

# Check what Stow would do
./scripts/stow-all.sh -n -v
```

## Best Practices

### 1. Organization

- **Logical Grouping**: Group related configs together
- **Consistent Naming**: Use lowercase, hyphen-separated names
- **Clear Structure**: Mirror the target directory structure

### 2. Version Control

- **Ignore Generated Files**: Add to `.stow-local-ignore`
- **Commit Regularly**: Track configuration changes
- **Document Changes**: Use meaningful commit messages

### 3. Portability

- **Use Variables**: For paths that differ between systems
- **Conditional Logic**: In shell configs for platform-specific settings
- **Separate Packages**: For incompatible configurations

### 4. Safety

- **Always Dry Run First**: Use `-n` flag before actual operations
- **Backup Important Configs**: Before major changes
- **Test on One Machine**: Before deploying everywhere

### 5. Maintenance

- **Regular Updates**: Keep configurations current
- **Clean Unused Packages**: Remove obsolete configurations
- **Document Custom Packages**: Add README files for complex setups

## Advanced Topics

### Custom Ignore Patterns

Edit `.stow-local-ignore` to exclude files from stowing:

```
# Documentation
README.*
*.md

# Backup files
*.backup
*.bak

# OS-specific files
.DS_Store
```

### Multiple Stow Directories

For complex setups, you can have multiple stow directories:

```bash
# Personal configs
stow -d ~/dotfiles/personal -t ~ personal-config

# Work configs
stow -d ~/dotfiles/work -t ~ work-config
```

### Stow Hooks

Create pre/post stow scripts:

```bash
# In scripts/setup/post-stow.sh
#!/bin/bash
# Run after stowing
echo "Rebuilding font cache..."
fc-cache -fv
```

### Nested Stow Directories

You can have packages within packages:

```
shell/
└── zsh/
    └── .config/
        └── zsh/
            ├── .zshrc
            └── plugins/
                └── stow/
                    └── custom-plugin/
```

### Environment-Specific Configs

Use symlinks or scripts to switch between environments:

```bash
# In config/git/
config -> config.personal  # Symlink to personal config

# Switch to work config
ln -sf config.work config
```

## Tips and Tricks

1. **Quick Edits**: Since configs are symlinked, edit either the repo file or the symlink - both update the same file

2. **Testing Changes**: Use a separate branch for experimental configurations

3. **Sharing Packages**: Extract common configs into a shared package that others can use

4. **Bootstrapping New Machines**: The bootstrap script handles everything including Stow installation

5. **Partial Stowing**: You can stow individual files by being more specific with paths

## Getting Help

- Run scripts with `-h` or `--help` for usage information
- Check GNU Stow manual: `man stow`
- See the [GNU Stow documentation](https://www.gnu.org/software/stow/manual/)
- File issues in the repository for problems specific to our setup 