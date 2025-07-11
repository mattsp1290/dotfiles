# Minimal Zsh Configuration for Integration Testing
# This file is used to test dotfiles installation and management

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Completion
autoload -Uz compinit
compinit

# Enable completion caching
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path ~/.zsh/cache

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Colored completion
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Prompt configuration
autoload -Uz promptinit
promptinit

# Simple prompt for testing
PROMPT='%F{blue}%n@%m%f:%F{green}%~%f$ '
RPROMPT='%F{yellow}[%D{%H:%M:%S}]%f'

# Aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# Test aliases for integration testing
alias test-marker='echo "INTEGRATION_TEST_MARKER: Zsh config loaded successfully"'

# Environment variables
export EDITOR=vim
export PAGER=less
export LANG=en_US.UTF-8

# Path configuration
if [[ -d ~/.local/bin ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Load additional functions if available
if [[ -f ~/.zsh/functions.zsh ]]; then
    source ~/.zsh/functions.zsh
fi

# Test function for integration testing
test_zsh_config() {
    echo "Zsh configuration test function loaded"
    echo "Current shell: $SHELL"
    echo "Zsh version: $ZSH_VERSION"
    return 0
} 