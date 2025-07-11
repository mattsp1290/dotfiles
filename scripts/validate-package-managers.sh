#!/usr/bin/env bash
# Package Manager Validation Script
# Validates that package manager configurations are working correctly

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Logging setup
log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*" >&2
}

# Validation results
VALIDATION_RESULTS=()

# Add validation result
add_result() {
    local status="$1"
    local message="$2"
    VALIDATION_RESULTS+=("$status: $message")
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate npm configuration
validate_npm() {
    log_info "Validating npm configuration..."
    
    if ! command_exists npm; then
        add_result "SKIP" "npm not installed"
        return 0
    fi
    
    # Check npm configuration loading
    if npm config list >/dev/null 2>&1; then
        add_result "PASS" "npm configuration loads successfully"
    else
        add_result "FAIL" "npm configuration failed to load"
        return 1
    fi
    
    # Check registry connectivity
    local registry
    registry=$(npm config get registry 2>/dev/null || echo "")
    if [[ -n "$registry" ]]; then
        log_info "Testing npm registry connectivity: $registry"
        if curl -s --head --max-time 10 "$registry" >/dev/null 2>&1; then
            add_result "PASS" "npm registry is accessible: $registry"
        else
            add_result "WARN" "npm registry connectivity issue: $registry"
        fi
    else
        add_result "WARN" "npm registry not configured"
    fi
    
    # Check npm cache configuration
    local cache_dir
    cache_dir=$(npm config get cache 2>/dev/null || echo "")
    if [[ -n "$cache_dir" ]]; then
        if [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir" 2>/dev/null; then
            add_result "PASS" "npm cache directory is accessible: $cache_dir"
        else
            add_result "WARN" "npm cache directory issue: $cache_dir"
        fi
    fi
    
    # Test basic npm functionality
    if npm list --depth=0 >/dev/null 2>&1; then
        add_result "PASS" "npm basic functionality works"
    else
        add_result "WARN" "npm basic functionality may have issues"
    fi
}

# Validate pip configuration
validate_pip() {
    log_info "Validating pip configuration..."
    
    if ! command_exists pip; then
        add_result "SKIP" "pip not installed"
        return 0
    fi
    
    # Check pip configuration loading
    if pip config list >/dev/null 2>&1; then
        add_result "PASS" "pip configuration loads successfully"
    else
        add_result "FAIL" "pip configuration failed to load"
        return 1
    fi
    
    # Check index URL connectivity
    local index_url
    index_url=$(pip config get global.index-url 2>/dev/null || echo "https://pypi.org/simple/")
    if [[ -n "$index_url" ]]; then
        log_info "Testing pip index connectivity: $index_url"
        if curl -s --head --max-time 10 "$index_url" >/dev/null 2>&1; then
            add_result "PASS" "pip index is accessible: $index_url"
        else
            add_result "WARN" "pip index connectivity issue: $index_url"
        fi
    fi
    
    # Check pip cache configuration
    local cache_dir
    cache_dir=$(pip config get global.cache-dir 2>/dev/null || echo "$HOME/.cache/pip")
    if [[ -n "$cache_dir" ]]; then
        if [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir" 2>/dev/null; then
            add_result "PASS" "pip cache directory is accessible: $cache_dir"
        else
            add_result "WARN" "pip cache directory issue: $cache_dir"
        fi
    fi
    
    # Test basic pip functionality
    if pip list >/dev/null 2>&1; then
        add_result "PASS" "pip basic functionality works"
    else
        add_result "WARN" "pip basic functionality may have issues"
    fi
}

# Validate gem configuration
validate_gem() {
    log_info "Validating gem configuration..."
    
    if ! command_exists gem; then
        add_result "SKIP" "gem not installed"
        return 0
    fi
    
    # Check gem configuration loading
    if gem environment >/dev/null 2>&1; then
        add_result "PASS" "gem configuration loads successfully"
    else
        add_result "FAIL" "gem configuration failed to load"
        return 1
    fi
    
    # Check gem sources connectivity
    local sources
    sources=$(gem sources --list 2>/dev/null | grep -E '^https?://' || echo "")
    if [[ -n "$sources" ]]; then
        while IFS= read -r source; do
            if [[ -n "$source" ]]; then
                log_info "Testing gem source connectivity: $source"
                if curl -s --head --max-time 10 "$source" >/dev/null 2>&1; then
                    add_result "PASS" "gem source is accessible: $source"
                else
                    add_result "WARN" "gem source connectivity issue: $source"
                fi
            fi
        done <<< "$sources"
    else
        add_result "WARN" "no gem sources configured"
    fi
    
    # Check gem installation directory
    local gem_dir
    gem_dir=$(gem environment gemdir 2>/dev/null || echo "")
    if [[ -n "$gem_dir" ]]; then
        if [[ -d "$gem_dir" ]] || mkdir -p "$gem_dir" 2>/dev/null; then
            add_result "PASS" "gem directory is accessible: $gem_dir"
        else
            add_result "WARN" "gem directory issue: $gem_dir"
        fi
    fi
    
    # Test basic gem functionality
    if gem list >/dev/null 2>&1; then
        add_result "PASS" "gem basic functionality works"
    else
        add_result "WARN" "gem basic functionality may have issues"
    fi
}

# Validate cargo configuration
validate_cargo() {
    log_info "Validating cargo configuration..."
    
    if ! command_exists cargo; then
        add_result "SKIP" "cargo not installed"
        return 0
    fi
    
    # Check cargo configuration loading
    if cargo --version >/dev/null 2>&1; then
        add_result "PASS" "cargo loads successfully"
    else
        add_result "FAIL" "cargo failed to load"
        return 1
    fi
    
    # Check crates.io connectivity
    log_info "Testing crates.io connectivity..."
    if curl -s --head --max-time 10 "https://crates.io" >/dev/null 2>&1; then
        add_result "PASS" "crates.io is accessible"
    else
        add_result "WARN" "crates.io connectivity issue"
    fi
    
    # Check cargo home directory
    local cargo_home
    cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    if [[ -d "$cargo_home" ]] || mkdir -p "$cargo_home" 2>/dev/null; then
        add_result "PASS" "cargo home directory is accessible: $cargo_home"
    else
        add_result "WARN" "cargo home directory issue: $cargo_home"
    fi
    
    # Test cargo configuration file
    local cargo_config="$cargo_home/config.toml"
    if [[ -f "$cargo_config" ]]; then
        # Try to parse the config by running a cargo command
        if cargo search --limit 1 >/dev/null 2>&1; then
            add_result "PASS" "cargo configuration is valid"
        else
            add_result "WARN" "cargo configuration may have issues"
        fi
    else
        add_result "INFO" "no custom cargo configuration found"
    fi
}

# Test package connectivity
test_connectivity() {
    log_info "Testing package manager connectivity..."
    
    # Test a simple package search/info for each manager
    local connectivity_results=()
    
    if command_exists npm; then
        if timeout 30 npm search --no-progress lodash >/dev/null 2>&1; then
            connectivity_results+=("npm: OK")
        else
            connectivity_results+=("npm: TIMEOUT/ERROR")
        fi
    fi
    
    if command_exists pip; then
        if timeout 30 pip search requests >/dev/null 2>&1 || \
           timeout 30 pip index versions requests >/dev/null 2>&1; then
            connectivity_results+=("pip: OK")
        else
            connectivity_results+=("pip: TIMEOUT/ERROR")
        fi
    fi
    
    if command_exists gem; then
        if timeout 30 gem search rails >/dev/null 2>&1; then
            connectivity_results+=("gem: OK")
        else
            connectivity_results+=("gem: TIMEOUT/ERROR")
        fi
    fi
    
    if command_exists cargo; then
        if timeout 30 cargo search serde >/dev/null 2>&1; then
            connectivity_results+=("cargo: OK")
        else
            connectivity_results+=("cargo: TIMEOUT/ERROR")
        fi
    fi
    
    for result in "${connectivity_results[@]}"; do
        add_result "CONNECTIVITY" "$result"
    done
}

# Print validation summary
print_summary() {
    log_info "Validation Summary:"
    echo "==================="
    
    local pass_count=0
    local warn_count=0
    local fail_count=0
    local skip_count=0
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        case "$result" in
            PASS:*)
                echo "✅ $result"
                ((pass_count++))
                ;;
            WARN:*)
                echo "⚠️  $result"
                ((warn_count++))
                ;;
            FAIL:*)
                echo "❌ $result"
                ((fail_count++))
                ;;
            SKIP:*)
                echo "⏭️  $result"
                ((skip_count++))
                ;;
            *)
                echo "ℹ️  $result"
                ;;
        esac
    done
    
    echo "==================="
    echo "Results: $pass_count passed, $warn_count warnings, $fail_count failed, $skip_count skipped"
    
    if [[ $fail_count -gt 0 ]]; then
        log_error "Validation failed with $fail_count critical issues"
        return 1
    elif [[ $warn_count -gt 0 ]]; then
        log_warn "Validation completed with $warn_count warnings"
        return 0
    else
        log_success "All validations passed successfully"
        return 0
    fi
}

# Main validation function
main() {
    log_info "Starting package manager validation..."
    
    # Run validations
    validate_npm
    validate_pip
    validate_gem
    validate_cargo
    
    # Test connectivity (optional, can be slow)
    if [[ "${1:-}" == "--connectivity" ]]; then
        test_connectivity
    fi
    
    # Print summary
    print_summary
}

# Help function
show_help() {
    cat << EOF
Package Manager Validation Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    --connectivity      Include connectivity tests (slower)

DESCRIPTION:
    This script validates that package manager configurations are working
    correctly and can connect to their respective registries.

EXAMPLES:
    $0                      # Basic validation
    $0 --connectivity      # Include connectivity tests
EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --connectivity)
        main --connectivity
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 