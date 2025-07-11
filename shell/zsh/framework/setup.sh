#!/usr/bin/env bash
# Framework Setup Script
# Integrates optimized framework configuration with existing shell setup

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ZSH_DIR="$DOTFILES_DIR/shell/zsh"
FRAMEWORK_DIR="$SCRIPT_DIR"

# Setup mode
SETUP_MODE="${1:-optimize}"
BACKUP_EXISTING="${BACKUP_EXISTING:-true}"
DRY_RUN="${DRY_RUN:-false}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Backup existing configuration
backup_existing_config() {
    if [[ "$BACKUP_EXISTING" != "true" ]]; then
        return 0
    fi
    
    local backup_dir="$ZSH_DIR/backup/$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup at: $backup_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup directory: $backup_dir"
        return 0
    fi
    
    mkdir -p "$backup_dir"
    
    # Backup existing modules that will be modified
    local modules_to_backup=(
        "06-prompt.zsh"
        "08-plugins.zsh"
        "05-completion.zsh"
        "02-path.zsh"
    )
    
    for module in "${modules_to_backup[@]}"; do
        local module_path="$ZSH_DIR/modules/$module"
        if [[ -f "$module_path" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would backup: $module"
            else
                cp "$module_path" "$backup_dir/"
                log_info "Backed up: $module"
            fi
        fi
    done
    
    log_success "Backup created successfully"
}

# Create optimized module replacements
create_optimized_modules() {
    log_info "Creating optimized module replacements..."
    
    # Create optimized plugins module
    create_optimized_plugins_module
    
    # Create optimized prompt module  
    create_optimized_prompt_module
    
    # Create optimized completion module
    create_optimized_completion_module
    
    # Create optimized path module
    create_optimized_path_module
}

# Create optimized plugins module
create_optimized_plugins_module() {
    local target_file="$ZSH_DIR/modules/08-plugins.zsh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create optimized plugins module: $target_file"
        return 0
    fi
    
    cat > "$target_file" << 'EOF'
# Optimized Plugins Module
# Performance-focused plugin loading with lazy loading

# Source the framework plugin configuration
if [[ -f "$DOTFILES_DIR/shell/zsh/framework/plugins.zsh" ]]; then
    source "$DOTFILES_DIR/shell/zsh/framework/plugins.zsh"
else
    # Fallback to basic plugin loading if framework not available
    log_warning "Framework plugins not found, using basic configuration"
    
    # Load basic external plugins
    if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
        ZSH_AUTOSUGGEST_USE_ASYNC=true
    fi
    
    if [[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        ZSH_HIGHLIGHT_MAXLENGTH=300
    fi
fi

# Performance monitoring (if enabled)
if [[ "${ZSH_FRAMEWORK_DEBUG:-false}" == "true" ]]; then
    echo "Plugins module loaded with framework optimization"
fi
EOF
    
    log_success "Created optimized plugins module"
}

# Create optimized prompt module
create_optimized_prompt_module() {
    local target_file="$ZSH_DIR/modules/06-prompt.zsh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create optimized prompt module: $target_file"
        return 0
    fi
    
    cat > "$target_file" << 'EOF'
# Optimized Prompt Module
# Performance-focused prompt configuration

# Source the framework theme configuration
if [[ -f "$DOTFILES_DIR/shell/zsh/framework/themes.zsh" ]]; then
    source "$DOTFILES_DIR/shell/zsh/framework/themes.zsh"
else
    # Fallback to basic Oh My Zsh configuration
    log_warning "Framework themes not found, using basic Oh My Zsh configuration"
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        export ZSH="$HOME/.oh-my-zsh"
        
        # Use optimized Spaceship configuration
        ZSH_THEME="spaceship"
        SPACESHIP_PROMPT_ASYNC=true  # CRITICAL for performance
        SPACESHIP_PROMPT_ORDER=(
            time
            dir
            git
            char
        )
        
        # Disable expensive components
        SPACESHIP_KUBECTL_SHOW=false
        SPACESHIP_DOCKER_SHOW=false
        SPACESHIP_AWS_SHOW=false
        SPACESHIP_NODE_SHOW=false
        SPACESHIP_PYTHON_SHOW=false
        
        # Basic plugins
        plugins=(git)
        
        # Load Oh My Zsh
        [[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
    else
        # Minimal fallback prompt
        autoload -Uz vcs_info
        precmd() { vcs_info }
        zstyle ':vcs_info:git:*' formats ' %F{red}%b%f'
        setopt PROMPT_SUBST
        PROMPT='%F{blue}%n@%m%f:%F{cyan}%~%f${vcs_info_msg_0_} %F{green}%#%f '
    fi
fi

# Terminal title
case $TERM in
    xterm*|rxvt*|screen*|tmux*)
        precmd_functions+=(set_terminal_title)
        set_terminal_title() {
            print -Pn "\e]0;%n@%m: %~\a"
        }
        ;;
esac
EOF
    
    log_success "Created optimized prompt module"
}

# Create optimized completion module
create_optimized_completion_module() {
    local target_file="$ZSH_DIR/modules/05-completion.zsh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create optimized completion module: $target_file"
        return 0
    fi
    
    cat > "$target_file" << 'EOF'
# Optimized Completion Module
# Performance-focused completion system with lazy loading

# Initialize completion system (optimized)
autoload -Uz compinit

# Performance: only rebuild completion cache once per day
local compdump="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/.zcompdump"
if [[ -n ${compdump}(#qN.mh+24) ]]; then
    compinit -d "$compdump"
else
    compinit -C -d "$compdump"
fi

# Load additional completions
if [[ -d "$DOTFILES_DIR/shell/zsh/completions" ]]; then
    fpath=("$DOTFILES_DIR/shell/zsh/completions" $fpath)
fi

# Basic completion styling (essential only)
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' special-dirs true

# Enable completion caching
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Ensure cache directory exists
[[ ! -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh" ]] && mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Homebrew completion (macOS) - load immediately as it's fast
if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
    if [[ -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]]; then
        fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
    fi
fi

# LAZY LOADING for expensive completions
# These functions will load completions only when the command is first used

# Kubernetes completion (lazy loaded)
if command -v kubectl >/dev/null 2>&1; then
    kubectl() {
        unfunction kubectl 2>/dev/null
        source <(kubectl completion zsh)
        compdef __start_kubectl k
        kubectl "$@"
    }
    alias k='kubectl'
fi

# AWS CLI completion (lazy loaded)
if command -v aws >/dev/null 2>&1; then
    aws() {
        unfunction aws 2>/dev/null
        autoload bashcompinit && bashcompinit
        complete -C aws_completer aws
        aws "$@"
    }
fi

# Terraform completion (lazy loaded)
if command -v terraform >/dev/null 2>&1; then
    terraform() {
        unfunction terraform 2>/dev/null
        autoload -U +X bashcompinit && bashcompinit
        complete -o nospace -C terraform terraform
        terraform "$@"
    }
    alias tf='terraform'
fi

# FZF completion (load immediately as it's fast)
if command -v fzf >/dev/null 2>&1; then
    if [[ "$OS_TYPE" == "macos" && -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
    elif [[ -f "/usr/share/fzf/completion.zsh" ]]; then
        source "/usr/share/fzf/completion.zsh"
    fi
fi

# Note: Version managers (pyenv, rbenv, nodenv) are handled in the path module
# with lazy loading to avoid startup performance impact
EOF
    
    log_success "Created optimized completion module"
}

# Create optimized path module
create_optimized_path_module() {
    local target_file="$ZSH_DIR/modules/02-path.zsh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create optimized path module: $target_file"
        return 0
    fi
    
    cat > "$target_file" << 'EOF'
# Optimized PATH Management Module
# Performance-focused PATH configuration with lazy loading for version managers

# Function to safely add to PATH (avoids duplicates)
path_prepend() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
}

path_append() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ ":$PATH:" != *":$dir:"* ]] && PATH="$PATH:$dir"
}

# Local user binaries (highest priority)
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"

# Homebrew paths (macOS)
if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
    path_prepend "$HOMEBREW_PREFIX/bin"
    path_prepend "$HOMEBREW_PREFIX/sbin"
    
    # GNU coreutils (prefer over macOS versions)
    path_prepend "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin"
    path_prepend "$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin"
    path_prepend "$HOMEBREW_PREFIX/opt/gnu-tar/libexec/gnubin"
    path_prepend "$HOMEBREW_PREFIX/opt/grep/libexec/gnubin"
    path_prepend "$HOMEBREW_PREFIX/opt/findutils/libexec/gnubin"
    
    # Other Homebrew tools
    path_prepend "$HOMEBREW_PREFIX/opt/curl/bin"
    path_prepend "$HOMEBREW_PREFIX/opt/openssl@3/bin"
fi

# Programming language paths (static paths only)
# Go
if [[ -n "$GOPATH" ]]; then
    path_append "$GOPATH/bin"
fi

# Rust/Cargo
if [[ -n "$CARGO_HOME" ]]; then
    path_append "$CARGO_HOME/bin"
elif [[ -d "$HOME/.cargo/bin" ]]; then
    path_append "$HOME/.cargo/bin"
fi

# Python/pipx
path_append "$HOME/.local/bin"

# Node.js tools (static paths)
if [[ -d "$HOME/.volta" ]]; then
    export VOLTA_HOME="$HOME/.volta"
    path_append "$VOLTA_HOME/bin"
fi

if [[ -d "$HOME/.deno" ]]; then
    export DENO_INSTALL="$HOME/.deno"
    path_append "$DENO_INSTALL/bin"
fi

# Work-specific paths (Datadog)
if [[ -d "$HOME/dd/devtools/bin" ]]; then
    export DATADOG_ROOT="$HOME/dd"
    path_append "$HOME/dd/devtools/bin"
    export MOUNT_ALL_GO_SRC=1
fi

# Cloud tools (static paths only)
# AWS CLI
if [[ "$OS_TYPE" == "macos" ]]; then
    path_append "$HOMEBREW_PREFIX/opt/awscli@1/bin"
fi

# Specific tool versions (static)
if [[ -d "$HOMEBREW_PREFIX/opt/go@1.21/bin" ]]; then
    path_prepend "$HOMEBREW_PREFIX/opt/go@1.21/bin"
fi

# LAZY LOADING for version managers (MAJOR PERFORMANCE IMPROVEMENT)
# These are the biggest performance killers during shell startup

# ASDF (lazy loaded)
if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    # Create wrapper functions for common commands
    for cmd in asdf node npm npx python python3 pip pip3 ruby gem bundle go rust cargo; do
        eval "$cmd() {
            unset -f asdf node npm npx python python3 pip pip3 ruby gem bundle go rust cargo 2>/dev/null
            source \"\$HOME/.asdf/asdf.sh\"
            $cmd \"\$@\"
        }"
    done
fi

# pyenv (lazy loaded - avoids expensive eval call)
if command -v pyenv >/dev/null 2>&1; then
    python() {
        unfunction python 2>/dev/null
        eval "$(pyenv init -)"
        python "$@"
    }
    python3() {
        unfunction python3 2>/dev/null
        eval "$(pyenv init -)"
        python3 "$@"
    }
    pip() {
        unfunction pip 2>/dev/null
        eval "$(pyenv init -)"
        pip "$@"
    }
    pip3() {
        unfunction pip3 2>/dev/null
        eval "$(pyenv init -)"
        pip3 "$@"
    }
fi

# rbenv (lazy loaded)
if command -v rbenv >/dev/null 2>&1; then
    ruby() {
        unfunction ruby 2>/dev/null
        eval "$(rbenv init - zsh)"
        ruby "$@"
    }
    gem() {
        unfunction gem 2>/dev/null
        eval "$(rbenv init - zsh)"
        gem "$@"
    }
    bundle() {
        unfunction bundle 2>/dev/null
        eval "$(rbenv init - zsh)"
        bundle "$@"
    }
fi

# nodenv (lazy loaded)
if command -v nodenv >/dev/null 2>&1; then
    node() {
        unfunction node 2>/dev/null
        eval "$(nodenv init -)"
        node "$@"
    }
    npm() {
        unfunction npm 2>/dev/null
        eval "$(nodenv init -)"
        npm "$@"
    }
    npx() {
        unfunction npx 2>/dev/null
        eval "$(nodenv init -)"
        npx "$@"
    }
fi

# Google Cloud SDK (lazy loaded for completion)
if [[ -d "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk" ]]; then
    GCLOUD_SDK_PATH="/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk"
    path_append "$GCLOUD_SDK_PATH/bin"
    
    # Lazy load completion files (they're expensive)
    gcloud() {
        unfunction gcloud 2>/dev/null
        [[ -f "$GCLOUD_SDK_PATH/completion.zsh.inc" ]] && source "$GCLOUD_SDK_PATH/completion.zsh.inc"
        gcloud "$@"
    }
fi

# Clean up functions
unset -f path_prepend path_append

# Export the final PATH
export PATH

# Performance note: Version managers are now lazy loaded!
# This should significantly improve shell startup time.
EOF
    
    log_success "Created optimized path module"
}

# Test the optimized configuration
test_optimized_config() {
    log_info "Testing optimized configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would test optimized configuration"
        return 0
    fi
    
    # Source the optimized modules to test for syntax errors
    local test_modules=(
        "$ZSH_DIR/modules/08-plugins.zsh"
        "$ZSH_DIR/modules/06-prompt.zsh" 
        "$ZSH_DIR/modules/05-completion.zsh"
        "$ZSH_DIR/modules/02-path.zsh"
    )
    
    for module in "${test_modules[@]}"; do
        if [[ -f "$module" ]]; then
            if zsh -n "$module" 2>/dev/null; then
                log_success "✓ $(basename "$module") - syntax OK"
            else
                log_error "✗ $(basename "$module") - syntax error"
                return 1
            fi
        else
            log_warning "Module not found: $module"
        fi
    done
    
    log_success "All modules passed syntax check"
}

# Show usage information
show_usage() {
    cat << EOF
Framework Setup Script

USAGE:
    $0 [mode] [options]

MODES:
    optimize    Apply performance optimizations (default)
    backup      Create backup only
    test        Test configuration syntax
    restore     Restore from backup
    help        Show this help

OPTIONS:
    DRY_RUN=true           Show what would be done
    BACKUP_EXISTING=false  Skip backup creation
    
EXAMPLES:
    # Apply optimizations with backup
    $0 optimize
    
    # Dry run to see what would change
    DRY_RUN=true $0 optimize
    
    # Create backup only
    $0 backup
    
    # Test syntax without changes
    $0 test

EOF
}

# Restore from backup
restore_from_backup() {
    log_info "Looking for backups..."
    
    local backup_base="$ZSH_DIR/backup"
    if [[ ! -d "$backup_base" ]]; then
        log_error "No backup directory found: $backup_base"
        return 1
    fi
    
    local latest_backup=$(find "$backup_base" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
    if [[ -z "$latest_backup" ]]; then
        log_error "No backups found in: $backup_base"
        return 1
    fi
    
    log_info "Latest backup: $(basename "$latest_backup")"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would restore from: $latest_backup"
        return 0
    fi
    
    # Restore modules
    for backup_file in "$latest_backup"/*.zsh; do
        if [[ -f "$backup_file" ]]; then
            local module_name=$(basename "$backup_file")
            local target_file="$ZSH_DIR/modules/$module_name"
            
            cp "$backup_file" "$target_file"
            log_success "Restored: $module_name"
        fi
    done
    
    log_success "Restore completed from: $(basename "$latest_backup")"
}

# Main execution
main() {
    case "$SETUP_MODE" in
        "optimize")
            log_info "Setting up optimized framework configuration..."
            backup_existing_config
            create_optimized_modules
            test_optimized_config
            log_success "Framework optimization complete!"
            log_info "Restart your shell to see the performance improvements"
            ;;
        "backup")
            backup_existing_config
            ;;
        "test")
            test_optimized_config
            ;;
        "restore")
            restore_from_backup
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown mode: $SETUP_MODE"
            show_usage
            exit 1
            ;;
    esac
}

# Handle command line arguments and run
main "$@" 