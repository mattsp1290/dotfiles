# ADR-002: Secret Management Strategy

**Status**: Accepted  
**Date**: 2024-12-19  
**Deciders**: Matt Spurlin  
**Technical Story**: Implement enterprise-grade secret management to eliminate exposed secrets in dotfiles while maintaining performance and usability

## Context and Problem Statement

The dotfiles system requires secure management of sensitive configuration data including:
- API keys and access tokens (AWS, GitHub, Azure, etc.)
- SSH private keys and certificates
- Database credentials and connection strings
- Application secrets and configuration keys
- Personal access tokens and authentication data

Initial security audit (AUDIT-002) discovered 25+ exposed secrets in configuration files, creating critical security vulnerabilities that prevent safe public repository sharing. The solution must provide:
- Zero secrets in repository with strong detection
- Fast secret retrieval (<100ms for shell startup)
- Cross-platform compatibility (macOS, Linux, WSL)
- Enterprise-grade security with encryption
- Seamless integration with existing workflows
- Team sharing capabilities for collaborative environments

## Decision Drivers

- **Security**: Enterprise-grade encryption and access controls
- **Performance**: Sub-100ms secret retrieval for shell startup
- **Cross-platform**: Identical experience across operating systems
- **User Experience**: Minimal friction for daily workflows
- **Integration**: Seamless template system integration
- **Compliance**: Meet enterprise security requirements
- **Backup**: Reliable backup and recovery mechanisms
- **Team Collaboration**: Support for shared secrets when needed

## Considered Options

1. **1Password CLI**: Commercial password manager with CLI integration
2. **pass (password-store)**: Unix password manager with GPG encryption
3. **Bitwarden CLI**: Open-source password manager with cloud sync
4. **age + sops**: Modern encryption tools for file-based secrets
5. **git-crypt**: Repository-level encryption for Git
6. **HashiCorp Vault**: Enterprise secret management platform

## Decision Outcome

**Chosen option**: "1Password CLI with Template Injection System"

We selected 1Password CLI as the foundation for secret management, integrated with a custom template injection system for seamless configuration generation.

### Positive Consequences
- Immediate resolution of critical security vulnerabilities
- Excellent performance with session caching (<50ms retrieval)
- Best-in-class user experience and CLI design
- Enterprise-grade security with Secret Key architecture
- Automatic cloud backup with version history
- Seamless cross-platform operation
- Strong ecosystem integration and support
- Future team sharing capabilities
- Professional support available

### Negative Consequences
- Monthly subscription cost ($2.99-7.99 per user)
- Dependency on cloud service provider
- Requires internet connection for initial setup
- Proprietary solution vs open-source alternatives
- Vendor lock-in for secret storage format

## Pros and Cons of the Options

### Option 1: 1Password CLI (Chosen)
- **Pros**: Best UX, excellent performance, enterprise security, cross-platform, existing user investment, team sharing
- **Cons**: Subscription cost, proprietary, cloud dependency

### Option 2: pass (password-store)
- **Pros**: Free, GPG-based, git integration, lightweight, open source
- **Cons**: Complex setup, GPG key management burden, poor UX, no cloud sync

### Option 3: Bitwarden CLI
- **Pros**: Open source, free tier, good security, web interface
- **Cons**: Slower performance, limited offline capabilities, less mature CLI

### Option 4: age + sops
- **Pros**: Modern crypto, very fast, simple design, no dependencies
- **Cons**: Immature ecosystem, requires custom tooling, no built-in sharing

### Option 5: git-crypt
- **Pros**: Repository integration, transparent encryption, simple concept
- **Cons**: Secrets still in repository, limited key management, sharing complexity

### Option 6: HashiCorp Vault
- **Pros**: Enterprise features, excellent security, dynamic secrets, audit trails
- **Cons**: Operational complexity, overkill for personal use, significant setup overhead

## Implementation Details

### Template Injection System
```bash
# Template syntax for secret references
git_signing_key: "{{ op://Personal/Git GPG Key/private_key }}"
github_token: "{{ op://Work/API Tokens/github_token }}"
ssh_private_key: "{{ op://Personal/SSH Keys/id_ed25519/private_key }}"

# Secret injection process
./scripts/inject-secrets.sh
./scripts/verify-secrets.sh
```

### Performance Optimizations
- Session caching to minimize API calls
- Bulk secret retrieval for related configurations
- Lazy loading for non-critical secrets
- Background pre-warming for frequently used secrets

### Security Measures
- Pre-commit hooks for secret detection
- Template validation before injection
- Secure temporary file handling
- Automatic cleanup of processed secrets
- Git history scanning for historical exposure

### Cross-Platform Setup
```bash
# macOS installation
brew install 1password-cli

# Linux installation (automated)
./scripts/setup-secrets.sh

# Authentication
op signin your-account.1password.com
```

### Integration Points
- Template system for configuration generation
- Shell environment variable injection
- Git hooks for automatic secret validation
- CI/CD integration for security scanning
- Backup system for vault structure

## Validation Criteria

### Security Validation
- Zero secrets detected in repository files
- All 25+ identified secrets migrated to 1Password
- Secret scanning passes in CI/CD pipeline
- Historical Git analysis shows no exposure
- Template injection works without leaving traces

### Performance Validation
```bash
# Shell startup time remains under 500ms
time zsh -i -c exit

# Secret retrieval benchmarks
./scripts/benchmark-secrets.sh
```

### Functionality Validation
```bash
# End-to-end secret workflow
./tests/integration/test-secret-management.sh

# Cross-platform compatibility
./tests/security/validate-secret-injection.sh
```

### Enterprise Validation
- Compliance with security policies
- Audit trail availability
- Team sharing capabilities tested
- Backup and recovery procedures verified

## Links

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [1Password Security Model](https://1password.com/security/)
- [Secret Management Documentation](../secret-management.md)
- [Template Injection Guide](../template-syntax.md)
- [Security Audit Report](../../proompting/audit/secrets_report.md)
- [ADR-009: Security Architecture](009-security-architecture.md)

## Notes

The 1Password CLI decision represents a pragmatic balance between security, usability, and maintainability. While the subscription cost was a consideration, the security benefits and developer productivity gains justify the investment. The template injection system provides a clean abstraction that could be adapted to other secret management backends if needed in the future.

The implementation includes comprehensive validation to ensure the security improvements are effective and maintainable over time. 