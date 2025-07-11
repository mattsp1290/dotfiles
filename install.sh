#!/usr/bin/env bash
# Dotfiles Installation Script
# This script downloads and runs the bootstrap script for dotfiles installation
# Can be run with: curl -fsSL https://raw.githubusercontent.com/[username]/dotfiles/main/install.sh | bash

set -euo pipefail

# Configuration
readonly INSTALL_VERSION="1.0.0"
readonly DEFAULT_REPO="https://github.com/$(whoami)/dotfiles.git"
readonly DEFAULT_BRANCH="main"
readonly INSTALL_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Colors (if terminal supports them)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

# Simple logging functions
info() {
    echo "${BLUE}[INFO]${RESET} $*"
}

success() {
    echo "${GREEN}[SUCCESS]${RESET} $*"
}

warning() {
    echo "${YELLOW}[WARNING]${RESET} $*" >&2
}

error() {
    echo "${RED}[ERROR]${RESET} $*" >&2
}

# Show usage
usage() {
    cat << EOF
Dotfiles Installation Script v${INSTALL_VERSION}

USAGE:
    curl -fsSL [URL]/install.sh | bash
    wget -qO- [URL]/install.sh | bash
    bash install.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -r, --repo URL         Repository URL (default: $DEFAULT_REPO)
    -b, --branch BRANCH    Branch to clone (default: $DEFAULT_BRANCH)
    -d, --directory DIR    Installation directory (default: $INSTALL_DIR)
    --dry-run              Show what would be done without making changes
    --skip-prerequisites   Skip prerequisite checking
    --offline              Run in offline mode (must have repo cloned)

ENVIRONMENT VARIABLES:
    DOTFILES_REPO_URL      Override default repository URL
    DOTFILES_BRANCH        Override default branch
    DOTFILES_DIR           Override installation directory

EXAMPLES:
    # Basic installation
    curl -fsSL https://example.com/install.sh | bash

    # Custom repository
    curl -fsSL https://example.com/install.sh | bash -s -- --repo https://github.com/user/dotfiles.git

    # Specific branch
    wget -qO- https://example.com/install.sh | bash -s -- --branch develop

EOF
}

# Parse command line arguments
parse_args() {
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--repo)
                REPO_URL="$2"
                shift 2
                ;;
            -b|--branch)
                REPO_BRANCH="$2"
                shift 2
                ;;
            -d|--directory)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --dry-run|--skip-prerequisites|--offline)
                BOOTSTRAP_ARGS+=("$1")
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Download file
download() {
    local url="$1"
    local output="$2"
    
    if has_command curl; then
        curl -fsSL "$url" -o "$output"
    elif has_command wget; then
        wget -qO "$output" "$url"
    else
        error "Neither curl nor wget found. Please install one of them."
        return 1
    fi
}

# Detect OS
detect_os() {
    case "$OSTYPE" in
        linux*)   echo "linux" ;;
        darwin*)  echo "macos" ;;
        *)        echo "unknown" ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check for bash
    if ! has_command bash; then
        error "Bash is required but not found"
        return 1
    fi
    
    # Check bash version (need 3.2+)
    local bash_version=$(bash --version | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    local major_version=${bash_version%%.*}
    local minor_version=${bash_version#*.}
    
    if [[ $major_version -lt 3 ]] || [[ $major_version -eq 3 && $minor_version -lt 2 ]]; then
        error "Bash 3.2 or higher is required (found $bash_version)"
        return 1
    fi
    
    # Check for git
    if ! has_command git; then
        warning "Git is not installed. It will be installed during setup."
    fi
    
    # Check OS
    local os=$(detect_os)
    if [[ "$os" == "unknown" ]]; then
        warning "Unknown operating system. Installation may not work correctly."
    else
        info "Detected OS: $os"
    fi
    
    success "Prerequisites check passed"
    return 0
}

# Clone repository
clone_repository() {
    local repo="$1"
    local branch="$2"
    local target="$3"
    
    info "Cloning repository..."
    info "  Repository: $repo"
    info "  Branch: $branch"
    info "  Directory: $target"
    
    if [[ -d "$target/.git" ]]; then
        warning "Repository already exists at $target"
        return 0
    fi
    
    if [[ -d "$target" ]]; then
        error "Directory $target exists but is not a git repository"
        return 1
    fi
    
    if has_command git; then
        git clone --branch "$branch" "$repo" "$target"
    else
        error "Git is required to clone the repository"
        error "Please install git and try again"
        return 1
    fi
    
    success "Repository cloned successfully"
}

# Main installation function
main() {
    echo ""
    echo "${BOLD}${BLUE}Dotfiles Installation Script v${INSTALL_VERSION}${RESET}"
    echo "${BOLD}${BLUE}========================================${RESET}"
    echo ""
    
    # Set defaults
    REPO_URL="${DOTFILES_REPO_URL:-$DEFAULT_REPO}"
    REPO_BRANCH="${DOTFILES_BRANCH:-$DEFAULT_BRANCH}"
    BOOTSTRAP_ARGS=()
    
    # Parse arguments
    parse_args "$@"
    
    # Check prerequisites
    if ! check_prerequisites; then
        error "Prerequisites check failed"
        exit 1
    fi
    
    # Handle offline mode
    if [[ " ${BOOTSTRAP_ARGS[*]} " =~ " --offline " ]]; then
        if [[ ! -d "$INSTALL_DIR/.git" ]]; then
            error "Offline mode requires repository to be already cloned at $INSTALL_DIR"
            exit 1
        fi
        info "Running in offline mode"
    else
        # Clone repository if needed
        if [[ ! -d "$INSTALL_DIR/.git" ]]; then
            if ! clone_repository "$REPO_URL" "$REPO_BRANCH" "$INSTALL_DIR"; then
                error "Failed to clone repository"
                exit 1
            fi
        else
            info "Using existing repository at $INSTALL_DIR"
        fi
    fi
    
    # Check if bootstrap script exists
    local bootstrap_script="$INSTALL_DIR/scripts/bootstrap.sh"
    if [[ ! -f "$bootstrap_script" ]]; then
        error "Bootstrap script not found at $bootstrap_script"
        error "The repository may be incomplete or corrupted"
        exit 1
    fi
    
    # Make bootstrap script executable
    chmod +x "$bootstrap_script"
    
    # Run bootstrap script
    info "Running bootstrap script..."
    echo ""
    
    # Change to repository directory and run bootstrap
    cd "$INSTALL_DIR"
    exec "$bootstrap_script" "${BOOTSTRAP_ARGS[@]}" install
}

# Handle script being piped
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    warning "This script should be executed, not sourced"
    return 1
fi

# Run main function
main "$@" 