#!/bin/zsh
echo "Current directory: $(pwd)"
echo "DOTFILES_DIR before sourcing: $DOTFILES_DIR"

source shell/zsh/.zshenv

echo "DOTFILES_DIR after .zshenv: $DOTFILES_DIR"
echo "XDG_CONFIG_HOME: $XDG_CONFIG_HOME"

# Test individual module
echo "Testing environment module..."
source shell/zsh/modules/01-environment.zsh

echo "OS_TYPE after env module: $OS_TYPE"
echo "HOMEBREW_PREFIX after env module: $HOMEBREW_PREFIX"

# Test full config
echo "Loading full config..."
source shell/zsh/.zshrc

echo "Final OS_TYPE: $OS_TYPE"
echo "Final HOMEBREW_PREFIX: $HOMEBREW_PREFIX"
echo "Configuration test complete" 