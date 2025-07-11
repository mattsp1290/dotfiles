# Framework Theme Configuration
# Optimized theme loading with performance enhancements

# Theme configuration variables
ZSH_FRAMEWORK_THEME="${ZSH_FRAMEWORK_THEME:-spaceship}"
ZSH_FRAMEWORK_ASYNC="${ZSH_FRAMEWORK_ASYNC:-true}"

# Performance monitoring
if [[ "${ZSH_FRAMEWORK_DEBUG:-false}" == "true" ]]; then
    zmodload zsh/datetime
    THEME_LOAD_START=$EPOCHREALTIME
fi

# Spaceship Theme Configuration (Performance Optimized)
configure_spaceship_theme() {
    ZSH_THEME="spaceship"
    
    # Performance optimizations
    SPACESHIP_PROMPT_ASYNC=true                    # Enable async rendering (CRITICAL)
    SPACESHIP_PROMPT_ADD_NEWLINE=true
    SPACESHIP_CHAR_SUFFIX=" "
    
    # Optimize prompt order (fastest components first)
    SPACESHIP_PROMPT_ORDER=(
        time          # Fast - just timestamp
        dir           # Fast - current directory
        git           # Medium - git status (async helps)
        char          # Fast - prompt character
    )
    
    # Disable expensive components by default (can be enabled per-project)
    SPACESHIP_KUBECTL_SHOW=false                   # Expensive
    SPACESHIP_KUBECTL_VERSION_SHOW=false
    SPACESHIP_TERRAFORM_SHOW=false                 # Expensive
    SPACESHIP_DOCKER_SHOW=false                    # Expensive
    SPACESHIP_DOCKER_CONTEXT_SHOW=false
    SPACESHIP_AWS_SHOW=false                       # Expensive
    SPACESHIP_GCLOUD_SHOW=false                    # Expensive
    SPACESHIP_AZURE_SHOW=false                     # Expensive
    
    # Optimize git display
    SPACESHIP_GIT_BRANCH_PREFIX="on "
    SPACESHIP_GIT_STATUS_STASHED=""
    SPACESHIP_GIT_STATUS_AHEAD="↑"
    SPACESHIP_GIT_STATUS_BEHIND="↓"
    SPACESHIP_GIT_STATUS_DIVERGED="↕"
    
    # Language version displays (disabled by default for performance)
    SPACESHIP_NODE_SHOW=false
    SPACESHIP_PYTHON_SHOW=false
    SPACESHIP_RUBY_SHOW=false
    SPACESHIP_GOLANG_SHOW=false
    SPACESHIP_RUST_SHOW=false
    SPACESHIP_PHP_SHOW=false
    SPACESHIP_JAVA_SHOW=false
    
    # Package manager displays (disabled)
    SPACESHIP_PACKAGE_SHOW=false
    SPACESHIP_NPM_SHOW=false
    SPACESHIP_YARN_SHOW=false
    
    # Environment displays (disabled)
    SPACESHIP_VENV_SHOW=false
    SPACESHIP_CONDA_SHOW=false
    # SPACESHIP_PYENV_SHOW=false  # Deprecated, using SPACESHIP_PYTHON_SHOW instead
    SPACESHIP_DOTNET_SHOW=false
    
    # Right prompt (keep it minimal)
    SPACESHIP_RPROMPT_ORDER=(
        exit_code     # Show exit code if non-zero
    )
    
    # Load Spaceship theme if available
    if [[ -f "$HOME/.zsh/spaceship/spaceship.zsh" ]]; then
        source "$HOME/.zsh/spaceship/spaceship.zsh"
    elif [[ -f "$HOME/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme" ]]; then
        # Custom installation path
        source "$HOME/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme"
    fi
}

# Spaceship helper functions
spaceship_enable_project_context() {
    # Enable components useful for development
    SPACESHIP_NODE_SHOW=true
    SPACESHIP_PYTHON_SHOW=true
    SPACESHIP_DOCKER_SHOW=true
    SPACESHIP_KUBECTL_SHOW=true
    
    # Update prompt order to include them
    SPACESHIP_PROMPT_ORDER=(
        time
        dir
        git
        node
        python
        docker
        kubectl
        char
    )
    
    echo "Spaceship: Enabled project context components"
}

spaceship_minimal_mode() {
    SPACESHIP_PROMPT_ORDER=(
        dir
        git
        char
    )
    
    # Disable all expensive components
    SPACESHIP_NODE_SHOW=false
    SPACESHIP_PYTHON_SHOW=false
    SPACESHIP_DOCKER_SHOW=false
    SPACESHIP_KUBECTL_SHOW=false
    SPACESHIP_AWS_SHOW=false
    SPACESHIP_GCLOUD_SHOW=false
    
    echo "Spaceship: Minimal mode enabled"
}

# Powerlevel10k Theme Configuration  
configure_p10k_theme() {
    ZSH_THEME="powerlevel10k/powerlevel10k"
    
    # Enable instant prompt (fastest startup)
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
        source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi
    
    # Load configuration if it exists
    [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
    
    echo "Note: Powerlevel10k provides excellent performance but requires configuration"
    echo "Run 'p10k configure' to set it up"
}

# Starship Theme Configuration (External)
configure_starship_theme() {
    # Disable Oh My Zsh theme when using Starship
    ZSH_THEME=""
    
    if command -v starship >/dev/null 2>&1; then
        # Use lazy loading for starship (it's usually fast but safe to lazy load)
        if [[ "${ZSH_FRAMEWORK_ASYNC}" == "true" ]]; then
            eval "$(starship init zsh)"
        else
            # Immediate loading
            eval "$(starship init zsh)"
        fi
    else
        echo "Starship not found. Install with: curl -sS https://starship.rs/install.sh | sh"
        configure_minimal_theme
    fi
}

# Minimal Theme Configuration (Fallback)
configure_minimal_theme() {
    ZSH_THEME=""
    
    # Simple but informative prompt
    autoload -Uz vcs_info
    precmd() { vcs_info }
    
    zstyle ':vcs_info:git:*' formats ' %F{red}%b%f'
    zstyle ':vcs_info:*' enable git
    
    setopt PROMPT_SUBST
    PROMPT='%F{blue}%n@%m%f:%F{cyan}%~%f${vcs_info_msg_0_} %F{green}%#%f '
    RPROMPT='%F{yellow}[%D{%H:%M:%S}]%f'
    
    echo "Using minimal built-in theme for best performance"
}

# Theme switching functions

# Switch to performance mode
theme_performance_mode() {
    case "$ZSH_THEME" in
        "spaceship")
            spaceship_minimal_mode
            ;;
        *)
            echo "Performance optimizations not available for theme: $ZSH_THEME"
            ;;
    esac
}

# Switch to full-featured mode
theme_full_mode() {
    case "$ZSH_THEME" in
        "spaceship")
            spaceship_enable_project_context
            ;;
        *)
            echo "Context switching not available for theme: $ZSH_THEME"
            ;;
    esac
}

# Switch theme dynamically
switch_theme() {
    local new_theme="$1"
    
    if [[ -z "$new_theme" ]]; then
        echo "Available themes: spaceship, powerlevel10k, starship, minimal"
        echo "Current theme: $ZSH_THEME"
        return 1
    fi
    
    export ZSH_FRAMEWORK_THEME="$new_theme"
    
    case "$new_theme" in
        "spaceship")
            configure_spaceship_theme
            ;;
        "powerlevel10k"|"p10k")
            configure_p10k_theme
            ;;
        "starship")
            configure_starship_theme
            ;;
        "minimal")
            configure_minimal_theme
            ;;
        *)
            ZSH_THEME="$new_theme"
            echo "Switched to Oh My Zsh theme: $new_theme"
            ;;
    esac
    
    # Reload Oh My Zsh if it's active
    if [[ -n "$ZSH" ]]; then
        source "$ZSH/oh-my-zsh.sh"
    fi
    
    echo "Theme switched to: $new_theme"
}

# Theme performance testing
benchmark_theme() {
    local iterations=${1:-5}
    local total_time=0
    
    echo "Benchmarking theme performance ($iterations iterations)..."
    
    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s.%N)
        
        # Simulate prompt generation
        print -P "$PROMPT" >/dev/null
        
        local end_time=$(date +%s.%N)
        local iteration_time=$(echo "$end_time - $start_time" | bc -l)
        total_time=$(echo "$total_time + $iteration_time" | bc -l)
        
        echo "  Iteration $i: $(echo "$iteration_time * 1000" | bc -l | cut -d. -f1)ms"
    done
    
    local avg_time=$(echo "$total_time / $iterations" | bc -l)
    local avg_time_ms=$(echo "$avg_time * 1000" | bc -l | cut -d. -f1)
    
    echo "Average prompt generation: ${avg_time_ms}ms"
    
    if [[ $avg_time_ms -lt 50 ]]; then
        echo "Performance: EXCELLENT"
    elif [[ $avg_time_ms -lt 100 ]]; then
        echo "Performance: GOOD"
    elif [[ $avg_time_ms -lt 200 ]]; then
        echo "Performance: ACCEPTABLE"
    else
        echo "Performance: POOR (consider optimizing)"
    fi
}

# Terminal title management
case $TERM in
    xterm*|rxvt*|screen*|tmux*)
        # Set terminal title
        precmd_functions+=(set_terminal_title)
        set_terminal_title() {
            print -Pn "\e]0;%n@%m: %~\a"
        }
        ;;
esac

# Export theme functions for global use (silenced to avoid startup output)
export -f theme_performance_mode theme_full_mode switch_theme benchmark_theme >/dev/null 2>&1
export -f spaceship_enable_project_context spaceship_minimal_mode >/dev/null 2>&1

# Oh My Zsh Theme Configuration (MOVED TO END - after all functions are defined)
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    export ZSH="$HOME/.oh-my-zsh"
    
    # Theme selection - now that all functions are defined
    case "$ZSH_FRAMEWORK_THEME" in
        "spaceship")
            configure_spaceship_theme
            ;;
        "powerlevel10k"|"p10k")
            configure_p10k_theme
            ;;
        "starship")
            configure_starship_theme
            ;;
        "minimal")
            configure_minimal_theme
            ;;
        *)
            ZSH_THEME="$ZSH_FRAMEWORK_THEME"
            ;;
    esac
fi

# Load theme-specific customizations
if [[ -d "$DOTFILES_DIR/shell/zsh/framework/themes" ]]; then
    for theme_file in "$DOTFILES_DIR/shell/zsh/framework/themes"/*.zsh; do
        [[ -r "$theme_file" ]] && source "$theme_file"
    done
fi

# Performance monitoring (debug mode)
if [[ "${ZSH_FRAMEWORK_DEBUG:-false}" == "true" ]]; then
    THEME_LOAD_END=$EPOCHREALTIME
    THEME_LOAD_TIME=$(echo "($THEME_LOAD_END - $THEME_LOAD_START) * 1000" | bc -l | cut -d. -f1)
    echo "Theme loading time: ${THEME_LOAD_TIME}ms"
fi