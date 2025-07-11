# Zsh Functions for Integration Testing
# Additional functions loaded by the main zshrc

# Directory navigation helpers
up() {
    local levels=${1:-1}
    local path=""
    for ((i=0; i<levels; i++)); do
        path="../$path"
    done
    cd "$path" || return 1
}

# Quick directory creation and navigation
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Find files by name
ff() {
    find . -name "*$1*" -type f 2>/dev/null
}

# Find directories by name
fd() {
    find . -name "*$1*" -type d 2>/dev/null
}

# Extract various archive formats
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Git helpers
gst() {
    git status "$@"
}

gco() {
    git checkout "$@"
}

gcb() {
    git checkout -b "$@"
}

# Test function for integration testing
test_functions_loaded() {
    echo "INTEGRATION_TEST_MARKER: Zsh functions loaded successfully"
    echo "Available functions: up, mkcd, ff, fd, extract, gst, gco, gcb"
    return 0
}

# Show current git branch in prompt helper
git_branch() {
    git branch 2>/dev/null | grep '^*' | colrm 1 2
}

# Simple calculator
calc() {
    echo "scale=3; $*" | bc -l
}

# Weather function (mock for testing)
weather() {
    echo "INTEGRATION_TEST_MARKER: Weather function called for ${1:-current location}"
    echo "Mock weather data: Sunny, 72°F"
} 