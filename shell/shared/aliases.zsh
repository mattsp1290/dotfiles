# Shared aliases for all shells
# Part of dotfiles repository managed by GNU Stow

# Enhanced ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ls='ls --color=auto'  # Linux
[[ "$OSTYPE" == "darwin"* ]] && alias ls='ls -G'  # macOS

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# Git aliases (comprehensive)
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline'
alias gd='git diff'
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git remote'
alias grv='git remote -v'
alias gf='git fetch'
alias gt='git tag'
alias gst='git stash'
alias gsp='git stash pop'

# File operations
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'

# System monitoring
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias top='top -o cpu'

# Networking
alias ping='ping -c 5'
alias wget='wget -c'

# Package management
if command -v brew >/dev/null 2>&1; then
    alias brewup='brew update && brew upgrade && brew cleanup'
    alias brewlist='brew list --formula'
    alias brewcask='brew list --cask'
fi

if command -v apt >/dev/null 2>&1; then
    alias aptup='sudo apt update && sudo apt upgrade'
    alias aptlist='apt list --installed'
    alias aptsearch='apt search'
fi

# Docker aliases (if Docker is installed)
if command -v docker >/dev/null 2>&1; then
    alias dps='docker ps'
    alias dpa='docker ps -a'
    alias di='docker images'
    alias drmi='docker rmi'
    alias drm='docker rm'
    alias dstop='docker stop'
    alias dstart='docker start'
    alias dexec='docker exec -it'
    alias dlogs='docker logs'
    alias dclean='docker system prune -f'
fi

# Kubernetes aliases (if kubectl is installed)
if command -v kubectl >/dev/null 2>&1; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias kgn='kubectl get nodes'
    alias kdesc='kubectl describe'
    alias klogs='kubectl logs'
    alias kexec='kubectl exec -it'
fi

# Text processing
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Editor aliases
alias vi='nvim'
alias vim='nvim'
alias nano='nvim'

# Quick edits
alias edit-zshrc='$EDITOR ~/.zshrc'
alias edit-bashrc='$EDITOR ~/.bashrc'
alias edit-vimrc='$EDITOR ~/.vimrc'
alias reload-shell='source ~/.zshrc 2>/dev/null || source ~/.bashrc 2>/dev/null'

# Network utilities
alias myip='curl -s https://ipinfo.io/ip'
alias localip='ipconfig getifaddr en0 2>/dev/null || hostname -I | cut -d" " -f1'

# Quick access to common directories
alias dotfiles='cd $DOTFILES_DIR 2>/dev/null || cd ~/git/dotfiles 2>/dev/null || cd ~/.dotfiles'
alias downloads='cd ~/Downloads'
alias documents='cd ~/Documents'
alias desktop='cd ~/Desktop'

# Utility aliases
alias weather='curl wttr.in'
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec $SHELL'
alias h='history'
alias j='jobs'
alias which='command -v' 