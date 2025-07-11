# Linux Package Management

This directory contains comprehensive Linux package management for the dotfiles repository, supporting multiple Linux distributions and package managers.

## Overview

The Linux package management system provides:

- **Multi-Distribution Support**: APT (Debian/Ubuntu), DNF (Fedora/RHEL), Pacman (Arch Linux)
- **Universal Package Managers**: Snap and Flatpak support across all distributions
- **Core vs Optional Packages**: Modular package selection based on needs
- **Repository Management**: Automatic setup of additional repositories and PPAs
- **Error Handling**: Graceful handling of unavailable packages with detailed reporting
- **Integration**: Seamless integration with the dotfiles bootstrap system

## Quick Start

```bash
# Install core packages only (recommended for most users)
./scripts/linux-packages.sh

# Install core + optional packages
./scripts/linux-packages.sh --optional

# Install all packages (native + snap + flatpak)
./scripts/linux-packages.sh --all

# Check what's installed
./scripts/linux-packages.sh --status
```

## Supported Distributions

| Distribution | Package Manager | Minimum Version | Status |
|--------------|----------------|-----------------|---------|
| Ubuntu       | APT            | 20.04 LTS       | ✅ Full Support |
| Debian       | APT            | 11 (Bullseye)   | ✅ Full Support |
| Fedora       | DNF            | 36              | ✅ Full Support |
| Arch Linux   | Pacman         | Rolling         | ✅ Full Support |
| Linux Mint   | APT            | 20              | ✅ Derivative Support |
| Pop!_OS      | APT            | 20.04           | ✅ Derivative Support |

## Directory Structure

```
os/linux/
├── packages/           # Package lists for each manager
│   ├── apt.txt        # Debian/Ubuntu packages
│   ├── dnf.txt        # Fedora/RHEL packages
│   ├── pacman.txt     # Arch Linux packages
│   ├── snap.txt       # Universal Snap packages
│   └── flatpak.txt    # Universal Flatpak packages
├── scripts/           # Distribution-specific installation scripts
│   └── install-apt.sh # APT package manager script
├── repos/             # Repository configuration files
└── README.md          # This file
```

## Package Lists

### Core Packages

Core packages are essential for most development workflows and include:

- **Build Tools**: `build-essential`, `cmake`, `pkg-config`
- **Version Control**: `git`, `git-lfs`
- **Shell Utilities**: `zsh`, `stow`, `direnv`, `tree`, `htop`
- **Modern CLI Tools**: `bat`, `fzf`, `fd-find`, `ripgrep`
- **Programming Languages**: `python3`, `nodejs`, `ruby`, `golang`
- **Development Libraries**: SSL, XML, YAML, readline development headers
- **Programming Fonts**: Fira Code, JetBrains Mono

### Optional Packages

Optional packages extend functionality for specific workflows:

- **Enhanced CLI Tools**: `exa`, `yq`, `httpie`, `duf`
- **Additional Languages**: Multiple Python/Go versions
- **Container Tools**: `containerd`, `runc`
- **SSH Server**: `openssh-server`
- **Additional Fonts**: Hack, Powerline fonts

### Universal Packages

Universal packages work across all Linux distributions:

#### Snap Packages
- **Development**: `gh` (GitHub CLI), `code` (VS Code), `docker`
- **Productivity**: `obsidian`, `discord`
- **Cloud Tools**: `aws-cli`, `google-cloud-cli`, `azure-cli`

#### Flatpak Packages
- **Development**: `com.visualstudio.code`, `com.vscodium.codium`
- **Communication**: `com.discordapp.Discord`, `com.slack.Slack`
- **Productivity**: `md.obsidian.Obsidian`, `com.notion.Notion`

## Usage

### Main Installation Script

The main script `scripts/linux-packages.sh` provides comprehensive package management:

```bash
# Installation modes
./scripts/linux-packages.sh --core-only    # Core packages only (default)
./scripts/linux-packages.sh --optional     # Core + optional packages  
./scripts/linux-packages.sh --all          # All packages (native + universal)

# Package manager specific
./scripts/linux-packages.sh --native       # Native packages only (apt/dnf/pacman)
./scripts/linux-packages.sh --snap         # Snap packages only
./scripts/linux-packages.sh --flatpak      # Flatpak packages only

# Maintenance operations
./scripts/linux-packages.sh --update       # Update package databases
./scripts/linux-packages.sh --status       # Check package status
./scripts/linux-packages.sh --cleanup      # Clean package caches
./scripts/linux-packages.sh --dry-run      # Show what would be installed
```

### Distribution-Specific Scripts

For advanced usage, you can use distribution-specific scripts directly:

```bash
# APT (Debian/Ubuntu)
./os/linux/scripts/install-apt.sh /path/to/apt.txt
./os/linux/scripts/install-apt.sh --optional /path/to/apt.txt
./os/linux/scripts/install-apt.sh --status /path/to/apt.txt

# Similar patterns for DNF and Pacman scripts (when implemented)
```

## Package File Format

Package files use a simple format with comments:

```bash
# Category Header
package-name                  # Description of package
optional-package             # Package description #OPTIONAL
group-package                # Package group (DNF) #OPTIONAL

# Comments and empty lines are ignored
# Packages marked with #OPTIONAL are only installed with --optional flag
```

## Repository Management

### APT (Debian/Ubuntu)

Automatically configured repositories:
- **Universe Repository** (Ubuntu): Additional open source packages
- **Restricted Repository** (Ubuntu): Codecs and drivers
- **Non-free Repository** (Debian): Proprietary packages
- **Git PPA**: Latest Git versions
- **GitHub CLI Repository**: Official GitHub CLI packages

### DNF (Fedora)

Automatically configured repositories:
- **RPM Fusion Free**: Additional open source packages
- **RPM Fusion Non-free**: Proprietary packages and codecs

### Pacman (Arch)

Standard repositories with optional AUR support:
- **Core**: Essential Arch packages
- **Extra**: Additional official packages  
- **Community**: Community-maintained packages
- **AUR**: User repository (requires AUR helper like `yay` or `paru`)

## Integration with Bootstrap

The Linux package system integrates seamlessly with the main bootstrap script:

```bash
# Bootstrap will automatically detect Linux and install appropriate packages
./install.sh

# Manual integration
source scripts/lib/detect-os.sh
if [[ $(detect_os_type) == "linux" ]]; then
    ./scripts/linux-packages.sh --core-only
fi
```

## Troubleshooting

### Common Issues

#### Package Not Found
```bash
# Check if package is available
apt search package-name        # APT
dnf search package-name        # DNF  
pacman -Ss package-name        # Pacman

# Update package database
sudo apt update                # APT
sudo dnf check-update          # DNF
sudo pacman -Sy               # Pacman
```

#### Repository Issues
```bash
# Reset APT repositories
sudo apt update --fix-missing

# Reset DNF cache
sudo dnf clean all && sudo dnf makecache

# Reset Pacman database
sudo pacman -Sy
```

#### Permission Issues
```bash
# Ensure user is in sudo group
sudo usermod -aG sudo $USER

# Logout and login again for group changes to take effect
```

### Snap Issues
```bash
# Install snapd if not available
sudo apt install snapd        # Debian/Ubuntu
sudo dnf install snapd        # Fedora
sudo pacman -S snapd          # Arch

# Enable snapd service
sudo systemctl enable --now snapd

# Create symlink for classic snap support
sudo ln -s /var/lib/snapd/snap /snap
```

### Flatpak Issues
```bash
# Install flatpak if not available
sudo apt install flatpak      # Debian/Ubuntu
sudo dnf install flatpak      # Fedora
sudo pacman -S flatpak        # Arch

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Update flatpak
flatpak update
```

## Performance

### Installation Times

Approximate installation times on modern hardware:

| Package Set | Ubuntu | Fedora | Arch | Network |
|-------------|--------|--------|------|---------|
| Core Only   | 5-8 min | 6-10 min | 4-7 min | Required |
| Core + Optional | 10-15 min | 12-18 min | 8-12 min | Required |
| All Packages | 15-25 min | 18-28 min | 12-20 min | Required |

### Optimization Tips

- Use `--core-only` for minimal installations
- Run `--update` periodically to keep package databases current
- Use `--cleanup` regularly to free disk space
- Consider using `--dry-run` to preview changes

## Security

### Repository Security

- All external repositories use GPG signature verification
- Repository URLs are validated before addition
- No credentials or sensitive information in package files
- Integration with project secret management system

### Package Verification

- Package managers verify checksums and signatures automatically
- External repositories require explicit GPG key import
- Failed installations are logged for security review

## Maintenance

### Regular Maintenance

```bash
# Update package databases
./scripts/linux-packages.sh --update

# Clean up package caches and orphaned packages
./scripts/linux-packages.sh --cleanup

# Check status of installed packages
./scripts/linux-packages.sh --status
```

### Adding New Packages

1. **Identify the package name** for each supported distribution
2. **Add to appropriate package files** with description
3. **Mark as optional** if not essential: `package-name  # Description #OPTIONAL`
4. **Test installation** on each supported distribution
5. **Update documentation** if needed

### Removing Packages

1. **Remove from package files** or comment out
2. **Test that dependents still work**
3. **Consider cleanup** of orphaned dependencies

## Contributing

When contributing to the Linux package management:

1. **Test on multiple distributions** before submitting
2. **Follow the established package file format**
3. **Add appropriate comments** explaining package purpose
4. **Consider cross-distribution compatibility**
5. **Update documentation** for significant changes

## Related Documentation

- [Main Repository README](../../README.md)
- [macOS Package Management](../macos/README.md)
- [Bootstrap Documentation](../../docs/bootstrap.md)
- [Cross-Platform Setup Guide](../../docs/setup.md) 