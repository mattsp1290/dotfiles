# Cross-Platform Tools

This document describes the cross-platform tool installation system that provides consistent development tools across macOS and Linux environments.

## Overview

The cross-platform tools system installs essential development tools that work consistently across different operating systems. It includes:

- **ASDF Version Manager**: Multi-language version manager for Node.js, Python, Ruby, Go, and more
- **Modern CLI Tools**: Enhanced replacements for standard Unix tools (bat, exa, fd, ripgrep, fzf)
- **Container Tools**: Docker, Docker Compose, and Kubernetes tools
- **Cloud CLI Tools**: AWS CLI, Google Cloud CLI, Azure CLI, Terraform
- **Development Utilities**: Git tools, HTTP clients, text processors

## Quick Start

### Install Core Tools

```bash
# Install essential cross-platform tools
scripts/install-tools.sh core

# Or use the bootstrap system
scripts/bootstrap.sh install
```

### Install All Tools

```bash
# Install all tools including optional ones
scripts/install-tools.sh all
```

### Check Status

```bash
# Check what tools are installed
scripts/install-tools.sh status
```

## Tool Categories

### ASDF Version Manager

ASDF provides unified version management for multiple programming languages:

- **Languages**: Node.js, Python, Ruby, Go, Rust, Deno
- **Infrastructure**: Terraform, kubectl, Helm
- **Utilities**: direnv, jq, yq

**Configuration**: Default versions are defined in `config/asdf/.tool-versions`

**Usage**:
```bash
# List installed tools
asdf current

# Install a new version
asdf install nodejs 18.19.0

# Set global version
asdf global nodejs 18.19.0

# Set local version for a project
asdf local python 3.11.7
```

### Modern CLI Tools

Enhanced replacements for standard Unix tools:

| Tool | Replaces | Description |
|------|----------|-------------|
| `bat` | `cat` | Syntax highlighting and Git integration |
| `exa` | `ls` | Modern directory listing with colors |
| `fd` | `find` | Simple, fast, user-friendly file finder |
| `ripgrep` (`rg`) | `grep` | Ultra-fast text search |
| `fzf` | - | Fuzzy finder for command line |
| `jq` | - | JSON processor |
| `git-delta` | `diff` | Enhanced git diff viewer |

### Container Tools

Container and orchestration tools:

- **Docker**: Container runtime and CLI
- **Docker Compose**: Multi-container applications
- **kubectl**: Kubernetes CLI
- **Helm**: Kubernetes package manager
- **k9s**: Terminal UI for Kubernetes (optional)

### Cloud CLI Tools

Cloud platform command-line interfaces:

- **AWS CLI v2**: Amazon Web Services
- **Google Cloud CLI**: Google Cloud Platform
- **Azure CLI**: Microsoft Azure
- **Terraform**: Infrastructure as Code
- **Vault**: HashiCorp Vault (optional)

### Development Tools

Git and development utilities:

- **GitHub CLI (gh)**: GitHub repository management
- **HTTPie**: User-friendly HTTP client
- **gitleaks**: Secret detection in Git repos (optional)
- **tree**: Directory structure visualization
- **ncdu**: Disk usage analyzer (optional)

## Installation Scripts

The system consists of modular installation scripts:

### Main Script: `scripts/install-tools.sh`

The primary entry point for cross-platform tool installation.

**Usage**:
```bash
scripts/install-tools.sh [OPTIONS] [CATEGORY]
```

**Categories**:
- `core` - Essential tools (default)
- `asdf` - ASDF version manager only
- `docker` - Container tools only
- `cloud` - Cloud CLI tools only
- `dev` - Development tools only
- `optional` - Optional tools
- `all` - All tools including optional

**Options**:
- `--dry-run` - Show what would be installed
- `--verbose` - Enable verbose output
- `--offline` - Skip network operations
- `--skip-asdf` - Skip ASDF installation
- `--skip-docker` - Skip Docker installation

### Individual Scripts

Located in `tools/scripts/`:

- `install-asdf.sh` - ASDF version manager
- `install-docker.sh` - Docker and container tools  
- `install-cloud-tools.sh` - Cloud CLI tools
- `setup-development-tools.sh` - Development utilities

Each script can be run independently:

```bash
# Install ASDF with plugins and tools
tools/scripts/install-asdf.sh install

# Install Docker on current platform
tools/scripts/install-docker.sh install

# Install AWS CLI and Terraform
tools/scripts/install-cloud-tools.sh install

# Install all cloud tools
tools/scripts/install-cloud-tools.sh all

# Install core development tools
tools/scripts/setup-development-tools.sh install
```

## Configuration

### Tool Versions

Default tool versions are managed in `config/asdf/.tool-versions`:

```
# Core Programming Languages
nodejs 20.12.0
python 3.12.2
ruby 3.3.0
golang 1.22.1

# Infrastructure Tools  
terraform 1.7.4
kubectl 1.29.3
helm 3.14.3
```

This file is symlinked to `~/.tool-versions` by Stow for global defaults.

### Project-Specific Versions

Create a `.tool-versions` file in any project directory:

```
nodejs 18.19.0
python 3.11.7
terraform 1.6.6
```

ASDF will automatically switch to these versions when you enter the directory.

### Tool Lists

Tool selections are defined in:

- `tools/core-tools.txt` - Essential cross-platform tools
- `tools/optional-tools.txt` - Specialized tools for advanced workflows

## Platform Support

### macOS

- **Package Manager**: Homebrew preferred, direct downloads as fallback
- **Docker**: Docker Desktop via Homebrew Cask
- **ASDF**: Homebrew installation preferred
- **Architecture**: Intel (x86_64) and Apple Silicon (arm64) supported

### Linux

Supported distributions:
- **Ubuntu/Debian**: APT package manager
- **Fedora**: DNF package manager
- **CentOS/RHEL**: YUM package manager  
- **Arch Linux**: Pacman package manager

**Docker**: Official Docker repositories used
**ASDF**: Git installation method
**Fallbacks**: Direct downloads for tools not in repositories

## Integration with Bootstrap

The cross-platform tools are automatically installed during the bootstrap process:

```bash
scripts/bootstrap.sh install
```

This will:
1. Install OS-specific packages (Homebrew on macOS, Linux packages)
2. Install cross-platform tools (ASDF, Docker, development tools)
3. Configure shell integration
4. Set up dotfiles with Stow

## Troubleshooting

### Common Issues

**ASDF not found after installation**:
```bash
# Restart your shell or source the config
source ~/.zshrc

# Check if ASDF is in PATH
echo $PATH | grep asdf
```

**Docker permission denied (Linux)**:
```bash
# Add user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Or use newgrp to apply group changes
newgrp docker
```

**Tool installation fails**:
```bash
# Check network connectivity
ping google.com

# Try installing individual categories
scripts/install-tools.sh asdf
scripts/install-tools.sh dev
```

### Manual Installation

If automatic installation fails, tools can be installed manually:

**ASDF**:
```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
```

**Homebrew** (macOS):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Verification

Check tool installations:

```bash
# Verify ASDF
asdf --version
asdf plugin list

# Verify Docker
docker --version
docker compose version

# Verify development tools
bat --version
exa --version
fd --version
rg --version
```

## Customization

### Adding New Tools

1. **For ASDF tools**: Add to plugin list in `tools/scripts/install-asdf.sh`
2. **For development tools**: Add to tool arrays in `tools/scripts/setup-development-tools.sh`
3. **For cloud tools**: Add to `tools/scripts/install-cloud-tools.sh`

### Removing Tools

Edit the respective tool lists and re-run installation:

```bash
# Remove from tool arrays in scripts
# Then re-run installation
scripts/install-tools.sh dev
```

### Version Overrides

Override tool versions with environment variables:

```bash
# Override ASDF version
ASDF_VERSION=v0.13.1 tools/scripts/install-asdf.sh install

# Override default tool versions
NODEJS_VERSION=18.19.0 tools/scripts/install-asdf.sh install
```

## Security Considerations

- All tools are installed from official sources or verified repositories
- GPG signatures are verified where available
- No tools require elevated privileges unless necessary
- Secure handling of shell environment modifications
- Integration with existing secret management system

## Performance

- **Installation time**: 15-30 minutes for complete installation
- **Disk usage**: ~2-5GB for all tools
- **Shell startup**: <100ms additional overhead
- **Tool detection**: <2 seconds for status checks

## See Also

- [ASDF Documentation](https://asdf-vm.com/)
- [Docker Documentation](https://docs.docker.com/)
- [OS-002: Homebrew Bundle](../OS-002_COMPLETION_SUMMARY.md)
- [OS-003: Linux Packages](../OS-003_COMPLETION_SUMMARY.md) 