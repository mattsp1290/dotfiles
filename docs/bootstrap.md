# Bootstrap System Documentation

## Overview

The dotfiles bootstrap system provides a robust, cross-platform installation framework for setting up your development environment. It consists of several components working together to ensure a smooth installation experience on both macOS and Linux systems.

## Components

### 1. `install.sh` - Entry Point Script
The user-facing installation script that can be run via curl/wget for one-liner installations.

**Features:**
- Downloads and runs the bootstrap script
- Supports custom repository URLs and branches
- Basic prerequisite checking
- Works with piped input (curl/wget)

**Usage:**
```bash
# Basic installation
curl -fsSL https://raw.githubusercontent.com/[username]/dotfiles/main/install.sh | bash

# With custom repository
curl -fsSL https://example.com/install.sh | bash -s -- --repo https://github.com/user/dotfiles.git

# Specific branch
wget -qO- https://example.com/install.sh | bash -s -- --branch develop
```

### 2. `scripts/bootstrap.sh` - Main Bootstrap Script
The comprehensive bootstrap script that handles the actual installation process.

**Features:**
- Multiple installation modes (install, update, repair, uninstall, doctor)
- Cross-platform support (macOS, Linux distributions)
- Automatic tool installation (Homebrew, GNU Stow, Git, 1Password CLI)
- Repository management
- Dry-run mode for testing
- Interactive and non-interactive modes
- Comprehensive error handling and recovery

**Modes:**
- **install**: Fresh installation of dotfiles
- **update**: Update existing installation
- **repair**: Fix broken symlinks and configurations
- **uninstall**: Remove dotfiles installation
- **doctor**: Diagnose common issues

**Usage:**
```bash
# Fresh installation
./scripts/bootstrap.sh install

# Update existing installation
./scripts/bootstrap.sh update

# Dry run to preview changes
./scripts/bootstrap.sh --dry-run install

# Force mode (skip confirmations)
./scripts/bootstrap.sh --force update

# Diagnose issues
./scripts/bootstrap.sh doctor

# Offline mode
./scripts/bootstrap.sh --offline install
```

### 3. `scripts/lib/detect-os.sh` - OS Detection Library
Comprehensive operating system detection utilities.

**Functions:**
- `detect_os_type()`: Detect base OS (Linux, macOS, BSD)
- `detect_linux_distribution()`: Identify Linux distribution
- `detect_os_version()`: Get OS version
- `detect_architecture()`: Detect system architecture
- `detect_package_manager()`: Find available package manager
- `is_container()`: Check if running in container
- `is_wsl()`: Check if running in WSL
- `is_apple_silicon()`: Check for Apple Silicon Mac
- `check_os_compatibility()`: Verify OS meets requirements

### 4. `scripts/lib/utils.sh` - Utility Functions Library
Common utility functions for scripts.

**Features:**
- Colored logging functions
- Progress indicators and spinners
- Command existence checking
- Network connectivity testing
- File download with progress
- User prompts and confirmations
- Safe file operations
- Retry mechanisms

## Installation Process

1. **Prerequisites Check**
   - OS compatibility verification
   - Required commands check
   - Disk space verification
   - Network connectivity test

2. **Repository Management**
   - Clone repository (if needed)
   - Update existing repository
   - Handle uncommitted changes

3. **Tool Installation**
   - Install Homebrew (macOS)
   - Install GNU Stow
   - Install Git (if missing)
   - Install 1Password CLI

4. **Directory Creation**
   - Create XDG directories
   - Set up required paths

5. **Dotfiles Installation**
   - Use GNU Stow to create symlinks
   - Handle OS-specific configurations
   - Run post-installation scripts

## Configuration

### Environment Variables
- `DOTFILES_REPO_URL`: Override repository URL
- `DOTFILES_BRANCH`: Override default branch
- `DOTFILES_DIR`: Override installation directory
- `CURRENT_LOG_LEVEL`: Set logging verbosity

### Supported Platforms
- **macOS**: 12.0+ (Monterey and later)
- **Linux**: Ubuntu 20.04+, Debian 11+, Fedora 36+, Arch Linux
- **Architecture**: x86_64, ARM64 (including Apple Silicon)

## Error Handling

The bootstrap system includes comprehensive error handling:
- Rollback capabilities for failed operations
- Clear error messages with recovery suggestions
- Broken symlink detection and repair
- Network failure resilience
- Partial failure recovery

## Testing

### Dry Run Mode
Test the installation without making changes:
```bash
./scripts/bootstrap.sh --dry-run install
```

### Doctor Mode
Diagnose common issues:
```bash
./scripts/bootstrap.sh doctor
```

### Verbose Mode
Get detailed output:
```bash
./scripts/bootstrap.sh --verbose install
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure scripts are executable: `chmod +x scripts/bootstrap.sh`
   - Some operations may require sudo (package installation)

2. **Network Issues**
   - Use `--offline` mode if network is unreliable
   - Check proxy settings if behind corporate firewall

3. **Package Manager Issues**
   - Ensure package manager is up to date
   - May need to install package manager first (e.g., Homebrew on macOS)

4. **Broken Symlinks**
   - Run `./scripts/bootstrap.sh repair` to fix
   - Use `doctor` mode to diagnose

### Debug Mode
Enable debug logging:
```bash
CURRENT_LOG_LEVEL=0 ./scripts/bootstrap.sh install
```

## Extending the Bootstrap System

### Adding New OS Support
1. Update `scripts/lib/detect-os.sh` with new OS detection
2. Add package manager support in `install_stow()` and related functions
3. Create OS-specific directory under `os/`
4. Update documentation

### Adding New Tools
1. Create installation function in `bootstrap.sh`
2. Add to `install_tools()` function
3. Make installation conditional based on OS/environment
4. Update documentation

### Custom Post-Installation Scripts
Place executable scripts in `scripts/setup/` directory. They will be run automatically after installation.

## Security Considerations

- No hardcoded credentials
- Secure command execution
- Input validation on all user inputs
- Safe temporary file handling
- No unnecessary privilege escalation

## Best Practices

1. Always run `doctor` mode after installation
2. Use `--dry-run` before making changes
3. Keep repository up to date with `update` mode
4. Regular backups before major changes
5. Test changes on a fresh system/VM 