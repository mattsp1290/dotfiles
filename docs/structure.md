# Repository Structure

This document provides a detailed explanation of the dotfiles repository structure and organization principles.

## Overview

The repository follows a modular, Stow-compatible structure that separates concerns while maintaining cross-platform compatibility.

## Directory Structure

### `/config/`
Contains configurations that follow the XDG Base Directory specification. These files will be symlinked to `$XDG_CONFIG_HOME` (typically `~/.config/`).

```
config/
├── git/        # Git configuration
├── nvim/       # Neovim configuration
├── alacritty/  # Alacritty terminal
└── kitty/      # Kitty terminal
```

### `/home/`
Contains files that should be symlinked directly to the user's home directory. Use sparingly - prefer XDG locations when possible.

```
home/
├── .zshrc      # Zsh configuration (if not using XDG)
└── .tmux.conf  # Tmux configuration
```

### `/shell/`
Shell-specific configurations organized by shell type with modular components.

```
shell/
├── zsh/
│   ├── .zshrc           # Main Zsh config
│   ├── .zshenv          # Environment variables
│   └── modules/         # Modular components
│       ├── aliases.zsh
│       ├── functions.zsh
│       └── prompt.zsh
├── bash/
│   └── modules/
└── fish/
    └── modules/
```

### `/scripts/`
Installation, setup, and utility scripts.

```
scripts/
├── bootstrap.sh    # Main installation script
├── install.sh      # Component installer
├── lib/           # Shared functions
│   ├── common.sh
│   └── logging.sh
├── setup/         # Component-specific installers
│   ├── macos.sh
│   ├── linux.sh
│   └── tools.sh
└── utils/         # Utility scripts
    └── clean.sh
```

### `/templates/`
Template files that require processing before installation. Uses `{{VARIABLE}}` syntax for substitution.

```
templates/
├── gitconfig.tmpl
└── ssh_config.tmpl
```

### `/os/`
Operating system-specific configurations and scripts.

```
os/
├── macos/
│   ├── defaults/    # macOS defaults scripts
│   └── homebrew/    # Brewfile and related
└── linux/
    ├── apt/         # Debian/Ubuntu packages
    ├── dnf/         # Fedora packages
    └── pacman/      # Arch packages
```

### `/docs/`
Documentation and architecture decision records.

```
docs/
├── structure.md      # This file
├── installation.md   # Installation guide
├── contributing.md   # Contribution guidelines
├── adr/             # Architecture Decision Records
│   ├── 001-use-stow.md
│   └── 002-xdg-compliance.md
└── guides/          # How-to guides
    └── adding-tools.md
```

### `/tests/`
Test suites for validation.

```
tests/
├── unit/           # Unit tests
│   └── stow_test.sh
└── integration/    # Integration tests
    └── install_test.sh
```

## Naming Conventions

### Directories
- Use lowercase with hyphens: `my-tool/`
- Group related tools: `dev-tools/`

### Files
- Shell scripts: Use `.sh` extension
- Config files: Match tool expectations
- Documentation: Use `.md` extension
- Templates: Use `.tmpl` extension

### Scripts
- Executable scripts: Use underscores: `install_packages.sh`
- Library files: Use descriptive names: `logging.sh`

## Stow Package Structure

Each Stow package should mirror the target directory structure:

```
package-name/
├── .config/          # → ~/.config/
│   └── tool/         # → ~/.config/tool/
├── .local/           # → ~/.local/
│   └── bin/          # → ~/.local/bin/
└── .toolrc           # → ~/.toolrc
```

## Best Practices

### 1. XDG Compliance
Prefer XDG Base Directory locations:
- Configuration: `$XDG_CONFIG_HOME` (`~/.config`)
- Data: `$XDG_DATA_HOME` (`~/.local/share`)
- Cache: `$XDG_CACHE_HOME` (`~/.cache`)

### 2. Modularity
- Keep configurations modular and composable
- Use separate files for aliases, functions, exports
- Source modules from main configuration files

### 3. Platform Handling
- Use OS-specific directories for platform code
- Implement detection in scripts
- Provide graceful fallbacks

### 4. Documentation
- Every directory should have a README
- Document non-obvious decisions
- Include examples where helpful

### 5. Security
- Never commit secrets
- Use templates for sensitive values
- Document required secrets

## Adding New Tools

1. Determine the appropriate location:
   - XDG-compliant? → `/config/tool-name/`
   - Home directory? → `/home/`
   - Shell-specific? → `/shell/{shell}/`

2. Create the directory structure

3. Add installation logic to `/scripts/setup/`

4. Update documentation

5. Add tests if applicable

## Examples

### Adding a new XDG-compliant tool:
```bash
mkdir -p config/toolname
# Add configuration files
# Update scripts/setup/tools.sh
```

### Adding shell aliases:
```bash
# Add to shell/zsh/modules/aliases.zsh
# Will be sourced by shell/zsh/.zshrc
```

### Adding OS-specific configuration:
```bash
# macOS: os/macos/defaults/toolname.sh
# Linux: os/linux/configs/toolname.conf
```
