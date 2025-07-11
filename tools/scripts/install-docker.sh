#!/usr/bin/env bash
# Docker and Container Tools Installation Script
# Installs Docker, Docker Compose, and Kubernetes tools across platforms

set -euo pipefail

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source libraries
source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"
source "$DOTFILES_ROOT/scripts/lib/utils.sh"

# Container tools configuration
declare -a CORE_CONTAINER_TOOLS=(
    "docker"
    "docker-compose"
    "kubectl"
    "helm"
)

declare -a OPTIONAL_CONTAINER_TOOLS=(
    "k9s"
    "kubectx"
    "kubens"
    "kustomize"
    "stern"
    "crane"
    "skopeo"
    "dive"
    "ctop"
)

# Check if Docker is installed and running
is_docker_installed() {
    command -v docker >/dev/null 2>&1
}

# Check if Docker daemon is running
is_docker_running() {
    docker info >/dev/null 2>&1
}

# Install Docker
install_docker() {
    local os_type
    os_type=$(detect_os_type)
    
    log_info "Installing Docker..."
    
    # Check if already installed
    if is_docker_installed; then
        local docker_version
        docker_version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        log_info "Docker is already installed (version: $docker_version)"
        return 0
    fi
    
    case "$os_type" in
        macos)
            install_docker_macos
            ;;
        linux)
            install_docker_linux
            ;;
        *)
            log_error "Docker installation not supported for OS: $os_type"
            return 1
            ;;
    esac
}

# Install Docker on macOS
install_docker_macos() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            log_info "Installing Docker Desktop via Homebrew..."
            brew install --cask docker
            log_success "Docker Desktop installed"
            log_info "Please start Docker Desktop manually from Applications"
            ;;
        *)
            log_warning "Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop"
            return 1
            ;;
    esac
}

# Install Docker on Linux
install_docker_linux() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        apt)
            install_docker_ubuntu_debian
            ;;
        dnf)
            install_docker_fedora
            ;;
        pacman)
            install_docker_arch
            ;;
        *)
            log_error "Docker installation not supported for package manager: $package_manager"
            return 1
            ;;
    esac
    
    # Start and enable Docker service
    setup_docker_service
}

# Install Docker on Ubuntu/Debian
install_docker_ubuntu_debian() {
    log_info "Installing Docker on Ubuntu/Debian..."
    
    # Update package index and install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker installed successfully"
}

# Install Docker on Fedora
install_docker_fedora() {
    log_info "Installing Docker on Fedora..."
    
    # Add Docker repository
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # Install Docker
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker installed successfully"
}

# Install Docker on Arch Linux
install_docker_arch() {
    log_info "Installing Docker on Arch Linux..."
    
    # Install Docker
    sudo pacman -S --noconfirm docker docker-compose
    
    log_success "Docker installed successfully"
}

# Setup Docker service on Linux
setup_docker_service() {
    log_info "Setting up Docker service..."
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    if ! groups | grep -q docker; then
        sudo usermod -aG docker "$USER"
        log_info "Added $USER to docker group"
        log_warning "Please log out and back in for group changes to take effect"
    fi
    
    log_success "Docker service configured"
}

# Install Docker Compose (standalone)
install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    # Check if already installed
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker-compose --version | cut -d' ' -f3 | sed 's/,//')
        log_info "Docker Compose is already installed (version: $compose_version)"
        return 0
    fi
    
    # Check if installed as Docker plugin
    if docker compose version >/dev/null 2>&1; then
        log_info "Docker Compose is installed as Docker plugin"
        return 0
    fi
    
    local os_type arch
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    # Convert architecture to Docker Compose naming
    case "$arch" in
        x86_64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        *) 
            log_error "Unsupported architecture for Docker Compose: $arch"
            return 1
            ;;
    esac
    
    # Download and install Docker Compose
    local compose_version="v2.26.1"
    local download_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-${os_type}-${arch}"
    local install_path="/usr/local/bin/docker-compose"
    
    log_info "Downloading Docker Compose $compose_version..."
    
    if sudo curl -L "$download_url" -o "$install_path"; then
        sudo chmod +x "$install_path"
        log_success "Docker Compose installed successfully"
    else
        log_error "Failed to download Docker Compose"
        return 1
    fi
}

# Install kubectl
install_kubectl() {
    log_info "Installing kubectl..."
    
    # Check if already installed
    if command -v kubectl >/dev/null 2>&1; then
        local kubectl_version
        kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        log_info "kubectl is already installed (version: $kubectl_version)"
        return 0
    fi
    
    local os_type arch package_manager
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install kubectl
            ;;
        apt)
            # Add Kubernetes repository
            curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
                sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
                sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install -y kubectl
            ;;
        dnf|yum)
            # Add Kubernetes repository
            cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
            sudo "$package_manager" install -y kubectl
            ;;
        pacman)
            sudo pacman -S --noconfirm kubectl
            ;;
        *)
            # Install via direct download
            install_kubectl_direct
            ;;
    esac
    
    log_success "kubectl installed successfully"
}

# Install kubectl via direct download
install_kubectl_direct() {
    local os_type arch
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    # Convert architecture to kubectl naming
    case "$arch" in
        x86_64) arch="amd64" ;;
        arm64) arch="arm64" ;;
        *) 
            log_error "Unsupported architecture for kubectl: $arch"
            return 1
            ;;
    esac
    
    local kubectl_version
    kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    local download_url="https://dl.k8s.io/release/${kubectl_version}/bin/${os_type}/${arch}/kubectl"
    local install_path="/usr/local/bin/kubectl"
    
    log_info "Downloading kubectl $kubectl_version..."
    
    if sudo curl -L "$download_url" -o "$install_path"; then
        sudo chmod +x "$install_path"
        log_success "kubectl installed via direct download"
    else
        log_error "Failed to download kubectl"
        return 1
    fi
}

# Install Helm
install_helm() {
    log_info "Installing Helm..."
    
    # Check if already installed
    if command -v helm >/dev/null 2>&1; then
        local helm_version
        helm_version=$(helm version --short 2>/dev/null | cut -d' ' -f1 | sed 's/v//' || echo "unknown")
        log_info "Helm is already installed (version: $helm_version)"
        return 0
    fi
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install helm
            ;;
        apt)
            curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
                sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
            sudo apt-get update
            sudo apt-get install -y helm
            ;;
        dnf)
            sudo dnf install -y helm
            ;;
        pacman)
            sudo pacman -S --noconfirm helm
            ;;
        *)
            # Install via script
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
    esac
    
    log_success "Helm installed successfully"
}

# Install optional container tools
install_optional_tools() {
    log_info "Installing optional container tools..."
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    # k9s - Kubernetes TUI
    if ! command -v k9s >/dev/null 2>&1; then
        case "$package_manager" in
            brew)
                brew install k9s
                ;;
            *)
                install_tool_from_github "derailed/k9s" "k9s"
                ;;
        esac
    fi
    
    # kubectx and kubens
    if ! command -v kubectx >/dev/null 2>&1; then
        case "$package_manager" in
            brew)
                brew install kubectx
                ;;
            apt)
                sudo apt-get install -y kubectx
                ;;
            *)
                install_tool_from_github "ahmetb/kubectx" "kubectx"
                install_tool_from_github "ahmetb/kubectx" "kubens"
                ;;
        esac
    fi
    
    # dive - Docker image explorer
    if ! command -v dive >/dev/null 2>&1; then
        case "$package_manager" in
            brew)
                brew install dive
                ;;
            *)
                install_tool_from_github "wagoodman/dive" "dive"
                ;;
        esac
    fi
    
    # ctop - Container metrics
    if ! command -v ctop >/dev/null 2>&1; then
        case "$package_manager" in
            brew)
                brew install ctop
                ;;
            *)
                install_tool_from_github "bcicen/ctop" "ctop"
                ;;
        esac
    fi
    
    log_success "Optional container tools installation completed"
}

# Install tool from GitHub releases
install_tool_from_github() {
    local repo="$1"
    local tool_name="$2"
    local os_type arch
    
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    log_info "Installing $tool_name from GitHub..."
    
    # Get latest release URL
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local download_url
    
    # This is a simplified approach - in practice, each tool may have different naming conventions
    case "$tool_name" in
        k9s)
            download_url=$(curl -s "$api_url" | grep browser_download_url | grep "${os_type}" | grep "${arch}" | head -1 | cut -d'"' -f4)
            ;;
        kubectx|kubens)
            download_url=$(curl -s "$api_url" | grep browser_download_url | grep "${tool_name}" | grep "${os_type}" | grep "${arch}" | head -1 | cut -d'"' -f4)
            ;;
        *)
            log_warning "GitHub installation not implemented for $tool_name"
            return 1
            ;;
    esac
    
    if [[ -n "$download_url" ]]; then
        local temp_file="/tmp/${tool_name}"
        if curl -L "$download_url" -o "$temp_file"; then
            sudo mv "$temp_file" "/usr/local/bin/$tool_name"
            sudo chmod +x "/usr/local/bin/$tool_name"
            log_success "$tool_name installed from GitHub"
        else
            log_error "Failed to download $tool_name"
            return 1
        fi
    else
        log_error "Could not find download URL for $tool_name"
        return 1
    fi
}

# Verify Docker installation
verify_docker() {
    log_info "Verifying Docker installation..."
    
    if ! is_docker_installed; then
        log_error "Docker is not installed"
        return 1
    fi
    
    # Test Docker functionality
    if is_docker_running; then
        if docker run --rm hello-world >/dev/null 2>&1; then
            log_success "Docker is working correctly"
        else
            log_warning "Docker is installed but not functioning properly"
            return 1
        fi
    else
        log_warning "Docker is installed but not running"
        log_info "Please start Docker manually"
    fi
}

# Show container tools status
show_container_status() {
    log_info "Container Tools Status:"
    
    # Docker
    if command -v docker >/dev/null 2>&1; then
        local docker_version
        docker_version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        log_info "  ${BULLET} Docker: $docker_version"
        
        if is_docker_running; then
            log_info "    Status: Running"
        else
            log_warning "    Status: Not running"
        fi
    else
        log_warning "  ${BULLET} Docker: Not installed"
    fi
    
    # Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker-compose --version | cut -d' ' -f3 | sed 's/,//')
        log_info "  ${BULLET} Docker Compose: $compose_version"
    elif docker compose version >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker compose version --short)
        log_info "  ${BULLET} Docker Compose (plugin): $compose_version"
    else
        log_warning "  ${BULLET} Docker Compose: Not installed"
    fi
    
    # kubectl
    if command -v kubectl >/dev/null 2>&1; then
        local kubectl_version
        kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        log_info "  ${BULLET} kubectl: $kubectl_version"
    else
        log_warning "  ${BULLET} kubectl: Not installed"
    fi
    
    # Helm
    if command -v helm >/dev/null 2>&1; then
        local helm_version
        helm_version=$(helm version --short 2>/dev/null | cut -d' ' -f1 | sed 's/v//' || echo "unknown")
        log_info "  ${BULLET} Helm: $helm_version"
    else
        log_warning "  ${BULLET} Helm: Not installed"
    fi
}

# Main function
main() {
    local mode="${1:-install}"
    
    case "$mode" in
        install)
            install_docker
            install_docker_compose
            install_kubectl
            install_helm
            verify_docker
            ;;
        optional)
            install_optional_tools
            ;;
        verify)
            verify_docker
            ;;
        status)
            show_container_status
            ;;
        *)
            echo "Usage: $0 {install|optional|verify|status}"
            echo ""
            echo "Commands:"
            echo "  install   - Install core container tools (Docker, kubectl, Helm)"
            echo "  optional  - Install optional container tools (k9s, kubectx, etc.)"
            echo "  verify    - Verify Docker installation"
            echo "  status    - Show container tools status"
            exit 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f is_docker_installed
export -f is_docker_running
export -f install_docker
export -f install_docker_compose
export -f install_kubectl
export -f install_helm
export -f verify_docker
export -f show_container_status

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 