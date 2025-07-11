# ADR-006: Cross-Platform Compatibility Strategy

**Status**: Accepted  
**Date**: 2024-12-19  
**Deciders**: Matt Spurlin  
**Technical Story**: Implement comprehensive cross-platform support enabling consistent dotfiles experience across macOS, Linux distributions, and WSL environments

## Context and Problem Statement

The dotfiles system must support multiple operating systems and environments including:
- macOS (Intel and Apple Silicon architectures)
- Linux distributions (Ubuntu, Fedora, Arch Linux, RHEL/CentOS)
- Windows Subsystem for Linux (WSL 1 and WSL 2)
- Different package managers (Homebrew, APT, DNF, Pacman, Yum)
- Architecture differences (x86_64, ARM64, Apple Silicon)
- Filesystem behavior variations (case sensitivity, symlink support)
- Path conventions and environment variables
- Tool availability and version differences

The solution must provide a consistent user experience while accommodating platform-specific optimizations and requirements without sacrificing maintainability or creating complex platform-specific branches.

## Decision Drivers

- **Consistency**: Identical user experience across platforms
- **Maintainability**: Single codebase to reduce maintenance overhead
- **Performance**: Platform-specific optimizations where beneficial
- **Reliability**: Robust platform detection and fallback mechanisms
- **Flexibility**: Support for platform-specific customizations
- **Simplicity**: Avoid unnecessary complexity in cross-platform logic
- **Future-proofing**: Extensible to new platforms and architectures
- **Testing**: Comprehensive validation across all supported platforms

## Considered Options

1. **Single Repository with Conditional Logic**: OS detection with platform-specific configurations
2. **Separate Platform Repositories**: Independent repositories for each operating system
3. **Platform-Specific Branches**: Git branches for different operating systems
4. **Container-Based Approach**: Containerized environments for platform isolation
5. **Configuration Management**: Ansible/Chef-style platform abstraction
6. **Symlink Platform Directories**: Platform-specific directory structure with symlinks

## Decision Outcome

**Chosen option**: "Single Repository with OS Detection and Conditional Configurations"

We implemented a unified repository with intelligent OS detection and conditional logic that provides platform-specific optimizations while maintaining code reuse and consistency.

### Positive Consequences
- Maximum code reuse across platforms reduces maintenance burden
- Consistent user experience and feature parity across operating systems
- Single documentation set and testing framework
- Easy to add support for new platforms or distributions
- Shared improvements benefit all platforms simultaneously
- Simplified deployment and version management
- Strong platform detection prevents configuration conflicts

### Negative Consequences
- Increased complexity in platform detection and conditional logic
- Testing matrix grows exponentially with platform combinations
- Some platform-specific features may be compromised for consistency
- Debugging platform-specific issues requires access to target systems
- Risk of platform-specific regressions affecting other platforms

## Pros and Cons of the Options

### Option 1: Single Repository with Conditional Logic (Chosen)
- **Pros**: Code reuse, consistency, single maintenance point, shared improvements
- **Cons**: Complex detection logic, large testing matrix, potential conflicts

### Option 2: Separate Platform Repositories
- **Pros**: Platform-specific optimization, isolated testing, simpler per-platform logic
- **Cons**: Code duplication, maintenance overhead, feature drift, version synchronization

### Option 3: Platform-Specific Branches
- **Pros**: Git-native separation, shared history, easier merging
- **Cons**: Complex branching strategy, merge conflicts, feature synchronization challenges

### Option 4: Container-Based Approach
- **Pros**: Perfect isolation, reproducible environments, simplified testing
- **Cons**: Container overhead, not suitable for dotfiles, complex user experience

### Option 5: Configuration Management
- **Pros**: Powerful abstraction, enterprise features, proven approach
- **Cons**: Overkill for dotfiles, steep learning curve, heavy dependencies

### Option 6: Symlink Platform Directories
- **Pros**: Clear separation, simple to understand, GNU Stow compatible
- **Cons**: Duplication, maintenance overhead, inconsistent user experience

## Implementation Details

### OS Detection Framework
```bash
# Comprehensive OS detection library
source "scripts/lib/detect-os.sh"

detect_os_type() {
    case "$(uname -s)" in
        Darwin)     echo "macos" ;;
        Linux)      echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

detect_os_version() {
    local os_type="$(detect_os_type)"
    case "$os_type" in
        macos)
            sw_vers -productVersion
            ;;
        linux)
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                echo "$VERSION_ID"
            fi
            ;;
    esac
}

detect_architecture() {
    case "$(uname -m)" in
        x86_64|amd64)     echo "x86_64" ;;
        arm64|aarch64)    echo "arm64" ;;
        armv7l)           echo "arm" ;;
        *)                echo "unknown" ;;
    esac
}
```

### Package Manager Detection
```bash
detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    else
        echo "unknown"
    fi
}
```

### Platform-Specific Directory Structure
```bash
dotfiles/
├── os/                      # Platform-specific configurations
│   ├── macos/              # macOS system preferences and setup
│   │   ├── defaults.sh     # System preferences automation
│   │   ├── dock.sh         # Dock configuration
│   │   ├── finder.sh       # Finder customization
│   │   └── homebrew/       # Homebrew package lists
│   ├── linux/              # Linux distribution support
│   │   ├── ubuntu.sh       # Ubuntu-specific packages
│   │   ├── fedora.sh       # Fedora-specific packages
│   │   ├── arch.sh         # Arch Linux packages
│   │   └── common.sh       # Cross-distribution packages
│   └── wsl/                # Windows Subsystem for Linux
│       ├── wsl1.sh         # WSL 1 specific configuration
│       ├── wsl2.sh         # WSL 2 specific configuration
│       └── windows-integration.sh
└── scripts/
    ├── lib/
    │   ├── detect-os.sh    # OS detection library
    │   └── platform.sh     # Platform-specific utilities
    └── setup/
        └── platform-setup.sh # Platform-specific installation
```

### Conditional Configuration Loading
```bash
# Shell configuration with platform awareness
case "$(detect_os_type)" in
    macos)
        # macOS-specific aliases and functions
        alias ls='ls -G'
        alias ll='ls -alG'
        export BROWSER='open'
        
        # macOS-specific paths
        export PATH="/opt/homebrew/bin:$PATH"
        ;;
    linux)
        # Linux-specific aliases
        alias ls='ls --color=auto'
        alias ll='ls -alh --color=auto'
        export BROWSER='xdg-open'
        
        # Linux-specific paths
        export PATH="/usr/local/bin:$PATH"
        ;;
esac
```

### Package Installation Strategy
```bash
install_package() {
    local package="$1"
    local package_manager="$(detect_package_manager)"
    
    case "$package_manager" in
        brew)
            brew install "$package"
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package"
            ;;
        *)
            log_error "Unsupported package manager: $package_manager"
            return 1
            ;;
    esac
}
```

### Environment Detection and Optimization
```bash
# WSL detection and optimization
is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]
}

# Apple Silicon detection
is_apple_silicon() {
    [[ "$(detect_os_type)" == "macos" ]] && [[ "$(detect_architecture)" == "arm64" ]]
}

# Container environment detection
is_container() {
    [[ -f /.dockerenv ]] || [[ -n "${container:-}" ]]
}

# Apply environment-specific optimizations
optimize_for_environment() {
    if is_wsl; then
        # WSL-specific optimizations
        export DISPLAY=:0
        alias pbcopy='clip.exe'
        alias pbpaste='powershell.exe -command "Get-Clipboard"'
    fi
    
    if is_apple_silicon; then
        # Apple Silicon optimizations
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    fi
    
    if is_container; then
        # Container-specific settings
        export TERM=xterm-256color
    fi
}
```

### Cross-Platform Testing Framework
```bash
# Platform compatibility testing
test_cross_platform() {
    local platforms=("macos" "ubuntu" "fedora" "arch")
    
    for platform in "${platforms[@]}"; do
        echo "Testing platform: $platform"
        docker run --rm -v "$PWD:/dotfiles" \
            "dotfiles-test:$platform" \
            /dotfiles/tests/integration/test-platform.sh
    done
}
```

### Platform-Specific Feature Flags
```bash
# Feature availability detection
has_gui() {
    case "$(detect_os_type)" in
        macos) return 0 ;;
        linux) [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]] ;;
        *) return 1 ;;
    esac
}

has_package_manager() {
    [[ "$(detect_package_manager)" != "unknown" ]]
}

supports_symlinks() {
    # Test symlink creation capability
    local test_dir=$(mktemp -d)
    local test_file="$test_dir/test"
    local test_link="$test_dir/link"
    
    echo "test" > "$test_file"
    if ln -s "$test_file" "$test_link" 2>/dev/null; then
        rm -rf "$test_dir"
        return 0
    else
        rm -rf "$test_dir"
        return 1
    fi
}
```

## Validation Criteria

### Platform Coverage Validation
```bash
# Test matrix covering all supported platforms
make test-platforms

# Individual platform testing
make test-macos
make test-ubuntu
make test-fedora
make test-arch
make test-wsl
```

### Success Metrics
- Identical core functionality across all platforms
- Platform-specific optimizations work correctly
- Installation succeeds on all supported platforms (>95% success rate)
- Cross-platform shell startup time remains consistent
- Platform detection accuracy: 100% for supported platforms
- Feature parity maintained across platforms

### Performance Validation
```bash
# Cross-platform performance benchmarking
./tests/performance/benchmark-platforms.sh

# Platform-specific optimization verification
./tests/performance/validate-optimizations.sh
```

### Compatibility Testing
- Regular testing across platform matrix in CI/CD
- Docker-based testing for Linux distributions
- Virtual machine testing for comprehensive validation
- Manual testing on physical hardware for platform-specific features

## Links

- [OS Detection Library](../../scripts/lib/detect-os.sh)
- [Platform Setup Scripts](../../scripts/setup/)
- [macOS Configuration](../../os/macos/)
- [Linux Configuration](../../os/linux/)
- [Cross-Platform Testing](../../tests/integration/)
- [ADR-003: Installation Approach](003-installation-approach.md)
- [ADR-008: Performance Optimization](008-performance-optimization.md)

## Notes

The single repository approach with conditional logic has proven successful in providing consistent functionality across platforms while enabling platform-specific optimizations. The key insight is that most dotfiles functionality is platform-agnostic, with only specific areas requiring platform awareness.

Critical success factors:
- Robust OS detection that handles edge cases and new platforms
- Careful balance between consistency and platform-specific optimization
- Comprehensive testing across the full platform matrix
- Clear documentation of platform-specific behaviors
- Graceful fallbacks for unsupported or unknown platforms

The approach scales well to new platforms and has enabled rapid adoption across diverse development environments while maintaining a single, maintainable codebase. 