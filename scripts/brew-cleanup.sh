#!/usr/bin/env bash

# Homebrew Cleanup and Maintenance Script
# Clean up Homebrew packages, cache, and manage dependencies

set -euo pipefail

# Script directory and root directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$DOTFILES_ROOT/os/macos"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is only supported on macOS"
        exit 1
    fi
}

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is not installed"
        exit 1
    fi
}

# Show disk usage before cleanup
show_usage_before() {
    log_info "Homebrew disk usage before cleanup:"
    
    if [[ -d "$(brew --cache)" ]]; then
        local cache_size=$(du -sh "$(brew --cache)" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  Cache: $cache_size"
    fi
    
    if [[ -d "$(brew --prefix)/Cellar" ]]; then
        local cellar_size=$(du -sh "$(brew --prefix)/Cellar" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  Cellar: $cellar_size"
    fi
    
    if [[ -d "$(brew --prefix)/Caskroom" ]]; then
        local caskroom_size=$(du -sh "$(brew --prefix)/Caskroom" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  Caskroom: $caskroom_size"
    fi
}

# Show disk usage after cleanup
show_usage_after() {
    log_success "Homebrew disk usage after cleanup:"
    
    if [[ -d "$(brew --cache)" ]]; then
        local cache_size=$(du -sh "$(brew --cache)" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  Cache: $cache_size"
    fi
    
    if [[ -d "$(brew --prefix)/Cellar" ]]; then
        local cellar_size=$(du -sh "$(brew --prefix)/Cellar" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  Cellar: $cellar_size"
    fi
    
    if [[ -d "$(brew --prefix)/Caskroom" ]]; then
        local caskroom_size=$(du -sh "$(brew --prefix)/Caskroom" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  Caskroom: $caskroom_size"
    fi
}

# Basic cleanup - safe operations
basic_cleanup() {
    log_info "Performing basic Homebrew cleanup..."
    
    # Remove old versions of installed packages
    log_info "Removing outdated package versions..."
    brew cleanup --prune=all
    
    # Remove unused dependencies
    log_info "Removing unused dependencies..."
    brew autoremove
    
    # Clean up cache for uninstalled packages
    log_info "Cleaning cache for uninstalled packages..."
    brew cleanup --prune-prefix
    
    log_success "Basic cleanup completed"
}

# Deep cleanup - more aggressive operations
deep_cleanup() {
    log_warning "Performing deep cleanup - this may take longer..."
    
    # Basic cleanup first
    basic_cleanup
    
    # Remove all cached downloads
    log_info "Removing all cached downloads..."
    rm -rf "$(brew --cache)"/*
    
    # Clean up temporary files
    log_info "Cleaning temporary files..."
    brew cleanup --prune=0
    
    # Clean up repository clones
    log_info "Cleaning repository clones..."
    rm -rf "$(brew --repository)/.git/objects/pack/*.pack"
    
    log_success "Deep cleanup completed"
}

# Show packages not in Brewfiles
show_orphaned_packages() {
    local core_brewfile="$MACOS_DIR/Brewfile"
    local optional_brewfile="$MACOS_DIR/Brewfile.optional"
    
    log_info "Checking for packages not managed by Brewfiles..."
    
    # Get currently installed packages
    local installed_formulae=$(brew list --formulae)
    local installed_casks=$(brew list --casks)
    
    # Get packages from Brewfiles
    local brewfile_formulae=""
    local brewfile_casks=""
    
    if [[ -f "$core_brewfile" ]]; then
        brewfile_formulae+=" $(grep '^brew ' "$core_brewfile" | sed 's/brew "//' | sed 's/".*//' | tr '\n' ' ')"
    fi
    
    if [[ -f "$optional_brewfile" ]]; then
        brewfile_formulae+=" $(grep '^brew ' "$optional_brewfile" | sed 's/brew "//' | sed 's/".*//' | tr '\n' ' ')"
    fi
    
    if [[ -f "$core_brewfile" ]]; then
        brewfile_casks+=" $(grep '^cask ' "$core_brewfile" | sed 's/cask "//' | sed 's/".*//' | tr '\n' ' ')"
    fi
    
    if [[ -f "$optional_brewfile" ]]; then
        brewfile_casks+=" $(grep '^cask ' "$optional_brewfile" | sed 's/cask "//' | sed 's/".*//' | tr '\n' ' ')"
    fi
    
    # Find orphaned formulae
    local orphaned_formulae=""
    for formula in $installed_formulae; do
        if [[ "$brewfile_formulae" != *" $formula "* ]]; then
            orphaned_formulae+="$formula "
        fi
    done
    
    # Find orphaned casks
    local orphaned_casks=""
    for cask in $installed_casks; do
        if [[ "$brewfile_casks" != *" $cask "* ]]; then
            orphaned_casks+="$cask "
        fi
    done
    
    if [[ -n "$orphaned_formulae" ]]; then
        log_warning "Formulae not in Brewfiles:"
        for formula in $orphaned_formulae; do
            echo "  • $formula"
        done
    fi
    
    if [[ -n "$orphaned_casks" ]]; then
        log_warning "Casks not in Brewfiles:"
        for cask in $orphaned_casks; do
            echo "  • $cask"
        done
    fi
    
    if [[ -z "$orphaned_formulae" && -z "$orphaned_casks" ]]; then
        log_success "All installed packages are managed by Brewfiles"
    fi
}

# Remove packages not in Brewfiles
remove_orphaned_packages() {
    local core_brewfile="$MACOS_DIR/Brewfile"
    local optional_brewfile="$MACOS_DIR/Brewfile.optional"
    
    log_warning "This will remove packages not managed by your Brewfiles!"
    log_warning "Make sure you've backed up any important data first."
    
    # Show what would be removed
    show_orphaned_packages
    
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        return 0
    fi
    
    # Implementation would go here - for safety, just show what would be done
    log_info "This feature is intentionally not implemented for safety"
    log_info "Please manually review and remove packages as needed"
}

# Health check
health_check() {
    log_info "Running Homebrew health check..."
    
    # Run brew doctor
    if brew doctor; then
        log_success "Homebrew health check passed"
    else
        log_warning "Homebrew health check found issues - see output above"
    fi
    
    # Check for missing dependencies
    log_info "Checking for missing dependencies..."
    brew missing
    
    # Check for oudated packages
    local outdated=$(brew outdated)
    if [[ -n "$outdated" ]]; then
        log_warning "Outdated packages found:"
        echo "$outdated"
        echo
        log_info "Run 'brew upgrade' or '$SCRIPT_DIR/brew-install.sh --update' to update"
    else
        log_success "All packages are up to date"
    fi
}

# Show statistics
show_statistics() {
    log_info "Homebrew statistics:"
    
    local formulae_count=$(brew list --formulae | wc -l | tr -d ' ')
    local casks_count=$(brew list --casks | wc -l | tr -d ' ')
    local services_count=$(brew services list | grep -c started || echo "0")
    local outdated_count=$(brew outdated | wc -l | tr -d ' ')
    
    echo "  Formulae installed: $formulae_count"
    echo "  Casks installed: $casks_count"
    echo "  Services running: $services_count"
    echo "  Outdated packages: $outdated_count"
    
    # Show top-level packages (not dependencies)
    log_info "Top-level packages (not dependencies):"
    brew leaves | head -10 | sed 's/^/  • /'
    
    if [[ $(brew leaves | wc -l) -gt 10 ]]; then
        echo "  ... and $(($(brew leaves | wc -l) - 10)) more"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Clean up and maintain Homebrew installation.

OPTIONS:
    -b, --basic         Basic cleanup (default) - remove old versions and unused deps
    -d, --deep          Deep cleanup - remove all cache and temporary files
    -o, --orphaned      Show packages not managed by Brewfiles
    -r, --remove        Remove packages not in Brewfiles (interactive)
    -c, --check         Run health check and show diagnostics
    -s, --stats         Show Homebrew statistics
    -a, --all           Run all cleanup operations
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Basic cleanup
    $0 --deep           # Deep cleanup with cache removal
    $0 --orphaned       # Show unmanaged packages
    $0 --check          # Run health check
    $0 --all            # Run all operations

EOF
}

# Parse command line arguments
BASIC_CLEANUP=false
DEEP_CLEANUP=false
SHOW_ORPHANED=false
REMOVE_ORPHANED=false
HEALTH_CHECK=false
SHOW_STATS=false
RUN_ALL=false

# Default to basic cleanup if no arguments
if [[ $# -eq 0 ]]; then
    BASIC_CLEANUP=true
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--basic)
            BASIC_CLEANUP=true
            shift
            ;;
        -d|--deep)
            DEEP_CLEANUP=true
            shift
            ;;
        -o|--orphaned)
            SHOW_ORPHANED=true
            shift
            ;;
        -r|--remove)
            REMOVE_ORPHANED=true
            shift
            ;;
        -c|--check)
            HEALTH_CHECK=true
            shift
            ;;
        -s|--stats)
            SHOW_STATS=true
            shift
            ;;
        -a|--all)
            RUN_ALL=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 Homebrew Cleanup & Maintenance              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check environment
    check_macos
    check_homebrew
    
    # Show usage before cleanup
    show_usage_before
    echo
    
    if [[ "$RUN_ALL" == true ]]; then
        # Run all operations
        deep_cleanup
        echo
        show_orphaned_packages
        echo
        health_check
        echo
        show_statistics
        
    else
        # Run individual operations
        if [[ "$BASIC_CLEANUP" == true ]]; then
            basic_cleanup
            echo
        fi
        
        if [[ "$DEEP_CLEANUP" == true ]]; then
            deep_cleanup
            echo
        fi
        
        if [[ "$SHOW_ORPHANED" == true ]]; then
            show_orphaned_packages
            echo
        fi
        
        if [[ "$REMOVE_ORPHANED" == true ]]; then
            remove_orphaned_packages
            echo
        fi
        
        if [[ "$HEALTH_CHECK" == true ]]; then
            health_check
            echo
        fi
        
        if [[ "$SHOW_STATS" == true ]]; then
            show_statistics
            echo
        fi
    fi
    
    # Show usage after cleanup
    if [[ "$BASIC_CLEANUP" == true || "$DEEP_CLEANUP" == true || "$RUN_ALL" == true ]]; then
        show_usage_after
        echo
    fi
    
    log_success "Homebrew maintenance completed!"
}

# Handle script interruption
trap 'echo -e "\n${RED}Operation interrupted by user${NC}"; exit 130' INT

# Run main function
main "$@" 