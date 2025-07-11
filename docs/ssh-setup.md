# SSH Configuration Guide

This guide covers the SSH configuration system implemented as part of the dotfiles repository. The SSH configuration provides secure, optimized, and modular SSH settings with cross-platform compatibility.

## Overview

The SSH configuration system includes:
- **Modular Configuration**: Organized by purpose (GitHub, work, personal, cloud, local)
- **Security Hardening**: Strong encryption, proper permissions, and secure defaults
- **Performance Optimization**: Connection multiplexing and compression
- **Secret Integration**: Template-based configuration with secret injection
- **Cross-Platform Support**: Works on macOS and Linux
- **Management Scripts**: Automated setup, validation, and security auditing

## Directory Structure

```
├── home/.ssh/                    # Main SSH directory (symlinked)
│   └── config                    # Main SSH configuration file
├── config/ssh/                   # SSH configuration modules
│   └── config.d/                 # Modular host configurations
│       ├── github.ssh            # GitHub-specific configuration
│       ├── personal.ssh          # Personal servers and services
│       ├── work.ssh              # Work-related hosts
│       ├── cloud.ssh             # Cloud provider configurations
│       └── local.ssh             # Local development and testing
├── templates/ssh/                # Secret injection templates
│   ├── personal-servers.ssh.template
│   └── work-servers.ssh.template
├── scripts/                      # Management scripts
│   ├── ssh-setup.sh              # SSH setup and installation
│   └── ssh-audit.sh              # Security audit script
└── docs/                         # Documentation
    ├── ssh-setup.md              # This file
    └── ssh-troubleshooting.md    # Troubleshooting guide
```

## Installation

### Prerequisites

- **OpenSSH Client**: Available on all target platforms
- **GNU Stow**: For symlink management (installed via CORE-003)
- **Secret Management**: 1Password CLI (configured via SECRET-003)

### Quick Installation

1. **Install SSH configuration:**
   ```bash
   ./scripts/ssh-setup.sh install
   ```

2. **Validate configuration:**
   ```bash
   ./scripts/ssh-setup.sh validate
   ```

3. **Test connectivity:**
   ```bash
   ./scripts/ssh-setup.sh test github.com
   ```

### Manual Installation

1. **Create backup of existing SSH configuration:**
   ```bash
   ./scripts/ssh-setup.sh backup
   ```

2. **Install using Stow:**
   ```bash
   cd ~/.dotfiles
   stow --target="$HOME" home
   ```

3. **Set proper permissions:**
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/config
   ```

## Configuration

### Main Configuration File

The main SSH configuration (`home/.ssh/config`) includes:
- Preservation of existing workspace and Colima configurations
- Global security and performance settings
- Modular includes for different host types

### Modular Host Configurations

#### GitHub Configuration (`config/ssh/config.d/github.ssh`)
- Optimized for Git operations
- Connection multiplexing for performance
- Alternative hostnames and fallback configurations

#### Personal Configuration (`config/ssh/config.d/personal.ssh`)
- Template-based with secret injection
- Personal servers, VPS, home lab, IoT devices
- Flexible security settings for different environments

#### Work Configuration (`config/ssh/config.d/work.ssh`)
- Enterprise-focused with bastion host support
- Jump host configurations
- Development environment optimizations

#### Cloud Configuration (`config/ssh/config.d/cloud.ssh`)
- AWS, GCP, Azure, DigitalOcean configurations
- Provider-specific optimizations
- Security settings for cloud environments

#### Local Configuration (`config/ssh/config.d/local.ssh`)
- Development containers and VMs
- Local network devices
- Relaxed security for testing environments

## Secret Integration

### Template System

SSH configurations can use templates for sensitive information:

1. **Create template** in `templates/ssh/`
2. **Define variables** using Jinja2 syntax
3. **Store secrets** in 1Password or configured secret store
4. **Generate configuration** via secret injection system

### Example Template Usage

```ssh
# In templates/ssh/work-servers.ssh.template
Host work-server
    HostName {{ WORK_SERVER_HOST }}
    User {{ WORK_USERNAME }}
    IdentityFile ~/.ssh/{{ WORK_SSH_KEY }}
```

## SSH Key Management

### Generating SSH Keys

**Generate Ed25519 key (recommended):**
```bash
./scripts/ssh-setup.sh keygen --type ed25519
```

**Generate RSA key:**
```bash
./scripts/ssh-setup.sh keygen --type rsa
```

### Key Security Best Practices

1. **Use strong passphrases** for all private keys
2. **Use Ed25519** for new key generation
3. **Rotate keys regularly** (annually recommended)
4. **Use different keys** for different purposes
5. **Store keys securely** with proper file permissions

### SSH Agent Configuration

The configuration includes optimized SSH agent settings:
- Automatic key loading on macOS (UseKeychain yes)
- Key forwarding controls for security
- Connection multiplexing for performance

## Security Features

### Security Hardening

- **Strong Encryption**: Modern cipher and MAC preferences
- **Host Verification**: VerifyHostKeyDNS and VisualHostKey
- **Authentication**: Publickey authentication prioritized
- **Connection Security**: Appropriate timeouts and keep-alive settings

### File Permissions

The system automatically enforces proper SSH file permissions:
- SSH directory: 700
- Private keys: 600
- Public keys: 644
- Configuration files: 600
- known_hosts: 600

### Security Audit

Run comprehensive security audit:
```bash
./scripts/ssh-audit.sh
```

The audit checks:
- File and directory permissions
- Key algorithm strength and protection
- Configuration security settings
- SSH agent configuration
- known_hosts security

## Performance Optimization

### Connection Multiplexing

Configured for optimal performance:
- **ControlMaster auto**: Automatic connection sharing
- **ControlPersist**: Keeps connections alive for reuse
- **ControlPath**: Organized socket paths

### Compression and Keep-Alive

- **Compression yes**: Reduces bandwidth usage
- **ServerAliveInterval**: Prevents connection timeouts
- **TCPKeepAlive**: Maintains connection stability

## Usage Examples

### Basic SSH Connection
```bash
ssh github.com                    # Uses GitHub configuration
ssh personal-server               # Uses personal server config
ssh work-dev                      # Uses work development config
```

### Git Operations
```bash
git clone git@github.com:user/repo.git    # Uses GitHub SSH config
git clone git@work-git:company/repo.git   # Uses work Git config
```

### Jump Host Usage
```bash
ssh work-server-1                 # Automatically uses bastion jump host
```

### Local Development
```bash
ssh docker-container -p 2222     # Connect to Docker container
ssh vm-development               # Connect to local VM
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Check file permissions with `./scripts/ssh-audit.sh`
   - Ensure SSH agent is running and keys are loaded

2. **Configuration Syntax Errors**
   - Validate with `./scripts/ssh-setup.sh validate`
   - Check SSH config syntax with `ssh -F ~/.ssh/config -G hostname`

3. **Connection Timeouts**
   - Verify network connectivity
   - Check host key verification settings
   - Review connection timeout settings

4. **Key Authentication Failures**
   - Ensure public key is added to target server
   - Check SSH agent key loading
   - Verify private key permissions and passphrases

### Debug Mode

Enable SSH debug output for troubleshooting:
```bash
ssh -vvv hostname    # Verbose SSH debugging
```

### Testing Connectivity

Test specific host configurations:
```bash
./scripts/ssh-setup.sh test github.com
./scripts/ssh-setup.sh test work-server
```

## Advanced Configuration

### Custom Host Configurations

Add custom host configurations to appropriate modules:

1. **For personal hosts**: Edit `config/ssh/config.d/personal.ssh`
2. **For work hosts**: Edit `config/ssh/config.d/work.ssh`
3. **For cloud hosts**: Edit `config/ssh/config.d/cloud.ssh`

### SSH Certificates

For environments using SSH certificates:
```ssh
Host *.company.com
    CertificateFile ~/.ssh/id_ed25519-cert.pub
    IdentityFile ~/.ssh/id_ed25519
```

### Port Forwarding

Configure port forwarding for development:
```ssh
Host dev-server
    LocalForward 3000 localhost:3000
    LocalForward 5432 db-server:5432
```

## Maintenance

### Regular Tasks

1. **Security Audit**: Run monthly
   ```bash
   ./scripts/ssh-audit.sh
   ```

2. **Key Rotation**: Annually or as required
   ```bash
   ./scripts/ssh-setup.sh keygen --type ed25519
   ```

3. **Configuration Validation**: After changes
   ```bash
   ./scripts/ssh-setup.sh validate
   ```

### Backup and Recovery

- **Backup**: Created automatically during installation
- **Manual Backup**: `./scripts/ssh-setup.sh backup`
- **Recovery**: Restore from backup and re-run installation

## Integration

### Git Integration

The SSH configuration is optimized for Git operations:
- GitHub configurations with fallback options
- Work Git server configurations
- Connection multiplexing for faster operations

### Development Workflow

SSH configuration supports modern development workflows:
- VS Code remote development
- Container and VM access
- Jump host configurations for secure environments

## Security Considerations

### Best Practices

1. **Never commit private keys** to the repository
2. **Use secret injection** for sensitive configurations
3. **Regular security audits** with provided tools
4. **Monitor SSH access logs** on target servers
5. **Use hardware security keys** where possible

### Compliance

The configuration follows security best practices from:
- NIST SSH Guidelines
- CIS SSH Benchmarks
- OpenSSH security recommendations
- Industry security standards

## Support

For issues or questions:
1. Check the [troubleshooting guide](ssh-troubleshooting.md)
2. Run the security audit: `./scripts/ssh-audit.sh`
3. Validate configuration: `./scripts/ssh-setup.sh validate`
4. Review SSH debug output with `-vvv` flag 