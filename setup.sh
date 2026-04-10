#!/bin/sh

if [ "$PWD" != "$HOME/git/dotfiles" ]; then
  echo "Error: setup.sh must be run from \"$HOME/git/dotfiles" >&2
  exit 1
fi

echo "Setting up your Mac..."

# Check for Oh My Zsh and install if we don't have it
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Check for nvm and install if we don't have it
if ! brew list nvm &> /dev/null && ! type nvm &> /dev/null; then
  brew install nvm
  mkdir -p "$HOME/.nvm"
  export NVM_DIR="$HOME/.nvm"
  . "$(brew --prefix nvm)/nvm.sh"
  nvm install node
fi

# Check for pyenv and install if we don't have it
if ! command -v pyenv > /dev/null 2>&1; then
  brew install pyenv
  eval "$(pyenv init -)"
  pyenv install -s 3
  pyenv global "$(pyenv install -l | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | xargs)"
fi

# Check for pnpm and install if we don't have it
if ! command -v pnpm > /dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$(brew --prefix nvm)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"
  npm install -g pnpm
fi

# Check for GitHub CLI and install if we don't have it
if ! brew list gh &> /dev/null && ! command -v gh > /dev/null 2>&1; then
  brew install gh
fi

# Check for Go and install if we don't have it
if ! brew list go &> /dev/null && ! command -v go > /dev/null 2>&1; then
  brew install go
fi

# Check for Rust and install if we don't have it
if ! command -v rustup > /dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Check for Colima and install if we don't have it
if ! brew list colima &> /dev/null && ! command -v docker > /dev/null 2>&1; then
  brew install docker docker-compose docker-buildx
  brew install colima
  colima start --cpu 4 --memory 16 --vm-type vz --vz-rosetta
fi

# Check for wget and install if we don't have it
if ! brew list wget &> /dev/null && ! command -v wget > /dev/null 2>&1; then
  brew install wget
fi

# Ensure docker CLI plugins directory is configured (required for docker compose, buildx, etc.)
python3 scripts/ensure-docker-cli-plugins.py

# Ensure go bin directory exists
mkdir -p "$HOME/go/bin"

# Check for iTerm2 and install if we don't have it
if ! brew list --cask iterm2 &> /dev/null && [ ! -d "/Applications/iTerm.app" ]; then
  brew install --cask iterm2
fi

# Check for Ghostty and install if we don't have it
if ! brew list --cask ghostty &> /dev/null && [ ! -d /Applications/Ghostty.app ]; then
  brew install --cask ghostty
fi

# Check for cmux and install if we don't have it
if ! brew list --cask cmux &> /dev/null && [ ! -d /Applications/cmux.app ]; then
  brew tap manaflow-ai/cmux
  brew install --cask cmux
fi

# Check for Powerline fonts and install if we don't have them
if ! find "$HOME/Library/Fonts" -name "*Powerline*" -print -quit 2>/dev/null | grep -q .; then
  git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
  /tmp/powerline-fonts/install.sh
  rm -rf /tmp/powerline-fonts
fi

# Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the .dotfiles
if test -f $HOME/.zshrc; then
  cp $HOME/.zshrc $HOME/.zshrc.backup
  rm -rf $HOME/.zshrc
fi

ln -snf "$HOME/git/dotfiles/.zshrc" "$HOME/.zshrc"

# Symlink Ghostty config (used by both Ghostty and cmux)
mkdir -p "$HOME/.config"
ln -snf "$HOME/git/dotfiles/.config/ghostty" "$HOME/.config/ghostty"

# Import Smyck color scheme into iTerm2 if installed
if [ -d "/Applications/iTerm.app" ]; then
  if ! defaults read com.googlecode.iterm2 "Custom Color Presets" 2>/dev/null | grep -q 'Smyck'; then
    open "$HOME/git/dotfiles/Smyck.itermcolors" 2>/dev/null || true
  fi
fi

# Set iTerm2 font to Ubuntu Mono derivative Powerline
if [ -d "/Applications/iTerm.app" ]; then
  /usr/libexec/PlistBuddy -c "Set ':New Bookmarks:0:Normal Font' 'UbuntuMonoDerivativePowerline-Regular 16'" \
    "$HOME/Library/Preferences/com.googlecode.iterm2.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set ':New Bookmarks:0:Non Ascii Font' 'UbuntuMonoDerivativePowerline-Regular 16'" \
    "$HOME/Library/Preferences/com.googlecode.iterm2.plist" 2>/dev/null || true
fi

if test ! -f $HOME/.profile; then
  touch $HOME/.profile
fi

# Ensure reviews/ is in the global gitignore
GITIGNORE_GLOBAL="$HOME/.gitignore_global"
touch "$GITIGNORE_GLOBAL"
if ! grep -qF 'reviews/' "$GITIGNORE_GLOBAL"; then
  echo 'reviews/' >> "$GITIGNORE_GLOBAL"
fi
git config --global core.excludesFile "$GITIGNORE_GLOBAL"

# Set vim as the default git editor
git config --global core.editor "vim"

# Install OpenCode if not already present
if ! command -v opencode > /dev/null 2>&1 && [ ! -f "$HOME/.opencode/bin/opencode" ]; then
  curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
fi

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

echo "Done!"