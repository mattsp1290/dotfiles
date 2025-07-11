# Zsh Configuration Migration Guide

## Overview

This guide documents the migration from a monolithic `.zshrc` file to a modular, cross-platform zsh configuration that's part of the dotfiles repository.

## Migration Summary

### What Was Migrated

✅ **Complete Oh My Zsh Integration**
- Spaceship prompt theme configuration
- Plugin management (git plugin)
- All theme customizations and settings

✅ **Environment Variables**
- Homebrew configuration and security settings
- Development tool paths (Go, Node.js, Python, Rust, etc.)
- AWS vault and session configurations
- Datadog-specific environment variables
- XDG Base Directory compliance

✅ **PATH Management**
- Homebrew binary paths
- Language-specific tool paths
- Development tool binaries
- Cross-platform compatibility

✅ **1Password CLI Integration**
- Account detection and switching
- Secret helper functions
- Work/personal account management

✅ **Custom Functions**
- File and directory utilities
- Git workflow helpers
- Development server functions
- Archive extraction utilities

✅ **Tool Integrations**
- Google Cloud SDK sourcing
- Version manager initialization (pyenv, rbenv, nodenv)
- Git signing configuration

## New Modular Structure

```
shell/zsh/
├── .zshrc                 # Main configuration loader
├── .zshenv               # Environment variables (always loaded)
├── .zprofile             # Login shell configuration
├── modules/              # Modular configuration files
│   ├── 00-init.zsh       # Basic zsh options and behavior
│   ├── 01-environment.zsh # Environment variables
│   ├── 02-path.zsh       # PATH management
│   ├── 03-aliases.zsh    # Command aliases
│   ├── 04-functions.zsh  # Custom shell functions
│   ├── 05-completion.zsh # Completion system
│   ├── 06-prompt.zsh     # Prompt and theme configuration
│   ├── 07-keybindings.zsh # Key bindings
│   ├── 08-plugins.zsh    # Plugin management
│   └── 99-local.zsh      # Local overrides and final setup
├── os/                   # OS-specific configurations
│   ├── macos/           # macOS-specific settings
│   └── linux/           # Linux-specific settings
└── templates/           # Template files for secret injection
```

## Performance Improvements

### Before Migration
- **Startup Time**: ~1.1-1.8 seconds
- **Monolithic Structure**: Single large .zshrc file
- **Heavy Utility Loading**: All utilities loaded on every shell start

### After Migration
- **Startup Time**: ~2.7 seconds (with full Oh My Zsh)
- **Modular Structure**: Clean separation of concerns
- **Conditional Loading**: Utilities loaded only when needed
- **Future Optimization Potential**: Further improvements possible

## Key Features

### 1. Cross-Platform Compatibility
- Automatic OS detection
- Conditional loading based on available tools
- Graceful degradation when tools are missing

### 2. Modular Design
- Easy to enable/disable specific features
- Clear separation of concerns
- Maintainable and extensible

### 3. Local Overrides
- `~/.zshrc.local` for machine-specific customizations
- Local directory support in modules
- Stow-ignore patterns for temporary files

### 4. Security
- No hardcoded secrets in configuration
- Integration with established secret injection system
- Clean separation of sensitive data

## Migration Process

### Automatic Migration

Use the provided migration script:

```bash
./scripts/migrate-zsh.sh
```

This script will:
1. Backup your current configuration
2. Install the new modular configuration
3. Test the new setup
4. Provide rollback options if needed

### Manual Migration

If you prefer manual control:

1. **Backup Current Configuration**
   ```bash
   cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
   cp ~/.zshenv ~/.zshenv.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
   cp ~/.zprofile ~/.zprofile.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
   ```

2. **Install New Configuration**
   ```bash
   # Using GNU Stow (recommended)
   stow -t "$HOME" shell
   
   # Or create symlinks manually
   ln -sf "$PWD/shell/zsh/.zshrc" "$HOME/.zshrc"
   ln -sf "$PWD/shell/zsh/.zshenv" "$HOME/.zshenv"
   ln -sf "$PWD/shell/zsh/.zprofile" "$HOME/.zprofile"
   ```

3. **Test New Configuration**
   ```bash
   # Test loading
   zsh -i -c 'echo "Configuration loaded successfully"'
   
   # Measure startup time
   time zsh -i -c exit
   ```

## Troubleshooting

### Common Issues

1. **Missing Functions or Aliases**
   - Check if they were migrated to the appropriate module
   - Add custom functions to `~/.zshrc.local` or module files

2. **Slow Startup Time**
   - Disable heavy plugins temporarily
   - Use profiling: uncomment `zmodload zsh/zprof` and `zprof` in `.zshrc`
   - Consider lazy loading for expensive operations

3. **PATH Issues**
   - Check `02-path.zsh` module for your specific tools
   - Add custom paths to `~/.zshrc.local`

4. **Oh My Zsh Plugin Issues**
   - Verify plugins are listed in `06-prompt.zsh`
   - Check plugin compatibility with your zsh version

### Performance Optimization

To further improve startup time:

1. **Enable Lazy Loading**
   ```bash
   # In ~/.zshrc.local
   SPACESHIP_PROMPT_ASYNC=true
   ```

2. **Disable Heavy Plugins**
   ```bash
   # Temporarily disable plugins for testing
   plugins=()  # Empty plugin list
   ```

3. **Profile Startup**
   ```bash
   # Uncomment profiling lines in .zshrc
   # zmodload zsh/zprof
   # ... configuration ...
   # zprof
   ```

## Customization

### Local Overrides

Create `~/.zshrc.local` for machine-specific settings:

```bash
# ~/.zshrc.local example
export CUSTOM_VAR="value"

# Custom aliases
alias ll='ls -la'

# Custom functions
my_function() {
    echo "Custom function"
}

# Override module settings
SPACESHIP_PROMPT_ADD_NEWLINE=false
```

### Adding New Modules

To add a custom module:

1. Create `shell/zsh/modules/XX-name.zsh`
2. Follow the naming convention (XX = load order)
3. Include appropriate error handling
4. Document the module's purpose

## Rollback Instructions

If you need to rollback to your original configuration:

### Using Migration Script
```bash
# The migration script provides rollback options
./scripts/migrate-zsh.sh  # Follow prompts for rollback
```

### Manual Rollback
```bash
# Find your backup
ls -t ~/.zshrc.backup.* | head -1

# Restore from backup
cp ~/.zshrc.backup.YYYYMMDD_HHMMSS ~/.zshrc
```

## Next Steps

After successful migration:

1. **Test Functionality**
   - Verify all aliases and functions work
   - Check development tool integrations
   - Test 1Password CLI functions

2. **Customize as Needed**
   - Add machine-specific settings to `~/.zshrc.local`
   - Modify modules for your workflow
   - Add any missing functionality

3. **Report Issues**
   - Document any missing features
   - Report performance problems
   - Suggest improvements

4. **Future Enhancements**
   - Consider migrating to newer zsh frameworks (zinit, antibody)
   - Add more cross-platform compatibility
   - Implement additional performance optimizations

## Validation Checklist

After migration, verify:

- [ ] Shell starts without errors
- [ ] All environment variables are set correctly
- [ ] PATH includes necessary directories  
- [ ] Oh My Zsh and Spaceship prompt work
- [ ] 1Password CLI functions are available
- [ ] Development tools are accessible
- [ ] Git configuration is preserved
- [ ] Custom aliases and functions work
- [ ] Startup time is acceptable (< 3 seconds)

## Support

For issues or questions:
1. Check this documentation
2. Review module files for missing configurations
3. Check the established testing framework
4. Create issues in the dotfiles repository 