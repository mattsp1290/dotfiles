#!/usr/bin/env bash
# Test Bootstrap Script for Minimal Dotfiles Configuration
# Used in integration testing to simulate real dotfiles installation

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
if [[ -t 1 ]]; then
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

# Logging functions
info() {
    echo "${BLUE}[INFO]${RESET} $*"
}

success() {
    echo "${GREEN}[SUCCESS]${RESET} $*"
}

warning() {
    echo "${YELLOW}[WARNING]${RESET} $*"
}

error() {
    echo "${RED}[ERROR]${RESET} $*" >&2
}

# Show usage
usage() {
    cat << EOF
Test Bootstrap Script for Minimal Dotfiles

USAGE:
    $0 [OPTIONS] COMMAND

COMMANDS:
    install     Install dotfiles configuration
    doctor      Check system and configuration
    uninstall   Remove dotfiles configuration

OPTIONS:
    -h, --help              Show this help message
    --dry-run               Show what would be done without making changes
    --verbose               Enable verbose output

EXAMPLES:
    $0 install              # Install dotfiles
    $0 --dry-run install    # Preview installation
    $0 doctor               # Check system status

EOF
}

# Check system status
check_system() {
    info "Checking system status..."
    
    # Check for required tools
    local required_tools=(git stow)
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check current directory
    info "Current directory: $(pwd)"
    info "Dotfiles root: $DOTFILES_ROOT"
    
    # Check version
    if [[ -f "$DOTFILES_ROOT/.version" ]]; then
        local version=$(cat "$DOTFILES_ROOT/.version")
        info "Configuration version: $version"
    fi
    
    success "System check completed"
    return 0
}

# Install dotfiles
install_dotfiles() {
    local dry_run="${1:-false}"
    
    info "Starting dotfiles installation..."
    
    if [[ "$dry_run" == "true" ]]; then
        info "DRY RUN MODE: No changes will be made"
    fi
    
    # Check for existing configurations
    local config_files=(.vimrc .zshrc .gitconfig .tmux.conf)
    local existing_files=()
    
    for file in "${config_files[@]}"; do
        if [[ -f "$HOME/$file" ]]; then
            existing_files+=("$file")
        fi
    done
    
    if [[ ${#existing_files[@]} -gt 0 ]]; then
        warning "Found existing configuration files: ${existing_files[*]}"
        if [[ "$dry_run" == "true" ]]; then
            info "Would backup existing files"
        else
            # In real scenario, would backup files
            info "Backing up existing files..."
        fi
    fi
    
    # Stow packages
    local packages=(vim zsh git tmux)
    
    for package in "${packages[@]}"; do
        if [[ -d "$DOTFILES_ROOT/$package" ]]; then
            info "Installing $package configuration..."
            
            if [[ "$dry_run" == "true" ]]; then
                info "Would run: stow -t $HOME $package"
            else
                # In real scenario, would run stow
                info "Simulating: stow -t $HOME $package"
            fi
        fi
    done
    
    # Process templates
    if [[ -d "$DOTFILES_ROOT/templates" ]]; then
        info "Processing configuration templates..."
        
        local templates=($(find "$DOTFILES_ROOT/templates" -name "*.tmpl" 2>/dev/null || true))
        
        if [[ ${#templates[@]} -gt 0 ]]; then
            info "Found ${#templates[@]} template files"
            
            for template in "${templates[@]}"; do
                local output_file="${template%.tmpl}"
                output_file="$HOME/.${output_file##*/}"
                
                if [[ "$dry_run" == "true" ]]; then
                    info "Would process template: $(basename "$template")"
                else
                    info "Processing template: $(basename "$template")"
                    # In real scenario, would process template
                fi
            done
        fi
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        success "Dry run completed successfully"
    else
        success "Dotfiles installation completed"
    fi
}

# Doctor mode - check system and configuration
doctor_mode() {
    info "Running system diagnostics..."
    
    # Check system
    check_system
    
    # Check for common issues
    info "Checking for common issues..."
    
    # Check shell
    if [[ -n "${SHELL:-}" ]]; then
        info "Current shell: $SHELL"
    else
        warning "SHELL environment variable not set"
    fi
    
    # Check HOME directory
    if [[ -n "${HOME:-}" ]] && [[ -d "$HOME" ]]; then
        info "Home directory: $HOME"
    else
        error "Invalid HOME directory"
        return 1
    fi
    
    # Check permissions
    if [[ -w "$HOME" ]]; then
        info "Home directory is writable"
    else
        error "Home directory is not writable"
        return 1
    fi
    
    success "System diagnostics completed"
}

# Uninstall dotfiles
uninstall_dotfiles() {
    local dry_run="${1:-false}"
    
    info "Starting dotfiles uninstallation..."
    
    if [[ "$dry_run" == "true" ]]; then
        info "DRY RUN MODE: No changes will be made"
    fi
    
    # Unstow packages
    local packages=(vim zsh git tmux)
    
    for package in "${packages[@]}"; do
        if [[ -d "$DOTFILES_ROOT/$package" ]]; then
            info "Removing $package configuration..."
            
            if [[ "$dry_run" == "true" ]]; then
                info "Would run: stow -D -t $HOME $package"
            else
                info "Simulating: stow -D -t $HOME $package"
            fi
        fi
    done
    
    if [[ "$dry_run" == "true" ]]; then
        success "Uninstallation dry run completed"
    else
        success "Dotfiles uninstallation completed"
    fi
}

# Main function
main() {
    local dry_run=false
    local verbose=false
    local command=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --verbose)
                verbose=true
                set -x
                shift
                ;;
            install|doctor|uninstall)
                command="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate command
    if [[ -z "$command" ]]; then
        error "No command specified"
        usage
        exit 1
    fi
    
    # Execute command
    case "$command" in
        install)
            install_dotfiles "$dry_run"
            ;;
        doctor)
            doctor_mode
            ;;
        uninstall)
            uninstall_dotfiles "$dry_run"
            ;;
        *)
            error "Unknown command: $command"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 