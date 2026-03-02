#!/bin/sh

if [ "$PWD" != "$HOME/git/dotfiles" ]; then
  echo "Error: setup.sh must be run from \"$HOME/git/dotfiles" >&2
  exit 1
fi

echo "Setting up your Mac..."

# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the .dotfiles
if test -f $HOME/.zshrc; then
  cp $HOME/.zshrc $HOME/.zshrc.backup
  rm -rf $HOME/.zshrc
fi

ln -snf "$HOME/git/dotfiles/.zshrc" "$HOME/.zshrc"

# Install Claude Code if not already present
if ! command -v claude > /dev/null 2>&1 && [ ! -f "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Ensure $HOME/.claude directory exists (not a symlink, so Claude Code can manage its own files)
mkdir -p "$HOME/.claude"

# Symlink each subdirectory in dotfiles .claude into $HOME/.claude dynamically
# This means adding new subdirectories to dotfiles/.claude will auto-link on next setup run
DOTFILES_CLAUDE="$HOME/git/dotfiles/.claude"
for dir in "$DOTFILES_CLAUDE"/*/; do
  dir_name=$(basename "$dir")
  ln -snf "$dir" "$HOME/.claude/$dir_name"
done
