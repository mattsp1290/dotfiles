#!/usr/bin/env bash

# =============================================================================
# Git Profile Management Utility
# =============================================================================
# This utility helps manage Git profiles and provides information about
# the current profile context

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Git Profile Management Utility

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    current         Show current Git profile context
    list            List all available profiles
    info PROFILE    Show information about a specific profile
    create DIR      Create a new profile directory
    validate        Validate profile configurations
    help            Show this help message

Profile Management:
    Git profiles are automatically selected based on repository location:
    
    ~/personal/*    -> Personal profile
    ~/work/*        -> Work profile  
    ~/opensource/*  -> Open source profile
    Other locations -> Default profile

Examples:
    $0 current              # Show current profile
    $0 list                 # List all profiles
    $0 info work            # Show work profile details
    $0 create ~/personal    # Create personal profile directory

EOF
}

# Detect current profile based on current directory
detect_current_profile() {
    local current_dir
    current_dir=$(pwd)
    
    case "$current_dir" in
        "$HOME/personal/"*) echo "personal" ;;
        "$HOME/work/"*) echo "work" ;;
        "$HOME/opensource/"*) echo "opensource" ;;
        *) echo "default" ;;
    esac
}

# Get profile configuration file path
get_profile_config_path() {
    local profile="$1"
    echo "$HOME/.config/git/includes/$profile.gitconfig"
}

# Check if profile configuration exists
profile_config_exists() {
    local profile="$1"
    local config_file
    config_file=$(get_profile_config_path "$profile")
    [[ -f "$config_file" ]]
}

# Show current profile information
show_current_profile() {
    log_info "Current Git Profile Context"
    echo "============================"
    
    local current_profile
    current_profile=$(detect_current_profile)
    
    echo "Current Directory: $(pwd)"
    echo "Active Profile: $current_profile"
    
    if [[ "$current_profile" != "default" ]]; then
        local config_file
        config_file=$(get_profile_config_path "$current_profile")
        if [[ -f "$config_file" ]]; then
            echo "Configuration File: $config_file ✓"
        else
            echo "Configuration File: $config_file ✗ (missing)"
        fi
    fi
    
    echo
    
    # Show effective Git configuration in current context
    if git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Current Repository Configuration:"
        local user_name user_email signing_key
        user_name=$(git config user.name 2>/dev/null || echo "Not set")
        user_email=$(git config user.email 2>/dev/null || echo "Not set")
        signing_key=$(git config user.signingkey 2>/dev/null || echo "Not set")
        
        echo "  User Name: $user_name"
        echo "  User Email: $user_email"
        echo "  Signing Key: $signing_key"
    else
        echo "Not in a Git repository"
        
        # Show global configuration
        echo "Global Git Configuration:"
        local global_name global_email global_key
        global_name=$(git config --global user.name 2>/dev/null || echo "Not set")
        global_email=$(git config --global user.email 2>/dev/null || echo "Not set")
        global_key=$(git config --global user.signingkey 2>/dev/null || echo "Not set")
        
        echo "  User Name: $global_name"
        echo "  User Email: $global_email"
        echo "  Signing Key: $global_key"
    fi
}

# List all available profiles
list_profiles() {
    log_info "Available Git Profiles"
    echo "======================"
    
    local profiles=("personal" "work" "opensource")
    
    for profile in "${profiles[@]}"; do
        local config_file
        config_file=$(get_profile_config_path "$profile")
        local status="✗"
        local directory_status="✗"
        
        if [[ -f "$config_file" ]]; then
            status="✓"
        fi
        
        local profile_dir="$HOME/$profile"
        if [[ -d "$profile_dir" ]]; then
            directory_status="✓"
        fi
        
        printf "%-12s Config: %s  Directory: %s\n" "$profile" "$status" "$directory_status"
        printf "%-12s Path: %s\n" "" "$profile_dir"
        
        if [[ -f "$config_file" ]]; then
            # Extract user info from config file
            local profile_name profile_email
            profile_name=$(grep "name = " "$config_file" 2>/dev/null | sed 's/.*name = //' || echo "Not set")
            profile_email=$(grep "email = " "$config_file" 2>/dev/null | sed 's/.*email = //' || echo "Not set")
            printf "%-12s User: %s <%s>\n" "" "$profile_name" "$profile_email"
        fi
        echo
    done
    
    echo "Default Profile:"
    local global_name global_email
    global_name=$(git config --global user.name 2>/dev/null || echo "Not set")
    global_email=$(git config --global user.email 2>/dev/null || echo "Not set")
    printf "%-12s User: %s <%s>\n" "" "$global_name" "$global_email"
}

# Show information about a specific profile
show_profile_info() {
    local profile="$1"
    
    if [[ -z "$profile" ]]; then
        log_error "Profile name required"
        return 1
    fi
    
    log_info "Profile Information: $profile"
    echo "=============================="
    
    local config_file
    config_file=$(get_profile_config_path "$profile")
    local profile_dir="$HOME/$profile"
    
    echo "Profile: $profile"
    echo "Directory: $profile_dir"
    echo "Configuration: $config_file"
    
    # Check if directory exists
    if [[ -d "$profile_dir" ]]; then
        echo "Directory Status: ✓ Exists"
        local repo_count
        repo_count=$(find "$profile_dir" -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')
        echo "Git Repositories: $repo_count found"
    else
        echo "Directory Status: ✗ Missing"
        echo "  Create with: mkdir -p $profile_dir"
    fi
    
    # Check if configuration exists
    if [[ -f "$config_file" ]]; then
        echo "Configuration Status: ✓ Exists"
        echo
        echo "Configuration Contents:"
        echo "----------------------"
        cat "$config_file"
    else
        echo "Configuration Status: ✗ Missing"
        echo "  Configuration will be created during secret injection"
    fi
}

# Create a profile directory
create_profile_directory() {
    local target_dir="$1"
    
    if [[ -z "$target_dir" ]]; then
        log_error "Directory path required"
        return 1
    fi
    
    # Expand ~ to $HOME if needed
    target_dir="${target_dir/#\~/$HOME}"
    
    if [[ -d "$target_dir" ]]; then
        log_warn "Directory already exists: $target_dir"
        return 0
    fi
    
    log_info "Creating profile directory: $target_dir"
    if mkdir -p "$target_dir"; then
        log_success "Directory created successfully"
        
        # Detect profile type from path
        local profile_type
        case "$target_dir" in
            "$HOME/personal"*) profile_type="personal" ;;
            "$HOME/work"*) profile_type="work" ;;
            "$HOME/opensource"*) profile_type="opensource" ;;
            *) profile_type="custom" ;;
        esac
        
        if [[ "$profile_type" != "custom" ]]; then
            log_info "This directory will use the '$profile_type' Git profile"
            log_info "Repository configuration will be applied automatically"
        else
            log_info "This directory will use the default Git profile"
        fi
    else
        log_error "Failed to create directory: $target_dir"
        return 1
    fi
}

# Validate profile configurations
validate_profiles() {
    log_info "Validating Git Profile Configurations"
    echo "====================================="
    
    local profiles=("personal" "work" "opensource")
    local validation_passed=true
    
    for profile in "${profiles[@]}"; do
        echo "Validating $profile profile..."
        
        local config_file
        config_file=$(get_profile_config_path "$profile")
        
        if [[ ! -f "$config_file" ]]; then
            log_warn "$profile: Configuration file missing"
            continue
        fi
        
        # Check for required fields
        local required_fields=("user.name" "user.email")
        for field in "${required_fields[@]}"; do
            if grep -q "$field" "$config_file"; then
                log_success "$profile: $field configured"
            else
                log_error "$profile: $field missing"
                validation_passed=false
            fi
        done
        
        # Check for template variables (indicates injection needed)
        if grep -q '\${' "$config_file"; then
            log_warn "$profile: Contains template variables (secret injection needed)"
        else
            log_success "$profile: All variables resolved"
        fi
        
        echo
    done
    
    if [[ "$validation_passed" == true ]]; then
        log_success "Profile validation passed"
    else
        log_error "Profile validation failed"
        return 1
    fi
}

# Main function
main() {
    local command="${1:-current}"
    
    case "$command" in
        current)
            show_current_profile
            ;;
        list)
            list_profiles
            ;;
        info)
            show_profile_info "${2:-}"
            ;;
        create)
            create_profile_directory "${2:-}"
            ;;
        validate)
            validate_profiles
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 