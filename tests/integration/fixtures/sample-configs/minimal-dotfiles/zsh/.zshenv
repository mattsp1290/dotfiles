# Zsh Environment Configuration for Integration Testing
# This file is sourced for all zsh sessions

# Set default editor
export EDITOR=vim
export VISUAL=vim

# Set default pager
export PAGER=less

# Language and locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History settings
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

# Less configuration
export LESS='-R -i -w -M -z-4'

# Path configuration
typeset -U path
path=(
    ~/.local/bin
    /usr/local/bin
    /usr/bin
    /bin
    /usr/sbin
    /sbin
    $path
)

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Development environment
export DEVELOPMENT_MODE=true

# Integration testing marker
export INTEGRATION_TEST_MARKER="Zsh environment loaded"

# Platform detection
case "$OSTYPE" in
    darwin*)
        export PLATFORM="macos"
        ;;
    linux*)
        export PLATFORM="linux"
        ;;
    *)
        export PLATFORM="unknown"
        ;;
esac

# Test-specific environment variables
if [[ "${DOTFILES_CI:-false}" == "true" ]]; then
    export CI_MODE=true
    export TEST_MODE=true
fi 