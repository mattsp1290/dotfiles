# Zsh Interactive Shell Configuration
# Part of dotfiles repository managed by GNU Stow

# Performance profiling (uncomment to debug startup time)
# zmodload zsh/zprof

# Early exit for non-interactive shells
[[ $- != *i* ]] && return

# Essential environment setup (minimal for performance)
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/git/dotfiles}"

# Only load utility functions when needed (not during normal shell startup)
# They can be loaded on-demand with: source "$DOTFILES_DIR/scripts/lib/utils.sh"

# Determine module directory
ZMODULES_DIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/modules"
if [[ ! -d "$ZMODULES_DIR" ]]; then
    # Fallback to dotfiles location if ZDOTDIR modules don't exist
    ZMODULES_DIR="$DOTFILES_DIR/shell/zsh/modules"
fi

# Load modules in order
if [[ -d "$ZMODULES_DIR" ]]; then
    for module in "$ZMODULES_DIR"/*.zsh; do
        if [[ -r "$module" ]]; then
            source "$module"
        fi
    done
    unset module
fi

# Load shared shell configuration
if [[ -d "$DOTFILES_DIR/shell/shared" ]]; then
    for shared_file in "$DOTFILES_DIR/shell/shared"/*.zsh; do
        [[ -r "$shared_file" ]] && source "$shared_file"
    done
    unset shared_file
fi

# Load local overrides (machine-specific configuration)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Clean up variables
unset ZMODULES_DIR

# Performance profiling output (uncomment to debug startup time)
# zprof 
export WASMTIME_HOME="$HOME/.wasmtime"

export PATH="$WASMTIME_HOME/bin:$PATH"
export PATH=$HOME/.wasmtime/bin:$PATH
