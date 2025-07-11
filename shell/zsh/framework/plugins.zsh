# Framework Plugin Management
# Optimized plugin loading with lazy loading and categorization

# Plugin loading utilities
source "${ZSH_FRAMEWORK_DIR:-$(dirname $0)}/config/plugin-utils.zsh" 2>/dev/null || {
    # Inline plugin utilities if separate file doesn't exist
    
    # Lazy loading function
    lazy_load() {
        local cmd="$1"
        local init_cmd="$2"
        
        # Create a wrapper function with error handling
        eval "$cmd() {
            unfunction $cmd 2>/dev/null
            if ! eval \"$init_cmd\" 2>/dev/null; then
                echo \"Warning: Failed to initialize $cmd\" >&2
            fi
            command $cmd \"\$@\"
        }" 2>/dev/null || echo "Warning: Failed to create lazy loader for $cmd" >&2
    }
    
    # Plugin availability check
    plugin_available() {
        local cmd="$1"
        command -v "$cmd" >/dev/null 2>&1
    }
    
    # Conditional loading
    load_if_available() {
        local cmd="$1"
        local init_cmd="$2"
        local lazy="${3:-false}"
        
        if plugin_available "$cmd"; then
            if [[ "$lazy" == "true" ]]; then
                lazy_load "$cmd" "$init_cmd"
            else
                if ! eval "$init_cmd" 2>/dev/null; then
                    echo "Warning: Failed to initialize $cmd" >&2
                fi
            fi
        fi
    }
}

# Oh My Zsh Plugin Configuration
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    # Essential plugins only (performance focused)
    OMZ_ESSENTIAL_PLUGINS=(
        git                    # Git aliases and functions
        colored-man-pages     # Colored man pages
        command-not-found     # Suggest packages for missing commands
    )
    
    # Conditional plugins (only if tools are available)
    plugin_available "docker" && OMZ_ESSENTIAL_PLUGINS+=(docker)
    plugin_available "kubectl" && OMZ_ESSENTIAL_PLUGINS+=(kubectl)
    plugin_available "terraform" && OMZ_ESSENTIAL_PLUGINS+=(terraform)
    
    # Optional plugins (loaded on demand)
    OMZ_OPTIONAL_PLUGINS=(
        aws                   # AWS CLI completion
        gcloud               # Google Cloud CLI completion
        azure                # Azure CLI completion
        helm                 # Helm completion
        pip                  # Python pip completion
        npm                  # NPM completion
        yarn                 # Yarn completion
        cargo                # Rust cargo completion
        golang               # Go development helpers
        python               # Python development helpers
        node                 # Node.js development helpers
        ruby                 # Ruby development helpers
        rust                 # Rust development helpers
        vagrant              # Vagrant completion
        ansible              # Ansible completion
    )
    
    # Set plugins for Oh My Zsh (only essential ones)
    plugins=($OMZ_ESSENTIAL_PLUGINS)
    
    # Function to load optional plugins on demand
    load_omz_plugin() {
        local plugin="$1"
        if [[ " ${OMZ_OPTIONAL_PLUGINS[*]} " =~ " ${plugin} " ]]; then
            plugins+=($plugin)
            # Reload Oh My Zsh with new plugin
            source "$ZSH/oh-my-zsh.sh"
        else
            echo "Plugin '$plugin' not available in optional list"
            echo "Available plugins: ${OMZ_OPTIONAL_PLUGINS[*]}"
        fi
    }
fi

# External Plugin Management (Outside Oh My Zsh)

# Zsh Autosuggestions (performance optimized)
if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    # Performance optimizations
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
    ZSH_AUTOSUGGEST_USE_ASYNC=true
elif [[ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
    ZSH_AUTOSUGGEST_USE_ASYNC=true
fi

# Zsh Syntax Highlighting (load last, with performance optimizations)
if [[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    # Performance optimizations
    ZSH_HIGHLIGHT_MAXLENGTH=300
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
elif [[ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    ZSH_HIGHLIGHT_MAXLENGTH=300
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
fi

# Tool Integration (Lazy Loaded)

# Direnv (essential, but can be lazy loaded)
load_if_available "direnv" 'eval "$(direnv hook zsh)"' true

# Modern CLI tools (lazy loaded for first use)
load_if_available "zoxide" 'eval "$(zoxide init zsh)"; alias cd="z"' true
load_if_available "atuin" 'eval "$(atuin init zsh)"' true
load_if_available "mcfly" 'eval "$(mcfly init zsh)"' true
load_if_available "starship" 'eval "$(starship init zsh)"' true

# Development tools (lazy loaded)
load_if_available "gh" 'eval "$(gh completion -s zsh)"' true
load_if_available "glab" 'eval "$(glab completion -s zsh)"' true
load_if_available "helm" 'source <(helm completion zsh)' true

# Fun tools (lazy loaded)
load_if_available "thefuck" 'eval "$(thefuck --alias)"' true

# Version Managers (Lazy Loaded - Major Performance Improvement)
# These are the biggest performance killers, so we lazy load them
# NOTE: pyenv, rbenv, nodenv are handled in the path module with proper error handling

# ASDF (if available, lazy load)
if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    lazy_load "asdf" 'source "$HOME/.asdf/asdf.sh"'
    # Also create lazy aliases for common language commands
    for lang in node npm npx python python3 pip pip3 ruby gem bundle go rust cargo; do
        lazy_load "$lang" 'source "$HOME/.asdf/asdf.sh"'
    done
fi

# Cloud CLI Completions (Lazy Loaded)
# These are also performance killers

# AWS CLI (lazy loaded)
if command -v aws >/dev/null 2>&1; then
    aws() {
        unfunction aws 2>/dev/null
        # Load completion only when needed
        autoload bashcompinit && bashcompinit
        complete -C aws_completer aws
        aws "$@"
    }
fi

# Google Cloud CLI (lazy loaded)
if command -v gcloud >/dev/null 2>&1; then
    gcloud() {
        unfunction gcloud 2>/dev/null
        # Load completion only when needed
        if [[ -f "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc" ]]; then
            source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
        fi
        gcloud "$@"
    }
fi

# Kubernetes tools (lazy loaded)
if command -v kubectl >/dev/null 2>&1; then
    kubectl() {
        unfunction kubectl 2>/dev/null
        source <(kubectl completion zsh)
        compdef __start_kubectl k
        kubectl "$@"
    }
    # Alias for k
    alias k='kubectl'
fi

# HashiCorp tools (lazy loaded with error handling)
for tool in vault consul nomad packer; do
    if command -v "$tool" >/dev/null 2>&1; then
        eval "$tool() {
            unfunction $tool 2>/dev/null
            autoload -U +X bashcompinit && bashcompinit
            complete -o nospace -C $tool $tool
            command $tool \"\$@\"
        }" 2>/dev/null || echo "Warning: Failed to create lazy loader for $tool" >&2
    fi
done

# Language-specific package managers (lazy loaded)
load_if_available "poetry" 'source <(poetry completions zsh)' true
load_if_available "pipenv" 'eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"' true

# Container tools (lazy loaded)
load_if_available "podman" 'source <(podman completion zsh)' true

# FZF Integration (lazy loaded for key bindings)
if command -v fzf >/dev/null 2>&1; then
    # Load completion immediately (it's fast)
    if [[ "$OS_TYPE" == "macos" && -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
    elif [[ -f "/usr/share/fzf/completion.zsh" ]]; then
        source "/usr/share/fzf/completion.zsh"
    fi
    
    # Lazy load key bindings (they can be slower)
    fzf_keybindings() {
        unfunction fzf_keybindings 2>/dev/null
        if [[ "$OS_TYPE" == "macos" && -f "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]]; then
            source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
        elif [[ -f "/usr/share/fzf/key-bindings.zsh" ]]; then
            source "/usr/share/fzf/key-bindings.zsh"
        fi
    }
    
    # Auto-load on first Ctrl+R, Ctrl+T, or Alt+C
    bindkey '^R' fzf_keybindings
    bindkey '^T' fzf_keybindings
    bindkey '^[c' fzf_keybindings
fi

# Plugin Management Commands

# List all available plugins
list_plugins() {
    echo "Oh My Zsh Essential Plugins (loaded):"
    printf "  %s\n" "${OMZ_ESSENTIAL_PLUGINS[@]}"
    echo ""
    echo "Oh My Zsh Optional Plugins (available):"
    printf "  %s\n" "${OMZ_OPTIONAL_PLUGINS[@]}"
    echo ""
    echo "External Plugins:"
    echo "  zsh-autosuggestions: $(plugin_available zsh-autosuggestions && echo "✓" || echo "✗")"
    echo "  zsh-syntax-highlighting: $(plugin_available zsh-syntax-highlighting && echo "✓" || echo "✗")"
}

# Show plugin status
plugin_status() {
    echo "Plugin Loading Status:"
    echo "  Oh My Zsh plugins: ${#plugins[@]} loaded"
    local lazy_count=$(functions 2>/dev/null | grep -c "unfunction" 2>/dev/null || echo "0")
    echo "  Lazy loaded functions: $lazy_count"
    echo ""
    echo "Performance mode: OPTIMIZED (lazy loading enabled)"
}

# Load a plugin on demand
load_plugin() {
    local plugin="$1"
    if [[ -z "$plugin" ]]; then
        echo "Usage: load_plugin <plugin_name>"
        return 1
    fi
    
    # Try loading as Oh My Zsh plugin first
    load_omz_plugin "$plugin"
}

# Export functions for use elsewhere (silenced to avoid startup output)
export -f list_plugins plugin_status load_plugin load_omz_plugin >/dev/null 2>&1

# Load custom plugins from dotfiles
if [[ -d "$DOTFILES_DIR/shell/zsh/framework/custom" ]]; then
    for plugin_file in "$DOTFILES_DIR/shell/zsh/framework/custom"/*.zsh; do
        [[ -r "$plugin_file" ]] && source "$plugin_file"
    done
fi 