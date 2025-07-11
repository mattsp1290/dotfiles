# 1Password CLI Setup Guide

This guide walks you through setting up 1Password CLI for managing secrets in your dotfiles across multiple environments (work and personal).

## Prerequisites

- [x] 1Password account(s) (personal and/or work)
- [x] 1Password CLI installed (`brew install --cask 1password-cli`)
- [x] 1Password desktop app installed and signed in

## Important: Multi-Account Setup

Since this dotfiles repository will be used on both work and personal computers with different 1Password accounts, we'll set up a system that:
- Automatically detects which environment you're in
- Uses the appropriate 1Password account
- Maintains the same secret names across accounts
- Falls back gracefully if secrets don't exist

## Step-by-Step Setup

### 1. Add ALL Your 1Password Accounts

You can add multiple accounts to the CLI. Each will have a shorthand name.

#### For Personal Account:
```bash
op account add --address my.1password.com --email personal@example.com --shorthand personal
```

#### For Work Account:
```bash
op account add --address company.1password.com --email work@company.com --shorthand work
```

You'll be prompted for:
1. **Secret Key**: From 1Password app > Settings > Account > Set Up Another Device
2. **Master Password**: Your account's master password

### 2. List Your Accounts

Verify both accounts are added:
```bash
op account list
```

### 3. Create Environment Detection

We'll create a system that automatically selects the right account based on your environment.

Create `~/.config/op/env-detect.sh`:
```bash
#!/bin/bash
# Detect which 1Password account to use based on environment

# Method 1: Check hostname
if [[ "$(hostname)" == *"work"* ]] || [[ "$(hostname)" == *"company"* ]]; then
    echo "work"
elif [[ "$(hostname)" == *"personal"* ]] || [[ "$(hostname)" == *"home"* ]]; then
    echo "personal"
# Method 2: Check for work-specific directories
elif [[ -d "$HOME/work" ]] || [[ -d "/opt/company" ]]; then
    echo "work"
# Method 3: Check for environment variable
elif [[ -n "$WORK_ENV" ]]; then
    echo "work"
else
    # Default to personal
    echo "personal"
fi
```

### 4. Create Account Switcher

Add this to your shell configuration (`~/.zshrc` or `~/.bashrc`):

```bash
# 1Password Multi-Account Support
export OP_ACCOUNT_ALIAS=$(~/.config/op/env-detect.sh 2>/dev/null || echo "personal")

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

# List available accounts
op-accounts() {
    op account list
}

# Get current account
op-current() {
    echo "Current account alias: $OP_ACCOUNT_ALIAS"
    op account get --account "$OP_ACCOUNT_ALIAS"
}
```

### 5. Create Development Vaults in Both Accounts

Sign in to each account and create matching vault structures:

```bash
# Personal account
op-personal
op vault create "Development"

# Work account
op-work
op vault create "Development"
```

## Handling Secrets Across Accounts

### Strategy 1: Duplicate Important Secrets

Keep the same secret names in both accounts:
```bash
# In personal account
op item create --category "API Credential" --title "GITHUB_TOKEN" \
    --vault Development credential="ghp_personal_token"

# In work account
op item create --category "API Credential" --title "GITHUB_TOKEN" \
    --vault Development credential="ghp_work_token"
```

### Strategy 2: Account-Specific Secrets

Use prefixes for account-specific secrets:
```bash
# Personal-only secret
op item create --title "personal/aws-access-key" --vault Development

# Work-only secret
op item create --title "work/datadog-api-key" --vault Development
```

### Strategy 3: Universal Secret Getter

Create a function that tries multiple accounts:
```bash
# Add to your shell configuration
get-secret() {
    local secret_name="$1"
    local field="${2:-password}"
    
    # Try current account first
    if op item get "$secret_name" --vault Development --fields "$field" 2>/dev/null; then
        return 0
    fi
    
    # Try other accounts
    for account in personal work; do
        if [[ "$account" != "$OP_ACCOUNT_ALIAS" ]]; then
            if op item get "$secret_name" --vault Development --fields "$field" --account "$account" 2>/dev/null; then
                return 0
            fi
        fi
    done
    
    # Secret not found
    echo "Secret '$secret_name' not found in any account" >&2
    return 1
}
```

## Environment Variable Loading

Create a universal secret loader that works across accounts:

```bash
# ~/.config/op/load-secrets.sh
#!/bin/bash

# Ensure we're signed in
if ! op account get --account "$OP_ACCOUNT_ALIAS" >/dev/null 2>&1; then
    echo "Not signed in to 1Password. Run 'op-signin'" >&2
    return 1
fi

# Load common secrets (present in both accounts)
export GITHUB_TOKEN=$(get-secret "GITHUB_TOKEN" credential)
export ANTHROPIC_API_KEY=$(get-secret "ANTHROPIC_API_KEY" credential)

# Load account-specific secrets
if [[ "$OP_ACCOUNT_ALIAS" == "work" ]]; then
    export DATADOG_API_KEY=$(get-secret "DATADOG_API_KEY" credential)
    export DATADOG_APP_KEY=$(get-secret "DATADOG_APP_KEY" credential)
fi

# Load AWS credentials (might differ between accounts)
export AWS_ACCESS_KEY_ID=$(get-secret "AWS_ACCESS_KEY_ID" credential)
export AWS_SECRET_ACCESS_KEY=$(get-secret "AWS_SECRET_ACCESS_KEY" credential)
```

## Best Practices for Multi-Account Setup

1. **Consistent Naming**: Use the same secret names across accounts when possible
2. **Environment Detection**: Make detection robust using multiple methods
3. **Graceful Fallbacks**: Handle missing secrets without breaking shell startup
4. **Clear Indicators**: Always show which account is active
5. **Easy Switching**: Provide quick commands to switch contexts

## Testing Your Setup

```bash
# Test environment detection
~/.config/op/env-detect.sh

# Test account switching
op-personal
op vault list

op-work
op vault list

# Test secret retrieval
get-secret "GITHUB_TOKEN" credential
```

## Troubleshooting Multi-Account Issues

### "Account not found" when switching
```bash
# Re-add the account
op account add --address company.1password.com --email work@company.com --shorthand work
```

### Wrong account detected
```bash
# Override detection
export OP_ACCOUNT_ALIAS="work"
op-signin
```

### Secret exists in wrong account
```bash
# Check which account has the secret
for account in personal work; do
    echo "Checking $account:"
    op item get "SECRET_NAME" --vault Development --account "$account" 2>/dev/null && echo "Found!"
done
```

## Next Steps

1. Add both your 1Password accounts using the commands above
2. Set up environment detection for your specific machines
3. Create the Development vault in both accounts
4. Test the account switching functionality
5. Begin migrating secrets from AUDIT-002

## Additional Resources

- [1Password CLI Multiple Accounts](https://developer.1password.com/docs/cli/sign-in#sign-in-to-multiple-accounts)
- [1Password CLI Account Management](https://developer.1password.com/docs/cli/reference/management-commands/account)

## Shell Integration

### Automatic Sign-in (Optional)

Add this to your `~/.zshrc` or `~/.bashrc` for easier access:

```bash
# 1Password CLI helper
op-signin() {
    eval $(op signin)
}

# Auto-signin if not already authenticated
if ! op account list >/dev/null 2>&1; then
    echo "1Password CLI not authenticated. Run 'op-signin' to sign in."
fi
```

### Session Management

1Password CLI sessions expire after 30 minutes of inactivity. You can:

- **Manual re-authentication**: Run `eval $(op signin)` when needed
- **Check session status**: `op account list`
- **Sign out**: `op signout`

## Common Commands

### Working with Secrets

```bash
# Create a new secret
op item create --category login --title "GitHub Token" --vault Development \
    username="mattspurlin" password="ghp_xxxxxxxxxxxx"

# Get a secret
op item get "GitHub Token" --vault Development

# Get just the password field
op item get "GitHub Token" --vault Development --fields password

# Update a secret
op item edit "GitHub Token" --vault Development password="new_token_value"

# Delete a secret
op item delete "GitHub Token" --vault Development
```

### Environment Variable Pattern

Create secrets that work well with environment variables:

```bash
# Create an API key
op item create --category "API Credential" \
    --title "GITHUB_TOKEN" \
    --vault Development \
    credential="ghp_xxxxxxxxxxxx"

# Use in scripts
export GITHUB_TOKEN=$(op item get "GITHUB_TOKEN" --vault Development --fields credential)
```

## Troubleshooting

### "No account found" Error
- Run `op account list` to see configured accounts
- Re-add your account with `op account add`

### "Session expired" Error
- Run `eval $(op signin)` to start a new session

### "Vault not found" Error
- Check vault name with `op vault list`
- Vault names are case-sensitive

### Performance Issues
- 1Password CLI caches data for better performance
- First call might be slower, subsequent calls are faster
- Use `--cache` flag for better performance in scripts

## Security Best Practices

1. **Never hardcode secrets** in scripts
2. **Use descriptive item names** for easy identification
3. **Organize with vaults** (Development, Production, Personal)
4. **Regular rotation** - 1Password can remind you to rotate secrets
5. **Audit access** - Check who has access to shared vaults

## Linux Setup

For Linux systems, installation differs slightly:

```bash
# Debian/Ubuntu
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(lsb_release -cs) stable main" | \
    sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# Fedora/RHEL
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
sudo dnf install 1password-cli
```

## Next Steps

1. ✅ Complete CLI setup
2. Create secrets for all items from AUDIT-002
3. Update shell configurations to use `op` commands
4. Test shell startup performance
5. Document your specific secret patterns

## Additional Resources

- [1Password CLI Reference](https://developer.1password.com/docs/cli/reference)
- [1Password CLI Secrets Automation](https://developer.1password.com/docs/cli/secrets-automation)
- [Shell Plugin Documentation](https://developer.1password.com/docs/cli/shell-plugins) 