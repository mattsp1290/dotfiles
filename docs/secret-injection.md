# Secret Injection System User Guide

The secret injection system provides a secure way to manage secrets in your dotfiles by storing them in 1Password and injecting them into configuration files at runtime.

## Overview

The system consists of several components:

1. **Template Engine** - Processes template files with various token formats
2. **Secret Helpers** - Retrieves secrets from 1Password with caching
3. **Injection Scripts** - User-facing tools for processing templates
4. **Template Files** - Configuration files with secret placeholders

## Quick Start

### 1. Ensure Prerequisites

```bash
# Check if signed in to 1Password
op account get

# Sign in if needed
eval $(op signin)
```

### 2. Create a Template

Create a template file with secret placeholders:

```bash
# ~/.aws/credentials.template
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
```

### 3. Process the Template

```bash
# Process single template
scripts/inject-secrets.sh ~/.aws/credentials.template

# Process with output to specific file
scripts/inject-secrets.sh -o ~/.aws/credentials ~/.aws/credentials.template

# Dry run to preview
scripts/inject-secrets.sh --dry-run ~/.aws/credentials.template
```

### 4. Load Secrets into Environment

```bash
# Source the load-secrets script
source scripts/load-secrets.sh

# Or use eval
eval "$(scripts/load-secrets.sh Employee print)"
```

## Template Formats

The system supports multiple template formats:

| Format | Syntax | Example |
|--------|--------|---------|
| env | `${NAME}` | `${GITHUB_TOKEN}` |
| env-simple | `$NAME` | `$GITHUB_TOKEN` |
| go | `{{ op://Vault/Name/field }}` | `{{ op://Employee/GITHUB_TOKEN/credential }}` |
| custom | `%%NAME%%` | `%%GITHUB_TOKEN%%` |
| double-brace | `{{NAME}}` | `{{GITHUB_TOKEN}}` |

## Core Scripts

### inject-secrets.sh

The main script for processing template files.

```bash
# Basic usage
scripts/inject-secrets.sh [OPTIONS] FILE

# Options
-f, --format FORMAT    # Specify template format (default: auto)
-v, --vault VAULT     # 1Password vault (default: Employee)
-o, --output FILE     # Output file (default: remove .template extension)
-d, --dry-run        # Preview changes without modifying
-b, --backup         # Create backup before modifying
--verbose            # Show detailed output
--stdin              # Read from stdin
```

#### Examples

```bash
# Process with specific format
scripts/inject-secrets.sh --format go config.template

# Process from stdin
echo 'token=${GITHUB_TOKEN}' | scripts/inject-secrets.sh --stdin

# Process with backup
scripts/inject-secrets.sh --backup ~/.gitconfig.template

# Process directory recursively
scripts/inject-secrets.sh -r ~/configs/
```

### load-secrets.sh

Load commonly used secrets as environment variables.

```bash
# Source directly
source scripts/load-secrets.sh

# Use with eval
eval "$(scripts/load-secrets.sh)"

# Specify vault
source scripts/load-secrets.sh Personal

# Print export commands
scripts/load-secrets.sh Employee print
```

### inject-all.sh

Batch process all template files in common locations.

```bash
# Process all templates
scripts/inject-all.sh

# Dry run first
scripts/inject-all.sh --dry-run

# Skip backups
scripts/inject-all.sh --no-backup

# Verbose output
scripts/inject-all.sh --verbose
```

### validate-templates.sh

Validate template syntax and check secret availability.

```bash
# Validate single file
scripts/validate-templates.sh config.template

# Validate without checking secrets
scripts/validate-templates.sh --no-check *.template

# Validate directory
scripts/validate-templates.sh ~/templates/

# Verbose validation
scripts/validate-templates.sh --verbose config.tmpl
```

## Performance Optimization

### Caching

The system includes automatic caching to improve performance:

```bash
# Set cache TTL (default: 300 seconds)
export OP_CACHE_TTL=600

# Disable caching
export OP_CACHE_ENABLED=false

# Warm cache before processing
scripts/inject-secrets.sh --warm-cache config.template
```

### Batch Processing

For better performance when processing multiple files:

```bash
# Use inject-all for batch processing
scripts/inject-all.sh

# Or process directory recursively
scripts/inject-secrets.sh -r ~/configs/
```

## Best Practices

### 1. Template Organization

```
templates/
├── aws/
│   └── credentials.tmpl
├── shell/
│   ├── profile.tmpl
│   └── env.tmpl
├── git/
│   └── config.tmpl
└── ssh/
    └── config.tmpl
```

### 2. Naming Conventions

- Use UPPERCASE for secret names: `GITHUB_TOKEN`, not `github_token`
- Use descriptive names: `AWS_PROD_ACCESS_KEY` vs `AWS_KEY`
- Be consistent with naming across templates

### 3. Security

- Never commit processed files with secrets
- Add processed files to `.gitignore`
- Use restrictive file permissions for sensitive configs
- Regularly rotate secrets in 1Password

### 4. Testing

```bash
# Always dry-run first
scripts/inject-secrets.sh --dry-run template.tmpl

# Validate templates before processing
scripts/validate-templates.sh template.tmpl

# Use verbose mode for debugging
scripts/inject-secrets.sh --verbose --dry-run template.tmpl
```

## Common Use Cases

### AWS Credentials

```bash
# Create template
cat > ~/.aws/credentials.template << 'EOF'
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF

# Process template
scripts/inject-secrets.sh ~/.aws/credentials.template
```

### Git Configuration

```bash
# Create git config template
cat > ~/.gitconfig.secrets.template << 'EOF'
[credential "https://github.com"]
    username = ${GITHUB_USERNAME}
[url "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/"]
    insteadOf = https://github.com/
EOF

# Process and include in main gitconfig
scripts/inject-secrets.sh ~/.gitconfig.secrets.template
git config --global include.path ~/.gitconfig.secrets
```

### Shell Environment

```bash
# Create environment template
cat > ~/.env.secrets.template << 'EOF'
export GITHUB_TOKEN="${GITHUB_TOKEN}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
EOF

# Process and source
scripts/inject-secrets.sh ~/.env.secrets.template
echo "source ~/.env.secrets" >> ~/.bashrc
```

## Troubleshooting

### Secrets Not Found

```bash
# Check if secret exists
op item get GITHUB_TOKEN --vault Employee

# List all secrets in vault
op item list --vault Employee

# Try different vault
scripts/inject-secrets.sh --vault Personal template.tmpl
```

### Performance Issues

```bash
# Check cache status
ls -la /tmp/op-cache-*

# Clear cache
rm -rf /tmp/op-cache-*

# Increase cache TTL
export OP_CACHE_TTL=3600
```

### Template Not Processing

```bash
# Validate template syntax
scripts/validate-templates.sh --verbose template.tmpl

# Check template format detection
TEMPLATE_DEBUG=true scripts/inject-secrets.sh --dry-run template.tmpl

# Force specific format
scripts/inject-secrets.sh --format env template.tmpl
```

### Permission Errors

```bash
# Check file permissions
ls -la template.tmpl

# Fix permissions
chmod 600 ~/.aws/credentials
chmod 700 ~/.ssh
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OP_CACHE_ENABLED` | Enable/disable caching | `true` |
| `OP_CACHE_TTL` | Cache time-to-live in seconds | `300` |
| `TEMPLATE_DEBUG` | Enable debug output | `false` |
| `TEMPLATE_DRY_RUN` | Force dry-run mode | `false` |
| `OP_ACCOUNT_ALIAS` | Current 1Password account | auto-detected |

## Advanced Usage

### Custom Template Formats

Add new formats by modifying `scripts/lib/template-engine.sh`:

```bash
# Add to TEMPLATE_FORMATS array
["myformat"]='<pattern>'
```

### Conditional Processing

```bash
# Process only if secrets available
if scripts/validate-templates.sh --no-check template.tmpl >/dev/null 2>&1; then
    scripts/inject-secrets.sh template.tmpl
fi
```

### Integration with Shell

Add to your shell initialization file:

```bash
# ~/.bashrc or ~/.zshrc
# Auto-load secrets on shell start
if command -v op >/dev/null 2>&1 && op account get >/dev/null 2>&1; then
    source ~/dotfiles/scripts/load-secrets.sh
fi

# Alias for quick secret injection
alias inject-secrets='~/dotfiles/scripts/inject-secrets.sh'
alias inject-all='~/dotfiles/scripts/inject-all.sh'
```

## Security Considerations

1. **Never** commit files containing actual secrets
2. **Always** use `.gitignore` for processed files
3. **Regularly** rotate secrets in 1Password
4. **Restrict** file permissions on sensitive configs
5. **Audit** template files for accidental secret exposure
6. **Use** separate vaults for different security levels

## Support

For issues or questions:

1. Check the troubleshooting section
2. Run with `--verbose` for detailed output
3. Check 1Password CLI is properly configured
4. Verify secrets exist in the specified vault 