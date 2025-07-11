# SSH Troubleshooting Guide

This guide helps resolve common SSH configuration and connectivity issues when using the dotfiles SSH system.

## Table of Contents

1. [Quick Diagnosis](#quick-diagnosis)
2. [Common Issues](#common-issues)
3. [Configuration Problems](#configuration-problems)
4. [Authentication Issues](#authentication-issues)
5. [Connection Problems](#connection-problems)
6. [Performance Issues](#performance-issues)
7. [Debug Techniques](#debug-techniques)
8. [Platform-Specific Issues](#platform-specific-issues)

## Quick Diagnosis

### Run Diagnostics First

```bash
# Validate SSH configuration
./scripts/ssh-setup.sh validate

# Run security audit
./scripts/ssh-audit.sh

# Test specific connection
./scripts/ssh-setup.sh test github.com
```

### Check SSH Agent Status

```bash
# Check if SSH agent is running
echo $SSH_AUTH_SOCK

# List loaded keys
ssh-add -l

# Load keys if needed
ssh-add ~/.ssh/id_rsa
```

### Basic Connectivity Test

```bash
# Test with verbose output
ssh -vvv hostname

# Test configuration parsing
ssh -F ~/.ssh/config -G hostname
```

## Common Issues

### 1. Permission Denied (publickey)

**Symptoms:**
- `Permission denied (publickey)` error
- Connection rejected immediately

**Causes & Solutions:**

#### Missing or Wrong Public Key
```bash
# Check if public key exists on server
ssh-copy-id user@hostname

# Or manually add to server
cat ~/.ssh/id_rsa.pub | ssh user@hostname 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
```

#### Wrong SSH Key
```bash
# Specify correct key
ssh -i ~/.ssh/specific_key user@hostname

# Update SSH config to use correct key
Host myserver
    IdentityFile ~/.ssh/correct_key
    IdentitiesOnly yes
```

#### SSH Agent Issues
```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_rsa

# Verify keys are loaded
ssh-add -l
```

### 2. Host Key Verification Failed

**Symptoms:**
- `Host key verification failed` error
- Warning about changed host keys

**Solutions:**

#### First Connection (Expected)
```bash
# Accept new host key (verify fingerprint first)
ssh hostname
# Type 'yes' when prompted

# Or disable strict checking for testing
ssh -o StrictHostKeyChecking=no hostname
```

#### Changed Host Key (Security Risk)
```bash
# Remove old host key
ssh-keygen -R hostname

# Connect again to add new key
ssh hostname
```

#### Check Host Key Fingerprint
```bash
# Get server's host key fingerprint
ssh-keyscan hostname | ssh-keygen -lf -

# Compare with expected fingerprint
```

### 3. Connection Timeout

**Symptoms:**
- Long delays before connection
- `Connection timed out` errors

**Solutions:**

#### Network Issues
```bash
# Test basic connectivity
ping hostname
telnet hostname 22

# Try different port (if configured)
ssh -p 2222 hostname
```

#### Firewall/NAT Issues
```bash
# Try alternative SSH port (443)
ssh -p 443 hostname

# Use HTTP CONNECT proxy
ssh -o ProxyCommand='nc -X connect -x proxy:8080 %h %p' hostname
```

#### DNS Issues
```bash
# Use IP address instead
ssh user@192.168.1.100

# Check DNS resolution
nslookup hostname
dig hostname
```

## Configuration Problems

### 1. Invalid SSH Config Syntax

**Symptoms:**
- SSH commands fail with config errors
- Validation script reports syntax errors

**Diagnosis:**
```bash
# Test configuration
ssh -F ~/.ssh/config -G localhost

# Validate with script
./scripts/ssh-setup.sh validate
```

**Common Syntax Issues:**

#### Incorrect Indentation
```ssh
# Wrong
Host github.com
HostName github.com

# Correct
Host github.com
    HostName github.com
```

#### Missing Host Block
```ssh
# Wrong
HostName example.com
User myuser

# Correct
Host example
    HostName example.com
    User myuser
```

#### Invalid Option Names
```ssh
# Wrong
Host example
    Hostname example.com  # Note: lowercase 'n'

# Correct
Host example
    HostName example.com  # Note: uppercase 'N'
```

### 2. Include Path Issues

**Symptoms:**
- Modular configs not loading
- Some host configurations ignored

**Solutions:**

#### Check Include Paths
```bash
# Verify paths exist
ls -la ~/.dotfiles/config/ssh/config.d/

# Check permissions
ls -la ~/.ssh/config
```

#### Fix Include Directive
```ssh
# Use full path for reliability
Include /Users/username/.dotfiles/config/ssh/config.d/*.ssh

# Or relative to home
Include ~/.dotfiles/config/ssh/config.d/*.ssh
```

### 3. Stow Conflicts

**Symptoms:**
- `stow` command fails with conflicts
- Configuration not installed

**Solutions:**

#### Resolve Conflicts
```bash
# Remove existing files
rm ~/.ssh/config

# Or adopt existing configuration
stow --adopt --target="$HOME" home

# Then re-install
stow --restow --target="$HOME" home
```

## Authentication Issues

### 1. SSH Key Not Found

**Symptoms:**
- SSH tries password authentication
- Multiple key attempts

**Solutions:**

#### Specify Key Explicitly
```ssh
Host myserver
    IdentityFile ~/.ssh/specific_key
    IdentitiesOnly yes
```

#### Check Key Permissions
```bash
# Private key: 600
chmod 600 ~/.ssh/id_rsa

# Public key: 644
chmod 644 ~/.ssh/id_rsa.pub

# SSH directory: 700
chmod 700 ~/.ssh
```

### 2. Passphrase Issues

**Symptoms:**
- Repeated passphrase prompts
- Cannot authenticate with key

**Solutions:**

#### SSH Agent Management
```bash
# Kill existing agents
killall ssh-agent

# Start new agent
eval "$(ssh-agent -s)"

# Add key with passphrase
ssh-add ~/.ssh/id_rsa
```

#### macOS Keychain Integration
```ssh
Host *
    AddKeysToAgent yes
    UseKeychain yes
```

### 3. Multiple Key Confusion

**Symptoms:**
- Wrong key used for connection
- Authentication fails unexpectedly

**Solutions:**

#### Use IdentitiesOnly
```ssh
Host specific-server
    IdentityFile ~/.ssh/specific_key
    IdentitiesOnly yes
```

#### Clear SSH Agent
```bash
# Remove all keys
ssh-add -D

# Add only needed key
ssh-add ~/.ssh/specific_key
```

## Connection Problems

### 1. Multiplexing Issues

**Symptoms:**
- "Control socket connect" errors
- Stale connections

**Solutions:**

#### Clean Control Sockets
```bash
# Remove stale sockets
rm /tmp/ssh_mux_*

# Or disable multiplexing temporarily
ssh -o ControlMaster=no hostname
```

#### Fix Control Socket Path
```ssh
Host *
    ControlPath /tmp/ssh_mux_%h_%p_%r
    ControlMaster auto
    ControlPersist 10m
```

### 2. Jump Host Problems

**Symptoms:**
- Cannot connect through bastion
- ProxyJump failures

**Solutions:**

#### Test Jump Host Separately
```bash
# Test bastion connection
ssh bastion-host

# Test with explicit proxy command
ssh -o ProxyCommand='ssh -W %h:%p bastion-host' target-host
```

#### Update Jump Configuration
```ssh
Host target-server
    ProxyJump bastion-host
    # Or use ProxyCommand
    # ProxyCommand ssh -W %h:%p bastion-host
```

### 3. Port Forwarding Issues

**Symptoms:**
- Local ports not accessible
- Forwarding setup fails

**Solutions:**

#### Check Port Availability
```bash
# Check if port is in use
lsof -i :3000
netstat -an | grep 3000
```

#### Fix Forwarding Configuration
```ssh
Host dev-server
    LocalForward 3000 localhost:3000
    # Use different local port if conflict
    # LocalForward 3001 localhost:3000
```

## Performance Issues

### 1. Slow Connection Establishment

**Solutions:**

#### Enable Compression
```ssh
Host slow-connection
    Compression yes
```

#### Optimize Keep-Alive
```ssh
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

#### Use Connection Multiplexing
```ssh
Host *
    ControlMaster auto
    ControlPath /tmp/ssh_mux_%h_%p_%r
    ControlPersist 600
```

### 2. DNS Resolution Delays

**Solutions:**

#### Use IP Addresses
```ssh
Host server-ip
    HostName 192.168.1.100
    User myuser
```

#### Configure DNS Options
```ssh
Host *
    AddressFamily inet  # IPv4 only
```

## Debug Techniques

### 1. Verbose SSH Output

```bash
# Levels of verbosity
ssh -v hostname     # Basic verbose
ssh -vv hostname    # More verbose
ssh -vvv hostname   # Maximum verbose
```

**What to Look For:**
- Authentication method attempts
- Key file locations
- Configuration parsing
- Connection establishment steps

### 2. Configuration Testing

```bash
# Test configuration without connecting
ssh -F ~/.ssh/config -G hostname

# Parse specific configuration
ssh -F /path/to/config -G hostname
```

### 3. Network Debugging

```bash
# Test basic connectivity
nc -zv hostname 22

# Trace route to host
traceroute hostname

# Check DNS resolution
dig hostname
nslookup hostname
```

### 4. SSH Agent Debugging

```bash
# List agent keys with details
ssh-add -l -E sha256

# Test key authentication
ssh-add -T ~/.ssh/id_rsa

# Debug agent communication
SSH_AUTH_SOCK=/path/to/socket ssh-add -l
```

## Platform-Specific Issues

### macOS Issues

#### Keychain Integration
```bash
# Add key to keychain
ssh-add --apple-use-keychain ~/.ssh/id_rsa

# Load keys from keychain
ssh-add --apple-load-keychain
```

#### PATH Issues
```bash
# Use full path for SSH
/usr/bin/ssh hostname

# Check SSH version
ssh -V
```

### Linux Issues

#### SSH Agent on Login
```bash
# Add to ~/.bashrc or ~/.zshrc
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
fi
```

#### SELinux Issues
```bash
# Check SELinux context
ls -Z ~/.ssh/

# Restore context
restorecon -R ~/.ssh/
```

### Cross-Platform Issues

#### Line Ending Problems
```bash
# Convert line endings (if config copied from Windows)
dos2unix ~/.ssh/config
```

#### Permission Issues
```bash
# Reset all SSH permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub
```

## Emergency Procedures

### 1. Complete SSH Reset

```bash
# Backup current configuration
cp -r ~/.ssh ~/.ssh.backup.$(date +%Y%m%d)

# Remove current configuration
rm -rf ~/.ssh

# Reinstall from dotfiles
./scripts/ssh-setup.sh install

# Generate new keys if needed
./scripts/ssh-keygen-helper.sh
```

### 2. Bypass SSH Config

```bash
# Connect without config file
ssh -F /dev/null user@hostname

# Use minimal options
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no user@hostname
```

### 3. Recovery Access

If locked out completely:

1. **Use console access** (if available)
2. **Use recovery key/password** on cloud instances
3. **Mount disk externally** to fix configuration
4. **Contact system administrator** for assistance

## Getting Help

### Built-in Help

```bash
# SSH help
man ssh
man ssh_config

# Script help
./scripts/ssh-setup.sh help
./scripts/ssh-keygen-helper.sh --help
```

### Log Analysis

```bash
# System SSH logs (varies by platform)
tail -f /var/log/auth.log          # Ubuntu/Debian
tail -f /var/log/secure            # CentOS/RHEL
log show --predicate 'process == "sshd"' --last 1h  # macOS
```

### Community Resources

- [OpenSSH Documentation](https://www.openssh.com/manual.html)
- [SSH Academy](https://www.ssh.com/academy/)
- [GitHub SSH Help](https://docs.github.com/en/authentication/troubleshooting-ssh)

### Contact Information

For dotfiles-specific issues:
1. Run diagnostics: `./scripts/ssh-audit.sh`
2. Check logs and verbose output
3. Review configuration with `ssh -G hostname`
4. Document error messages and steps to reproduce 