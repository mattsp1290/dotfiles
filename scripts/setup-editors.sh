#!/usr/bin/env bash
# DEV-003: Editor Configuration Setup Script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# Install Neovim
install_neovim() {
    log "Installing Neovim..."
    if command_exists nvim; then
        log "Neovim already installed"
        return 0
    fi
    
    if is_macos && command_exists brew; then
        brew install neovim
    elif command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y neovim
    elif command_exists dnf; then
        sudo dnf install -y neovim
    elif command_exists pacman; then
        sudo pacman -S neovim
    else
        error "Cannot install Neovim automatically"
        return 1
    fi
    success "Neovim installed"
}

# Install supporting tools
install_tools() {
    log "Installing supporting tools..."
    
    # Node.js for language servers
    if ! command_exists node; then
        if is_macos && command_exists brew; then
            brew install node
        elif command_exists apt-get; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
    fi
    
    # Ripgrep for better search
    if ! command_exists rg; then
        if is_macos && command_exists brew; then
            brew install ripgrep
        elif command_exists apt-get; then
            sudo apt-get install -y ripgrep
        fi
    fi
    
    # fd for faster file finding
    if ! command_exists fd; then
        if is_macos && command_exists brew; then
            brew install fd
        elif command_exists apt-get; then
            sudo apt-get install -y fd-find
        fi
    fi
    
    success "Supporting tools installed"
}

# Setup Neovim configuration
setup_neovim() {
    log "Setting up Neovim configuration..."
    
    local nvim_dir="${HOME}/.config/nvim"
    
    # Backup existing config
    if [[ -d "${nvim_dir}" && ! -L "${nvim_dir}" ]]; then
        mv "${nvim_dir}" "${nvim_dir}.backup.$(date +%s)"
    fi
    
    # Create parent directory
    mkdir -p "$(dirname "${nvim_dir}")"
    
    # Link configuration
    cd "${DOTFILES_ROOT}"
    if command_exists stow; then
        stow -t "${HOME}/.config" config/nvim
    else
        ln -sfn "${DOTFILES_ROOT}/config/nvim" "${nvim_dir}"
    fi
    
    # Install plugins
    if command_exists nvim; then
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    fi
    
    success "Neovim configuration complete"
}

# Setup Vim configuration
setup_vim() {
    log "Setting up Vim configuration..."
    
    local vimrc="${HOME}/.vimrc"
    
    # Backup existing config
    if [[ -f "${vimrc}" && ! -L "${vimrc}" ]]; then
        mv "${vimrc}" "${vimrc}.backup.$(date +%s)"
    fi
    
    # Link configuration
    cd "${DOTFILES_ROOT}"
    if command_exists stow; then
        stow -t "${HOME}" home
    else
        ln -sfn "${DOTFILES_ROOT}/home/.vimrc" "${vimrc}"
    fi
    
    success "Vim configuration complete"
}

# Setup VS Code configuration
setup_vscode() {
    log "Setting up VS Code configuration..."
    
    local vscode_dir
    if is_macos; then
        vscode_dir="${HOME}/Library/Application Support/Code/User"
    else
        vscode_dir="${HOME}/.config/Code/User"
    fi
    
    mkdir -p "${vscode_dir}"
    
    # Backup and link settings
    for file in settings.json keybindings.json; do
        if [[ -f "${vscode_dir}/${file}" && ! -L "${vscode_dir}/${file}" ]]; then
            mv "${vscode_dir}/${file}" "${vscode_dir}/${file}.backup.$(date +%s)"
        fi
    done
    
    # Link configurations
    ln -sfn "${DOTFILES_ROOT}/config/Code/User/settings.json" "${vscode_dir}/settings.json"
    ln -sfn "${DOTFILES_ROOT}/config/Code/User/keybindings.json" "${vscode_dir}/keybindings.json"
    
    # Install extensions if VS Code is available
    if command_exists code; then
        log "Installing VS Code extensions..."
        local extensions=(
            "ms-python.python"
            "ms-python.black-formatter"
            "golang.go"
            "rust-lang.rust-analyzer"
            "esbenp.prettier-vscode"
            "eamodio.gitlens"
            "GitHub.github-vscode-theme"
            "PKief.material-icon-theme"
            "usernamehw.errorlens"
            "vscodevim.vim"
        )
        
        for ext in "${extensions[@]}"; do
            code --install-extension "${ext}" --force 2>/dev/null || true
        done
    fi
    
    success "VS Code configuration complete"
}

# Health check
health_check() {
    log "Running health check..."
    
    local issues=0
    
    # Check Neovim
    if command_exists nvim && [[ -d "${HOME}/.config/nvim" ]]; then
        success "✓ Neovim configured"
    else
        error "✗ Neovim not configured"
        ((issues++))
    fi
    
    # Check Vim
    if command_exists vim && [[ -f "${HOME}/.vimrc" ]]; then
        success "✓ Vim configured"
    else
        warn "△ Vim not configured"
    fi
    
    # Check VS Code
    local vscode_dir
    if is_macos; then
        vscode_dir="${HOME}/Library/Application Support/Code/User"
    else
        vscode_dir="${HOME}/.config/Code/User"
    fi
    
    if command_exists code && [[ -f "${vscode_dir}/settings.json" ]]; then
        success "✓ VS Code configured"
    else
        warn "△ VS Code not configured"
    fi
    
    if ((issues == 0)); then
        success "Health check passed!"
    else
        error "Health check found ${issues} issue(s)"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== DEV-003: Editor Configuration Setup ===${NC}"
    
    case "${1:-all}" in
        install)
            install_neovim
            install_tools
            ;;
        configure)
            setup_neovim
            setup_vim
            setup_vscode
            ;;
        health)
            health_check
            ;;
        nvim)
            install_neovim
            install_tools
            setup_neovim
            ;;
        all|*)
            install_neovim
            install_tools
            setup_neovim
            setup_vim
            setup_vscode
            health_check
            ;;
    esac
    
    success "Editor setup completed! 🎉"
}

# Make sure we're in the right directory
cd "${DOTFILES_ROOT}"

# Run with all arguments
main "$@" 