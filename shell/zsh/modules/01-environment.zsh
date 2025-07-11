# Environment Variables Module
# Configuration for various tools and applications

# Source profile if it exists (compatibility with bash)
[[ -f "$HOME/.profile" ]] && source "$HOME/.profile"

# Only load utilities if explicitly requested (for performance)
# Use: LOAD_DOTFILES_UTILS=1 zsh to enable
if [[ "$LOAD_DOTFILES_UTILS" == "1" ]] && [[ -f "$DOTFILES_DIR/scripts/lib/utils.sh" ]]; then
    source "$DOTFILES_DIR/scripts/lib/utils.sh"
fi

# Detect operating system (simplified version for performance)
if [[ -f "$DOTFILES_DIR/scripts/lib/detect-os.sh" ]] && [[ "$LOAD_DOTFILES_UTILS" == "1" ]]; then
    source "$DOTFILES_DIR/scripts/lib/detect-os.sh" 2>/dev/null
    
    # Try to use the functions, but fall back if they fail
    if command -v detect_os_type >/dev/null 2>&1; then
        export OS_TYPE="$(detect_os_type 2>/dev/null || echo 'unknown')"
        export OS_DISTRIBUTION="$(detect_linux_distribution 2>/dev/null || echo 'unknown')"
        export OS_VERSION="$(detect_os_version 2>/dev/null || echo 'unknown')"
        export OS_ARCH="$(detect_architecture 2>/dev/null || echo 'unknown')"
        export PACKAGE_MANAGER="$(detect_package_manager 2>/dev/null || echo 'unknown')"
    else
        # Fallback if functions aren't available
        case "$(uname -s)" in
            Darwin) export OS_TYPE="macos" ;;
            Linux)  export OS_TYPE="linux" ;;
            *)      export OS_TYPE="unknown" ;;
        esac
    fi
else
    # Fast OS detection without loading utilities
    case "$(uname -s)" in
        Darwin) export OS_TYPE="macos" ;;
        Linux)  export OS_TYPE="linux" ;;
        *)      export OS_TYPE="unknown" ;;
    esac
fi

# Homebrew configuration (macOS)
if [[ "$OS_TYPE" == "macos" ]]; then
    # Homebrew paths and security settings
    export HOMEBREW_NO_INSECURE_REDIRECT=1
    export HOMEBREW_CASK_OPTS="--require-sha"
    
    # Detect Homebrew installation
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        export HOMEBREW_PREFIX="/opt/homebrew"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        export HOMEBREW_PREFIX="/usr/local"
    fi
    
    if [[ -n "$HOMEBREW_PREFIX" ]]; then
        export HOMEBREW_DIR="$HOMEBREW_PREFIX"
        export HOMEBREW_BIN="$HOMEBREW_PREFIX/bin"
    fi
fi

# Development tools configuration
export GOPATH="${GOPATH:-$HOME/go}"
export GO111MODULE="${GO111MODULE:-auto}"
export GOPRIVATE="${GOPRIVATE:-github.com/DataDog}"

# Datadog-specific environment variables
if [[ -d "$HOME/dd" ]]; then
    export DATADOG_ROOT="$HOME/dd"
    export MOUNT_ALL_GO_SRC=1
fi

# Language-specific environment variables
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1
export PIP_REQUIRE_VIRTUALENV=true

# Node.js configuration
export NODE_ENV="${NODE_ENV:-development}"
export NPM_CONFIG_PROGRESS=false

# Volta (Node.js version manager)
if [[ -d "$HOME/.volta" ]]; then
    export VOLTA_HOME="$HOME/.volta"
fi

# Ruby configuration
export BUNDLE_USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/bundle"
export BUNDLE_USER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/bundle"
export BUNDLE_USER_PLUGIN="${XDG_DATA_HOME:-$HOME/.local/share}/bundle"

# Rust configuration
export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

# Docker configuration
export DOCKER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/docker"

# AWS configuration
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/aws/credentials"

# AWS Vault configuration
export AWS_VAULT_KEYCHAIN_NAME="login"
export AWS_SESSION_TTL="24h"
export AWS_ASSUME_ROLE_TTL="1h"

# Helm configuration
export HELM_DRIVER="configmap"

# GPG configuration
export GNUPGHOME="${XDG_DATA_HOME:-$HOME/.local/share}/gnupg"

# Tool-specific configurations
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/config"

# Terminal and display
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"

# Pager configuration
export MANPAGER="less -R"
export MANWIDTH=80

# Time zone (if not set by system)
export TZ="${TZ:-America/New_York}"

# 1Password CLI Integration
if [[ -f "$DOTFILES_DIR/scripts/op-env-detect.sh" ]]; then
    export OP_ACCOUNT_ALIAS=$("$DOTFILES_DIR/scripts/op-env-detect.sh" 2>/dev/null || echo "personal")
fi 