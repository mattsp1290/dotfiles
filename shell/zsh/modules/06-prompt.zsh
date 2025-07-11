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
