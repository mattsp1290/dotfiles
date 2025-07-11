# Package Manager Configurations

This document provides comprehensive information about the package manager configurations included in this dotfiles repository.

## Overview

The package manager configurations provide optimized settings for:
- **npm** - Node.js package manager
- **pip** - Python package manager  
- **gem** - RubyGems package manager
- **cargo** - Rust package manager

All configurations are designed for cross-platform compatibility and include performance optimizations, security settings, and enterprise support.

## Quick Start

1. **Setup all package managers:**
   ```bash
   ./scripts/setup-package-managers.sh
   ```

2. **Apply configurations with Stow:**
   ```bash
   stow config home
   ```

3. **Validate configurations:**
   ```bash
   ./scripts/validate-package-managers.sh
   ```

## Configuration Files

### npm Configuration (`config/npm/.npmrc`)

**Location:** `~/.config/npm/.npmrc` (symlinked via Stow)

**Key Features:**
- Registry: `https://registry.npmjs.org/`
- Performance optimization with caching and retry settings
- Security settings with audit levels
- Support for scoped registries and enterprise configurations
- CI/CD compatibility settings

**Important Settings:**
```ini
registry=https://registry.npmjs.org/
save-exact=true
package-lock=true
fetch-retries=3
loglevel=warn
```

**Enterprise Configuration:**
To configure enterprise npm registries, uncomment and modify:
```ini
# @company:registry=https://npm.company.com/
# //npm.company.com/:_authToken=${NPM_COMPANY_TOKEN}
```

### pip Configuration (`config/pip/pip.conf`)

**Location (macOS):** `~/Library/Application Support/pip/pip.conf`
**Location (Linux/WSL):** `~/.config/pip/pip.conf`

**Key Features:**
- Primary index: `https://pypi.org/simple/`
- Virtual environment requirement for security
- Caching and performance optimization
- Support for multiple indexes and mirrors
- Corporate proxy support

**Important Settings:**
```ini
[global]
index-url = https://pypi.org/simple/
require-virtualenv = true
cache-dir = ~/.cache/pip
timeout = 300
retries = 3
```

**Corporate Configuration:**
For corporate environments, modify:
```ini
# index-url = https://pypi.company.com/simple/
# trusted-host = pypi.company.com
```

### gem Configuration (`home/.gemrc`)

**Location:** `~/.gemrc` (symlinked via Stow)

**Key Features:**
- Source: `https://rubygems.org/`
- No documentation installation for faster installs
- Concurrent downloads for performance
- SSL verification and security settings
- User-level installation preferences

**Important Settings:**
```yaml
:sources:
  - https://rubygems.org/
gem: --no-document --no-ri --no-rdoc
:concurrent_downloads: 8
:user_install: true
```

**Mirror Configuration:**
For corporate or faster mirrors:
```yaml
# :sources:
#   - https://gems.company.com/
#   - https://rubygems.org/
```

### cargo Configuration (`config/cargo/config.toml`)

**Location:** `~/.cargo/config.toml` (symlinked via Stow)

**Key Features:**
- Registry: `https://github.com/rust-lang/crates.io-index`
- Build optimization profiles for development and release
- Network retry and timeout settings
- Support for alternative registries and mirrors
- Comprehensive compiler optimization settings

**Important Settings:**
```toml
[registry]
default = "crates-io"

[net]
retry = 3
offline = false

[build]
jobs = 0  # Use all available cores
incremental = true
```

**Enterprise Configuration:**
```toml
# [registries]
# company = { index = "https://crates.company.com/git/index" }
```

## Setup and Installation

### Prerequisites

Ensure the following package managers are installed:
- npm (via Node.js or volta)
- pip (via Python)
- gem (via Ruby)
- cargo (via Rust)

### Installation Steps

1. **Run the setup script:**
   ```bash
   ./scripts/setup-package-managers.sh
   ```

2. **Apply configurations:**
   ```bash
   stow config home
   ```

3. **Verify installation:**
   ```bash
   ./scripts/validate-package-managers.sh
   ```

### Individual Package Manager Setup

Setup individual package managers:
```bash
./scripts/setup-package-managers.sh --npm-only
./scripts/setup-package-managers.sh --pip-only
./scripts/setup-package-managers.sh --gem-only
./scripts/setup-package-managers.sh --cargo-only
```

## Configuration Validation

### Basic Validation

Run the validation script to ensure all configurations are working:
```bash
./scripts/validate-package-managers.sh
```

### Connectivity Testing

Test registry connectivity and performance:
```bash
./scripts/test-package-connectivity.sh
```

Test specific package managers:
```bash
./scripts/test-package-connectivity.sh npm
./scripts/test-package-connectivity.sh pip
./scripts/test-package-connectivity.sh gem
./scripts/test-package-connectivity.sh cargo
```

### Manual Verification

Verify configurations manually:

**npm:**
```bash
npm config list
npm config get registry
```

**pip:**
```bash
pip config list
pip config debug
```

**gem:**
```bash
gem environment
gem sources --list
```

**cargo:**
```bash
cargo --version
ls ~/.cargo/config.toml
```

## Performance Optimization

### npm Performance

- **Cache optimization:** Configured cache directory and retention
- **Parallel downloads:** Network optimization for faster installs
- **Registry mirrors:** Support for faster regional mirrors
- **Offline mode:** Prefer cached packages when available

### pip Performance

- **Binary preferences:** Prefer binary packages over source compilation
- **Caching:** Aggressive caching of downloaded packages
- **Timeout optimization:** Balanced timeout and retry settings
- **Index mirrors:** Support for faster PyPI mirrors

### gem Performance

- **Concurrent downloads:** Up to 8 parallel downloads
- **No documentation:** Skip ri/rdoc generation for speed
- **User installation:** Avoid system-wide installation overhead
- **Source optimization:** Prioritized source ordering

### cargo Performance

- **Parallel compilation:** Use all available CPU cores
- **Incremental builds:** Enable incremental compilation
- **Target optimization:** Separate debug and release profiles
- **Network optimization:** Retry and timeout settings

## Security Configuration

### Authentication

All configurations support secure authentication via environment variables:

**npm:**
```bash
export NPM_TOKEN="your-npm-token"
# Configure in .npmrc: //registry.npmjs.org/:_authToken=${NPM_TOKEN}
```

**pip:**
```bash
export PIP_INDEX_URL="https://user:token@pypi.company.com/simple/"
```

**gem:**
```bash
gem sources --add https://token@gems.company.com/
```

**cargo:**
```bash
cargo login your-crates-io-token
```

### SSL and Security

- **SSL verification:** Enabled by default for all package managers
- **Trusted hosts:** Configured for corporate environments
- **Audit settings:** npm audit levels configured
- **Virtual environments:** pip requires virtual environments by default

## Enterprise and Corporate Environments

### Proxy Configuration

Configure corporate proxies by uncommenting proxy settings in each configuration file:

**npm:**
```ini
proxy=http://proxy.company.com:8080
https-proxy=http://proxy.company.com:8080
```

**pip:**
```ini
[global]
proxy = http://proxy.company.com:8080
```

**gem:**
```yaml
:http_proxy: http://proxy.company.com:8080
:https_proxy: http://proxy.company.com:8080
```

**cargo:**
```toml
[http]
proxy = "http://proxy.company.com:8080"
```

### Private Registries

Each package manager supports private/enterprise registries:

1. Uncomment the enterprise registry examples in configuration files
2. Replace example URLs with your corporate registry URLs
3. Configure authentication using environment variables or secret injection

### Mirror Configuration

For regions with faster mirrors, update registry URLs to use local mirrors:
- npm: Taobao, cnpm mirrors
- pip: Douban, Aliyun mirrors  
- gem: Ruby China mirrors
- cargo: Regional mirrors

## Troubleshooting

### Common Issues

**npm Issues:**
- Registry timeout: Check network connectivity and firewall settings
- Authentication failure: Verify NPM_TOKEN environment variable
- Cache corruption: Clear cache with `npm cache clean --force`

**pip Issues:**
- SSL certificate errors: Configure trusted-host settings
- Virtual environment requirement: Create and activate a virtual environment
- Index timeout: Try alternative indexes or increase timeout

**gem Issues:**
- Permission errors: Ensure user-level installation is configured
- Source connectivity: Verify gem sources with `gem sources --list`
- SSL issues: Update RubyGems with `gem update --system`

**cargo Issues:**
- Registry index outdated: Update with `cargo update`
- Network timeout: Check connectivity to crates.io
- Compilation errors: Verify Rust toolchain installation

### Diagnostic Commands

**Check configuration loading:**
```bash
npm config list
pip config list
gem environment
cargo --version
```

**Test registry connectivity:**
```bash
curl -I https://registry.npmjs.org/
curl -I https://pypi.org/simple/
curl -I https://rubygems.org/
curl -I https://crates.io/
```

**Validate package installation:**
```bash
npm list --depth=0
pip list
gem list
cargo --version
```

### Getting Help

1. Run validation scripts for automatic diagnosis
2. Check connectivity with test scripts
3. Review configuration files for syntax errors
4. Consult package manager documentation for specific issues

## Advanced Configuration

### Custom Registries

To set up custom registries, modify the appropriate configuration files and add authentication:

1. Update registry URLs in configuration files
2. Add authentication tokens via environment variables
3. Configure SSL certificates if needed
4. Test connectivity with validation scripts

### Mirror Setup

For better performance, configure regional mirrors:

1. Research available mirrors for your region
2. Update configuration files with mirror URLs
3. Test performance with connectivity scripts
4. Configure fallback to official registries

### CI/CD Integration

These configurations are designed to work in CI/CD environments:

1. Use environment variables for authentication
2. Configure non-interactive modes
3. Enable appropriate caching strategies
4. Use validation scripts in CI pipelines

## References

- [npm Configuration Documentation](https://docs.npmjs.com/cli/v9/configuring-npm/npmrc)
- [pip Configuration Guide](https://pip.pypa.io/en/stable/topics/configuration/)
- [RubyGems Configuration](https://guides.rubygems.org/command-reference/#gem-environment)
- [Cargo Configuration Reference](https://doc.rust-lang.org/cargo/reference/config.html) 