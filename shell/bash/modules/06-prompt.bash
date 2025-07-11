# Optimized Prompt Module - Bash Compatible
# Performance-focused prompt configuration with git integration

# Git prompt function
_git_branch() {
    local branch
    if branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
        echo " ($branch)"
    fi
}

# Git status function (optional, can be expensive)
_git_status() {
    local status=""
    if git status --porcelain 2>/dev/null | grep -q .; then
        status="*"
    fi
    echo "$status"
}

# Fast git prompt (only shows branch, not status for performance)
_git_prompt() {
    local branch
    if branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
        echo " \[\033[31m\]($branch)\[\033[0m\]"
    fi
}

# Performance-focused prompt function
_set_prompt() {
    local exit_code=$?
    
    # Colors
    local red='\[\033[31m\]'
    local green='\[\033[32m\]'
    local yellow='\[\033[33m\]'
    local blue='\[\033[34m\]'
    local cyan='\[\033[36m\]'
    local reset='\[\033[0m\]'
    
    # Exit code indicator
    local exit_indicator=""
    if [[ $exit_code -ne 0 ]]; then
        exit_indicator="${red}[$exit_code]${reset} "
    fi
    
    # Build prompt
    PS1="${exit_indicator}${blue}\u@\h${reset}:${cyan}\w${reset}$(_git_prompt) ${green}\$${reset} "
}

# Check if we should use a simple or git-aware prompt
if command -v git >/dev/null 2>&1; then
    # Git is available, use git-aware prompt
    PROMPT_COMMAND="_set_prompt"
else
    # Simple prompt without git
    PS1='\[\033[34m\]\u@\h\[\033[0m\]:\[\033[36m\]\w\[\033[0m\] \[\033[32m\]\$\[\033[0m\] '
fi

# Terminal title function
_set_terminal_title() {
    case $TERM in
        xterm*|rxvt*|screen*|tmux*)
            printf '\033]0;%s@%s: %s\007' "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"
            ;;
    esac
}

# Update terminal title on each command
if [[ -n "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="$PROMPT_COMMAND; _set_terminal_title"
else
    PROMPT_COMMAND="_set_terminal_title"
fi

# Alternative simple prompts (uncomment to use instead)

# Minimal prompt
# PS1='\$ '

# Classic prompt
# PS1='\u@\h:\w\$ '

# Colorful but simple prompt
# PS1='\[\033[32m\]\u@\h\[\033[0m\]:\[\033[34m\]\w\[\033[0m\]\$ ' 