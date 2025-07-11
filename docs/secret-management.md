# Secret Management with 1Password CLI

This document describes how secrets are managed in this dotfiles repository using 1Password CLI with support for multiple accounts (work and personal).

## Overview

We use 1Password CLI to manage all secrets, preventing any sensitive information from being stored in the repository. The system automatically detects whether you're on a work or personal computer and uses the appropriate 1Password account.

## Environment Detection

The system automatically detects your environment based on your username:
- **Personal environment**: Username contains "1290" (e.g., `punk1290`, `mattsp1290`)
- **Work environment**: Username is `matt.spurlin`

You can override the detection by setting: `export OP_ACCOUNT_OVERRIDE=work` or `export OP_ACCOUNT_OVERRIDE=personal`

## Initial Setup

### 1. Install 1Password CLI

```bash
# macOS
brew install --cask 1password-cli

# Linux (see docs/secret-management-setup.md for detailed instructions)
```

### 2. Run Setup Script

```bash
./scripts/setup-secrets.sh
```

Choose option 1 to set up your accounts. You'll need:
- Your 1Password sign-in address (e.g., `my.1password.com`)
- Your email address
- Your Secret Key (from 1Password app → Settings → Account → Set Up Another Device)
- Your Master Password

### 3. Add Shell Integration

Add this to your `~/.zshrc` or `~/.bashrc`:

```bash
# 1Password CLI Integration
if [[ -f "$HOME/git/dotfiles/scripts/op-env-detect.sh" ]]; then
    export OP_ACCOUNT_ALIAS=$("$HOME/git/dotfiles/scripts/op-env-detect.sh" 2>/dev/null || echo "personal")
fi

# Source the secret helpers
if [[ -f "$HOME/git/dotfiles/scripts/lib/secret-helpers.sh" ]]; then
    source "$HOME/git/dotfiles/scripts/lib/secret-helpers.sh"
fi

# Sign in to the detected account
op-signin() {
    local account=${1:-$OP_ACCOUNT_ALIAS}
    echo "Signing in to 1Password account: $account"
    eval $(op signin --account "$account")
}

# Quick switch between accounts
op-work() {
    eval $(op signin --account work)
    export OP_ACCOUNT_ALIAS="work"
}

op-personal() {
    eval $(op signin --account personal)
    export OP_ACCOUNT_ALIAS="personal"
}

# Check current account
op-current() {
    echo "Current account alias: $OP_ACCOUNT_ALIAS"
    if op account get --account "$OP_ACCOUNT_ALIAS" 2>/dev/null; then
        echo "Status: Signed in ✓"
    else
        echo "Status: Not signed in ✗"
    fi
}
```

## Daily Usage

### Sign In
```bash
# Sign in to auto-detected account
op-signin

# Or explicitly choose
op-work      # Switch to work account
op-personal  # Switch to personal account
```

### Get Secrets
```bash
# Get a secret (tries current account first, then others)
GITHUB_TOKEN=$(get_secret "GITHUB_TOKEN" credential)

# Get with default value
API_KEY=$(get_secret_or_default "API_KEY" "default-value" credential)

# Check if secret exists
if secret_exists "MY_SECRET"; then
    echo "Secret found"
fi
```

### Set Secrets
```bash
# Create or update a secret
set_secret "GITHUB_TOKEN" "ghp_xxxxxxxxxxxx"

# Interactive creation
create_secret_interactive
```

### Load All Secrets
```bash
# Load common secrets as environment variables
load_secrets

# This loads:
# - GITHUB_TOKEN
# - GITLAB_TOKEN
# - ANTHROPIC_API_KEY
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - DATADOG_API_KEY (work account only)
# - DATADOG_APP_KEY (work account only)
```

### List Secrets
```bash
# List all secrets in Development vault
list_secrets
```

## Secret Migration from AUDIT-002

Based on the security audit, these secrets need to be migrated to 1Password:

### Common Secrets (Both Accounts)
- `GITHUB_TOKEN` - GitHub Personal Access Token
- `GITLAB_TOKEN` - GitLab Personal Access Token  
- `ANTHROPIC_API_KEY` - Claude API Key
- `AWS_ACCESS_KEY_ID` - AWS Access Key
- `AWS_SECRET_ACCESS_KEY` - AWS Secret Key

### Work-Specific Secrets
- `DATADOG_API_KEY` - Datadog API Key
- `DATADOG_APP_KEY` - Datadog Application Key
- Azure Storage Keys (various)
- Azure Client Secrets

### Personal-Specific Secrets
- Personal AWS credentials
- Personal API keys

## Backup and Recovery

### Backup Secrets
```bash
# Backup Development vault (creates encrypted file)
backup_secrets

# Backup to specific file
backup_secrets Development my-backup.json.age
```

### Recovery
1. Ensure you have your 1Password account credentials
2. Re-run `./scripts/setup-secrets.sh` to reconfigure accounts
3. Secrets are automatically synced from 1Password cloud

## Security Best Practices

1. **Never commit secrets** - All secrets stay in 1Password
2. **Use descriptive names** - Makes secrets easy to find
3. **Regular rotation** - Rotate secrets periodically
4. **Minimal permissions** - Grant only necessary access
5. **Audit access** - Review vault access regularly

## Troubleshooting

### "Not signed in" Error
```bash
op-signin
```

### Wrong Account Detected
```bash
# Check current detection
echo $OP_ACCOUNT_ALIAS

# Override if needed
export OP_ACCOUNT_OVERRIDE=work
```

### Secret Not Found
```bash
# Check which account has the secret
op-current  # See current account
list_secrets  # List secrets in current vault
```

### Performance Issues
- First call to 1Password may be slower
- Subsequent calls are cached
- Session lasts 30 minutes

## Architecture Decisions

See [ADR-001](../docs/adr/001-secret-management.md) for rationale behind choosing 1Password CLI.

## Related Documentation

- [Setup Guide](secret-management-setup.md) - Detailed setup instructions
- [Evaluation Matrix](../proompting/evaluation/secret-managers/evaluation-matrix.md) - Tool comparison
- [Security Report](../proompting/audit/secrets_report.md) - Original security findings 