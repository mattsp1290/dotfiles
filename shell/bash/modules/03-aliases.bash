# Aliases Module - Bash Compatible
# Command aliases for improved productivity and safety

# Safety aliases (prevent accidental damage)
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

# Enhanced ls aliases
if command -v exa >/dev/null 2>&1; then
    # Use exa if available (modern ls replacement)
    alias ls='exa --color=auto --group-directories-first'
    alias ll='exa -l --color=auto --group-directories-first'
    alias la='exa -la --color=auto --group-directories-first'
    alias lt='exa --tree --color=auto --group-directories-first'
    alias l='exa --color=auto --group-directories-first'
elif [[ "$OS_TYPE" == "macos" ]] && command -v gls >/dev/null 2>&1; then
    # Use GNU ls on macOS if available
    alias ls='gls --color=auto --group-directories-first'
    alias ll='gls -alF --color=auto --group-directories-first'
    alias la='gls -A --color=auto --group-directories-first'
    alias l='gls -CF --color=auto --group-directories-first'
else
    # Standard ls aliases
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
fi

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'

# Directory listing shortcuts
alias lh='ls -lh'        # Human readable sizes
alias lS='ls -1FSsh'     # Sort by size
alias ltr='ls -ltr'      # Sort by date, most recent last
alias lta='ls -lta'      # Sort by date, most recent last, include hidden

# Grep aliases
if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Find aliases
if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

# Cat aliases
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat'
elif command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --paging=never'
    alias less='batcat'
fi

# Git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch'
alias gd='git diff'
alias gdc='git diff --cached'
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git rebase'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gst='git stash'
alias gsp='git stash pop'
alias gsl='git stash list'

# System information
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias top='top -o cpu'
alias htop='htop'

# Network
alias ping='ping -c 5'
alias ports='netstat -tulanp'
alias myip='curl -s https://ipinfo.io/ip'
alias localip='ipconfig getifaddr en0'

# Process management
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias killall='killall -v'

# Archive and compression
alias tar='tar -v'
alias untar='tar -xvf'
alias targz='tar -czvf'
alias untargz='tar -xzvf'

# Development shortcuts
alias serve='python3 -m http.server'

# Docker aliases
if command -v docker >/dev/null 2>&1; then
    alias d='docker'
    alias dc='docker-compose'
    alias dps='docker ps'
    alias dpsa='docker ps -a'
    alias di='docker images'
    alias drmi='docker rmi'
    alias drmf='docker system prune -f'
    alias dlog='docker logs'
    alias dexec='docker exec -it'
fi

# Kubernetes aliases
if command -v kubectl >/dev/null 2>&1; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias kdp='kubectl describe pod'
    alias kds='kubectl describe service'
    alias kdd='kubectl describe deployment'
    alias klog='kubectl logs'
    alias kexec='kubectl exec -it'
fi

# Terraform aliases
if command -v terraform >/dev/null 2>&1; then
    alias tf='terraform'
    alias tfi='terraform init'
    alias tfp='terraform plan'
    alias tfa='terraform apply'
    alias tfd='terraform destroy'
    alias tfv='terraform validate'
    alias tff='terraform fmt'
fi

# Text editing
alias vim='nvim'
alias vi='nvim'
alias nano='nano -w'

# Quick config edits
alias bashconfig='$EDITOR ~/.bashrc'
alias bashreload='source ~/.bashrc'
alias vimconfig='$EDITOR ~/.config/nvim/init.vim'
alias gitconfig='$EDITOR ~/.gitconfig'

# Miscellaneous
alias reload='exec $BASH -l'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias nowdate='date +"%d-%m-%Y"'
alias week='date +%V'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'

# Work-specific aliases (Datadog)
if [[ -n "$DATADOG_ROOT" ]]; then
    alias dd='cd $DATADOG_ROOT'
    alias ddgo='cd $DATADOG_ROOT/dd-go'
fi

# 1Password CLI aliases
if command -v op >/dev/null 2>&1; then
    alias ops='op signin'
    alias opg='op get'
    alias opl='op list'
fi 