# Key Bindings Module
# Custom key bindings for improved productivity

# Use emacs key bindings (set in 00-init.zsh but ensure it's set)
bindkey -e

# History search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Word movement (Alt+Left/Right)
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

# Line movement (Ctrl+A/E)
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# Delete word (Ctrl+W)
bindkey '^W' backward-kill-word

# Delete to end of line (Ctrl+K)
bindkey '^K' kill-line

# Delete to beginning of line (Ctrl+U)
bindkey '^U' backward-kill-line

# Undo (Ctrl+Z in emacs mode)
bindkey '^Z' undo

# Clear screen (Ctrl+L)
bindkey '^L' clear-screen

# Accept suggestion (Ctrl+Space if using autosuggestions)
bindkey '^ ' autosuggest-accept

# History navigation with arrow keys
bindkey '^[[A' up-line-or-history
bindkey '^[[B' down-line-or-history

# Better history search with up/down arrows
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Home and End keys
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Delete key
bindkey '^[[3~' delete-char

# Page Up/Down
bindkey '^[[5~' up-line-or-history
bindkey '^[[6~' down-line-or-history

# Insert key
bindkey '^[[2~' overwrite-mode

# Alt+Backspace to delete word
bindkey '^[^?' backward-kill-word

# Ctrl+Left/Right for word movement (alternative bindings)
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Edit command line in editor (Ctrl+X Ctrl+E)
autoload -z edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Quick directory navigation
# Alt+Up to go up one directory
bindkey -s '^[[1;3A' 'cd ..\n'

# Custom functions for key bindings
# Quick git status
git-status-widget() {
    BUFFER="git status"
    zle accept-line
}
zle -N git-status-widget
bindkey '^G^S' git-status-widget

# Quick git add all
git-add-all-widget() {
    BUFFER="git add -A"
    zle accept-line
}
zle -N git-add-all-widget
bindkey '^G^A' git-add-all-widget

# Quick ls
ls-widget() {
    BUFFER="ls -la"
    zle accept-line
}
zle -N ls-widget
bindkey '^X^L' ls-widget

# Quick cd to home
cd-home-widget() {
    BUFFER="cd ~"
    zle accept-line
}
zle -N cd-home-widget
bindkey '^X^H' cd-home-widget

# FZF key bindings (if available)
if command -v fzf >/dev/null 2>&1; then
    # Ctrl+T for file search
    # Ctrl+R for history search (enhanced)
    # Alt+C for directory search
    # These are typically loaded by the FZF completion module
    
    # Custom FZF functions
    # Search and edit file
    fzf-edit-widget() {
        local file
        file=$(fzf --preview 'cat {}' --preview-window=right:60%:wrap)
        if [[ -n "$file" ]]; then
            BUFFER="$EDITOR $file"
            zle accept-line
        fi
    }
    zle -N fzf-edit-widget
    bindkey '^X^F' fzf-edit-widget
    
    # Search and cd to directory
    fzf-cd-widget() {
        local dir
        dir=$(find . -type d 2>/dev/null | fzf --preview 'ls -la {}')
        if [[ -n "$dir" ]]; then
            BUFFER="cd $dir"
            zle accept-line
        fi
    }
    zle -N fzf-cd-widget
    bindkey '^X^D' fzf-cd-widget
fi

# Sudo prefix toggle (Alt+S)
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
bindkey '^[s' sudo-command-line

# Quote current word (Alt+Q)
quote-word() {
    zle backward-word
    LBUFFER+="'"
    zle forward-word
    RBUFFER="'$RBUFFER"
}
zle -N quote-word
bindkey '^[q' quote-word

# Double quote current word (Alt+Shift+Q)
double-quote-word() {
    zle backward-word
    LBUFFER+='"'
    zle forward-word
    RBUFFER="\"$RBUFFER"
}
zle -N double-quote-word
bindkey '^[Q' double-quote-word 