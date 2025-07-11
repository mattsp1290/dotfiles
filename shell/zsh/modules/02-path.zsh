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

# pyenv (lazy loaded with error handling)
if command -v pyenv >/dev/null 2>&1; then
    python() {
        unfunction python 2>/dev/null
        local pyenv_init
        if pyenv_init=$(pyenv init - 2>/dev/null) && [[ -n "$pyenv_init" ]]; then
            eval "$pyenv_init" 2>/dev/null || echo "Warning: pyenv init failed" >&2
        fi
        command python "$@"
    }
    python3() {
        unfunction python3 2>/dev/null
        local pyenv_init
        if pyenv_init=$(pyenv init - 2>/dev/null) && [[ -n "$pyenv_init" ]]; then
            eval "$pyenv_init" 2>/dev/null || echo "Warning: pyenv init failed" >&2
        fi
        command python3 "$@"
    }
    pip() {
        unfunction pip 2>/dev/null
        local pyenv_init
        if pyenv_init=$(pyenv init - 2>/dev/null) && [[ -n "$pyenv_init" ]]; then
            eval "$pyenv_init" 2>/dev/null || echo "Warning: pyenv init failed" >&2
        fi
        command pip "$@"
    }
    pip3() {
        unfunction pip3 2>/dev/null
        local pyenv_init
        if pyenv_init=$(pyenv init - 2>/dev/null) && [[ -n "$pyenv_init" ]]; then
            eval "$pyenv_init" 2>/dev/null || echo "Warning: pyenv init failed" >&2
        fi
        command pip3 "$@"
    }
fi

# rbenv (lazy loaded with error handling)
if command -v rbenv >/dev/null 2>&1; then
    ruby() {
        unfunction ruby 2>/dev/null
        local rbenv_init
        if rbenv_init=$(rbenv init - zsh 2>/dev/null) && [[ -n "$rbenv_init" ]]; then
            eval "$rbenv_init" 2>/dev/null || echo "Warning: rbenv init failed" >&2
        fi
        command ruby "$@"
    }
    gem() {
        unfunction gem 2>/dev/null
        local rbenv_init
        if rbenv_init=$(rbenv init - zsh 2>/dev/null) && [[ -n "$rbenv_init" ]]; then
            eval "$rbenv_init" 2>/dev/null || echo "Warning: rbenv init failed" >&2
        fi
        command gem "$@"
    }
    bundle() {
        unfunction bundle 2>/dev/null
        local rbenv_init
        if rbenv_init=$(rbenv init - zsh 2>/dev/null) && [[ -n "$rbenv_init" ]]; then
            eval "$rbenv_init" 2>/dev/null || echo "Warning: rbenv init failed" >&2
        fi
        command bundle "$@"
    }
fi

# nodenv (lazy loaded with error handling)
if command -v nodenv >/dev/null 2>&1; then
    node() {
        unfunction node 2>/dev/null
        local nodenv_init
        if nodenv_init=$(nodenv init - 2>/dev/null) && [[ -n "$nodenv_init" ]]; then
            eval "$nodenv_init" 2>/dev/null || echo "Warning: nodenv init failed" >&2
        fi
        command node "$@"
    }
    npm() {
        unfunction npm 2>/dev/null
        local nodenv_init
        if nodenv_init=$(nodenv init - 2>/dev/null) && [[ -n "$nodenv_init" ]]; then
            eval "$nodenv_init" 2>/dev/null || echo "Warning: nodenv init failed" >&2
        fi
        command npm "$@"
    }
    npx() {
        unfunction npx 2>/dev/null
        local nodenv_init
        if nodenv_init=$(nodenv init - 2>/dev/null) && [[ -n "$nodenv_init" ]]; then
            eval "$nodenv_init" 2>/dev/null || echo "Warning: nodenv init failed" >&2
        fi
        command npx "$@"
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
