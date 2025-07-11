# Security Testing Suite

This directory contains comprehensive security validation tools for the dotfiles repository, implementing the TEST-004 Security Validation requirements. The suite ensures zero secret exposure and maintains security best practices throughout the development lifecycle.

## 🔒 Security Tools Overview

### Core Security Scripts

| Script | Purpose | Key Features |
|--------|---------|--------------|
| `scan-secrets.sh` | Secret detection | Multi-pattern scanning, whitelist support, comprehensive reporting |
| `check-permissions.sh` | File permission validation | Automatic fixing, SSH-specific checks, policy enforcement |
| `git-history-scan.sh` | Git history analysis | Commit message scanning, sensitive file detection, branch analysis |
| `template-security-test.sh` | Template system security | Injection testing, variable handling, error analysis |

### Configuration Files

| File | Purpose |
|------|---------|
| `config/whitelist.txt` | Approved patterns to reduce false positives |
| `config/patterns.yaml` | Custom secret detection patterns |
| `config/permissions.yaml` | File permission policy configuration |

## 🚀 Quick Start

### Installation

1. **Make scripts executable:**
   ```bash
   chmod +x tests/security/*.sh
   ```

2. **Install optional tools (recommended):**
   ```bash
   # macOS
   brew install trufflehog gitleaks jq
   pip install detect-secrets
   brew install git-secrets
   
   # Ubuntu/Debian
   sudo apt-get install jq
   pip install detect-secrets
   ```

3. **Install pre-commit hooks:**
   ```bash
   pip install pre-commit
   pre-commit install
   ```

### Basic Usage

```bash
# Run all security checks
./tests/security/scan-secrets.sh
./tests/security/check-permissions.sh
./tests/security/git-history-scan.sh
./tests/security/template-security-test.sh

# Quick security audit
./tests/security/scan-secrets.sh --verbose
```

## 📋 Detailed Tool Documentation

### 1. Secret Scanner (`scan-secrets.sh`)

Comprehensive secret detection using built-in patterns.

**Features:**
- 🔍 **Multi-Pattern Detection**: Private keys, API keys, passwords, tokens
- ⚡ **Performance Optimized**: Fast scanning with comprehensive coverage
- 🎯 **Whitelist Support**: Reduce false positives with approved patterns
- 📊 **Detailed Reporting**: Markdown and JSON report generation

**Usage:**
```bash
# Basic scan
./scan-secrets.sh

# Verbose output with debug information
./scan-secrets.sh --verbose

# CI-friendly mode (always exits 0)
./scan-secrets.sh --report-only

# Custom configuration directory
./scan-secrets.sh --config /path/to/config
```

**Detected Patterns:**
- **Private Keys**: RSA, DSA, EC, OpenSSH, PGP
- **API Keys**: Generic and service-specific patterns
- **Cloud Credentials**: AWS, GitHub, GitLab, Docker
- **Database Credentials**: MySQL, PostgreSQL, MongoDB
- **High-Entropy Strings**: Base64, hexadecimal patterns

### 2. Permission Checker (`check-permissions.sh`)

Validates and fixes file permissions according to security best practices.

**Security Policy:**
- **644**: Configuration files (readable, not executable)
- **755**: Scripts and executables
- **600**: Sensitive files (SSH keys, credentials)
- **700**: Sensitive directories

**Usage:**
```bash
# Check permissions (report only)
./check-permissions.sh

# Automatically fix permission issues
./check-permissions.sh --fix

# Verbose output with detailed analysis
./check-permissions.sh --verbose

# CI-friendly mode
./check-permissions.sh --report-only
```

**Features:**
- 🔧 **Automatic Fixing**: Correct permissions with `--fix` flag
- 🔐 **SSH Security**: Special handling for SSH keys and directories
- ⚠️ **Security Warnings**: Detect world-writable files
- 📋 **Policy Compliance**: Enforce organizational security policies

### 3. Git History Scanner (`git-history-scan.sh`)

Analyzes git history for potential security issues.

**Analysis Types:**
- **Commit Messages**: Suspicious patterns indicating secret exposure
- **File Patterns**: Sensitive files that shouldn't be in git
- **Branch/Tag Names**: Suspicious naming conventions
- **Content Scanning**: Deep analysis of historical file content (optional)

**Usage:**
```bash
# Basic history scan
./git-history-scan.sh

# Deep content analysis (slower but comprehensive)
./git-history-scan.sh --deep

# Scan commits since specific date
./git-history-scan.sh --since 2023-01-01

# Verbose output
./git-history-scan.sh --verbose
```

**Security Checks:**
- 🕵️ **Commit Message Analysis**: Detect secret-related commit messages
- 📁 **File Pattern Detection**: Find sensitive files in history
- 🌿 **Branch/Tag Analysis**: Identify suspicious naming patterns
- 📜 **Historical Content**: Scan file content across commits

### 4. Template Security Tester (`template-security-test.sh`)

Validates template system security against various attack vectors.

**Security Tests:**
- **Template Injection**: Code injection vulnerability testing
- **Secret Exposure**: Ensure templates don't leak secrets
- **Variable Handling**: Safe variable substitution validation
- **Error Handling**: Information disclosure in error messages
- **File Inclusion**: Path traversal vulnerability testing

**Usage:**
```bash
# Full security test suite
./template-security-test.sh

# Fast mode (basic validation only)
./template-security-test.sh --fast

# Verbose output with detailed test results
./template-security-test.sh --verbose

# CI-friendly mode
./template-security-test.sh --report-only
```

**Test Coverage:**
- 💉 **Injection Testing**: Malicious input patterns
- 🔒 **Secret Protection**: Template variable security
- 🛡️ **Input Sanitization**: Safe handling of user input
- ❌ **Error Security**: Safe error message generation

## 📁 Directory Structure

```
tests/security/
├── scan-secrets.sh              # Multi-tool secret scanner
├── check-permissions.sh         # File permission validator
├── git-history-scan.sh         # Git history security analysis
├── template-security-test.sh   # Template system security testing
├── config/                     # Configuration files
│   ├── whitelist.txt          # Approved patterns (false positive reduction)
│   ├── patterns.yaml          # Custom secret detection patterns
│   └── permissions.yaml       # File permission policies
├── logs/                      # Scan execution logs
│   ├── scan-secrets-*.log
│   ├── permissions-*.log
│   └── git-history-*.log
├── reports/                   # Generated security reports
│   ├── security-scan-*.md
│   ├── permission-check-*.md
│   └── git-history-*.md
└── README.md                  # This file
```

## ⚙️ Configuration

### Whitelist Configuration (`config/whitelist.txt`)

Reduce false positives by whitelisting approved patterns:

```text
# Example patterns (safe in dotfiles context)
example[_-]?password
test[_-]?key
sample[_-]?token

# Template variables (intentional placeholders)
\$\{.*\}
\{\{.*\}\}

# Documentation examples
password.*example
api.*key.*example
```

### Custom Patterns (`config/patterns.yaml`)

Define organization-specific secret detection patterns:

```yaml
patterns:
  - name: "Company API Keys"
    regex: "company_api_[a-zA-Z0-9]{32}"
    severity: "high"
    description: "Internal API keys"
```

## 🔄 CI/CD Integration

### GitHub Actions

Security validation is automatically triggered on:
- **Push** to main/master/develop branches
- **Pull Requests**
- **Daily Schedule** (2 AM UTC)
- **Manual Dispatch**

### Pre-commit Hooks

Prevent secrets from being committed:

```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# Run manually
pre-commit run --all-files
```

## 📊 Reports and Logging

### Report Generation

All tools generate comprehensive reports:

- **Markdown Reports**: Human-readable findings with recommendations
- **JSON Reports**: Machine-readable data for automation
- **Log Files**: Detailed execution logs for debugging

### Report Locations

- **Latest Reports**: `reports/.latest-*` files contain paths to newest reports
- **Archived Reports**: All reports are timestamped and preserved
- **Log Files**: Detailed execution logs in `logs/` directory

## 🚨 Security Incident Response

### When Secrets Are Detected

1. **Immediate Actions:**
   - Stop the commit/push process
   - Identify the secret type and scope
   - Remove secrets from files

2. **Assessment:**
   - Check if secrets were pushed to remote
   - Verify git history cleanliness
   - Evaluate exposure risk

3. **Remediation:**
   - Rotate exposed credentials
   - Clean git history if necessary
   - Update security baselines

### Tools for Secret Removal

- **BFG Repo-Cleaner**: `git clone --mirror <repo> && java -jar bfg.jar --delete-files secret.txt repo.git`
- **git-filter-branch**: `git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch secret.txt'`

## 🛠️ Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **False Positives** | Add patterns to `config/whitelist.txt` |
| **Performance Issues** | Use `--fast` mode for quicker scans |
| **Permission Errors** | Run `check-permissions.sh --fix` |
| **Tool Not Found** | Install optional tools or continue with built-in patterns |

### Debug Output

Enable verbose output for debugging:

```bash
./scan-secrets.sh --verbose
./check-permissions.sh --verbose
./git-history-scan.sh --verbose
./template-security-test.sh --verbose
```

### Log Analysis

Check log files for detailed execution information:

```bash
# View latest scan logs
tail -f logs/scan-secrets-*.log

# Check for specific errors
grep "ERROR" logs/*.log
```

## 📈 Performance Optimization

### Scan Performance

- **Use `--fast` mode** for quicker development workflows
- **Limit git history** with `--since` flag for large repositories
- **Configure exclusions** in whitelist for known false positives
- **Use `--report-only`** in CI for non-blocking validation

### Resource Usage

- **Memory**: Typical usage < 100MB per scan
- **CPU**: Optimized for multi-core systems
- **Disk**: Reports and logs rotated automatically
- **Network**: No external dependencies for core functionality

## 🔐 Security Best Practices

### For Developers

1. **Install pre-commit hooks** before first commit
2. **Run security scans locally** before pushing
3. **Use template variables** instead of hardcoded secrets
4. **Review security reports** and address findings
5. **Keep tools updated** for latest threat detection

### For Administrators

1. **Regular security audits** using provided tools
2. **Monitor scan results** and trends
3. **Update security baselines** as needed
4. **Train team members** on security practices
5. **Maintain incident response procedures**

## 📚 Additional Resources

- **[Security Audit Documentation](../../docs/security-audit.md)**: Comprehensive security overview
- **[Pre-commit Configuration](../../.pre-commit-config.yaml)**: Hook configuration
- **[GitHub Actions Workflow](../../.github/workflows/security.yml)**: CI/CD security integration
- **[OWASP Secret Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)**: Industry best practices

## 📞 Support

For security-related issues:

1. **Review documentation** in this directory
2. **Check security reports** in `reports/` directory
3. **Examine log files** in `logs/` directory
4. **Run with `--verbose`** for detailed output
5. **Contact security team** for critical issues

---

**⚠️ Important**: This security validation system is designed to be comprehensive yet practical. Regular maintenance and updates ensure continued effectiveness against evolving security threats.

**🎯 Goal**: Achieve and maintain zero secret exposure while enabling productive development workflows. 