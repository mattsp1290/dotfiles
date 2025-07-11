# Shell Configuration Guide

A comprehensive guide to the advanced shell configuration system that provides consistent, high-performance shell environments across platforms with modular architecture and intelligent optimization.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration Details](#configuration-details)
- [Customization](#customization)
- [Performance Optimization](#performance-optimization)
- [Cross-Platform Support](#cross-platform-support)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [Advanced Usage](#advanced-usage)
- [Reference](#reference)

## Overview

The shell configuration system transforms your command-line experience into a powerful, efficient development environment. Built on a modular architecture, it provides:

- **⚡ High Performance**: Sub-500ms startup time with intelligent lazy loading
- **🔧 Modular Design**: 10+ specialized modules with clear separation of concerns
- **🌍 Cross-Platform**: Seamless operation on macOS, Linux, and Windows (WSL)
- **🔒 Security-First**: Zero secrets in configuration with 1Password integration
- **🎨 Rich Features**: Oh My Zsh, advanced completion, custom functions
- **📈 Optimized Workflow**: 200+ aliases and functions for developer productivity

### Supported Shells

| Shell | Support Level | Features |
|-------|---------------|----------|
| **Zsh** | Full | Complete modular system, Oh My Zsh, themes, plugins |
| **Bash** | Compatible | Core functionality, aliases, functions |
| **Fish** | Basic | Minimal configuration, planned expansion |

## Architecture

### Modular Configuration System

The shell configuration uses a numbered loading system that ensures proper dependency ordering:

```
shell/zsh/
├── .zshrc                    # Main loader (47 lines)
├── .zshenv                   # Environment setup (38 lines)
├── .zprofile                 # Login shell config (14 lines)
├── modules/                  # Core functionality modules
│   ├── 00-init.zsh          # Basic zsh options
│   ├── 01-environment.zsh   # Environment variables
│   ├── 02-path.zsh          # PATH management
│   ├── 03-aliases.zsh       # Command aliases
│   ├── 04-functions.zsh     # Custom functions
│   ├── 05-completion.zsh    # Completion system
│   ├── 06-prompt.zsh        # Oh My Zsh/themes
│   ├── 07-keybindings.zsh   # Key bindings
│   ├── 08-plugins.zsh       # External plugins
│   └── 99-local.zsh         # Local overrides
├── os/                       # OS-specific configurations
├── templates/               # Secret injection templates
└── local/                   # Machine-specific files
```

### Loading Sequence

1. **Environment Setup** (`.zshenv`): Essential environment variables
2. **Profile Loading** (`.zprofile`): Login shell initialization  
3. **Module Loading** (`.zshrc`): Sequential module processing
4. **Local Overrides**: Machine-specific customizations

## Quick Start

### Installation

```bash
# Via bootstrap (recommended)
./scripts/bootstrap.sh

# Manual shell configuration only
./scripts/setup/shell-setup.sh

# Migrate existing configuration
./scripts/migrate-zsh.sh
```

### Immediate Benefits

After installation, you'll have:

- ✅ **200+ Aliases**: Productivity shortcuts (`ll`, `la`, `grep`, `git` shortcuts)
- ✅ **Custom Functions**: `mkcd`, `extract`, `backup`, search utilities
- ✅ **Smart Completion**: Enhanced tab completion with fuzzy matching
- ✅ **Oh My Zsh**: Spaceship prompt with git integration
- ✅ **1Password Integration**: Secure credential management
- ✅ **Development Tools**: Support for 15+ programming languages

### Verification

```bash
# Check shell configuration
echo $SHELL                    # Should show zsh path
echo $SHELL_STARTUP_TIME      # Should show <500ms

# Test key functionality
alias | head -10              # Show available aliases
which extract                 # Verify custom functions
git status                    # Test git integration
```

## Configuration Details

### Module Breakdown

#### 00-init.zsh - Core Zsh Options
```bash
# Key features
setopt AUTO_CD              # Change to directory by name
setopt CORRECT              # Command correction
setopt HIST_VERIFY         # Verify history expansions
setopt SHARE_HISTORY       # Share history between sessions
```

**What it provides:**
- History configuration (50,000 lines, deduplication)
- Directory navigation improvements
- Command correction and verification
- Completion system initialization

#### 01-environment.zsh - Environment Variables
```bash
# Essential variables
export EDITOR="nvim"
export PAGER="less"
export BROWSER="open"
export LANG="en_US.UTF-8"

# Development tools
export HOMEBREW_NO_ANALYTICS=1
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

**What it provides:**
- 30+ environment variables for development tools
- XDG Base Directory specification compliance
- Language and locale configuration
- Tool-specific optimizations

#### 02-path.zsh - PATH Management
```bash
# Priority order PATH construction
path=(
    $HOME/.local/bin
    $HOME/bin
    /opt/homebrew/bin     # Apple Silicon
    /usr/local/bin        # Intel Mac
    $path
)
```

**What it provides:**
- Intelligent PATH construction with priority ordering
- Conditional inclusion based on directory existence
- Cross-platform compatibility (macOS/Linux)
- Development tool integration (pyenv, rbenv, etc.)

#### 03-aliases.zsh - Command Aliases
```bash
# File operations
alias ll='ls -la'
alias la='ls -A'
alias tree='tree -C'

# Git shortcuts
alias g='git'
alias gst='git status'
alias gco='git checkout'

# System utilities
alias grep='grep --color=auto'
alias mkdir='mkdir -p'
alias du='du -h'
```

**Categories of aliases:**
- **File Operations** (40+ aliases): `ls`, `cp`, `mv`, `rm` variations
- **Git Workflow** (50+ aliases): Complete git command shortcuts
- **System Utilities** (30+ aliases): Enhanced system commands
- **Development Tools** (20+ aliases): Language-specific shortcuts
- **Network & Security** (25+ aliases): SSH, networking, security tools

#### 04-functions.zsh - Custom Functions
```bash
# Create and enter directory
mkcd() { mkdir -p "$1" && cd "$1" }

# Multi-format extraction
extract() {
    case $1 in
        *.tar.bz2) tar xjf $1 ;;
        *.tar.gz)  tar xzf $1 ;;
        *.zip)     unzip $1 ;;
        # ... more formats
    esac
}

# 1Password integration
op-get() { op item get "$1" --field password }
```

**Function categories:**
- **File Management**: `extract`, `backup`, `ff`, `fd`
- **Development**: `gcom`, `gpush`, `gnew`, `serve`
- **System Utilities**: `ports`, `processes`, `diskusage`
- **1Password Integration**: `op-signin`, `op-get`, account switching
- **Network Tools**: `localip`, `publicip`, `speedtest`

#### 05-completion.zsh - Enhanced Completion
```bash
# Modern completion system
autoload -Uz compinit
compinit -d ~/.cache/zsh/.zcompdump-$ZSH_VERSION

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
```

**Features:**
- Fuzzy matching with smart case handling
- Menu-driven selection interface
- Git completion with branch/tag awareness
- Command history integration
- Custom completion for development tools

#### 06-prompt.zsh - Oh My Zsh Integration
```bash
# Spaceship prompt configuration
SPACESHIP_PROMPT_ORDER=(
    time dir git package node docker kubectl exit_code line_sep char
)
SPACESHIP_TIME_SHOW=true
SPACESHIP_DIR_TRUNC=3
```

**Prompt features:**
- **Git Integration**: Branch, status, staged files
- **Development Context**: Node.js, Python, Go versions
- **Container Status**: Docker, Kubernetes context
- **Performance**: Sub-50ms prompt generation
- **Customization**: Configurable segments and colors

### Platform-Specific Configurations

#### macOS Optimizations
```bash
# Homebrew integration
if [[ -d "/opt/homebrew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# macOS-specific aliases
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false"
```

#### Linux Adaptations
```bash
# Package manager detection
if command -v apt >/dev/null; then
    alias install='sudo apt install'
    alias update='sudo apt update && sudo apt upgrade'
elif command -v dnf >/dev/null; then
    alias install='sudo dnf install'
    alias update='sudo dnf upgrade'
fi
```

## Customization

### Local Overrides

Create machine-specific customizations without modifying core configuration:

#### Personal Aliases
```bash
# ~/.config/shell/aliases.local
alias myproject="cd ~/code/myproject && code ."
alias backup-home="rsync -av ~ /backup/drive/"
alias work-vpn="sudo openconnect work.company.com"
```

#### Custom Functions
```bash
# ~/.config/shell/functions.local
# Quick project switcher
proj() {
    local project_dir="$HOME/code/$1"
    if [[ -d "$project_dir" ]]; then
        cd "$project_dir" && code .
    else
        echo "Project $1 not found"
    fi
}

# Environment-specific git config
work-mode() {
    git config user.email "you@company.com"
    git config user.name "Your Name (Work)"
}
```

#### Environment Variables
```bash
# ~/.config/shell/env.local
export MY_API_KEY="{{ op://Personal/API Keys/service_key }}"
export CUSTOM_PATH="/opt/custom/bin"
export WORK_CONFIG="$HOME/.config/work"
```

### Profile-Based Configuration

#### Work Profile
```yaml
# ~/.config/dotfiles/profiles/work.yml
shell:
  aliases:
    vpn: "sudo openconnect work-vpn.company.com"
    deploy: "kubectl apply -f k8s/"
    logs: "kubectl logs -f deployment/app"
  functions:
    work-ssh: "ssh work-server.company.com"
  environment:
    KUBECONFIG: "{{ op://Work/Kubernetes/config }}"
    AWS_PROFILE: "work"
```

#### Personal Profile
```yaml
# ~/.config/dotfiles/profiles/personal.yml
shell:
  aliases:
    homelab: "ssh homelab.local"
    backup: "rsync -av ~ /backup/"
    photos: "cd ~/Pictures && open ."
  environment:
    PERSONAL_CLOUD: "{{ op://Personal/Cloud/endpoint }}"
```

### Oh My Zsh Customization

#### Theme Configuration
```bash
# Override in ~/.config/shell/prompt.local
ZSH_THEME="powerlevel10k/powerlevel10k"

# Spaceship customization
SPACESHIP_PROMPT_ORDER=(
    user host dir git docker kubernetes aws time line_sep char
)
SPACESHIP_DOCKER_SHOW=true
SPACESHIP_KUBECTL_SHOW=true
```

#### Plugin Management
```bash
# Add plugins in ~/.config/shell/plugins.local
plugins=(
    git
    docker
    kubectl
    terraform
    aws
    zsh-autosuggestions
    zsh-syntax-highlighting
)
```

## Performance Optimization

### Startup Performance Analysis

The shell configuration achieves sub-500ms startup through several optimization strategies:

#### Conditional Loading
```bash
# Only load when tools are available
if command -v docker >/dev/null; then
    source "$ZSH_HOME/modules/docker.zsh"
fi

# Lazy loading for expensive operations
pyenv() {
    unfunction pyenv
    eval "$(command pyenv init -)"
    pyenv "$@"
}
```

#### Caching Strategies
```bash
# Cache expensive operations
if [[ ! -f ~/.cache/zsh/uname ]]; then
    uname -s > ~/.cache/zsh/uname
fi
OS_TYPE=$(cat ~/.cache/zsh/uname)

# Completion cache management
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit -d ~/.cache/zsh/.zcompdump-$ZSH_VERSION
else
    compinit -C -d ~/.cache/zsh/.zcompdump-$ZSH_VERSION
fi
```

### Performance Benchmarking

```bash
# Built-in timing
time zsh -i -c exit

# Detailed profiling
zmodload zsh/zprof
# ... shell startup
zprof
```

**Target metrics:**
- **Cold startup**: <500ms
- **Warm startup**: <200ms  
- **Command completion**: <50ms
- **Prompt generation**: <30ms

### Optimization Techniques

#### Module Optimization
```bash
# Use parameter expansion over subshells
${parameter:-default}        # Instead of $(echo ${parameter:-default})

# Avoid repeated external commands
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

# Cache directory checks
typeset -gA _dir_cache
check_dir() {
    [[ -n $_dir_cache[$1] ]] && return $_dir_cache[$1]
    [[ -d $1 ]]
    _dir_cache[$1]=$?
    return $?
}
```

#### History Optimization
```bash
# Optimized history settings
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.cache/zsh/.zsh_history

# Efficient history options
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
```

## Cross-Platform Support

### Platform Detection
```bash
# Efficient OS detection
case "$(uname -s)" in
    Darwin*)
        OS_TYPE="macos"
        BREW_PREFIX="/opt/homebrew"
        ;;
    Linux*)
        OS_TYPE="linux"
        if command -v apt >/dev/null; then
            DISTRO="debian"
        elif command -v dnf >/dev/null; then
            DISTRO="fedora"
        fi
        ;;
    CYGWIN*|MINGW*|MSYS*)
        OS_TYPE="windows"
        ;;
esac
```

### Platform-Specific Features

#### macOS Features
```bash
# Homebrew integration
[[ -f "$BREW_PREFIX/bin/brew" ]] && eval "$($BREW_PREFIX/bin/brew shellenv)"

# macOS-specific utilities
alias flushdns="sudo dscacheutil -flushcache"
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES"
alias airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
```

#### Linux Features
```bash
# Distribution-specific package management
case "$DISTRO" in
    debian)
        alias install="sudo apt install"
        alias search="apt search"
        ;;
    fedora)
        alias install="sudo dnf install"
        alias search="dnf search"
        ;;
    arch)
        alias install="sudo pacman -S"
        alias search="pacman -Ss"
        ;;
esac

# Linux-specific utilities
alias pbcopy="xclip -selection clipboard"
alias pbpaste="xclip -selection clipboard -o"
```

## Troubleshooting

### Common Issues

#### Slow Startup
```bash
# Profile startup time
zmodload zsh/zprof
# Open new shell
zprof | head -20

# Common culprits:
# - Oh My Zsh plugins
# - nvm/pyenv/rbenv without lazy loading
# - Network-dependent initialization
```

**Solutions:**
- Enable lazy loading for version managers
- Reduce Oh My Zsh plugins
- Cache expensive operations
- Use conditional loading

#### Completion Issues
```bash
# Rebuild completion cache
rm ~/.cache/zsh/.zcompdump*
autoload -Uz compinit && compinit

# Check completion function
which _git
echo $fpath
```

#### PATH Problems
```bash
# Debug PATH construction
echo $PATH | tr ':' '\n' | nl

# Check for duplicates
typeset -U path
echo $path
```

#### Oh My Zsh Problems
```bash
# Check Oh My Zsh installation
echo $ZSH
ls -la $ZSH

# Verify theme
echo $ZSH_THEME
ls $ZSH/themes/

# Plugin debugging
echo ${(j:\n:)plugins}
```

### Debugging Tools

#### Shell Debugging
```bash
# Enable debug mode
set -x
source ~/.zshrc
set +x

# Function tracing
setopt XTRACE
# ... operations
unsetopt XTRACE
```

#### Performance Debugging
```bash
# Startup profiling script
#!/bin/zsh
for i in {1..10}; do
    time zsh -i -c exit
done 2>&1 | grep real | awk '{print $2}' | sort -n
```

#### Configuration Validation
```bash
# Validate configuration
./shell/zsh/test-config.sh

# Check for errors
zsh -n ~/.zshrc
```

## Migration Guide

### From Bash
```bash
# Backup existing configuration
cp ~/.bashrc ~/.bashrc.backup
cp ~/.bash_profile ~/.bash_profile.backup

# Install zsh configuration
./scripts/migrate-zsh.sh --from-bash

# Manual migration steps for custom configurations
```

### From Default Zsh
```bash
# Backup current zsh config
cp ~/.zshrc ~/.zshrc.backup

# Migrate custom functions and aliases
grep "^alias\|^function\|^export" ~/.zshrc.backup > ~/.config/shell/personal.zsh
```

### From Oh My Zsh
```bash
# Migration preserves existing Oh My Zsh
./scripts/migrate-zsh.sh --preserve-oh-my-zsh

# Custom theme migration
cp ~/.oh-my-zsh/custom/themes/* ~/.config/shell/themes/
```

## Advanced Usage

### Custom Module Creation
```bash
# Create custom module
cat > ~/.config/shell/modules/20-custom.zsh << 'EOF'
# Custom development shortcuts

# Project navigation
cdp() { cd "$HOME/projects/$1" }

# Completion for projects
_cdp() {
    local projects
    projects=(${(f)"$(ls $HOME/projects)"})
    _describe 'projects' projects
}
compdef _cdp cdp
EOF
```

### Secret Integration
```bash
# Template-based secret injection
cat > ~/.config/shell/env.template << 'EOF'
export GITHUB_TOKEN="{{ op://Personal/GitHub/token }}"
export AWS_ACCESS_KEY_ID="{{ op://Work/AWS/access_key }}"
export DATABASE_URL="{{ op://Work/Database/url }}"
EOF

# Inject secrets
./scripts/inject-secrets.sh ~/.config/shell/env.template
source ~/.config/shell/env
```

### Team Configuration Sharing
```bash
# Team-specific configuration
cat > ~/.config/dotfiles/team.yml << 'EOF'
shell:
  aliases:
    deploy: "kubectl apply -f manifests/"
    staging: "kubectl config use-context staging"
    prod: "kubectl config use-context production"
  functions:
    team-setup: |
      git clone team-repo.git
      cd team-repo && ./setup.sh
EOF

# Apply team configuration
dotfiles apply-profile team
```

## Reference

### Key Files and Directories

| Path | Purpose |
|------|---------|
| `shell/zsh/.zshrc` | Main configuration loader |
| `shell/zsh/modules/` | Core functionality modules |
| `shell/zsh/local/` | Machine-specific overrides |
| `shell/zsh/templates/` | Secret injection templates |
| `~/.config/shell/` | Local customizations |

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SHELL_STARTUP_TIME` | Startup performance metric | Measured |
| `ZSH_HOME` | Zsh configuration directory | `$XDG_CONFIG_HOME/zsh` |
| `ZSH_CACHE_DIR` | Cache directory | `~/.cache/zsh` |
| `DOTFILES_SHELL_PROFILE` | Active profile | `default` |

### Available Commands

#### Configuration Management
```bash
dotfiles shell reload      # Reload configuration
dotfiles shell profile     # Show active profile  
dotfiles shell benchmark   # Performance testing
dotfiles shell validate    # Configuration validation
```

#### Maintenance
```bash
shell-update               # Update Oh My Zsh and plugins
shell-cleanup             # Clean caches and temp files
shell-backup              # Backup current configuration
shell-restore             # Restore from backup
```

### Plugin Ecosystem

#### Recommended Plugins
- `zsh-autosuggestions`: Command suggestions based on history
- `zsh-syntax-highlighting`: Real-time syntax highlighting
- `fzf`: Fuzzy finder integration
- `z`: Smart directory jumping

#### Installation
```bash
# Via Oh My Zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Add to plugins in ~/.config/shell/plugins.local
plugins=(... zsh-autosuggestions)
```

### Performance Targets

| Metric | Target | Typical |
|--------|--------|---------|
| Cold startup | <500ms | ~300ms |
| Warm startup | <200ms | ~150ms |
| Tab completion | <50ms | ~20ms |
| Prompt generation | <30ms | ~15ms |
| Command execution overhead | <5ms | ~2ms |

This shell configuration system provides a robust, performant, and highly customizable foundation for your command-line workflow. The modular architecture ensures maintainability while delivering enterprise-grade performance and security. 