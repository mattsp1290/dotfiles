#!/usr/bin/env bash
# ASDF Version Manager Installation Script
# Installs and configures ASDF for cross-platform version management

set -euo pipefail

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source libraries
source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"
source "$DOTFILES_ROOT/scripts/lib/utils.sh"

# ASDF configuration
readonly ASDF_VERSION="${ASDF_VERSION:-v0.14.0}"
readonly ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"
readonly ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"

# Plugin list for ASDF
declare -a CORE_PLUGINS=(
    "nodejs"
    "python" 
    "ruby"
    "golang"
    "terraform"
    "kubectl"
    "helm"
    "direnv"
    "jq"
    "yq"
)

declare -a OPTIONAL_PLUGINS=(
    "awscli"
    "gcloud"
    "azure-cli"
    "docker-compose"
    "gh"
    "git-delta"
)

# Check if ASDF is already installed
is_asdf_installed() {
    [[ -d "$ASDF_DIR" ]] && command -v asdf >/dev/null 2>&1
}

# Get ASDF version
get_asdf_version() {
    if command -v asdf >/dev/null 2>&1; then
        asdf version 2>/dev/null | cut -d' ' -f1 || echo "unknown"
    else
        echo "not_installed"
    fi
}

# Install ASDF
install_asdf() {
    local os_type
    os_type=$(detect_os_type)
    
    log_info "Installing ASDF version manager..."
    
    # Check if already installed
    if is_asdf_installed; then
        local current_version
        current_version=$(get_asdf_version)
        log_info "ASDF is already installed (version: $current_version)"
        return 0
    fi
    
    # Install ASDF based on OS
    case "$os_type" in
        macos)
            install_asdf_macos
            ;;
        linux)
            install_asdf_linux
            ;;
        *)
            log_error "ASDF installation not supported for OS: $os_type"
            return 1
            ;;
    esac
    
    # Verify installation
    if is_asdf_installed; then
        log_success "ASDF installed successfully"
    else
        log_error "ASDF installation failed"
        return 1
    fi
}

# Install ASDF on macOS
install_asdf_macos() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            log_info "Installing ASDF via Homebrew..."
            brew install asdf
            ;;
        *)
            log_info "Installing ASDF from Git..."
            install_asdf_from_git
            ;;
    esac
}

# Install ASDF on Linux
install_asdf_linux() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        apt)
            # Install dependencies
            sudo apt-get update
            sudo apt-get install -y curl git
            install_asdf_from_git
            ;;
        dnf|yum)
            # Install dependencies
            sudo "$package_manager" install -y curl git
            install_asdf_from_git
            ;;
        pacman)
            # Check if available in AUR or official repos
            if pacman -Si asdf-vm >/dev/null 2>&1; then
                sudo pacman -S --noconfirm asdf-vm
            else
                install_asdf_from_git
            fi
            ;;
        *)
            install_asdf_from_git
            ;;
    esac
}

# Install ASDF from Git
install_asdf_from_git() {
    log_info "Cloning ASDF from Git..."
    
    # Remove existing installation if present
    if [[ -d "$ASDF_DIR" ]]; then
        log_warning "Removing existing ASDF installation..."
        rm -rf "$ASDF_DIR"
    fi
    
    # Clone ASDF repository
    git clone https://github.com/asdf-vm/asdf.git "$ASDF_DIR" --branch "$ASDF_VERSION"
    
    # Set up environment for current session
    export PATH="$ASDF_DIR/bin:$PATH"
    source "$ASDF_DIR/asdf.sh"
}

# Install ASDF plugin
install_plugin() {
    local plugin_name="$1"
    
    log_info "Installing ASDF plugin: $plugin_name"
    
    # Check if plugin is already installed
    if asdf plugin list | grep -q "^${plugin_name}$"; then
        log_info "Plugin $plugin_name is already installed"
        return 0
    fi
    
    # Install the plugin
    if asdf plugin add "$plugin_name" 2>/dev/null; then
        log_success "Plugin $plugin_name installed"
    else
        log_warning "Failed to install plugin: $plugin_name"
        return 1
    fi
}

# Install core ASDF plugins
install_core_plugins() {
    log_info "Installing core ASDF plugins..."
    
    # Ensure ASDF is sourced
    if ! command -v asdf >/dev/null 2>&1; then
        source_asdf
    fi
    
    local failed_plugins=()
    
    for plugin in "${CORE_PLUGINS[@]}"; do
        if ! install_plugin "$plugin"; then
            failed_plugins+=("$plugin")
        fi
    done
    
    if [[ ${#failed_plugins[@]} -gt 0 ]]; then
        log_warning "Some core plugins failed to install: ${failed_plugins[*]}"
    else
        log_success "All core plugins installed successfully"
    fi
}

# Install optional ASDF plugins
install_optional_plugins() {
    log_info "Installing optional ASDF plugins..."
    
    # Ensure ASDF is sourced
    if ! command -v asdf >/dev/null 2>&1; then
        source_asdf
    fi
    
    local failed_plugins=()
    
    for plugin in "${OPTIONAL_PLUGINS[@]}"; do
        if ! install_plugin "$plugin"; then
            failed_plugins+=("$plugin")
        fi
    done
    
    if [[ ${#failed_plugins[@]} -gt 0 ]]; then
        log_warning "Some optional plugins failed to install: ${failed_plugins[*]}"
    else
        log_success "All optional plugins installed successfully"
    fi
}

# Source ASDF in current shell
source_asdf() {
    if [[ -f "$ASDF_DIR/asdf.sh" ]]; then
        source "$ASDF_DIR/asdf.sh"
        export PATH="$ASDF_DIR/bin:$PATH"
    elif command -v brew >/dev/null 2>&1 && [[ -f "$(brew --prefix asdf)/libexec/asdf.sh" ]]; then
        source "$(brew --prefix asdf)/libexec/asdf.sh"
    else
        log_error "Cannot find ASDF installation to source"
        return 1
    fi
}

# Install tools from .tool-versions file
install_tools_from_versions_file() {
    local versions_file="${1:-$DOTFILES_ROOT/tools/asdf/.tool-versions}"
    
    if [[ ! -f "$versions_file" ]]; then
        log_warning "Tool versions file not found: $versions_file"
        return 0
    fi
    
    log_info "Installing tools from versions file: $versions_file"
    
    # Ensure ASDF is sourced
    if ! command -v asdf >/dev/null 2>&1; then
        source_asdf
    fi
    
    # Copy the versions file to home directory if it doesn't exist
    if [[ ! -f "$HOME/.tool-versions" ]]; then
        cp "$versions_file" "$HOME/.tool-versions"
        log_info "Copied default .tool-versions to home directory"
    fi
    
    # Read and install each tool
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse tool name and version
        local tool_name version
        read -r tool_name version <<< "$line"
        
        if [[ -n "$tool_name" ]] && [[ -n "$version" ]]; then
            log_info "Installing $tool_name $version..."
            
            # Check if plugin is installed
            if ! asdf plugin list | grep -q "^${tool_name}$"; then
                log_warning "Plugin $tool_name not installed, skipping..."
                continue
            fi
            
            # Install the version
            if asdf install "$tool_name" "$version" 2>/dev/null; then
                log_success "Installed $tool_name $version"
            else
                log_warning "Failed to install $tool_name $version"
            fi
        fi
    done < "$versions_file"
    
    # Set global versions
    log_info "Setting global tool versions..."
    asdf global $(awk '!/^[[:space:]]*#/ && NF==2 {print $1" "$2}' "$versions_file")
}

# Setup shell integration
setup_shell_integration() {
    log_info "Setting up shell integration for ASDF..."
    
    local shell_configs=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    local asdf_init_script
    
    # Determine ASDF initialization script
    if command -v brew >/dev/null 2>&1 && [[ -f "$(brew --prefix asdf)/libexec/asdf.sh" ]]; then
        asdf_init_script="$(brew --prefix asdf)/libexec/asdf.sh"
    elif [[ -f "$ASDF_DIR/asdf.sh" ]]; then
        asdf_init_script="$ASDF_DIR/asdf.sh"
    else
        log_error "Cannot find ASDF initialization script"
        return 1
    fi
    
    # Add to shell configurations
    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            # Check if already added
            if grep -q "asdf.sh" "$config" 2>/dev/null; then
                log_info "ASDF already configured in $(basename "$config")"
                continue
            fi
            
            # Add ASDF initialization
            {
                echo ""
                echo "# ASDF version manager"
                echo "if [[ -f \"$asdf_init_script\" ]]; then"
                echo "    source \"$asdf_init_script\""
                echo "fi"
            } >> "$config"
            
            log_success "Added ASDF integration to $(basename "$config")"
        fi
    done
}

# Show ASDF status
show_asdf_status() {
    log_info "ASDF Status:"
    
    if ! command -v asdf >/dev/null 2>&1; then
        source_asdf || {
            log_error "ASDF not found or not properly installed"
            return 1
        }
    fi
    
    # Show version
    local version
    version=$(get_asdf_version)
    log_info "  ${BULLET} Version: $version"
    
    # Show installed plugins
    log_info "  ${BULLET} Installed plugins:"
    while IFS= read -r plugin; do
        log_info "    - $plugin"
    done < <(asdf plugin list 2>/dev/null || echo "None")
    
    # Show current tool versions
    log_info "  ${BULLET} Current tool versions:"
    asdf current 2>/dev/null | sed 's/^/    /' || log_info "    None set"
}

# Main function
main() {
    local mode="${1:-install}"
    
    case "$mode" in
        install)
            install_asdf
            install_core_plugins
            setup_shell_integration
            install_tools_from_versions_file
            ;;
        plugins)
            install_core_plugins
            ;;
        optional)
            install_optional_plugins
            ;;
        status)
            show_asdf_status
            ;;
        *)
            echo "Usage: $0 {install|plugins|optional|status}"
            echo ""
            echo "Commands:"
            echo "  install   - Install ASDF, core plugins, and tools"
            echo "  plugins   - Install core plugins only"
            echo "  optional  - Install optional plugins"
            echo "  status    - Show ASDF status"
            exit 1
            ;;
    esac
}

# Export functions for use in other scripts (silenced to avoid startup output)
export -f is_asdf_installed >/dev/null 2>&1
export -f install_asdf >/dev/null 2>&1
export -f install_plugin >/dev/null 2>&1
export -f source_asdf >/dev/null 2>&1
export -f show_asdf_status >/dev/null 2>&1

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 