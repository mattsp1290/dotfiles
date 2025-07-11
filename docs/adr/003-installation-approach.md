# ADR-003: Installation and Bootstrap Strategy

**Status**: Accepted  
**Date**: 2024-12-19  
**Deciders**: Matt Spurlin  
**Technical Story**: Design comprehensive installation system supporting multiple deployment scenarios with robust error handling and cross-platform compatibility

## Context and Problem Statement

The dotfiles system requires a reliable, user-friendly installation mechanism that supports:
- Fresh installations on new systems
- Updates to existing installations  
- Cross-platform deployment (macOS, Linux, WSL)
- Multiple installation methods (one-command, manual, selective)
- Error recovery and rollback capabilities
- Offline installation scenarios
- Enterprise deployment requirements
- Developer onboarding workflows

Traditional dotfiles installations often fail due to missing dependencies, permission issues, or platform incompatibilities. The solution must provide a robust, automated approach that handles edge cases gracefully while maintaining simplicity for end users.

## Decision Drivers

- **Reliability**: High success rate across diverse environments
- **User Experience**: Simple one-command installation for most users
- **Flexibility**: Multiple installation modes for different scenarios
- **Cross-platform**: Identical experience across operating systems
- **Error Handling**: Graceful failure recovery and clear error messages
- **Performance**: Fast installation (<15 minutes typical)
- **Offline Support**: Work without internet connectivity when possible
- **Enterprise Ready**: Support for automated/scripted deployments
- **Maintainability**: Easy to extend and debug installation logic

## Considered Options

1. **Manual Installation Only**: Simple clone and manual setup
2. **Single Script Installer**: One shell script handles everything
3. **Package Manager Based**: Distribute via Homebrew/APT/etc.
4. **Container-Based Installation**: Docker/Podman for isolation
5. **Comprehensive Bootstrap System**: Multi-stage installation with options
6. **Configuration Management**: Ansible/Chef-based deployment

## Decision Outcome

**Chosen option**: "Comprehensive Bootstrap System with Multiple Installation Methods"

We implemented a sophisticated bootstrap system that provides multiple installation pathways while maintaining simplicity for common use cases.

### Positive Consequences
- One-command installation works for 95% of use cases
- Flexible installation options for power users and enterprises
- Robust error handling with clear diagnostics
- Excellent cross-platform compatibility
- Fast installation with progress feedback
- Offline mode for restricted environments
- Comprehensive logging for troubleshooting
- Easy to extend with new components

### Negative Consequences
- More complex than simple shell script
- Requires maintenance of multiple installation paths
- Bootstrap script itself is substantial (1000+ lines)
- More testing required across installation modes
- Documentation overhead for all options

## Pros and Cons of the Options

### Option 1: Manual Installation Only
- **Pros**: Simple, no script maintenance, maximum user control
- **Cons**: Poor user experience, error-prone, no automation, requires expertise

### Option 2: Single Script Installer
- **Pros**: Simple implementation, easy to understand, minimal maintenance
- **Cons**: Limited flexibility, hard to extend, poor error handling, monolithic

### Option 3: Package Manager Based
- **Pros**: Standard distribution mechanism, automatic updates, dependency handling
- **Cons**: Limited to specific platforms, packaging overhead, slower releases

### Option 4: Container-Based Installation
- **Pros**: Perfect isolation, reproducible environments, easy testing
- **Cons**: Container overhead, not suitable for dotfiles, complex for users

### Option 5: Comprehensive Bootstrap System (Chosen)
- **Pros**: Best user experience, flexible, robust, enterprise-ready, maintainable
- **Cons**: Complex implementation, more testing overhead, substantial codebase

### Option 6: Configuration Management
- **Pros**: Enterprise features, powerful templating, idempotent operations
- **Cons**: Overkill for dotfiles, steep learning curve, heavy dependencies

## Implementation Details

### Installation Methods Provided

#### Method 1: One-Command Install (Primary)
```bash
curl -fsSL https://raw.githubusercontent.com/user/dotfiles/main/install.sh | bash
```

#### Method 2: Manual Clone and Bootstrap  
```bash
git clone https://github.com/user/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles && ./scripts/bootstrap.sh
```

#### Method 3: Advanced Installation with Options
```bash
./scripts/bootstrap.sh --force --components "shell,git,ssh" --dry-run
```

### Bootstrap Script Architecture
```bash
├── scripts/bootstrap.sh          # Main orchestrator (959 lines)
├── scripts/lib/                  # Shared libraries
│   ├── detect-os.sh             # OS detection and compatibility
│   ├── utils.sh                 # Common utilities and validation
│   ├── logging.sh               # Structured logging system
│   └── colors.sh                # Terminal output formatting
├── scripts/setup/               # Component installers
│   ├── package-managers.sh      # Homebrew, APT, DNF setup
│   ├── shell-setup.sh           # Shell configuration
│   └── secret-management.sh     # 1Password CLI setup
└── scripts/install-tools.sh     # Cross-platform tool installation
```

### Key Features Implemented

#### 1. Multi-Stage Installation Process
```bash
# Stage 1: Prerequisites and validation
check_prerequisites()
install_package_managers()

# Stage 2: Core tool installation
install_stow()
install_git()
install_1password_cli()

# Stage 3: Dotfiles deployment
stow_configurations()
inject_secrets()
validate_installation()
```

#### 2. Comprehensive Options Support
- `--dry-run`: Preview without changes
- `--force`: Non-interactive installation
- `--verbose`: Detailed logging
- `--offline`: Work without internet
- `--components`: Selective installation
- `--skip-*`: Skip specific stages

#### 3. Cross-Platform Compatibility
```bash
# Automatic OS detection
detect_os_type()      # macos, linux, wsl
detect_os_version()   # Version-specific handling
detect_architecture() # x86_64, arm64, etc.
detect_package_manager() # brew, apt, dnf, pacman

# Platform-specific optimizations
install_macos_specifics()
install_linux_packages()
configure_wsl_integration()
```

#### 4. Error Handling and Recovery
- Pre-flight checks for system compatibility
- Disk space validation before installation
- Network connectivity verification
- Backup creation before major changes
- Rollback capability for failed installations
- Detailed error messages with resolution steps

#### 5. Performance Optimizations
- Parallel package installation where possible
- Smart caching of downloaded resources
- Minimal network requests in offline mode
- Progress indicators for long-running operations
- Benchmark reporting for installation time

### Validation and Testing Strategy
```bash
# Unit tests for all components
make test-bootstrap

# Integration tests across platforms
./tests/integration/test-fresh-install.sh
./tests/integration/test-update-install.sh

# Docker-based testing for multiple distributions
docker-compose -f docker-compose.test.yml up
```

## Validation Criteria

### Success Metrics
- 95%+ success rate for one-command installation
- Installation completes in <15 minutes on typical systems
- All installation modes work correctly
- Clear error messages for failure scenarios
- Rollback works correctly when needed

### Performance Targets
```bash
# Installation timing benchmarks
Fresh macOS installation: <10 minutes
Linux installation: <12 minutes
Update installation: <3 minutes
Dry-run execution: <30 seconds
```

### Compatibility Validation
- macOS 11+ (Intel and Apple Silicon)
- Ubuntu 20.04+ LTS
- Fedora 35+
- Arch Linux current
- Windows 11 WSL2

### User Experience Validation
- New users can install without documentation
- Error messages provide actionable guidance
- Progress feedback keeps users informed
- Installation can be interrupted and resumed

## Links

- [Bootstrap Script](../../scripts/bootstrap.sh)
- [Installation Documentation](../installation.md)
- [Bootstrap Documentation](../bootstrap.md) 
- [Cross-Platform Testing](../../tests/integration/)
- [ADR-001: Repository Structure](001-repository-structure.md)
- [ADR-006: Cross-Platform Strategy](006-cross-platform-strategy.md)

## Notes

The comprehensive bootstrap approach represents significant investment in user experience and reliability. While the implementation is complex, it provides the foundation for the high success rates and positive user feedback the project has received.

The modular architecture allows for easy extension as new platforms or components are added. The extensive testing ensures that changes don't break existing installation scenarios.

Key lessons learned:
- Early validation prevents most installation failures
- Clear progress feedback significantly improves user experience  
- Offline mode is crucial for enterprise and restricted environments
- Platform detection must be robust and future-proof
- Error messages should include specific resolution steps 