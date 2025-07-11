# Optimized Completion Module - Bash Compatible
# Performance-focused completion system with lazy loading

# Enable bash completion
if ! shopt -oq posix; then
    # Source bash completion if available
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        source /etc/bash_completion
    elif [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
        # macOS with Homebrew
        if [[ -f "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
            source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
        fi
    fi
fi

# Load additional completions
if [[ -d "$DOTFILES_DIR/shell/bash/completion" ]]; then
    for completion_file in "$DOTFILES_DIR/shell/bash/completion"/*.bash; do
        [[ -r "$completion_file" ]] && source "$completion_file"
    done
fi

# Basic completion options
bind "set completion-ignore-case on"
bind "set completion-map-case on"
bind "set show-all-if-ambiguous on"
bind "set mark-symlinked-directories on"

# History completion
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Homebrew completion (macOS) - load immediately as it's fast
if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
    if [[ -d "$HOMEBREW_PREFIX/etc/bash_completion.d" ]]; then
        for completion in "$HOMEBREW_PREFIX/etc/bash_completion.d"/*; do
            [[ -r "$completion" ]] && source "$completion"
        done
    fi
fi

# LAZY LOADING for expensive completions
# These functions will load completions only when the command is first used

# Kubernetes completion (lazy loaded)
if command -v kubectl >/dev/null 2>&1; then
    _kubectl_completion_loaded=false
    
    kubectl() {
        if [[ "$_kubectl_completion_loaded" == "false" ]]; then
            source <(kubectl completion bash)
            complete -F __start_kubectl k
            _kubectl_completion_loaded=true
        fi
        command kubectl "$@"
    }
    
    k() {
        if [[ "$_kubectl_completion_loaded" == "false" ]]; then
            source <(kubectl completion bash)
            complete -F __start_kubectl k
            _kubectl_completion_loaded=true
        fi
        command kubectl "$@"
    }
fi

# AWS CLI completion (lazy loaded)
if command -v aws >/dev/null 2>&1; then
    _aws_completion_loaded=false
    
    aws() {
        if [[ "$_aws_completion_loaded" == "false" ]]; then
            complete -C aws_completer aws
            _aws_completion_loaded=true
        fi
        command aws "$@"
    }
fi

# Terraform completion (lazy loaded)
if command -v terraform >/dev/null 2>&1; then
    _terraform_completion_loaded=false
    
    terraform() {
        if [[ "$_terraform_completion_loaded" == "false" ]]; then
            complete -C terraform terraform
            _terraform_completion_loaded=true
        fi
        command terraform "$@"
    }
    
    tf() {
        if [[ "$_terraform_completion_loaded" == "false" ]]; then
            complete -C terraform terraform
            complete -C terraform tf
            _terraform_completion_loaded=true
        fi
        command terraform "$@"
    }
fi

# Docker completion (lazy loaded)
if command -v docker >/dev/null 2>&1; then
    _docker_completion_loaded=false
    
    docker() {
        if [[ "$_docker_completion_loaded" == "false" ]] && [[ -f /usr/share/bash-completion/completions/docker ]]; then
            source /usr/share/bash-completion/completions/docker
            _docker_completion_loaded=true
        elif [[ "$_docker_completion_loaded" == "false" ]] && [[ "$OS_TYPE" == "macos" && -f "$HOMEBREW_PREFIX/etc/bash_completion.d/docker" ]]; then
            source "$HOMEBREW_PREFIX/etc/bash_completion.d/docker"
            _docker_completion_loaded=true
        fi
        command docker "$@"
    }
fi

# Git completion (usually loaded by default, but ensure it's available)
if [[ "$OS_TYPE" == "macos" && -n "$HOMEBREW_PREFIX" ]]; then
    if [[ -f "$HOMEBREW_PREFIX/etc/bash_completion.d/git-completion.bash" ]]; then
        source "$HOMEBREW_PREFIX/etc/bash_completion.d/git-completion.bash"
    fi
fi

# FZF completion (load immediately as it's fast)
if command -v fzf >/dev/null 2>&1; then
    if [[ "$OS_TYPE" == "macos" && -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.bash" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.bash"
    elif [[ -f "/usr/share/bash-completion/completions/fzf" ]]; then
        source "/usr/share/bash-completion/completions/fzf"
    elif [[ -f "/usr/share/fzf/completion.bash" ]]; then
        source "/usr/share/fzf/completion.bash"
    fi
fi

# Note: Version managers (pyenv, rbenv, nodenv) are handled in the path module
# with lazy loading to avoid startup performance impact 