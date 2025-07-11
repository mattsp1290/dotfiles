#!/usr/bin/env bash

# =============================================================================
# File Permission Security Checker
# =============================================================================
# Comprehensive file permission validation for dotfiles repository
# Part of the TEST-004 Security Validation implementation
#
# This script validates file permissions to ensure security best practices:
# - 644 for configuration files (readable by owner/group, not executable)
# - 755 for scripts (executable by all, writable by owner only) 
# - 600 for sensitive files (readable by owner only)
# - 700 for sensitive directories (accessible by owner only)
# - No world-writable files or directories
# - Proper SSH key permissions
#
# Usage: ./check-permissions.sh [options]
# Options:
#   --fix         Automatically fix permission issues
#   --report-only Generate report without failing
#   --config FILE Use custom permissions policy file
#   --verbose     Enable verbose output
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_DIR="${SCRIPT_DIR}/reports"

# Command line options
FIX_MODE=false
REPORT_ONLY=false
VERBOSE=false
CUSTOM_CONFIG=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

log_fix() {
    echo -e "${CYAN}[FIX]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix)
                FIX_MODE=true
                shift
                ;;
            --report-only)
                REPORT_ONLY=true
                shift
                ;;
            --config)
                CUSTOM_CONFIG="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
File Permission Security Checker

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --fix          Automatically fix permission issues
    --report-only  Generate report without failing
    --config FILE  Use custom permissions policy file
    --verbose      Enable verbose output
    --help, -h     Show this help message

DESCRIPTION:
    Validates file permissions for security compliance:
    - 644 for configuration files (readable, not executable)
    - 755 for scripts (executable by all, writable by owner only)
    - 600 for sensitive files (readable by owner only)
    - 700 for sensitive directories (accessible by owner only)
    - No world-writable files or directories
    - Proper SSH key permissions

EXAMPLES:
    $0                    # Check permissions and report issues
    $0 --fix             # Check and automatically fix issues
    $0 --report-only     # Generate report without failing CI
    $0 --verbose         # Enable debug output
EOF
}

# Get file permissions in octal format
get_file_permissions() {
    local file="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f "%A" "$file" 2>/dev/null || echo "000"
    else
        stat -c "%a" "$file" 2>/dev/null || echo "000"
    fi
}

# Check if file is script based on extension or shebang
is_script_file() {
    local file="$1"
    
    # Check extension
    if [[ "$file" =~ \.(sh|bash|zsh|py|pl|rb|js|ts)$ ]]; then
        return 0
    fi
    
    # Check shebang
    if [[ -f "$file" ]] && head -1 "$file" 2>/dev/null | grep -q "^#!"; then
        return 0
    fi
    
    return 1
}

# Check if file is configuration file
is_config_file() {
    local file="$1"
    
    # Common config file patterns
    if [[ "$file" =~ \.(conf|config|cfg|ini|yaml|yml|json|toml|xml)$ ]]; then
        return 0
    fi
    
    # Dotfiles (configuration files starting with .)
    local basename
    basename=$(basename "$file")
    if [[ "$basename" =~ ^\. ]] && [[ ! "$basename" =~ \.(sh|py|pl|rb|js|ts)$ ]]; then
        return 0
    fi
    
    return 1
}

# Check if file is sensitive (should have restricted permissions)
is_sensitive_file() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    
    # SSH keys and certificates
    if [[ "$file" =~ (ssh|\.ssh) ]] && [[ "$basename" =~ (id_|key|private|\.pem|\.p12|\.pfx)$ ]]; then
        return 0
    fi
    
    # Password and credential files
    if [[ "$basename" =~ (password|passwd|secret|credential|token|key)$ ]]; then
        return 0
    fi
    
    # Environment files with potential secrets
    if [[ "$basename" =~ \.env ]]; then
        return 0
    fi
    
    return 1
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Starting file permission security check..."
    log_info "Repository: $REPO_ROOT"
    log_info "Fix mode: $FIX_MODE"
    
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
    
    local total_issues=0
    local checked_files=0
    
    # Check all files in repository
    log_info "Checking file permissions in repository..."
    while IFS= read -r -d '' file; do
        ((checked_files++))
        local current_perms
        current_perms=$(get_file_permissions "$file")
        log_debug "Checking $file (current: $current_perms)"
        
        # Skip .git directory
        if [[ "$file" =~ \.git/ ]]; then
            continue
        fi
        
        local expected_perms=""
        local needs_fix=false
        
        if [[ -d "$file" ]]; then
            # Directory permissions
            if is_sensitive_file "$file"; then
                expected_perms="700"
            else
                expected_perms="755"
            fi
            
            if [[ "$current_perms" != "$expected_perms" ]]; then
                needs_fix=true
            fi
        else
            # File permissions
            if is_sensitive_file "$file"; then
                expected_perms="600"
            elif is_script_file "$file"; then
                expected_perms="755"
            elif is_config_file "$file"; then
                expected_perms="644"
            else
                expected_perms="644"
            fi
            
            if [[ "$current_perms" != "$expected_perms" ]]; then
                needs_fix=true
            fi
        fi
        
        # Check for world-writable files (security risk)
        if [[ "${current_perms:2:1}" =~ [2367] ]]; then
            log_error "World-writable file detected: $file ($current_perms)"
            needs_fix=true
        fi
        
        if [[ "$needs_fix" == "true" ]]; then
            ((total_issues++))
            if [[ "$FIX_MODE" == "true" ]]; then
                log_fix "Setting $file to $expected_perms"
                chmod "$expected_perms" "$file"
            else
                log_error "Permission issue: $file should have $expected_perms (current: $current_perms)"
            fi
        fi
        
    done < <(find "$REPO_ROOT" -not -path "*/.git/*" -print0 2>/dev/null)
    
    # Summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "Permission check completed in ${duration}s"
    log_info "Checked $checked_files files and directories"
    
    if [[ $total_issues -eq 0 ]]; then
        log_success "🎉 All file permissions are correctly configured!"
    else
        if [[ "$FIX_MODE" == "true" ]]; then
            log_success "🔧 Fixed $total_issues permission issues"
        else
            log_error "⚠️  Found $total_issues permission issues"
            log_info "Run with --fix to automatically correct issues"
        fi
    fi
    
    # In report-only mode, always exit 0
    if [[ "$REPORT_ONLY" == "true" ]]; then
        log_info "Report-only mode: Exit code forced to 0"
        total_issues=0
    fi
    
    # Exit with non-zero if issues found and not fixed
    if [[ $total_issues -gt 0 ]] && [[ "$FIX_MODE" != "true" ]]; then
        exit 1
    fi
    
    exit 0
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi 