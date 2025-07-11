#!/usr/bin/env bash
# Development Tools Installation Script
# Installs modern CLI replacements and development utilities

set -euo pipefail

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source libraries
source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"
source "$DOTFILES_ROOT/scripts/lib/utils.sh"

# Development tools to install
declare -a CORE_DEV_TOOLS=(
    "bat"           # Better cat with syntax highlighting
    "exa"           # Modern ls replacement
    "fd"            # Better find
    "ripgrep"       # Ultra-fast text search (rg)
    "fzf"           # Fuzzy finder
    "jq"            # JSON processor
    "git-delta"     # Enhanced git diff
    "gh"            # GitHub CLI
    "httpie"        # User-friendly HTTP client
    "tree"          # Directory structure display
)

declare -a OPTIONAL_DEV_TOOLS=(
    "yq"            # YAML processor
    "gitleaks"      # Detect secrets in git repos
    "curlie"        # curl frontend with httpie syntax
    "ncdu"          # NCurses disk usage
    "age"           # Modern encryption tool
    "sops"          # Secrets management
    "dive"          # Docker image explorer
    "lazygit"       # Terminal UI for git
    "dust"          # Better du
    "procs"         # Modern ps replacement
    "bottom"        # System monitor
    "hyperfine"     # Benchmarking tool
    "tealdeer"      # Fast tldr client
    "starship"      # Cross-shell prompt
    "zoxide"        # Smarter cd command
)

# Install core development tools
install_core_dev_tools() {
    log_info "Installing core development tools..."
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            install_core_tools_brew
            ;;
        apt)
            install_core_tools_apt
            ;;
        dnf|yum)
            install_core_tools_dnf
            ;;
        pacman)
            install_core_tools_pacman
            ;;
        *)
            log_warning "Package manager $package_manager not fully supported"
            install_core_tools_fallback
            ;;
    esac
    
    log_success "Core development tools installation completed"
}

# Install core tools via Homebrew
install_core_tools_brew() {
    local tools=(
        "bat"
        "exa" 
        "fd"
        "ripgrep"
        "fzf"
        "jq"
        "git-delta"
        "gh"
        "httpie"
        "tree"
    )
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_info "Installing $tool..."
            brew install "$tool"
        else
            log_info "$tool is already installed"
        fi
    done
}

# Install core tools via APT
install_core_tools_apt() {
    # Update package list
    sudo apt-get update
    
    # Install available tools from repository
    local apt_tools=(
        "bat"
        "fd-find"       # fd is named fd-find on Ubuntu/Debian
        "ripgrep"
        "fzf"
        "jq"
        "tree"
        "httpie"
    )
    
    sudo apt-get install -y "${apt_tools[@]}"
    
    # Install tools not available in standard repos
    install_exa_linux
    install_git_delta_linux
    install_gh_linux_apt
}

# Install core tools via DNF/YUM
install_core_tools_dnf() {
    local dnf_tools=(
        "bat"
        "fd-find"
        "ripgrep" 
        "fzf"
        "jq"
        "tree"
    )
    
    sudo "$package_manager" install -y "${dnf_tools[@]}"
    
    # Install tools not available in standard repos
    install_exa_linux
    install_git_delta_linux
    install_gh_linux_dnf
    install_httpie_python
}

# Install core tools via Pacman
install_core_tools_pacman() {
    local pacman_tools=(
        "bat"
        "exa"
        "fd"
        "ripgrep"
        "fzf"
        "jq"
        "git-delta"
        "tree"
        "httpie"
    )
    
    sudo pacman -S --noconfirm "${pacman_tools[@]}"
    
    # Install GitHub CLI
    install_gh_linux_pacman
}

# Fallback installation for unsupported package managers
install_core_tools_fallback() {
    log_info "Using fallback installation methods..."
    
    # Install tools via alternative methods
    install_exa_linux
    install_git_delta_linux
    install_fzf_git
    install_httpie_python
    
    log_warning "Some tools may not be available. Consider using a supported package manager."
}

# Install exa on Linux
install_exa_linux() {
    if command -v exa >/dev/null 2>&1; then
        log_info "exa is already installed"
        return 0
    fi
    
    log_info "Installing exa..."
    
    local os_type arch
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    # Convert architecture for exa naming
    case "$arch" in
        x86_64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        *) 
            log_warning "Unsupported architecture for exa: $arch"
            return 1
            ;;
    esac
    
    local download_url="https://github.com/ogham/exa/releases/latest/download/exa-linux-${arch}-musl-v0.10.1.zip"
    local temp_dir
    temp_dir=$(create_temp_dir "exa")
    
    if download_file "$download_url" "$temp_dir/exa.zip" "Downloading exa"; then
        cd "$temp_dir"
        unzip -q exa.zip
        sudo mv bin/exa /usr/local/bin/
        sudo chmod +x /usr/local/bin/exa
        cd - >/dev/null
        rm -rf "$temp_dir"
        log_success "exa installed via direct download"
    else
        log_warning "Failed to download exa"
        return 1
    fi
}

# Install git-delta on Linux
install_git_delta_linux() {
    if command -v delta >/dev/null 2>&1; then
        log_info "git-delta is already installed"
        return 0
    fi
    
    log_info "Installing git-delta..."
    
    local arch
    arch=$(detect_architecture)
    
    # Convert architecture for git-delta naming
    case "$arch" in
        x86_64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        *) 
            log_warning "Unsupported architecture for git-delta: $arch"
            return 1
            ;;
    esac
    
    # Get latest release
    local api_url="https://api.github.com/repos/dandavison/delta/releases/latest"
    local download_url
    download_url=$(curl -s "$api_url" | grep browser_download_url | grep "linux" | grep "${arch}" | grep -v "musl" | head -1 | cut -d'"' -f4)
    
    if [[ -n "$download_url" ]]; then
        local temp_dir
        temp_dir=$(create_temp_dir "git-delta")
        
        if download_file "$download_url" "$temp_dir/git-delta.tar.gz" "Downloading git-delta"; then
            cd "$temp_dir"
            tar -xzf git-delta.tar.gz
            sudo mv delta-*/delta /usr/local/bin/
            sudo chmod +x /usr/local/bin/delta
            cd - >/dev/null
            rm -rf "$temp_dir"
            log_success "git-delta installed via direct download"
        else
            log_warning "Failed to download git-delta"
            return 1
        fi
    else
        log_warning "Could not find download URL for git-delta"
        return 1
    fi
}

# Install GitHub CLI on Ubuntu/Debian
install_gh_linux_apt() {
    if command -v gh >/dev/null 2>&1; then
        log_info "GitHub CLI is already installed"
        return 0
    fi
    
    log_info "Installing GitHub CLI..."
    
    # Add GitHub CLI repository
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y gh
    
    log_success "GitHub CLI installed via APT"
}

# Install GitHub CLI on Fedora/CentOS
install_gh_linux_dnf() {
    if command -v gh >/dev/null 2>&1; then
        log_info "GitHub CLI is already installed"
        return 0
    fi
    
    log_info "Installing GitHub CLI..."
    
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
    
    log_success "GitHub CLI installed via DNF"
}

# Install GitHub CLI on Arch Linux
install_gh_linux_pacman() {
    if command -v gh >/dev/null 2>&1; then
        log_info "GitHub CLI is already installed"
        return 0
    fi
    
    log_info "Installing GitHub CLI..."
    sudo pacman -S --noconfirm github-cli
    log_success "GitHub CLI installed via Pacman"
}

# Install fzf from Git
install_fzf_git() {
    if command -v fzf >/dev/null 2>&1; then
        log_info "fzf is already installed"
        return 0
    fi
    
    log_info "Installing fzf from Git..."
    
    local fzf_dir="$HOME/.fzf"
    
    if [[ -d "$fzf_dir" ]]; then
        log_info "Updating existing fzf installation..."
        cd "$fzf_dir"
        git pull
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
        cd "$fzf_dir"
    fi
    
    # Install fzf
    ./install --all
    
    log_success "fzf installed from Git"
}

# Install HTTPie via Python pip
install_httpie_python() {
    if command -v http >/dev/null 2>&1; then
        log_info "HTTPie is already installed"
        return 0
    fi
    
    log_info "Installing HTTPie via pip..."
    
    # Check if pip is available
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user httpie
        log_success "HTTPie installed via pip3"
    elif command -v pip >/dev/null 2>&1; then
        pip install --user httpie
        log_success "HTTPie installed via pip"
    else
        log_warning "pip not available, skipping HTTPie installation"
        return 1
    fi
}

# Install optional development tools
install_optional_dev_tools() {
    log_info "Installing optional development tools..."
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            install_optional_tools_brew
            ;;
        apt)
            install_optional_tools_apt
            ;;
        dnf|yum)
            install_optional_tools_dnf
            ;;
        pacman)
            install_optional_tools_pacman
            ;;
        *)
            log_warning "Package manager $package_manager not fully supported for optional tools"
            ;;
    esac
    
    log_success "Optional development tools installation completed"
}

# Install optional tools via Homebrew
install_optional_tools_brew() {
    local tools=(
        "yq"
        "gitleaks" 
        "ncdu"
        "dust"
        "procs"
        "bottom"
        "hyperfine"
        "tealdeer"
        "starship"
        "zoxide"
        "lazygit"
    )
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_info "Installing $tool..."
            brew install "$tool"
        else
            log_info "$tool is already installed"
        fi
    done
    
    # Install tools with different names
    if ! command -v age >/dev/null 2>&1; then
        brew install age
    fi
    
    if ! command -v sops >/dev/null 2>&1; then
        brew install sops
    fi
}

# Install optional tools via APT
install_optional_tools_apt() {
    local apt_tools=(
        "ncdu"
    )
    
    sudo apt-get install -y "${apt_tools[@]}"
    
    # Install Rust-based tools via cargo if available
    if command -v cargo >/dev/null 2>&1; then
        install_rust_tools_cargo
    fi
}

# Install optional tools via DNF/YUM
install_optional_tools_dnf() {
    local dnf_tools=(
        "ncdu"
    )
    
    sudo "$package_manager" install -y "${dnf_tools[@]}"
    
    # Install additional tools via cargo if available
    if command -v cargo >/dev/null 2>&1; then
        install_rust_tools_cargo
    fi
}

# Install optional tools via Pacman
install_optional_tools_pacman() {
    local pacman_tools=(
        "dust"
        "procs"
        "bottom"
        "hyperfine"
        "tealdeer"
        "starship"
        "zoxide"
        "ncdu"
    )
    
    sudo pacman -S --noconfirm "${pacman_tools[@]}"
}

# Install Rust-based tools via Cargo
install_rust_tools_cargo() {
    log_info "Installing Rust-based tools via Cargo..."
    
    local cargo_tools=(
        "dust"
        "procs"
        "bottom"
        "hyperfine"
        "tealdeer"
        "starship"
        "zoxide"
    )
    
    for tool in "${cargo_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_info "Installing $tool via Cargo..."
            cargo install "$tool"
        fi
    done
}

# Show development tools status
show_dev_tools_status() {
    log_info "Development Tools Status:"
    
    # Core tools
    log_info "  Core Tools:"
    for tool in "${CORE_DEV_TOOLS[@]}"; do
        local cmd="$tool"
        
        # Handle special cases
        case "$tool" in
            "git-delta") cmd="delta" ;;
            "ripgrep") cmd="rg" ;;
        esac
        
        if command -v "$cmd" >/dev/null 2>&1; then
            local version="unknown"
            case "$tool" in
                "bat") version=$($cmd --version | cut -d' ' -f2) ;;
                "exa") version=$($cmd --version | cut -d' ' -f2) ;;
                "fd") version=$($cmd --version | cut -d' ' -f2) ;;
                "ripgrep") version=$($cmd --version | head -1 | cut -d' ' -f2) ;;
                "jq") version=$($cmd --version | sed 's/jq-//') ;;
                "gh") version=$($cmd --version | cut -d' ' -f3) ;;
                *) version="installed" ;;
            esac
            log_info "    ${BULLET} $tool: $version"
        else
            log_warning "    ${BULLET} $tool: Not installed"
        fi
    done
}

# Main function
main() {
    local mode="${1:-install}"
    
    case "$mode" in
        install)
            install_core_dev_tools
            ;;
        optional)
            install_optional_dev_tools
            ;;
        all)
            install_core_dev_tools
            install_optional_dev_tools
            ;;
        status)
            show_dev_tools_status
            ;;
        *)
            echo "Usage: $0 {install|optional|all|status}"
            echo ""
            echo "Commands:"
            echo "  install   - Install core development tools"
            echo "  optional  - Install optional development tools"
            echo "  all       - Install all development tools"
            echo "  status    - Show development tools status"
            exit 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f install_core_dev_tools
export -f install_optional_dev_tools
export -f show_dev_tools_status

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 