# Optimized Plugins Module
# Performance-focused plugin loading with lazy loading

# Source the framework plugin configuration
if [[ -f "$DOTFILES_DIR/shell/zsh/framework/plugins.zsh" ]]; then
    source "$DOTFILES_DIR/shell/zsh/framework/plugins.zsh"
else
    # Fallback to basic plugin loading if framework not available
    log_warning "Framework plugins not found, using basic configuration"
    
    # Load basic external plugins
    if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
        ZSH_AUTOSUGGEST_USE_ASYNC=true
    fi
    
    if [[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        ZSH_HIGHLIGHT_MAXLENGTH=300
    fi
fi

# Performance monitoring (if enabled)
if [[ "${ZSH_FRAMEWORK_DEBUG:-false}" == "true" ]]; then
    echo "Plugins module loaded with framework optimization"
fi
