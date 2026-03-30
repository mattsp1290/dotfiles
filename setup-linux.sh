#!/bin/bash

if [ "$(uname)" != "Linux" ]; then
  echo "Error: setup-linux.sh is for Linux systems" >&2
  exit 1
fi

if [ "$PWD" != "$HOME/git/dotfiles" ]; then
  echo "Error: setup-linux.sh must be run from \"$HOME/git/dotfiles\"" >&2
  exit 1
fi

echo "Setting up your Linux machine..."

# Install zsh if not present
if ! command -v zsh > /dev/null 2>&1; then
  sudo apt update && sudo apt install -y zsh
fi

# Set zsh as default shell if not already
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  # Ensure zsh is listed in /etc/shells (required by chsh)
  if ! grep -qxF "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  fi
  sudo chsh -s "$ZSH_PATH" "$USER"
fi

# Check for Oh My Zsh and install if we don't have it
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)" "" --unattended
fi

# Check for nvm and install if we don't have it
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if ! command -v node > /dev/null 2>&1; then
  nvm install node
fi

# Check for pyenv and install if we don't have it
if ! command -v pyenv > /dev/null 2>&1; then
  sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
  curl https://pyenv.run | bash
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  pyenv install -s 3
  pyenv global "$(pyenv install -l | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | xargs)"
fi

# Ensure pyenv init is in .profile (idempotent)
if ! grep -qF 'PYENV_ROOT' "$HOME/.profile" 2>/dev/null; then
  cat >> "$HOME/.profile" << 'PYENV_BLOCK'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
PYENV_BLOCK
fi

# Check for pnpm and install if we don't have it
if ! command -v pnpm > /dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  npm install -g pnpm
fi

# Check for GitHub CLI and install if we don't have it
if ! command -v gh > /dev/null 2>&1; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update
  sudo apt install -y gh
fi

# Check for Go and install if we don't have it
if ! command -v go > /dev/null 2>&1; then
  GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
  curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:$PATH"
fi

# Ensure Go binary path is in .profile (idempotent)
if ! grep -qF '/usr/local/go/bin' "$HOME/.profile" 2>/dev/null; then
  cat >> "$HOME/.profile" << 'GO_BLOCK'

# Go (Linux install location)
export PATH="/usr/local/go/bin:$PATH"
GO_BLOCK
fi

# Check for Rust and install if we don't have it
if ! command -v rustup > /dev/null 2>&1 && [ ! -f "$HOME/.cargo/bin/rustup" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Check for Docker and install if we don't have it
if ! command -v docker > /dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
fi

# Check for wget and install if we don't have it
if ! command -v wget > /dev/null 2>&1; then
  sudo apt install -y wget
fi

# Ensure go bin directory exists
mkdir -p "$HOME/go/bin"

# Check for Powerline fonts and install if we don't have them
FONT_DIR="$HOME/.local/share/fonts"
if ! find "$FONT_DIR" -name "*Powerline*" -print -quit 2>/dev/null | grep -q .; then
  git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
  /tmp/powerline-fonts/install.sh
  rm -rf /tmp/powerline-fonts
  fc-cache -f "$FONT_DIR" 2>/dev/null || true
fi

# Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the dotfiles
if test -f "$HOME/.zshrc"; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  rm -rf "$HOME/.zshrc"
fi

ln -snf "$HOME/git/dotfiles/.zshrc" "$HOME/.zshrc"

# Symlink Ghostty config (ready if Ghostty is ever installed)
mkdir -p "$HOME/.config"
ln -snf "$HOME/git/dotfiles/.config/ghostty" "$HOME/.config/ghostty"

if test ! -f "$HOME/.profile"; then
  touch "$HOME/.profile"
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

echo "Done! Log out and back in for shell and group changes to take effect."
