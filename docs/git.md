# Git Configuration Guide

A comprehensive guide to the advanced Git configuration system that provides secure, profile-based identity management, extensive automation, and cross-platform compatibility for modern development workflows.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Profile Management](#profile-management)
- [Security Features](#security-features)
- [Aliases and Automation](#aliases-and-automation)
- [Git Hooks](#git-hooks)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [Advanced Usage](#advanced-usage)
- [Reference](#reference)

## Overview

The Git configuration system provides enterprise-grade Git management with security-first principles, automatic profile switching, and workflow automation. Built for developers who work across multiple contexts (personal, work, open source), it ensures consistent, secure, and productive Git workflows.

### Key Features

- **🔒 Security-First**: Zero credentials in repository, GPG/SSH signing support
- **👤 Profile Management**: Automatic identity switching by directory context
- **🚀 Workflow Automation**: 50+ productivity aliases and custom commands
- **🔧 Smart Defaults**: Optimized Git settings for modern development
- **🌍 Cross-Platform**: Works seamlessly on macOS, Linux, and Windows
- **🔗 Integration**: Deep integration with SSH, 1Password, and shell systems

### Profile System Overview

| Profile | Context | Identity | Signing | Use Case |
|---------|---------|----------|---------|----------|
| **Personal** | `~/personal/*` | Personal email | GPG/SSH | Personal projects |
| **Work** | `~/work/*` | Work email | Corporate keys | Company projects |
| **Open Source** | `~/opensource/*` | Public email | GPG | Contributions |
| **Default** | Other paths | Template-based | Configurable | Fallback |

## Architecture

### Configuration Structure

```
config/git/
├── config                     # Main Git configuration
├── ignore                     # Global gitignore patterns  
├── attributes                 # Git attributes and LFS
├── hooks/                     # Automated quality gates
│   ├── pre-commit            # Secret scanning, validation
│   ├── commit-msg            # Message format validation
│   └── pre-push              # Security and quality checks
└── includes/                  # Profile-specific configurations
    ├── personal.gitconfig    # Personal identity and settings
    ├── work.gitconfig        # Work identity and policies
    └── opensource.gitconfig  # Open source contribution settings

scripts/
├── git-setup.sh              # Installation and management
└── git-profile.sh            # Profile management utilities

templates/git/
├── config.tmpl               # Main configuration template
├── personal.gitconfig.template
└── work.gitconfig.template
```

### Profile Loading Mechanism

```gitconfig
# Main config includes profiles based on directory
[includeIf "gitdir:~/personal/"]
    path = includes/personal.gitconfig
[includeIf "gitdir:~/work/"] 
    path = includes/work.gitconfig
[includeIf "gitdir:~/opensource/"]
    path = includes/opensource.gitconfig
```

## Quick Start

### Installation

```bash
# Via bootstrap (recommended)
./scripts/bootstrap.sh

# Git configuration only
./scripts/git-setup.sh install

# Validate installation
./scripts/git-setup.sh validate
```

### Initial Setup

```bash
# Create profile directories
mkdir -p ~/personal ~/work ~/opensource

# Inject your identity (uses 1Password integration)
./scripts/inject-secrets.sh

# Verify profile switching
cd ~/personal && git config user.email    # Personal email
cd ~/work && git config user.email        # Work email
```

### Immediate Benefits

After installation, you'll have:

- ✅ **Automatic Profile Switching**: Identity changes based on directory
- ✅ **50+ Git Aliases**: Productivity shortcuts for common workflows
- ✅ **Security Automation**: Pre-commit hooks prevent secret exposure
- ✅ **Quality Gates**: Commit message validation and code quality checks
- ✅ **Cross-Platform URLs**: Automatic HTTPS → SSH rewriting
- ✅ **Performance Optimization**: Intelligent caching and parallel operations

## Profile Management

### Profile Configuration

Each profile contains identity information and context-specific settings:

#### Personal Profile
```gitconfig
# includes/personal.gitconfig
[user]
    name = {{ git_personal_name }}
    email = {{ git_personal_email }}
    signingkey = {{ git_personal_signing_key }}

[commit]
    gpgsign = true

[github]
    user = {{ github_personal_username }}

[core]
    sshCommand = ssh -i ~/.ssh/personal_ed25519
```

#### Work Profile  
```gitconfig
# includes/work.gitconfig
[user]
    name = {{ git_work_name }}
    email = {{ git_work_email }}
    signingkey = {{ git_work_signing_key }}

[commit]
    gpgsign = true

[github]
    user = {{ github_work_username }}

[core]
    sshCommand = ssh -i ~/.ssh/work_ed25519
    
[push]
    default = simple
    followTags = false  # Conservative for work
```

### Directory-Based Activation

Profiles activate automatically based on repository location:

```bash
# Personal projects
cd ~/personal/my-blog
git config user.email        # → personal@example.com

# Work projects
cd ~/work/company-app  
git config user.email        # → you@company.com

# Open source contributions
cd ~/opensource/project
git config user.email        # → opensource@example.com
```

### Profile Management Commands

```bash
# Show current profile
./scripts/git-profile.sh current

# List all configured profiles
./scripts/git-profile.sh list

# Show profile details
./scripts/git-profile.sh info work

# Create profile directory
./scripts/git-profile.sh create ~/freelance

# Validate profile configuration
./scripts/git-profile.sh validate
```

## Security Features

### Zero-Secret Repository

All personal information is externalized using the secret injection system:

```gitconfig
# Template with secret placeholders
[user]
    name = "{{ op://Personal/Git Config/name }}"
    email = "{{ op://Personal/Git Config/email }}"
    signingkey = "{{ op://Personal/Git GPG Key/key_id }}"
```

### Commit Signing

#### GPG Signing Configuration
```bash
# Generate GPG key for signing
gpg --full-generate-key

# Configure Git to use GPG
git config --global user.signingkey [KEY_ID]
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Store in 1Password for template injection
op create item --category="Secure Note" --title="Git GPG Key" \
  key_id=[KEY_ID] private_key="$(gpg --export-secret-keys --armor [KEY_ID])"
```

#### SSH Signing (Modern Alternative)
```bash
# Use SSH key for signing (Git 2.34+)
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/signing_key.pub
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

### Authentication Security

#### HTTPS → SSH Rewriting
```gitconfig
# Automatically use SSH for GitHub/GitLab
[url "ssh://git@github.com/"]
    insteadOf = https://github.com/

[url "ssh://git@gitlab.com/"]
    insteadOf = https://gitlab.com/
```

#### Credential Helper Configuration
```gitconfig
# Platform-specific credential helpers
[credential]
    helper = osxkeychain         # macOS
    # helper = libsecret         # Linux
    # helper = manager           # Windows
    
[credential "https://github.com"]
    username = {{ github_username }}
    helper = !gh auth git-credential
```

## Aliases and Automation

### Workflow Aliases

The configuration includes 50+ aliases organized by workflow:

#### Basic Operations
```gitconfig
[alias]
    # Status and information
    st = status
    s = status --short
    ss = status --short --branch
    
    # Staging and commits
    a = add
    aa = add --all
    ap = add --patch
    c = commit
    cm = commit --message
    ca = commit --amend
    
    # Branching and merging
    co = checkout
    cob = checkout -b
    br = branch
    bra = branch --all
    brd = branch --delete
```

#### Advanced Workflows
```gitconfig
[alias]
    # Logging and history
    l = log --oneline --graph --decorate
    la = log --oneline --graph --decorate --all
    ll = log --graph --pretty=format:'%C(yellow)%h%Creset -%C(red)%d%Creset %s %C(green)(%cr) %C(cyan)<%an>%Creset'
    
    # Stashing
    save = stash save
    pop = stash pop
    peek = stash show -p
    
    # Remote operations
    f = fetch
    fa = fetch --all
    p = push
    pu = push --set-upstream origin HEAD
    pl = pull
    
    # Rebasing and merging
    rb = rebase
    rbi = rebase --interactive
    rbic = rebase --interactive --continue
    mt = mergetool
```

#### Custom Commands
```gitconfig
[alias]
    # Quick commit with message
    gcom = "!f() { git add -A && git commit -m \"$1\"; }; f"
    
    # Push with upstream tracking
    gpush = "!f() { git push --set-upstream origin $(git branch --show-current); }; f"
    
    # Create and switch to new branch
    gnew = "!f() { git checkout -b \"$1\" && git push --set-upstream origin \"$1\"; }; f"
    
    # Show file contributors
    contributors = shortlog --summary --numbered --email
    
    # Clean merged branches
    cleanup = "!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d"
```

### Custom Git Commands

#### Advanced Workflow Commands
```bash
# scripts/git-flow.sh

# Interactive rebase from main
git-rebase-main() {
    git fetch origin
    git rebase -i origin/main
}

# Squash commits for PR
git-squash-pr() {
    local commit_count=${1:-2}
    git reset --soft HEAD~$commit_count
    git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"
}

# Create feature branch with Jira ticket
git-feature() {
    local ticket="$1"
    local description="$2"
    local branch="feature/${ticket}-${description//[ ]/-}"
    git checkout -b "$branch"
    git push --set-upstream origin "$branch"
}
```

## Git Hooks

### Pre-Commit Hook

Prevents common issues before commits are created:

```bash
#!/bin/bash
# config/git/hooks/pre-commit

# Secret scanning
echo "🔍 Scanning for secrets..."
if grep -r --include="*.env*" --include="*.key*" \
   -E "(password|secret|token|api_key)" .; then
    echo "❌ Potential secrets detected!"
    exit 1
fi

# File size validation
echo "📏 Checking file sizes..."
large_files=$(git diff --cached --name-only | xargs ls -la | awk '$5 > 52428800')
if [[ -n "$large_files" ]]; then
    echo "❌ Large files detected (>50MB):"
    echo "$large_files"
    exit 1
fi

# Trailing whitespace
echo "🧹 Checking for trailing whitespace..."
if git diff --cached --check; then
    echo "❌ Trailing whitespace detected!"
    exit 1
fi

# Syntax validation for common files
echo "✅ Running syntax validation..."
for file in $(git diff --cached --name-only --diff-filter=ACM); do
    case "$file" in
        *.py)   python -m py_compile "$file" || exit 1 ;;
        *.js)   node -c "$file" || exit 1 ;;
        *.sh)   bash -n "$file" || exit 1 ;;
        *.yml|*.yaml) yamllint "$file" || exit 1 ;;
    esac
done

echo "✅ Pre-commit checks passed!"
```

### Commit Message Hook

Enforces conventional commit format:

```bash
#!/bin/bash
# config/git/hooks/commit-msg

commit_file="$1"
commit_msg=$(cat "$commit_file")

# Skip for merge/revert commits
if echo "$commit_msg" | grep -qE "^(Merge|Revert)"; then
    exit 0
fi

# Conventional commits pattern
pattern="^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{1,72}"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
    echo "❌ Invalid commit message format!"
    echo "Format: type(scope): description"
    echo "Types: feat, fix, docs, style, refactor, test, chore"
    echo "Example: feat(auth): add OAuth integration"
    exit 1
fi

echo "✅ Commit message format validated!"
```

### Pre-Push Hook

Final security and quality checks:

```bash
#!/bin/bash
# config/git/hooks/pre-push

protected_branch="main"
current_branch=$(git branch --show-current)

# Protect main branch from direct pushes
if [[ "$current_branch" == "$protected_branch" ]]; then
    echo "❌ Direct push to $protected_branch is not allowed!"
    echo "Please create a feature branch and submit a PR."
    exit 1
fi

# Check for large files in history
echo "🔍 Scanning for large files..."
large_files=$(git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  awk '/^blob/ {if($3 > 104857600) print $4}')  # 100MB

if [[ -n "$large_files" ]]; then
    echo "❌ Large files found in history:"
    echo "$large_files"
    echo "Consider using Git LFS or removing these files."
    exit 1
fi

echo "✅ Pre-push checks passed!"
```

## Customization

### Personal Git Configuration

#### Local Overrides
```bash
# Create local Git config overrides
cat > ~/.config/git/local << 'EOF'
[user]
    # Override signing key for this machine
    signingkey = ABC123DEF

[core]
    # Use different editor
    editor = code --wait

[diff]
    # Use custom diff tool
    tool = vscode
EOF

# Include in main config
git config --global include.path ~/.config/git/local
```

#### Repository-Specific Configuration
```bash
# In specific repository
cd ~/special-project

# Use different identity for this repo
git config user.email "special@example.com"
git config user.name "Special Identity"

# Use different signing key
git config user.signingkey "DIFFERENT_KEY"
```

### Custom Aliases

#### Project-Specific Workflows
```gitconfig
# Add to ~/.config/git/aliases
[alias]
    # Deployment workflow
    deploy-staging = "!f() { git push origin main:staging && ./scripts/deploy-staging.sh; }; f"
    deploy-prod = "!f() { git tag -a v$1 -m 'Release v$1' && git push origin v$1; }; f"
    
    # Code review helpers
    review = "!f() { git log --oneline main..HEAD && git diff main..HEAD; }; f"
    conflicts = diff --name-only --diff-filter=U
    
    # Statistics and analysis
    stats = shortlog -sn
    activity = "!git log --since='1 week ago' --oneline --author=$(git config user.email)"
```

### Hook Customization

#### Repository-Specific Hooks
```bash
# Create repo-specific pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run global hook first
~/.config/git/hooks/pre-commit

# Repository-specific checks
npm test || exit 1
npm run lint || exit 1
EOF

chmod +x .git/hooks/pre-commit
```

## Troubleshooting

### Common Issues

#### Profile Not Switching
```bash
# Check Git configuration
git config --list --show-origin | grep user

# Verify includeIf paths
git config --list | grep includeIf

# Test profile matching
cd ~/work/test-repo
git config --show-origin user.email

# Common fixes:
# 1. Ensure trailing slash in gitdir paths
# 2. Use absolute paths for includes
# 3. Check file permissions on include files
```

#### Signing Issues
```bash
# GPG signing problems
git config --global --unset gpg.program
gpg --list-secret-keys --keyid-format LONG

# SSH signing issues (Git 2.34+)
ssh-add -l                    # Check SSH agent
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub

# Test signing
git commit --allow-empty -m "Test signing" -S
```

#### Hook Execution Problems
```bash
# Check hook permissions
ls -la .git/hooks/
chmod +x .git/hooks/*

# Test hooks manually
.git/hooks/pre-commit
echo $?  # Should return 0 for success

# Debug hook issues
bash -x .git/hooks/pre-commit
```

#### Performance Issues
```bash
# Check for large files
git count-objects -vH

# Cleanup repository
git gc --aggressive --prune=now

# Check configuration performance
time git config --list

# Optimize configuration
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256
```

### Diagnostic Commands

#### Configuration Analysis
```bash
# Show all Git configuration
git config --list --show-origin

# Test alias expansion
git config --get alias.st

# Verify signing setup
git config --get user.signingkey
git config --get commit.gpgsign
```

#### Performance Analysis
```bash
# Time Git operations
time git status
time git log --oneline -10

# Repository statistics
git count-objects -vH
du -sh .git/

# Network performance
time git ls-remote origin
```

## Migration Guide

### From Default Git Configuration

```bash
# Backup existing configuration
cp ~/.gitconfig ~/.gitconfig.backup

# Import existing settings
./scripts/git-setup.sh import-existing

# Manual migration of custom aliases
grep "^\[alias\]" -A 50 ~/.gitconfig.backup >> ~/.config/git/local
```

### From GUI Git Clients

#### From SourceTree
```bash
# Export SourceTree settings
# SourceTree → Preferences → Advanced → Export Settings

# Import relevant Git configuration
./scripts/git-setup.sh import-sourcetree ~/exported-settings.json
```

#### From GitKraken
```bash
# GitKraken stores Git config in standard locations
# Configuration is automatically detected during setup

# Import GitKraken profiles
./scripts/git-setup.sh detect-profiles
```

### From Corporate Git Setup

```bash
# Preserve corporate Git configuration
cp ~/.gitconfig ~/.gitconfig.corporate

# Create work profile from corporate config
./scripts/git-profile.sh create-from-config work ~/.gitconfig.corporate

# Apply corporate policies
cat >> ~/.config/git/includes/work.gitconfig << 'EOF'
[push]
    default = simple
    followTags = false

[pull]
    rebase = false

[merge]
    ff = false
EOF
```

## Advanced Usage

### Multi-Identity Workflows

#### Context Switching Automation
```bash
# Automatic profile setup based on remote origin
git-auto-profile() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    case "$remote_url" in
        *github.com/company*)
            git config include.path ~/.config/git/includes/work.gitconfig
            ;;
        *gitlab.com/personal*)
            git config include.path ~/.config/git/includes/personal.gitconfig
            ;;
    esac
}

# Add to shell hook
cd() { builtin cd "$@" && git-auto-profile 2>/dev/null; }
```

#### Team Configuration Sharing
```bash
# Team-specific Git configuration
cat > ~/.config/dotfiles/team-git.yml << 'EOF'
git:
  aliases:
    team-review: "!f() { git push origin HEAD && gh pr create --draft; }; f"
    deploy: "!f() { git tag deploy-$(date +%Y%m%d-%H%M%S) && git push origin --tags; }; f"
  hooks:
    pre-push: |
      # Team-specific validation
      npm test
      npm run security-scan
EOF

# Apply team configuration  
dotfiles apply-git-config team-git.yml
```

### Enterprise Integration

#### LDAP/Active Directory Integration
```bash
# Corporate identity lookup
git-corporate-identity() {
    local ldap_user=$(ldapwhoami -Q | sed 's/.*uid=\([^,]*\).*/\1/')
    local full_name=$(ldapsearch -LLL -Q uid=$ldap_user cn | grep 'cn:' | cut -d' ' -f2-)
    local email="${ldap_user}@company.com"
    
    git config user.name "$full_name"
    git config user.email "$email"
}
```

#### Compliance and Auditing
```bash
# Audit Git configuration compliance
git-compliance-check() {
    local issues=()
    
    # Check signing requirement
    [[ $(git config commit.gpgsign) != "true" ]] && issues+=("GPG signing not enabled")
    
    # Check email domain for work repositories
    if [[ "$PWD" =~ /work/ ]]; then
        local email=$(git config user.email)
        [[ "$email" =~ @company\.com$ ]] || issues+=("Non-corporate email in work repository")
    fi
    
    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "❌ Compliance issues found:"
        printf '%s\n' "${issues[@]}"
        return 1
    else
        echo "✅ Git configuration is compliant"
        return 0
    fi
}
```

## Reference

### Configuration Files

| File | Purpose | Template |
|------|---------|----------|
| `config/git/config` | Main Git configuration | `templates/git/config.tmpl` |
| `config/git/ignore` | Global gitignore patterns | Static |
| `config/git/attributes` | Git attributes and LFS | Static |
| `config/git/includes/*.gitconfig` | Profile configurations | `templates/git/*.template` |

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `GIT_AUTHOR_NAME` | Override author name | From config |
| `GIT_AUTHOR_EMAIL` | Override author email | From config |
| `GIT_COMMITTER_NAME` | Override committer name | From config |
| `GIT_COMMITTER_EMAIL` | Override committer email | From config |

### Available Commands

#### Profile Management
```bash
git-profile current           # Show active profile
git-profile list             # List all profiles  
git-profile info [profile]   # Show profile details
git-profile create [path]    # Create profile directory
git-profile validate         # Validate configuration
```

#### Setup and Maintenance
```bash
git-setup install           # Install Git configuration
git-setup validate          # Validate installation
git-setup status            # Show configuration status
git-setup clean             # Remove configuration
git-setup update            # Update configuration
```

### Performance Optimizations

| Setting | Purpose | Value |
|---------|---------|-------|
| `core.preloadindex` | Faster index operations | `true` |
| `core.fscache` | Cache file system calls | `true` |
| `gc.auto` | Automatic garbage collection | `256` |
| `pack.threads` | Parallel packing | `0` (auto) |
| `pack.windowMemory` | Pack window memory | `1g` |

This Git configuration system provides a secure, productive, and maintainable foundation for Git operations across all development contexts. The profile-based approach ensures appropriate identity management while extensive automation reduces manual overhead and prevents common mistakes. 