# Maintenance Procedures

A comprehensive guide to maintaining your dotfiles system, ensuring optimal performance, security, and reliability over time.

## Table of Contents

- [Overview](#overview)
- [Regular Maintenance Schedule](#regular-maintenance-schedule)
- [Update Procedures](#update-procedures)
- [Performance Monitoring](#performance-monitoring)
- [Security Maintenance](#security-maintenance)
- [Component Maintenance](#component-maintenance)
- [Automated Maintenance](#automated-maintenance)
- [Maintenance Scripts](#maintenance-scripts)
- [Health Checks](#health-checks)
- [Troubleshooting](#troubleshooting)

## Overview

The dotfiles system requires regular maintenance to ensure:
- **Optimal Performance**: Shell startup times under 500ms
- **Security Compliance**: Up-to-date packages and secure configurations
- **Reliability**: Functional symlinks and proper configurations
- **Compatibility**: Updated tools and maintained dependencies

### Maintenance Philosophy

- **Proactive**: Regular scheduled maintenance prevents issues
- **Automated**: Scripts handle routine tasks to reduce manual effort
- **Monitored**: Built-in diagnostics catch problems early
- **Documented**: All procedures are tracked and reproducible

## Regular Maintenance Schedule

### Daily Tasks (Automated)
- Secret injection validation
- Shell performance monitoring
- Git configuration health checks
- Broken symlink detection

### Weekly Tasks
- System package updates
- Tool version checks
- Configuration validation
- Performance benchmarking

### Monthly Tasks
- Security audits
- Dependency updates
- Backup verification
- Migration testing

### Quarterly Tasks
- Full system health audit
- Documentation updates
- Security policy review
- Architecture review

## Update Procedures

### System Updates

#### Quick Update (Recommended)
```bash
# Update dotfiles repository and refresh configurations
./scripts/bootstrap.sh update

# Validate installation
./scripts/bootstrap.sh doctor

# Restart shell to apply changes
exec $SHELL
```

#### Comprehensive Update
```bash
# 1. Backup current configuration
./scripts/backup-configs.sh

# 2. Update repository
cd ~/git/dotfiles
git fetch origin
git status  # Check for local changes
git pull origin main

# 3. Update dependencies
./scripts/bootstrap.sh update --force

# 4. Regenerate configurations
./scripts/inject-all.sh

# 5. Validate installation
./scripts/bootstrap.sh doctor
make test

# 6. Performance check
dotfiles benchmark
```

### Package Manager Updates

#### macOS (Homebrew)
```bash
# Update Homebrew itself
brew update

# List outdated packages
brew outdated

# Update all packages
brew upgrade

# Clean up old versions
./scripts/brew-cleanup.sh

# Verify installation
brew doctor
```

#### Linux (Distribution-specific)
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

# Fedora
sudo dnf upgrade -y
sudo dnf autoremove -y

# Arch Linux
sudo pacman -Syu --noconfirm
sudo pacman -Sc --noconfirm

# Verify package integrity
./scripts/validate-package-managers.sh
```

### Tool Version Management

#### Check Current Versions
```bash
# Built-in version checker
./scripts/check-tool-versions.sh

# Individual tool checks
git --version
op --version
stow --version
```

#### Update Specific Tools
```bash
# Update development tools
./scripts/install-tools.sh update

# Update editors
./scripts/setup-editors.sh update

# Update terminals
./scripts/setup-terminals.sh update
```

### Configuration Updates

#### Template Regeneration
```bash
# Check for template changes
./scripts/diff-templates.sh

# Regenerate all configurations
./scripts/inject-all.sh --backup

# Validate results
./scripts/validate-templates.sh
```

#### Secret Rotation
```bash
# Check secret freshness
./scripts/verify-secrets.sh

# Update expired secrets in 1Password
op item edit "Git GPG Key" --generate-password

# Regenerate configurations with new secrets
./scripts/inject-secrets.sh --all
```

## Performance Monitoring

### Shell Performance

#### Startup Time Monitoring
```bash
# Check current startup time
echo $SHELL_STARTUP_TIME

# Benchmark shell startup
time zsh -i -c exit
time bash -i -c exit

# Detailed profiling
zsh -i -c 'zprof'
```

#### Performance Optimization
```bash
# Clean shell history
./scripts/clean-shell-history.sh

# Optimize Zsh plugins
./scripts/optimize-zsh.sh

# Update Oh My Zsh
$ZSH/tools/upgrade.sh
```

### System Performance

#### Disk Usage Monitoring
```bash
# Check dotfiles disk usage
du -sh ~/git/dotfiles
du -sh ~/.config

# Clean temporary files
./scripts/clean-temp-files.sh

# Archive old backups
./scripts/archive-old-backups.sh
```

#### Memory Usage
```bash
# Monitor shell memory usage
ps aux | grep -E "(zsh|bash)" | head -10

# Check for memory leaks in custom functions
./scripts/profile-shell-functions.sh
```

## Security Maintenance

### Secret Management Audit

#### 1Password Integration Health
```bash
# Verify 1Password CLI authentication
op whoami
op vault list

# Test secret access
./scripts/verify-secrets.sh --verbose

# Check for expired tokens
./scripts/check-token-expiry.sh
```

#### Secret Scanning
```bash
# Scan for accidentally exposed secrets
./scripts/scan-secrets.sh --all

# Check Git history for leaked secrets
git secrets --scan-history

# Validate secret injection
./scripts/validate-secret-injection.sh
```

### Security Updates

#### SSH Key Maintenance
```bash
# Check SSH key health
./scripts/ssh-audit.sh

# Rotate SSH keys (if needed)
./scripts/ssh-keygen-helper.sh --rotate

# Update SSH configurations
./scripts/ssh-setup.sh --update
```

#### Git Security
```bash
# Verify GPG signing
git log --show-signature -5

# Update Git security settings
./scripts/git-setup.sh --security-update

# Check for insecure repositories
./scripts/audit-git-repos.sh
```

### File Permissions Audit
```bash
# Check and fix file permissions
./scripts/fix-permissions.sh

# Audit sensitive files
./scripts/audit-file-permissions.sh

# Security hardening check
./scripts/security-hardening-check.sh
```

## Component Maintenance

### Shell Configuration

#### Zsh Maintenance
```bash
# Update Oh My Zsh
$ZSH/tools/upgrade.sh

# Clean unused plugins
./scripts/clean-zsh-plugins.sh

# Update custom themes
./scripts/update-shell-themes.sh

# Validate shell configuration
./scripts/validate-shell-config.sh
```

#### Plugin Management
```bash
# List installed plugins
./scripts/list-shell-plugins.sh

# Update all plugins
./scripts/update-shell-plugins.sh

# Remove unused plugins
./scripts/cleanup-unused-plugins.sh
```

### Development Tools

#### Editor Maintenance
```bash
# Update Neovim configuration
./scripts/setup-editors.sh update

# Clean editor cache
./scripts/clean-editor-cache.sh

# Validate editor configuration
./scripts/validate-editor-config.sh
```

#### Version Manager Updates
```bash
# Update Node.js versions
nvm install --lts
nvm use --lts

# Update Python versions
pyenv update
pyenv install 3.11.0

# Update Ruby versions
rbenv install 3.1.0
rbenv global 3.1.0
```

### Terminal Configuration

#### Terminal Emulator Updates
```bash
# Update terminal configurations
./scripts/setup-terminals.sh update

# Validate terminal settings
./scripts/validate-terminals.sh

# Update terminal themes
./scripts/update-terminal-themes.sh
```

## Automated Maintenance

### Cron Jobs Setup

#### Daily Maintenance
```bash
# Add to crontab
# 0 9 * * * cd ~/git/dotfiles && ./scripts/daily-maintenance.sh

cat > ~/.local/bin/daily-dotfiles-maintenance << 'EOF'
#!/bin/bash
cd ~/git/dotfiles
./scripts/validate-symlinks.sh
./scripts/check-performance.sh
./scripts/verify-secrets.sh --quiet
EOF

chmod +x ~/.local/bin/daily-dotfiles-maintenance
```

#### Weekly Maintenance
```bash
# Weekly maintenance script
cat > ~/.local/bin/weekly-dotfiles-maintenance << 'EOF'
#!/bin/bash
cd ~/git/dotfiles
./scripts/bootstrap.sh update --quiet
./scripts/cleanup-old-backups.sh
./scripts/update-tools.sh --check-only
./scripts/performance-benchmark.sh
EOF

chmod +x ~/.local/bin/weekly-dotfiles-maintenance
```

### GitHub Actions Integration

#### Automated Testing
```yaml
# .github/workflows/maintenance.yml
name: Maintenance Checks
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  maintenance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run maintenance checks
        run: |
          ./scripts/validate-all.sh
          ./scripts/check-security.sh
          ./scripts/performance-benchmark.sh
```

## Maintenance Scripts

### Core Maintenance Scripts

#### Health Check Script
```bash
# scripts/health-check.sh
./scripts/bootstrap.sh doctor
./scripts/validate-package-managers.sh
./scripts/validate-terminals.sh
./scripts/verify-secrets.sh
./scripts/check-performance.sh
```

#### Update All Script
```bash
# scripts/update-all.sh
./scripts/bootstrap.sh update
./scripts/update-tools.sh
./scripts/update-packages.sh
./scripts/inject-all.sh
```

#### Cleanup Script
```bash
# scripts/cleanup.sh
./scripts/clean-temp-files.sh
./scripts/cleanup-old-backups.sh
./scripts/clean-shell-history.sh
./scripts/cleanup-unused-plugins.sh
```

### Custom Maintenance Tasks

#### Create Custom Maintenance Script
```bash
#!/bin/bash
# ~/.local/bin/dotfiles-maintenance

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

main() {
    log "Starting dotfiles maintenance..."
    
    # Health check
    log "Running health check..."
    ~/git/dotfiles/scripts/bootstrap.sh doctor
    
    # Update check
    log "Checking for updates..."
    cd ~/git/dotfiles
    git fetch --quiet
    if [[ $(git rev-list HEAD...origin/main --count) -gt 0 ]]; then
        log "Updates available, running update..."
        ./scripts/bootstrap.sh update
    fi
    
    # Performance check
    log "Checking performance..."
    if [[ ${SHELL_STARTUP_TIME:-1000} -gt 500 ]]; then
        log "Shell startup slow (${SHELL_STARTUP_TIME}ms), optimizing..."
        ./scripts/optimize-shell.sh
    fi
    
    # Secret validation
    log "Validating secrets..."
    ./scripts/verify-secrets.sh --quiet || {
        log "Secret validation failed, please check 1Password connection"
    }
    
    log "Maintenance completed successfully"
}

main "$@"
```

## Health Checks

### System Health Diagnostics

#### Built-in Doctor Mode
```bash
# Comprehensive health check
./scripts/bootstrap.sh doctor

# Specific component checks
./scripts/validate-package-managers.sh
./scripts/validate-terminals.sh
./scripts/validate-templates.sh
```

#### Performance Health Check
```bash
# Check shell performance
time zsh -i -c exit
echo "Startup time: ${SHELL_STARTUP_TIME}ms"

# Check symlink integrity
./scripts/validate-symlinks.sh

# Check configuration validity
./scripts/test-dotfiles.sh
```

#### Security Health Check
```bash
# Security audit
./scripts/security-audit.sh

# Secret validation
./scripts/verify-secrets.sh

# Permission audit
./scripts/audit-file-permissions.sh
```

### Monitoring Metrics

#### Key Performance Indicators
- Shell startup time: < 500ms
- Broken symlinks: 0
- Failed secret injections: 0
- Package manager errors: 0
- Security scan failures: 0

#### Health Check Schedule
```bash
# Add to ~/.zshrc or ~/.bashrc
if [[ -f ~/git/dotfiles/scripts/quick-health-check.sh ]]; then
    # Run quick health check on login (once per day)
    if [[ ! -f ~/.cache/dotfiles-health-check ]] || 
       [[ $(find ~/.cache/dotfiles-health-check -mtime +1) ]]; then
        ~/git/dotfiles/scripts/quick-health-check.sh --quiet
        touch ~/.cache/dotfiles-health-check
    fi
fi
```

## Troubleshooting

### Common Maintenance Issues

#### Slow Shell Startup
```bash
# Diagnose slow startup
zsh -xvs 2>&1 | head -50

# Profile startup
zsh -i -c 'zprof' | head -20

# Fix common issues
./scripts/optimize-shell.sh
```

#### Broken Symlinks
```bash
# Find broken symlinks
find ~ -type l -exec test ! -e {} \; -print 2>/dev/null

# Fix using bootstrap repair
./scripts/bootstrap.sh repair

# Manual fix
./scripts/fix-symlinks.sh
```

#### Secret Injection Failures
```bash
# Debug secret access
op signin --force
./scripts/verify-secrets.sh --verbose

# Re-inject secrets
./scripts/inject-all.sh --force
```

### Emergency Recovery

#### Restore from Backup
```bash
# Restore configurations from backup
./scripts/restore-from-backup.sh ~/.dotfiles-backup-$(date +%Y%m%d)

# Rebuild from scratch
./scripts/bootstrap.sh uninstall
./scripts/bootstrap.sh install
```

#### Reset to Known Good State
```bash
# Reset to latest known good commit
cd ~/git/dotfiles
git reset --hard origin/main

# Reinstall everything
./scripts/bootstrap.sh install --force
```

For more detailed troubleshooting procedures, see [troubleshooting.md](troubleshooting.md).

---

## Related Documentation

- [Backup and Recovery](backup.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Migration Procedures](migration.md)
- [Security Documentation](secrets.md)
- [Testing Framework](testing.md) 