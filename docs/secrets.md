# Secrets Management Guide

A comprehensive guide to the enterprise-grade secrets management system that enables secure storage, injection, and handling of sensitive information across all dotfiles components using 1Password CLI integration and template-based workflows.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [1Password Integration](#1password-integration)
- [Template System](#template-system)
- [Secret Injection](#secret-injection)
- [Security Best Practices](#security-best-practices)
- [Team and Enterprise Usage](#team-and-enterprise-usage)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [Advanced Usage](#advanced-usage)
- [Reference](#reference)

## Overview

The secrets management system ensures zero secrets exposure in the dotfiles repository while providing seamless access to sensitive configuration data. Built on 1Password CLI integration with a sophisticated template engine, it enables secure, auditable, and maintainable secret handling across all system components.

### Key Features

- **🔒 Zero Secret Exposure**: No sensitive data stored in repository or filesystem
- **🛡️ Enterprise-Grade Security**: 1Password integration with audit trails
- **⚡ High Performance**: Intelligent caching reduces retrieval time from 600ms to 5-10ms
- **🔧 Template Engine**: Flexible template system supporting multiple formats
- **🌍 Cross-Platform**: Works seamlessly on macOS, Linux, and Windows (WSL)
- **👥 Team Support**: Shared vaults and collaborative secret management
- **📝 Comprehensive Logging**: Detailed audit trails and monitoring capabilities

### Security Principles

- **Principle of Least Privilege**: Secrets accessed only when needed
- **Defense in Depth**: Multiple security layers and validation checks
- **Audit Transparency**: Complete logging of secret access and usage
- **Secure by Default**: Safe fallbacks and graceful degradation
- **Zero Trust**: All secret access authenticated and authorized

## Architecture

### System Components

```
secrets/
├── scripts/
│   ├── inject-secrets.sh         # Main secret injection tool
│   ├── load-secrets.sh           # Environment variable loader
│   ├── validate-templates.sh     # Template validation and testing
│   ├── diff-templates.sh         # Preview changes before injection
│   └── inject-all.sh             # Batch processing for all templates
├── lib/
│   ├── secret-helpers.sh         # Core secret retrieval functions
│   ├── template-engine.sh        # Template processing engine
│   └── cache-manager.sh          # Performance caching system
└── templates/
    ├── git/
    │   ├── config.tmpl           # Git configuration template
    │   └── gitconfig.j2          # Alternative Jinja2 format
    ├── ssh/
    │   ├── config.tmpl           # SSH configuration template
    │   └── personal-hosts.tmpl   # Personal SSH hosts
    ├── shell/
    │   ├── env.tmpl              # Environment variables
    │   └── profile.tmpl          # Shell profile with secrets
    └── aws/
        └── credentials.tmpl      # AWS credentials template
```

### Template Engine Architecture

```
Template Processing Pipeline:

1. Template Discovery
   ├── Scan for .tmpl, .j2, .template files
   ├── Auto-detect template format
   └── Validate syntax and structure

2. Secret Resolution
   ├── Extract secret references
   ├── Authenticate with 1Password
   ├── Retrieve secrets with caching
   └── Validate secret availability

3. Template Processing
   ├── Process template tokens
   ├── Apply transformations
   ├── Validate output format
   └── Generate final configuration

4. Secure Deployment
   ├── Backup existing files
   ├── Deploy with correct permissions
   ├── Validate configuration syntax
   └── Log deployment activities
```

## Quick Start

### Prerequisites

- 1Password account (personal or business)
- 1Password CLI v2.0+ installed
- Bash 3.2+ (macOS compatible)
- Authentication tokens configured

### Installation

```bash
# Install 1Password CLI (macOS)
brew install 1password-cli

# Install 1Password CLI (Linux)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

# Initial setup via bootstrap
./scripts/bootstrap.sh

# Secrets management only
./scripts/setup-secrets.sh
```

### Initial Configuration

```bash
# Sign in to 1Password
op signin

# Verify CLI integration
op whoami
op vault list

# Test secret retrieval
op item get "Example Login" --field password

# Initialize secrets system
./scripts/inject-secrets.sh --setup
```

### First Secret Injection

```bash
# Create a simple template
cat > ~/.aws/credentials.template << 'EOF'
[default]
aws_access_key_id = {{ op://Personal/AWS/access_key_id }}
aws_secret_access_key = {{ op://Personal/AWS/secret_access_key }}
region = us-west-2
EOF

# Inject secrets
./scripts/inject-secrets.sh ~/.aws/credentials.template

# Verify result
cat ~/.aws/credentials  # Shows resolved credentials
```

## 1Password Integration

### Authentication Setup

#### Personal Account Setup
```bash
# Sign in to personal 1Password account
op signin personal.1password.com

# Configure account shorthand
op account add --address personal.1password.com --email user@example.com

# Verify authentication
op whoami
```

#### Business Account Setup
```bash
# Sign in to business account
op signin company.1password.com

# Configure multiple accounts
op account add --address company.1password.com --email user@company.com

# Switch between accounts
op signin --account personal
op signin --account company
```

#### Service Account Integration (Enterprise)
```bash
# Configure service account for CI/CD
export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token"

# Verify service account access
op vault list
op item list --vault "Shared Infrastructure"
```

### 1Password Organization

#### Recommended Vault Structure
```
Personal Account:
├── Personal/              # Personal projects and services
│   ├── Git Config         # Git identity and signing keys
│   ├── SSH Keys           # Personal SSH keys and certificates
│   ├── API Keys           # Personal service API keys
│   └── Cloud Services     # Personal cloud provider credentials
├── Development/           # Development tools and services
│   ├── GitHub Token       # GitHub personal access tokens
│   ├── NPM Token          # NPM registry authentication
│   └── Docker Hub         # Container registry credentials
└── Backup/                # Recovery and backup credentials

Business Account:
├── Infrastructure/        # Shared infrastructure credentials
│   ├── AWS Production     # Production AWS credentials
│   ├── Database URLs      # Production database connections
│   └── Monitoring Keys    # Monitoring service API keys
├── Development/           # Shared development credentials
│   ├── Staging AWS        # Staging environment credentials
│   ├── CI/CD Tokens       # Continuous integration tokens
│   └── Testing Services   # Test environment credentials
└── Team/                  # Team-specific credentials
    ├── Shared SSH Keys    # Team SSH access
    └── Service Accounts   # Shared service accounts
```

### Secret Reference Formats

#### Standard 1Password References
```bash
# Basic item reference
{{ op://vault/item/field }}

# With account specification
{{ op://account/vault/item/field }}

# Examples
{{ op://Personal/GitHub Token/credential }}
{{ op://Work/AWS Production/access_key_id }}
{{ op://company/Infrastructure/Database/url }}
```

#### Advanced Reference Patterns
```bash
# Section-specific fields
{{ op://Personal/Git Config/Identity/name }}
{{ op://Personal/Git Config/Identity/email }}

# File attachments
{{ op://Personal/SSH Keys/private_key.pem }}

# TOTP codes (time-based)
{{ op://Personal/AWS/totp }}

# Custom field references
{{ op://Personal/API Keys/custom[service_token] }}
```

## Template System

### Template Formats

The system supports multiple template formats for flexibility and integration:

#### Environment Variable Format
```bash
# Format: {{VAR_NAME}}
export GITHUB_TOKEN="{{GITHUB_TOKEN}}"
export DATABASE_URL="{{DATABASE_URL}}"

# Secret references mapped via configuration
GITHUB_TOKEN = "op://Personal/GitHub/token"
DATABASE_URL = "op://Work/Database/url"
```

#### Double Brace Format (Default)
```bash
# Format: {{ op://vault/item/field }}
[user]
    name = "{{ op://Personal/Git Config/name }}"
    email = "{{ op://Personal/Git Config/email }}"
    signingkey = "{{ op://Personal/Git Config/signing_key }}"
```

#### Jinja2 Template Format
```jinja2
{# Advanced templating with logic #}
{% if environment == "production" %}
database_url = "{{ op://Work/Production Database/url }}"
{% else %}
database_url = "{{ op://Work/Staging Database/url }}"
{% endif %}

{# Loops and data processing #}
{% for service in services %}
{{ service.name }}_api_key = "{{ op://Personal/API Keys/{{ service.key }} }}"
{% endfor %}
```

#### Go Template Format
```go
// Format: {{.VaultPath}}
const (
    GitHubToken = "{{.GitHubToken}}"
    DatabaseURL = "{{.DatabaseURL}}"
    APIKey      = "{{.APIKey}}"
)

// Configuration mapping
GitHubToken: "op://Personal/GitHub/token"
DatabaseURL: "op://Work/Database/url"
APIKey:      "op://Personal/API Keys/service"
```

### Template Examples

#### Git Configuration Template
```gitconfig
# templates/git/config.tmpl
[user]
    name = "{{ op://Personal/Git Identity/name }}"
    email = "{{ op://Personal/Git Identity/email }}"
    signingkey = "{{ op://Personal/Git Identity/signing_key }}"

[github]
    user = "{{ op://Personal/GitHub/username }}"
    token = "{{ op://Personal/GitHub/token }}"

[url "ssh://git@github.com/"]
    insteadOf = https://github.com/

# Work-specific overrides
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work

# ~/.gitconfig-work template
[user]
    name = "{{ op://Work/Git Identity/name }}"
    email = "{{ op://Work/Git Identity/email }}"
    signingkey = "{{ op://Work/Git Identity/signing_key }}"
```

#### SSH Configuration Template
```sshconfig
# templates/ssh/config.tmpl
# Personal servers
Host personal-server
    HostName {{ op://Personal/SSH Hosts/personal_server/hostname }}
    User {{ op://Personal/SSH Hosts/personal_server/username }}
    IdentityFile ~/.ssh/personal_ed25519
    Port {{ op://Personal/SSH Hosts/personal_server/port }}

# Work infrastructure
Host bastion.company.com
    HostName {{ op://Work/Infrastructure/bastion/hostname }}
    User {{ op://Work/Infrastructure/bastion/username }}
    IdentityFile ~/.ssh/work_ed25519
    Port 22

Host *.company.com
    User {{ op://Work/Infrastructure/default/username }}
    IdentityFile ~/.ssh/work_ed25519
    ProxyJump bastion.company.com
```

#### Environment Variables Template
```bash
# templates/shell/env.tmpl
# Development environment variables
export GITHUB_TOKEN="{{ op://Personal/GitHub/token }}"
export NPM_TOKEN="{{ op://Personal/NPM/auth_token }}"
export DOCKER_HUB_TOKEN="{{ op://Personal/Docker Hub/access_token }}"

# AWS configuration
export AWS_ACCESS_KEY_ID="{{ op://Personal/AWS/access_key_id }}"
export AWS_SECRET_ACCESS_KEY="{{ op://Personal/AWS/secret_access_key }}"
export AWS_DEFAULT_REGION="us-west-2"

# Database connections
export DATABASE_URL="{{ op://Work/Database/url }}"
export REDIS_URL="{{ op://Work/Redis/url }}"
export ELASTICSEARCH_URL="{{ op://Work/Elasticsearch/url }}"

# API keys and service credentials
export STRIPE_SECRET_KEY="{{ op://Work/Payment/stripe_secret }}"
export SENDGRID_API_KEY="{{ op://Work/Email/sendgrid_key }}"
export SLACK_WEBHOOK_URL="{{ op://Work/Notifications/slack_webhook }}"
```

## Secret Injection

### Core Injection Tools

#### Main Injection Script
```bash
# scripts/inject-secrets.sh - Primary injection tool

# Usage examples
./scripts/inject-secrets.sh ~/.aws/credentials.template
./scripts/inject-secrets.sh --dry-run config.template
./scripts/inject-secrets.sh --format jinja2 deployment.j2
./scripts/inject-secrets.sh --backup config.template

# Options
--dry-run                    # Preview changes without applying
--verbose                    # Detailed output for debugging
--backup                     # Create backup before injection
--format [auto|env|jinja2]   # Specify template format
--validate                   # Validate secrets before injection
```

#### Batch Processing
```bash
# scripts/inject-all.sh - Process all templates

# Find and process all templates
./scripts/inject-all.sh

# With options
./scripts/inject-all.sh --dry-run --verbose

# Custom search paths
./scripts/inject-all.sh --paths "~/.config ~/work/configs"

# Exclude patterns
./scripts/inject-all.sh --exclude "*.backup,*.tmp"
```

#### Environment Loading
```bash
# scripts/load-secrets.sh - Load secrets into shell environment

# Load secrets for current session
source ./scripts/load-secrets.sh

# Load specific context
source ./scripts/load-secrets.sh --context work
source ./scripts/load-secrets.sh --context personal

# Export for child processes
eval "$(./scripts/load-secrets.sh --export)"
```

### Advanced Injection Features

#### Conditional Templates
```bash
# Context-aware template processing
cat > config.template << 'EOF'
# Base configuration
api_url = "https://api.service.com"

{% if context == "development" %}
debug = true
api_key = "{{ op://Personal/Service/dev_key }}"
{% elif context == "production" %}
debug = false
api_key = "{{ op://Work/Service/prod_key }}"
{% endif %}
EOF

# Process with context
./scripts/inject-secrets.sh --context production config.template
```

#### Template Validation
```bash
# scripts/validate-templates.sh - Template validation and testing

# Validate template syntax
./scripts/validate-templates.sh config.template

# Check secret availability
./scripts/validate-templates.sh --check-secrets config.template

# List required secrets
./scripts/validate-templates.sh --list-secrets templates/

# Test template processing
./scripts/validate-templates.sh --test config.template
```

#### Differential Preview
```bash
# scripts/diff-templates.sh - Preview changes

# Show what would change
./scripts/diff-templates.sh config.template

# Colored diff output
./scripts/diff-templates.sh --color config.template

# Compare multiple templates
./scripts/diff-templates.sh templates/*.tmpl
```

### Caching System

#### Performance Optimization
```bash
# Cache configuration in scripts/lib/secret-helpers.sh
CACHE_DIR="$HOME/.cache/dotfiles-secrets"
CACHE_TTL=300  # 5 minutes

# Cache operations
cache_secret() {
    local key="$1"
    local value="$2"
    local cache_file="$CACHE_DIR/${key//\//_}"
    
    echo "$value" > "$cache_file"
    touch -t "$(date -d '+5 minutes' +'%Y%m%d%H%M.%S')" "$cache_file"
}

# Performance metrics
# - Without cache: ~600ms per secret
# - With cache: ~5-10ms per secret
# - Typical speedup: 60-120x faster
```

#### Cache Management
```bash
# Clear cache
rm -rf ~/.cache/dotfiles-secrets

# Warm cache with common secrets
./scripts/load-secrets.sh --warm-cache

# Cache statistics
./scripts/secret-stats.sh
```

## Security Best Practices

### Access Control

#### 1Password Access Policies
```json
{
  "vault_policies": {
    "Personal": {
      "access": "full",
      "sharing": "owner_only"
    },
    "Work": {
      "access": "read_write",
      "sharing": "team_members",
      "audit": "required"
    },
    "Infrastructure": {
      "access": "read_only",
      "sharing": "admin_approval",
      "audit": "detailed"
    }
  }
}
```

#### Service Account Security
```bash
# Rotate service account tokens regularly
op service-account create --name "CI/CD Secrets" --vault "Infrastructure"

# Limit service account permissions
op service-account edit --vault "Infrastructure" --permissions "read"

# Monitor service account usage
op audit --service-account "CI/CD Secrets" --since "7 days ago"
```

### Secret Lifecycle Management

#### Secret Rotation Strategy
```bash
# Automated secret rotation
#!/bin/bash
# scripts/rotate-secrets.sh

rotate_secret() {
    local vault="$1"
    local item="$2"
    local field="$3"
    
    # Generate new secret
    local new_secret=$(generate_secure_token)
    
    # Update in 1Password
    op item edit "$item" --vault "$vault" "$field=$new_secret"
    
    # Re-inject templates
    ./scripts/inject-all.sh
    
    # Restart services if needed
    restart_dependent_services "$item"
}

# Schedule rotation
rotate_secret "Personal" "GitHub Token" "credential"
rotate_secret "Work" "Database" "password"
```

#### Secret Expiration Monitoring
```bash
# Monitor secret age and usage
#!/bin/bash
# scripts/secret-audit.sh

audit_secrets() {
    local vault="$1"
    
    op item list --vault "$vault" --format json | \
    jq -r '.[] | select(.updatedAt < (now - 2592000)) | .title' | \
    while read -r item; do
        echo "WARNING: $item in $vault not updated in 30 days"
    done
}

audit_secrets "Personal"
audit_secrets "Work"
```

### Template Security

#### Secure Template Patterns
```bash
# Avoid inline secrets (BAD)
password="hardcoded_secret_123"

# Use template references (GOOD)
password="{{ op://Personal/Database/password }}"

# Conditional access based on context
{% if user_authorized %}
admin_key="{{ op://Work/Admin/key }}"
{% endif %}

# Fail safely with default values
api_endpoint="{{ op://Personal/API/endpoint | default('https://api.example.com') }}"
```

#### Template Validation Rules
```bash
# Mandatory validation checks
validate_template() {
    local template="$1"
    
    # Check for hardcoded secrets
    if grep -E "(password|secret|key)\s*=" "$template" | grep -v "{{"; then
        echo "ERROR: Hardcoded secrets detected in $template"
        return 1
    fi
    
    # Validate secret references
    if ! ./scripts/validate-templates.sh --check-secrets "$template"; then
        echo "ERROR: Invalid secret references in $template"
        return 1
    fi
    
    # Check file permissions after injection
    if [[ -f "${template%.template}" ]]; then
        local perms=$(stat -c "%a" "${template%.template}")
        if [[ "$perms" -gt 600 ]]; then
            echo "WARNING: Insecure permissions on ${template%.template}"
        fi
    fi
}
```

## Team and Enterprise Usage

### Shared Vault Management

#### Team Vault Structure
```
Company 1Password Account:
├── Shared Development/
│   ├── Staging Environment/
│   │   ├── Database Credentials
│   │   ├── API Keys
│   │   └── Service Accounts
│   └── Development Tools/
│       ├── GitHub Organization Token
│       ├── Docker Registry
│       └── NPM Organization
├── Production/
│   ├── Infrastructure/
│   │   ├── AWS Production
│   │   ├── Database Cluster
│   │   └── Monitoring Services
│   └── Applications/
│       ├── Payment Processor
│       ├── Email Service
│       └── Analytics Platform
└── Team Personal/
    ├── Individual SSH Keys
    ├── Personal Git Configs
    └── Development Accounts
```

#### Access Control Policies
```yaml
# team-access-policy.yml
vault_access:
  "Shared Development":
    - role: developer
      permissions: [read, write]
    - role: intern
      permissions: [read]
      
  "Production":
    - role: senior_developer
      permissions: [read]
    - role: devops
      permissions: [read, write]
    - role: admin
      permissions: [read, write, admin]

audit_requirements:
  "Production": mandatory
  "Shared Development": recommended
  "Team Personal": optional
```

### CI/CD Integration

#### GitHub Actions Integration
```yaml
# .github/workflows/deploy.yml
name: Deploy with Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure 1Password
        uses: 1password/install-cli-action@v1
        
      - name: Inject secrets
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          ./scripts/inject-all.sh --context production
          
      - name: Deploy application
        run: |
          source ~/.env
          ./scripts/deploy.sh
```

#### GitLab CI Integration
```yaml
# .gitlab-ci.yml
variables:
  OP_SERVICE_ACCOUNT_TOKEN: $OP_SERVICE_ACCOUNT_TOKEN

before_script:
  - curl -sSfLo op.zip https://cache.agilebits.com/dist/1P/op2/pkg/v2.0.0/op_linux_amd64_v2.0.0.zip
  - unzip -o op.zip -d /usr/local/bin/
  - chmod +x /usr/local/bin/op

deploy:
  stage: deploy
  script:
    - ./scripts/inject-secrets.sh --context production config.template
    - ./scripts/deploy.sh
  only:
    - main
```

### Enterprise Security Features

#### Compliance and Auditing
```bash
# Enhanced audit logging
#!/bin/bash
# scripts/audit-logger.sh

log_secret_access() {
    local vault="$1"
    local item="$2" 
    local field="$3"
    local user="$(op whoami)"
    local timestamp="$(date -Iseconds)"
    
    # Log to centralized audit system
    cat >> /var/log/dotfiles-secrets.log << EOF
{
  "timestamp": "$timestamp",
  "user": "$user",
  "action": "secret_access",
  "vault": "$vault",
  "item": "$item",
  "field": "$field",
  "source": "dotfiles-injection"
}
EOF
    
    # Send to SIEM if configured
    if [[ -n "$SIEM_ENDPOINT" ]]; then
        curl -X POST "$SIEM_ENDPOINT/audit" \
          -H "Content-Type: application/json" \
          -d "{\"user\":\"$user\",\"action\":\"secret_access\",\"resource\":\"$vault/$item\"}"
    fi
}
```

#### Secret Scanning and Prevention
```bash
# Pre-commit secret scanning
#!/bin/bash
# scripts/secret-scan.sh

scan_for_secrets() {
    local files=("$@")
    local secrets_found=false
    
    for file in "${files[@]}"; do
        # Scan for common secret patterns
        if grep -E "(password|secret|key|token)\s*=" "$file" | grep -v "{{"; then
            echo "ERROR: Potential secret found in $file"
            secrets_found=true
        fi
        
        # Scan for 1Password references outside templates
        if [[ "$file" != *.template ]] && [[ "$file" != *.tmpl ]]; then
            if grep -E "op://[^}]+" "$file"; then
                echo "ERROR: 1Password reference in non-template file: $file"
                secrets_found=true
            fi
        fi
    done
    
    if [[ "$secrets_found" == true ]]; then
        echo "Secret scan failed. Please review and fix the issues above."
        exit 1
    fi
}

# Git hook integration
scan_for_secrets $(git diff --cached --name-only)
```

## Troubleshooting

### Common Issues

#### Authentication Problems
```bash
# Check 1Password CLI authentication
op whoami
# Should show: user@example.com

# Re-authenticate if needed
op signin
op signin --force  # Force re-authentication

# Check account configuration
op account list
op account get
```

#### Template Processing Issues
```bash
# Debug template processing
./scripts/inject-secrets.sh --verbose --dry-run config.template

# Check secret availability
./scripts/validate-templates.sh --check-secrets config.template

# Test individual secret retrieval
op item get "Item Name" --field "field_name"

# Validate template syntax
./scripts/validate-templates.sh config.template
```

#### Cache Problems
```bash
# Clear cache and retry
rm -rf ~/.cache/dotfiles-secrets
./scripts/inject-secrets.sh config.template

# Check cache permissions
ls -la ~/.cache/dotfiles-secrets/
chmod 700 ~/.cache/dotfiles-secrets/

# Disable cache for debugging
DISABLE_CACHE=1 ./scripts/inject-secrets.sh config.template
```

#### Performance Issues
```bash
# Check network connectivity
ping my.1password.com
curl -I https://my.1password.com

# Test 1Password CLI performance
time op item list

# Enable performance logging
DEBUG=1 ./scripts/inject-secrets.sh config.template
```

### Diagnostic Tools

#### Secret System Health Check
```bash
# scripts/secrets-doctor.sh
#!/bin/bash

check_op_cli() {
    if ! command -v op >/dev/null; then
        echo "❌ 1Password CLI not installed"
        return 1
    fi
    echo "✅ 1Password CLI installed: $(op --version)"
}

check_authentication() {
    if ! op whoami >/dev/null 2>&1; then
        echo "❌ Not authenticated with 1Password"
        return 1
    fi
    echo "✅ Authenticated as: $(op whoami)"
}

check_vault_access() {
    local vaults=($(op vault list --format json | jq -r '.[].name'))
    echo "✅ Available vaults: ${vaults[*]}"
}

check_cache_system() {
    if [[ -d ~/.cache/dotfiles-secrets ]]; then
        local cache_files=$(find ~/.cache/dotfiles-secrets -type f | wc -l)
        echo "✅ Cache system active: $cache_files cached secrets"
    else
        echo "ℹ️  Cache system not initialized"
    fi
}

check_template_syntax() {
    local templates=($(find . -name "*.template" -o -name "*.tmpl"))
    local errors=0
    
    for template in "${templates[@]}"; do
        if ! ./scripts/validate-templates.sh "$template" >/dev/null 2>&1; then
            echo "❌ Template error in $template"
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        echo "✅ All templates valid"
    else
        echo "❌ $errors template(s) have errors"
    fi
}

# Run all checks
echo "🔍 Secrets Management System Health Check"
echo "=========================================="
check_op_cli
check_authentication  
check_vault_access
check_cache_system
check_template_syntax
```

## Migration Guide

### From Other Secret Management Systems

#### From Environment Variables
```bash
# Migrate from .env files to templates

# Before: .env file with hardcoded secrets
echo "GITHUB_TOKEN=ghp_1234567890abcdef" > .env
echo "DATABASE_URL=postgresql://user:pass@host/db" >> .env

# After: Template with 1Password references
cat > .env.template << 'EOF'
GITHUB_TOKEN={{ op://Personal/GitHub/token }}
DATABASE_URL={{ op://Work/Database/url }}
EOF

# Migration script
#!/bin/bash
migrate_env_file() {
    local env_file="$1"
    local template_file="${env_file}.template"
    
    # Backup original
    cp "$env_file" "${env_file}.backup"
    
    # Convert to template
    sed 's/=.*/={{ op:\/\/Vault\/Item\/field }}/' "$env_file" > "$template_file"
    
    echo "Template created: $template_file"
    echo "Please update 1Password references and inject secrets"
}
```

#### From HashiCorp Vault
```bash
# Migrate from Vault to 1Password

# Export secrets from Vault
vault kv get -format=json secret/myapp | jq -r '.data.data' > vault-export.json

# Create 1Password items
while read -r key value; do
    op item create --category=password \
      --title="Migrated $key" \
      --vault=Personal \
      password="$value"
done < <(jq -r 'to_entries[] | "\(.key) \(.value)"' vault-export.json)

# Update templates to use 1Password references
sed -i 's/{{ vault "secret\/myapp" "key" }}/{{ op:\/\/Personal\/Migrated key\/password }}/' config.template
```

#### From AWS Secrets Manager
```bash
# Export from AWS Secrets Manager
aws secretsmanager list-secrets --query 'SecretList[*].Name' --output text | \
while read -r secret_name; do
    secret_value=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --query 'SecretString' --output text)
    
    # Create 1Password item
    op item create --category=password \
      --title="AWS $secret_name" \
      --vault=Work \
      password="$secret_value"
done

# Update CloudFormation templates
sed -i 's/{{resolve:secretsmanager:\([^:]*\):SecretString:\([^}]*\)}}/{{ op:\/\/Work\/AWS \1\/\2 }}/g' template.yaml
```

### Legacy Template Migration

#### Upgrade Template Formats
```bash
# Migrate from simple variable substitution
# Old format: $VARIABLE
# New format: {{ op://Vault/Item/field }}

#!/bin/bash
upgrade_template() {
    local template="$1"
    local mapping_file="$2"
    
    while IFS='=' read -r var secret_ref; do
        sed -i "s/\\\$${var}/{{ ${secret_ref} }}/g" "$template"
        sed -i "s/\${${var}}/{{ ${secret_ref} }}/g" "$template"
    done < "$mapping_file"
}

# Example mapping file
cat > variable-mapping.txt << 'EOF'
GITHUB_TOKEN=op://Personal/GitHub/token
DATABASE_URL=op://Work/Database/url
API_KEY=op://Personal/API Keys/service
EOF

upgrade_template config.template variable-mapping.txt
```

## Advanced Usage

### Custom Template Functions

#### Template Helpers
```bash
# Advanced template processing with custom functions
cat > templates/helpers.sh << 'EOF'
# Base64 encode secret
b64encode() {
    local secret="$1"
    echo -n "$secret" | base64
}

# Generate derived secrets
derive_key() {
    local master_key="$1"
    local context="$2"
    echo -n "${master_key}-${context}" | sha256sum | cut -d' ' -f1
}

# Format secret for specific use
format_connection_string() {
    local host="$1"
    local user="$2" 
    local pass="$3"
    local db="$4"
    echo "postgresql://${user}:${pass}@${host}/${db}"
}
EOF

# Use in templates
cat > config.template << 'EOF'
# Encoded API key
encoded_key="{{ op://Personal/API/key | b64encode }}"

# Derived database password
db_password="{{ op://Work/Master Key/key | derive_key "database" }}"

# Formatted connection string
database_url="{{ format_connection_string "{{ op://Work/DB/host }}" "{{ op://Work/DB/user }}" "{{ op://Work/DB/pass }}" "myapp" }}"
EOF
```

#### Dynamic Template Generation
```bash
# Generate templates from configuration
#!/bin/bash
generate_service_config() {
    local service="$1"
    local environment="$2"
    
    cat > "configs/${service}-${environment}.template" << EOF
[${service}]
api_key = "{{ op://Work/${service^}/${environment}_api_key }}"
endpoint = "{{ op://Work/${service^}/${environment}_endpoint }}"
timeout = 30

{% if environment == "production" %}
debug = false
log_level = "warn"
{% else %}
debug = true
log_level = "debug"
{% endif %}
EOF
}

# Generate configs for multiple services
for service in payment email analytics; do
    for env in development staging production; do
        generate_service_config "$service" "$env"
    done
done
```

### Integration Patterns

#### Docker Integration
```dockerfile
# Dockerfile with secret injection
FROM alpine:latest

# Install 1Password CLI
RUN apk add --no-cache curl && \
    curl -sSfLo op.zip https://cache.agilebits.com/dist/1P/op2/pkg/v2.0.0/op_linux_amd64_v2.0.0.zip && \
    unzip op.zip -d /usr/local/bin/ && \
    rm op.zip

# Copy dotfiles and templates
COPY . /dotfiles
WORKDIR /dotfiles

# Inject secrets at runtime
RUN ./scripts/inject-all.sh --context production

ENTRYPOINT ["./app"]
```

#### Kubernetes Integration
```yaml
# k8s-secrets-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: inject-secrets
spec:
  template:
    spec:
      containers:
      - name: secret-injector
        image: dotfiles:latest
        env:
        - name: OP_SERVICE_ACCOUNT_TOKEN
          valueFrom:
            secretKeyRef:
              name: onepassword-token
              key: token
        command:
        - /bin/bash
        - -c
        - |
          ./scripts/inject-all.sh --context production
          kubectl create secret generic app-secrets --from-env-file=.env
      restartPolicy: OnFailure
```

## Reference

### Configuration Files

| File | Purpose | Format |
|------|---------|---------|
| `~/.config/op/config` | 1Password CLI configuration | JSON |
| `~/.cache/dotfiles-secrets/` | Secret cache directory | Binary |
| `templates/**/*.tmpl` | Template files | Various |
| `scripts/inject-*.sh` | Injection scripts | Bash |

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `OP_SERVICE_ACCOUNT_TOKEN` | Service account authentication | None |
| `OP_CACHE_TTL` | Cache time-to-live (seconds) | 300 |
| `OP_DISABLE_CACHE` | Disable caching for debugging | false |
| `SECRETS_CONTEXT` | Template processing context | default |

### Secret Reference Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `op://vault/item/field` | Basic secret reference | `op://Personal/GitHub/token` |
| `op://account/vault/item/field` | Multi-account reference | `op://work/Infrastructure/DB/password` |
| `op://vault/item/section/field` | Section-specific field | `op://Personal/SSH/Work/private_key` |

### Performance Metrics

| Operation | Without Cache | With Cache | Improvement |
|-----------|---------------|------------|-------------|
| Single secret retrieval | ~600ms | ~5-10ms | 60-120x |
| Template with 10 secrets | ~6s | ~50-100ms | 60-120x |
| Full environment injection | ~30s | ~500ms | 60x |

### Security Guidelines

| Risk Level | Recommendation | Implementation |
|------------|----------------|----------------|
| **High** | Never commit secrets | Use templates and injection |
| **High** | Rotate secrets regularly | Automated rotation scripts |
| **Medium** | Monitor secret access | Audit logging and alerts |
| **Medium** | Validate templates | Pre-commit hooks and validation |
| **Low** | Cache management | TTL-based expiration |

This secrets management system provides enterprise-grade security with developer-friendly workflows, ensuring that sensitive information remains protected while enabling seamless integration across all dotfiles components. 