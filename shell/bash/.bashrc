# Bash Interactive Shell Configuration
# Part of dotfiles repository managed by GNU Stow

# Performance profiling (uncomment to debug startup time)
# Use: time bash -i -c exit

# Early exit for non-interactive shells (but allow sourcing for testing)
# Only exit if we're being executed directly, not sourced
if [[ $- != *i* ]] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    return
fi

# Essential environment setup (minimal for performance)
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/git/dotfiles}"

# Only load utility functions when needed (not during normal shell startup)
# They can be loaded on-demand with: source "$DOTFILES_DIR/scripts/lib/utils.sh"

# Determine module directory
BASH_MODULES_DIR="${DOTFILES_DIR}/shell/bash/modules"

# Load modules in order
if [[ -d "$BASH_MODULES_DIR" ]]; then
    # Use bash-compatible loop for loading modules in order
    for module in "$BASH_MODULES_DIR"/*.bash; do
        if [[ -r "$module" ]]; then
            source "$module"
        fi
    done
    unset module
fi

# Load shared shell configuration (bash-compatible files)
if [[ -d "$DOTFILES_DIR/shell/shared" ]]; then
    for shared_file in "$DOTFILES_DIR/shell/shared"/*.bash; do
        [[ -r "$shared_file" ]] && source "$shared_file"
    done
    unset shared_file
fi

# Load local overrides (machine-specific configuration)
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"

# Clean up variables
unset BASH_MODULES_DIR 