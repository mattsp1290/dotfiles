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
