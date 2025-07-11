# Zsh Configuration

This directory contains a modular, cross-platform zsh configuration that supports both macOS and Linux environments.

## Quick Start

### Installation

Using GNU Stow (recommended):
```bash
stow -t "$HOME" shell
```

Or create symlinks manually:
```bash
ln -sf "$PWD/.zshrc" "$HOME/.zshrc"
ln -sf "$PWD/.zshenv" "$HOME/.zshenv"  
ln -sf "$PWD/.zprofile" "$HOME/.zprofile"
```

### Testing

Test the configuration loads properly:
```bash
zsh -i -c 'echo "Configuration loaded successfully"'
```

Measure startup time:
```bash
time zsh -i -c exit
```

## Structure

```
.
├── .zshrc                 # Main configuration (sources modules)
├── .zshenv               # Environment variables (always loaded)
├── .zprofile             # Login shell configuration
├── .stow-local-ignore    # Files to ignore during stow
├── modules/              # Modular configuration files
│   ├── 00-init.zsh       # Basic zsh options and behavior
│   ├── 01-environment.zsh # Environment variables and tool config
│   ├── 02-path.zsh       # PATH management
│   ├── 03-aliases.zsh    # Command aliases
│   ├── 04-functions.zsh  # Custom shell functions
│   ├── 05-completion.zsh # Completion system configuration
│   ├── 06-prompt.zsh     # Oh My Zsh and Spaceship prompt
│   ├── 07-keybindings.zsh # Key bindings
│   ├── 08-plugins.zsh    # External plugin integration
│   └── 99-local.zsh      # Local overrides and final setup
├── os/                   # OS-specific configurations
│   ├── macos/           # macOS-specific overrides
│   └── linux/           # Linux-specific overrides
├── templates/           # Template files for secret injection
├── local/               # Local machine-specific files (git-ignored)
├── completions/         # Custom completion functions
├── functions/           # Additional function files
└── themes/              # Custom themes
```

## Module Loading Order

Modules are loaded in numerical order:

1. **00-init.zsh** - Sets up basic zsh options (history, completion, etc.)
2. **01-environment.zsh** - Exports environment variables and detects OS
3. **02-path.zsh** - Manages PATH for various tools and languages
4. **03-aliases.zsh** - Defines command aliases
5. **04-functions.zsh** - Custom shell functions and 1Password integration
6. **05-completion.zsh** - Completion system configuration
7. **06-prompt.zsh** - Oh My Zsh and Spaceship prompt setup
8. **07-keybindings.zsh** - Custom key bindings
9. **08-plugins.zsh** - External tool integrations and completions
10. **99-local.zsh** - Final setup and local overrides

## Features

### ✅ Cross-Platform Support
- Automatic macOS/Linux detection
- Conditional loading based on available tools
- Graceful degradation when tools are missing

### ✅ Oh My Zsh Integration  
- Full Oh My Zsh support with git plugin
- Spaceship prompt theme configuration
- Custom prompt ordering and settings

### ✅ Development Tool Support
- **Languages**: Go, Python, Node.js, Rust, Ruby
- **Version Managers**: pyenv, rbenv, nodenv, volta
- **Cloud Tools**: AWS CLI, Google Cloud SDK, kubectl, helm
- **Package Managers**: Homebrew, npm, pip, cargo

### ✅ Security
- 1Password CLI integration with account switching
- Secret injection system compatibility
- No hardcoded credentials or sensitive data

### ✅ Performance Optimized
- Conditional utility loading
- Fast OS detection
- Lazy loading for expensive operations
- Startup time under 3 seconds

### ✅ Customizable
- Local overrides via `~/.zshrc.local`
- Module-based architecture
- Easy to enable/disable features

## Key Functions

### File and Directory Utilities
- `mkcd <dir>` - Create directory and cd into it
- `extract <archive>` - Extract various archive formats
- `backup <file>` - Create timestamped backup
- `ff <name>` - Find files by name
- `fd <name>` - Find directories by name
- `grepf <pattern> [path]` - Recursive grep

### Git Helpers
- `gcom <message>` - Add all and commit with message
- `gpush` - Push with upstream tracking
- `gnew <branch>` - Create and switch to new branch

### Development Tools
- `httpserve [port]` - Start Python HTTP server (default port 8000)
- `json [file]` - Pretty print JSON
- `weather [location]` - Get weather info
- `listening` - Show listening ports

### 1Password CLI
- `op-signin [account]` - Sign in to 1Password account
- `op-work` - Switch to work account
- `op-personal` - Switch to personal account  
- `op-current` - Show current account status

## Customization

### Local Overrides

Create `~/.zshrc.local` for machine-specific settings:

```bash
# Custom environment variables
export CUSTOM_VAR="value"

# Custom aliases
alias ll='ls -la'
alias gs='git status'

# Custom functions
my_function() {
    echo "Custom functionality"
}

# Override module settings
SPACESHIP_PROMPT_ADD_NEWLINE=false
plugins=(git docker kubectl)
```

### Adding Custom Modules

1. Create `modules/XX-name.zsh` (XX = load order)
2. Include error handling and conditional logic
3. Follow the established patterns
4. Document the module's purpose

Example custom module:
```bash
# Custom Module - modules/50-custom.zsh
# Description: Custom functionality for this machine

# Only load if certain conditions are met
if [[ -d "/custom/path" ]]; then
    export CUSTOM_PATH="/custom/path"
    
    # Custom function
    custom_function() {
        echo "Custom functionality"
    }
fi
```

## Environment Variables

Key environment variables set by the configuration:

### Core Variables
- `DOTFILES_DIR` - Path to dotfiles repository
- `OS_TYPE` - Detected OS (macos/linux)
- `HOMEBREW_PREFIX` - Homebrew installation path

### XDG Base Directory
- `XDG_CONFIG_HOME` - User configuration directory
- `XDG_DATA_HOME` - User data directory
- `XDG_CACHE_HOME` - User cache directory

### Development Tools
- `GOPATH` - Go workspace path
- `CARGO_HOME` - Rust cargo home
- `VOLTA_HOME` - Node.js version manager
- `DATADOG_ROOT` - Datadog development root

### AWS Integration
- `AWS_VAULT_KEYCHAIN_NAME` - AWS vault keychain
- `AWS_SESSION_TTL` - Session timeout
- `AWS_ASSUME_ROLE_TTL` - Role assumption timeout

## Troubleshooting

### Common Issues

1. **Slow startup**: Use `zprof` to profile performance
2. **Missing PATH entries**: Check `02-path.zsh` and add to local config
3. **Function conflicts**: Rename custom functions to avoid conflicts
4. **Oh My Zsh errors**: Verify installation and plugin compatibility

### Performance Debugging

Enable profiling in `.zshrc`:
```bash
# Uncomment these lines
zmodload zsh/zprof
# ... configuration ...
zprof
```

### Verbose Loading

Debug module loading:
```bash
LOAD_DOTFILES_UTILS=1 zsh  # Enable utility loading
```

## Migration

For migrating from an existing zsh configuration, see:
- [`docs/shell-migration.md`](../../docs/shell-migration.md) - Complete migration guide
- [`scripts/migrate-zsh.sh`](../../scripts/migrate-zsh.sh) - Automated migration script

## Compatibility

### Supported Platforms
- **macOS**: 12.0+ (Monterey and later)
- **Linux**: Ubuntu 20.04+, Debian 11+, Fedora 36+, Arch Linux

### Required Tools
- **zsh**: 5.0+
- **GNU Stow**: For installation (recommended)

### Optional Tools
- **Oh My Zsh**: For enhanced prompt and plugins
- **Homebrew**: For macOS package management
- **1Password CLI**: For secret management

## Contributing

When modifying the configuration:

1. Test on both macOS and Linux if possible
2. Include error handling for missing tools
3. Document any new environment variables
4. Update this README for significant changes
5. Follow the established module patterns

For more information, see the [migration guide](../../docs/shell-migration.md). 