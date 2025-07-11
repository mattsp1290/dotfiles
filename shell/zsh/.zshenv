# Zsh Environment Configuration
# This file is sourced by all Zsh instances (login, non-login, interactive, non-interactive)
# Keep this file minimal and fast

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Zsh configuration directory
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# Dotfiles directory
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/git/dotfiles}"

# Essential environment variables
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export BROWSER="${BROWSER:-open}"

# Language and locale (only set if not already set)
export LANG="${LANG:-en_US.UTF-8}"

# History configuration
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
export HISTSIZE=50000
export SAVEHIST=50000

# Less configuration
export LESS="-R -F -X -M"
export LESSHISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/less/history"

# Ensure history directory exists (only if needed)
if [[ -n "$HISTFILE" && ! -d "$(dirname "$HISTFILE")" ]]; then
    mkdir -p "$(dirname "$HISTFILE")" 2>/dev/null || true
fi 