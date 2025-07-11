# Functions Module - Bash Compatible
# Useful shell functions for productivity

# Create directory and change into it
mkcd() {
    [[ $# -eq 1 ]] || { echo "Usage: mkcd <directory>"; return 1; }
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi
    
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi
    
    case "$1" in
        *.tar.bz2)   tar xjf "$1"     ;;
        *.tar.gz)    tar xzf "$1"     ;;
        *.tar.xz)    tar xJf "$1"     ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar e "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xf "$1"      ;;
        *.tbz2)      tar xjf "$1"     ;;
        *.tgz)       tar xzf "$1"     ;;
        *.zip)       unzip "$1"       ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *.deb)       ar x "$1"        ;;
        *.tar.zst)   tar --zstd -xf "$1" ;;
        *)           echo "Error: '$1' cannot be extracted via extract()" ;;
    esac
}

# Find and kill processes by name
killp() {
    [[ $# -eq 0 ]] && { echo "Usage: killp <process_name>"; return 1; }
    local pids=$(pgrep -f "$1")
    if [[ -n "$pids" ]]; then
        echo "Killing processes matching '$1':"
        ps -p $pids
        kill $pids
    else
        echo "No processes found matching '$1'"
    fi
}

# Quick backup of files
backup() {
    [[ $# -eq 0 ]] && { echo "Usage: backup <file>"; return 1; }
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
            echo "Backed up: $file"
        else
            echo "File not found: $file"
        fi
    done
}

# Weather function
weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?format=3"
}

# Generate random password
genpass() {
    local length="${1:-16}"
    openssl rand -base64 32 | cut -c1-"$length"
}

# Find files by name
ff() {
    [[ $# -eq 0 ]] && { echo "Usage: ff <filename>"; return 1; }
    find . -type f -iname "*$1*" 2>/dev/null
}

# Find directories by name (renamed to avoid conflict with fd tool)
findd() {
    [[ $# -eq 0 ]] && { echo "Usage: findd <dirname>"; return 1; }
    find . -type d -iname "*$1*" 2>/dev/null
}

# Quick grep in files
grepf() {
    [[ $# -eq 0 ]] && { echo "Usage: grepf <pattern> [path]"; return 1; }
    local pattern="$1"
    local path="${2:-.}"
    grep -r --color=auto "$pattern" "$path"
}

# Show disk usage of current directory
duh() {
    du -sh * | sort -hr
}

# Show listening ports
listening() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        lsof -iTCP -sTCP:LISTEN -n -P
    else
        netstat -tlnp
    fi
}

# Git functions
# Quick commit with message
gcom() {
    [[ $# -eq 0 ]] && { echo "Usage: gcom <message>"; return 1; }
    git add -A && git commit -m "$*"
}

# Git push with upstream
gpush() {
    local branch=$(git branch --show-current)
    git push -u origin "$branch"
}

# Create and switch to new git branch
gnew() {
    [[ $# -eq 0 ]] && { echo "Usage: gnew <branch_name>"; return 1; }
    git checkout -b "$1"
}

# 1Password CLI Integration Functions
# (Migrated from original .zshrc)

# Detect and set 1Password account
if [[ -f "$DOTFILES_DIR/scripts/op-env-detect.sh" ]]; then
    export OP_ACCOUNT_ALIAS=$("$DOTFILES_DIR/scripts/op-env-detect.sh" 2>/dev/null || echo "personal")
fi

# Source the secret helpers
if [[ -f "$DOTFILES_DIR/scripts/lib/secret-helpers.sh" ]]; then
    source "$DOTFILES_DIR/scripts/lib/secret-helpers.sh"
fi

# Sign in to the detected account
op-signin() {
    local account=${1:-$OP_ACCOUNT_ALIAS}
    echo "Signing in to 1Password account: $account"
    eval $(op signin --account "$account")
}

# Quick switch between accounts
op-work() {
    eval $(op signin --account work)
    export OP_ACCOUNT_ALIAS="work"
}

op-personal() {
    eval $(op signin --account personal)
    export OP_ACCOUNT_ALIAS="personal"
}

# Check current account
op-current() {
    echo "Current account alias: $OP_ACCOUNT_ALIAS"
    if op account get --account "$OP_ACCOUNT_ALIAS" 2>/dev/null; then
        echo "Status: Signed in ✓"
    else
        echo "Status: Not signed in ✗"
    fi
}

# Work-specific environment variables (from Ansible managed block)
if [[ -d "$HOME/dd" ]]; then
    # AWS configuration for work
    export AWS_VAULT_KEYCHAIN_NAME=login
    export AWS_SESSION_TTL=24h
    export AWS_ASSUME_ROLE_TTL=1h
    
    # Helm configuration
    export HELM_DRIVER=configmap
    
    # Go configuration for work
    export GOPRIVATE=github.com/DataDog
fi

# Development server functions
httpserve() {
    local port="${1:-8000}"
    echo "Starting HTTP server on port $port..."
    python3 -m http.server "$port"
}

# JSON pretty print
json() {
    if [[ $# -eq 0 ]]; then
        python3 -m json.tool
    else
        python3 -m json.tool "$1"
    fi
}

# URL encode/decode
urlencode() {
    python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(' '.join(sys.argv[1:])))" "$@"
}

urldecode() {
    python3 -c "import sys, urllib.parse as ul; print(ul.unquote_plus(' '.join(sys.argv[1:])))" "$@"
}

# Load additional functions from functions directory
if [[ -d "$DOTFILES_DIR/shell/bash/functions" ]]; then
    for func_file in "$DOTFILES_DIR/shell/bash/functions"/*.bash; do
        [[ -r "$func_file" ]] && source "$func_file"
    done
fi 