#!/usr/bin/env bash
# Cloud Tools Installation Script
# Installs AWS CLI, Google Cloud CLI, Azure CLI, and related cloud tools

set -euo pipefail

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source libraries
source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"
source "$DOTFILES_ROOT/scripts/lib/utils.sh"

# Cloud tools to install
declare -a CORE_CLOUD_TOOLS=(
    "aws"
    "terraform"
    "kubectl"
)

declare -a OPTIONAL_CLOUD_TOOLS=(
    "gcloud"
    "azure"
    "vault"
    "consul"
    "nomad"
)

# Install AWS CLI v2
install_aws_cli() {
    log_info "Installing AWS CLI v2..."
    
    # Check if already installed
    if command -v aws >/dev/null 2>&1; then
        local aws_version
        aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
        log_info "AWS CLI is already installed (version: $aws_version)"
        return 0
    fi
    
    local os_type arch
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    case "$os_type" in
        macos)
            install_aws_cli_macos "$arch"
            ;;
        linux)
            install_aws_cli_linux "$arch"
            ;;
        *)
            log_error "AWS CLI installation not supported for OS: $os_type"
            return 1
            ;;
    esac
}

# Install AWS CLI on macOS
install_aws_cli_macos() {
    local arch="$1"
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install awscli
            ;;
        *)
            # Direct installation
            local download_url
            if [[ "$arch" == "arm64" ]]; then
                download_url="https://awscli.amazonaws.com/AWSCLIV2-arm64.pkg"
            else
                download_url="https://awscli.amazonaws.com/AWSCLIV2.pkg"
            fi
            
            local temp_file="/tmp/AWSCLIV2.pkg"
            if download_file "$download_url" "$temp_file" "Downloading AWS CLI"; then
                sudo installer -pkg "$temp_file" -target /
                rm -f "$temp_file"
                log_success "AWS CLI installed via direct download"
            else
                log_error "Failed to download AWS CLI"
                return 1
            fi
            ;;
    esac
}

# Install AWS CLI on Linux
install_aws_cli_linux() {
    local arch="$1"
    local package_manager
    package_manager=$(detect_package_manager)
    
    # Convert architecture for AWS CLI naming
    case "$arch" in
        x86_64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        *) 
            log_error "Unsupported architecture for AWS CLI: $arch"
            return 1
            ;;
    esac
    
    case "$package_manager" in
        apt|dnf|yum)
            # Direct installation for most Linux distributions
            local download_url="https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"
            local temp_dir
            temp_dir=$(create_temp_dir "aws-cli")
            
            if download_file "$download_url" "$temp_dir/awscliv2.zip" "Downloading AWS CLI"; then
                cd "$temp_dir"
                unzip -q awscliv2.zip
                sudo ./aws/install
                cd - >/dev/null
                rm -rf "$temp_dir"
                log_success "AWS CLI installed via direct download"
            else
                log_error "Failed to download AWS CLI"
                return 1
            fi
            ;;
        pacman)
            # Use AUR package
            if command -v yay >/dev/null 2>&1; then
                yay -S --noconfirm aws-cli-v2
            else
                log_warning "Consider installing yay for AUR package support"
                log_info "Installing AWS CLI via direct download instead..."
                install_aws_cli_linux_direct "$arch"
            fi
            ;;
        *)
            install_aws_cli_linux_direct "$arch"
            ;;
    esac
}

# Install AWS CLI via direct download on Linux
install_aws_cli_linux_direct() {
    local arch="$1"
    local download_url="https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"
    local temp_dir
    temp_dir=$(create_temp_dir "aws-cli")
    
    if download_file "$download_url" "$temp_dir/awscliv2.zip" "Downloading AWS CLI"; then
        cd "$temp_dir"
        unzip -q awscliv2.zip
        sudo ./aws/install
        cd - >/dev/null
        rm -rf "$temp_dir"
        log_success "AWS CLI installed via direct download"
    else
        log_error "Failed to download AWS CLI"
        return 1
    fi
}

# Install Google Cloud CLI
install_gcloud() {
    log_info "Installing Google Cloud CLI..."
    
    # Check if already installed
    if command -v gcloud >/dev/null 2>&1; then
        local gcloud_version
        gcloud_version=$(gcloud version --format="value(Google Cloud SDK)" 2>/dev/null || echo "unknown")
        log_info "Google Cloud CLI is already installed (version: $gcloud_version)"
        return 0
    fi
    
    local os_type package_manager
    os_type=$(detect_os_type)
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install --cask google-cloud-sdk
            ;;
        apt)
            install_gcloud_apt
            ;;
        dnf|yum)
            install_gcloud_yum
            ;;
        *)
            install_gcloud_direct
            ;;
    esac
}

# Install Google Cloud CLI on APT systems
install_gcloud_apt() {
    # Add Google Cloud repository
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
        sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    
    sudo apt-get update
    sudo apt-get install -y google-cloud-cli
    
    log_success "Google Cloud CLI installed via APT"
}

# Install Google Cloud CLI on YUM/DNF systems
install_gcloud_yum() {
    # Add Google Cloud repository
    cat <<EOF | sudo tee /etc/yum.repos.d/google-cloud-sdk.repo
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
    
    sudo "$package_manager" install -y google-cloud-cli
    
    log_success "Google Cloud CLI installed via YUM/DNF"
}

# Install Google Cloud CLI via direct download
install_gcloud_direct() {
    local os_type arch
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    # Convert architecture for Google Cloud CLI naming
    case "$arch" in
        x86_64) arch="x86_64" ;;
        arm64) arch="arm" ;;
        *) 
            log_error "Unsupported architecture for Google Cloud CLI: $arch"
            return 1
            ;;
    esac
    
    local download_url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-latest-${os_type}-${arch}.tar.gz"
    local install_dir="$HOME/google-cloud-sdk"
    local temp_dir
    temp_dir=$(create_temp_dir "gcloud")
    
    if download_file "$download_url" "$temp_dir/google-cloud-cli.tar.gz" "Downloading Google Cloud CLI"; then
        cd "$temp_dir"
        tar -xzf google-cloud-cli.tar.gz
        
        # Remove existing installation if present
        [[ -d "$install_dir" ]] && rm -rf "$install_dir"
        
        # Move to installation directory
        mv google-cloud-sdk "$install_dir"
        
        # Run installer
        "$install_dir/install.sh" --quiet --path-update=true --bash-completion=true
        
        cd - >/dev/null
        rm -rf "$temp_dir"
        
        log_success "Google Cloud CLI installed via direct download"
        log_info "Please restart your shell or run: source ~/.bashrc"
    else
        log_error "Failed to download Google Cloud CLI"
        return 1
    fi
}

# Install Azure CLI
install_azure_cli() {
    log_info "Installing Azure CLI..."
    
    # Check if already installed
    if command -v az >/dev/null 2>&1; then
        local azure_version
        azure_version=$(az version --output tsv --query '"azure-cli"' 2>/dev/null || echo "unknown")
        log_info "Azure CLI is already installed (version: $azure_version)"
        return 0
    fi
    
    local os_type package_manager
    os_type=$(detect_os_type)
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew install azure-cli
            ;;
        apt)
            install_azure_cli_apt
            ;;
        dnf|yum)
            install_azure_cli_yum
            ;;
        *)
            install_azure_cli_script
            ;;
    esac
}

# Install Azure CLI on APT systems
install_azure_cli_apt() {
    # Get Ubuntu/Debian codename
    local codename
    codename=$(lsb_release -cs)
    
    # Add Microsoft repository
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    
    log_success "Azure CLI installed via APT"
}

# Install Azure CLI on YUM/DNF systems
install_azure_cli_yum() {
    # Add Microsoft repository
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    
    cat <<EOF | sudo tee /etc/yum.repos.d/azure-cli.repo
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    
    sudo "$package_manager" install -y azure-cli
    
    log_success "Azure CLI installed via YUM/DNF"
}

# Install Azure CLI via installation script
install_azure_cli_script() {
    curl -L https://aka.ms/InstallAzureCli | bash
    log_success "Azure CLI installed via installation script"
}

# Install Terraform
install_terraform() {
    log_info "Installing Terraform..."
    
    # Check if already installed
    if command -v terraform >/dev/null 2>&1; then
        local terraform_version
        terraform_version=$(terraform version -json | jq -r .terraform_version 2>/dev/null || terraform version | head -1 | cut -d' ' -f2)
        log_info "Terraform is already installed (version: $terraform_version)"
        return 0
    fi
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        brew)
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
            ;;
        apt)
            install_terraform_apt
            ;;
        dnf|yum)
            install_terraform_yum
            ;;
        *)
            install_terraform_direct
            ;;
    esac
}

# Install Terraform on APT systems
install_terraform_apt() {
    # Add HashiCorp repository
    wget -O- https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor | \
        sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    sudo apt-get update
    sudo apt-get install -y terraform
    
    log_success "Terraform installed via APT"
}

# Install Terraform on YUM/DNF systems
install_terraform_yum() {
    # Add HashiCorp repository
    sudo "$package_manager" install -y dnf-plugins-core
    sudo "$package_manager" config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    sudo "$package_manager" install -y terraform
    
    log_success "Terraform installed via YUM/DNF"
}

# Install Terraform via direct download
install_terraform_direct() {
    local os_type arch
    os_type=$(detect_os_type)
    arch=$(detect_architecture)
    
    # Convert architecture for Terraform naming
    case "$arch" in
        x86_64) arch="amd64" ;;
        arm64) arch="arm64" ;;
        *) 
            log_error "Unsupported architecture for Terraform: $arch"
            return 1
            ;;
    esac
    
    # Get latest version
    local version
    version=$(curl -s https://api.releases.hashicorp.com/v1/releases/terraform | jq -r '.[0].version')
    
    local download_url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${os_type}_${arch}.zip"
    local temp_dir
    temp_dir=$(create_temp_dir "terraform")
    
    if download_file "$download_url" "$temp_dir/terraform.zip" "Downloading Terraform"; then
        cd "$temp_dir"
        unzip -q terraform.zip
        sudo mv terraform /usr/local/bin/
        sudo chmod +x /usr/local/bin/terraform
        cd - >/dev/null
        rm -rf "$temp_dir"
        
        log_success "Terraform installed via direct download"
    else
        log_error "Failed to download Terraform"
        return 1
    fi
}

# Show cloud tools status
show_cloud_status() {
    log_info "Cloud Tools Status:"
    
    # AWS CLI
    if command -v aws >/dev/null 2>&1; then
        local aws_version
        aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
        log_info "  ${BULLET} AWS CLI: $aws_version"
    else
        log_warning "  ${BULLET} AWS CLI: Not installed"
    fi
    
    # Google Cloud CLI
    if command -v gcloud >/dev/null 2>&1; then
        local gcloud_version
        gcloud_version=$(gcloud version --format="value(Google Cloud SDK)" 2>/dev/null || echo "unknown")
        log_info "  ${BULLET} Google Cloud CLI: $gcloud_version"
    else
        log_warning "  ${BULLET} Google Cloud CLI: Not installed"
    fi
    
    # Azure CLI
    if command -v az >/dev/null 2>&1; then
        local azure_version
        azure_version=$(az version --output tsv --query '"azure-cli"' 2>/dev/null || echo "unknown")
        log_info "  ${BULLET} Azure CLI: $azure_version"
    else
        log_warning "  ${BULLET} Azure CLI: Not installed"
    fi
    
    # Terraform
    if command -v terraform >/dev/null 2>&1; then
        local terraform_version
        terraform_version=$(terraform version -json | jq -r .terraform_version 2>/dev/null || terraform version | head -1 | cut -d' ' -f2)
        log_info "  ${BULLET} Terraform: $terraform_version"
    else
        log_warning "  ${BULLET} Terraform: Not installed"
    fi
}

# Main function
main() {
    local mode="${1:-install}"
    
    case "$mode" in
        install)
            install_aws_cli
            install_terraform
            ;;
        all)
            install_aws_cli
            install_gcloud
            install_azure_cli
            install_terraform
            ;;
        aws)
            install_aws_cli
            ;;
        gcloud)
            install_gcloud
            ;;
        azure)
            install_azure_cli
            ;;
        terraform)
            install_terraform
            ;;
        status)
            show_cloud_status
            ;;
        *)
            echo "Usage: $0 {install|all|aws|gcloud|azure|terraform|status}"
            echo ""
            echo "Commands:"
            echo "  install    - Install core cloud tools (AWS CLI, Terraform)"
            echo "  all        - Install all cloud tools"
            echo "  aws        - Install AWS CLI only"
            echo "  gcloud     - Install Google Cloud CLI only"
            echo "  azure      - Install Azure CLI only"
            echo "  terraform  - Install Terraform only"
            echo "  status     - Show cloud tools status"
            exit 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f install_aws_cli
export -f install_gcloud
export -f install_azure_cli
export -f install_terraform
export -f show_cloud_status

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 