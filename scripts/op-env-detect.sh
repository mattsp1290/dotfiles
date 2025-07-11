#!/bin/bash
# Detect which 1Password account to use based on environment
# This script outputs either "work" or "personal"

# Method 1: Check for explicit environment variable override
if [[ -n "$OP_ACCOUNT_OVERRIDE" ]]; then
    echo "$OP_ACCOUNT_OVERRIDE"
    exit 0
fi

# Method 2: Check username (MOST RELIABLE METHOD)
USERNAME=$(whoami)
if [[ "$USERNAME" =~ 1290 ]]; then
    # Personal usernames always contain "1290" (punk1290, mattsp1290, etc.)
    echo "personal"
    exit 0
elif [[ "$USERNAME" == "matt.spurlin" ]]; then
    # Work username
    echo "work"
    exit 0
fi

# Method 3: Check hostname patterns (backup method)
HOSTNAME=$(hostname -s 2>/dev/null || hostname)
if [[ "$HOSTNAME" =~ (work|corp|company|office) ]]; then
    echo "work"
    exit 0
elif [[ "$HOSTNAME" =~ (home|personal|1290) ]]; then
    echo "personal"
    exit 0
fi

# Method 4: Check for work-specific directories or files
if [[ -d "$HOME/work" ]] || [[ -d "$HOME/Work" ]] || [[ -d "/opt/company" ]]; then
    echo "work"
    exit 0
fi

# Method 5: Check for work-specific environment variables
if [[ -n "$WORK_ENV" ]] || [[ -n "$CORPORATE_ENV" ]] || [[ -n "$COMPANY_NAME" ]]; then
    echo "work"
    exit 0
fi

# Method 6: Check network domain (macOS)
if command -v scutil >/dev/null 2>&1; then
    DOMAIN=$(scutil --get LocalHostName 2>/dev/null || echo "")
    if [[ "$DOMAIN" =~ (corp|company|work) ]]; then
        echo "work"
        exit 0
    fi
fi

# Method 7: Check git config for work email
if command -v git >/dev/null 2>&1; then
    GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    if [[ "$GIT_EMAIL" =~ @(datadog|work|corp) ]]; then
        echo "work"
        exit 0
    fi
fi

# Default to personal (fail-safe)
echo "personal" 