# Dotfiles

[![Build Status](https://img.shields.io/github/actions/workflow/status/mattsp1290/dotfiles/ci.yml?branch=main)](https://github.com/mattsp1290/dotfiles/actions)
[![Security Scan](https://img.shields.io/github/actions/workflow/status/mattsp1290/dotfiles/security.yml?branch=main&label=security)](https://github.com/mattsp1290/dotfiles/actions)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A comprehensive, security-first dotfiles system with cross-platform support (macOS and Linux) and enterprise-grade secret management.

## Quick Start

⚠️ **Warning**: Review the code before running. This will modify your system configuration.

```bash
# One-command installation
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash

# Or clone and install manually
git clone https://github.com/mattsp1290/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles && ./scripts/bootstrap.sh
```

## Prerequisites

- **macOS**: 13.0+ (Ventura) or **Linux**: Ubuntu 20.04+, Fedora 36+, Arch Linux
- Git 2.20+ and a POSIX-compliant shell (bash 3.2+, zsh 5.0+)
- Administrative privileges for package installation

## What's Included

- **Shell**: Zsh with Oh My Zsh, Bash compatibility, Fish support
- **Development Tools**: Git, SSH, Neovim, VS Code, Docker, Kubernetes
- **Package Management**: Homebrew (macOS), APT/DNF/Pacman (Linux)
- **Version Management**: ASDF for Python, Node.js, Go, Rust
- **Security**: 1Password CLI integration, secret scanning, GPG setup
- **Terminal**: Alacritty, Kitty, iTerm2 with optimized configurations
- **System**: macOS preferences automation, Linux desktop customization

## Repository Structure

```
dotfiles/
├── config/          # XDG-compliant app configurations
├── shell/           # Shell configurations (zsh, bash, fish)
├── os/              # OS-specific settings and packages
├── scripts/         # Installation and utility scripts
├── templates/       # Secret injection templates
├── docs/            # Comprehensive documentation
└── tests/           # Testing framework
```

## Key Features

- **🔒 Security-First**: Zero secrets in repository, automated scanning
- **🖥️ Cross-Platform**: Native macOS and Linux support
- **📦 Modular**: GNU Stow-based symlink management
- **🚀 Fast**: <500ms shell startup, <15min installation
- **🔧 Enterprise-Ready**: Comprehensive testing and validation

## Getting Started

### 1. Install

```bash
curl -fsSL https://raw.githubusercontent.com/mattsp1290/dotfiles/main/install.sh | bash
```

### 2. Configure Secrets (Optional)

```bash
# Install 1Password CLI
brew install 1password-cli  # macOS
# or follow Linux instructions in docs/

# Sign in and test
op signin
dotfiles template-test
```

### 3. Customize

```bash
# Edit personal configuration
$EDITOR ~/.config/dotfiles/personal.yml

# Apply changes
dotfiles regenerate
```

### 4. Verify

```bash
# Check installation
dotfiles doctor

# Test shell startup time
echo $SHELL_STARTUP_TIME  # Should be <500ms
```

## Documentation

- [Detailed Installation](docs/detailed-installation.md) - Complete setup guide
- [Customization](docs/customization.md) - Personal configuration options
- [Features](docs/features.md) - Comprehensive feature overview
- [Security](docs/security-audit.md) - Security architecture and validation
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

---

**Made with ❤️ by developers, for developers**