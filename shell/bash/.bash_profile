# Bash Login Shell Configuration
# Part of dotfiles repository managed by GNU Stow

# Source the profile if it exists (compatibility with other tools)
[[ -f "$HOME/.profile" ]] && source "$HOME/.profile"

# Source bashrc for interactive shells
if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc"
fi

# Bash-specific login configuration
# Set bash options for login shells
set -o vi  # Use vi-style command line editing

# History configuration for login shells
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=10000
export HISTFILESIZE=20000

# Append to the history file, don't overwrite it
shopt -s histappend

# Update LINES and COLUMNS after each command
shopt -s checkwinsize

# Enable extended globbing
shopt -s extglob

# Enable case-insensitive globbing
shopt -s nocaseglob

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Include dotfiles in pathname expansion
shopt -s dotglob

# Terminal title for login shells
case $TERM in
    xterm*|rxvt*|screen*|tmux*)
        export PROMPT_COMMAND="echo -ne '\033]0;${USER}@${HOSTNAME}: ${PWD}\007'"
        ;;
esac 