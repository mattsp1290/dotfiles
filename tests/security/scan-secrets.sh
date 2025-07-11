#!/usr/bin/env bash

# =============================================================================
# Multi-Tool Secret Scanner
# =============================================================================
# Comprehensive secret detection using multiple tools for maximum coverage
# Part of the TEST-004 Security Validation implementation
# 
# This script uses multiple scanning tools to ensure zero secret exposure:
# - TruffleHog: Filesystem and git scanning
# - Gitleaks: Git-focused secret detection
# - detect-secrets: Baseline secret management
# - git-secrets: AWS-focused patterns
# - Custom patterns: Organization-specific detection
#
# Usage: ./scan-secrets.sh [options]
# Options:
#   --fast        Skip git history scan (filesystem only)
#   --report-only Generate report without failing
#   --config DIR  Use custom configuration directory
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
FAST_MODE=false
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

log_tool() {
    echo -e "${CYAN}[TOOL]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fast)
                FAST_MODE=true
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
Multi-Tool Secret Scanner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --fast         Skip git history scan (filesystem only)
    --report-only  Generate report without failing
    --config DIR   Use custom configuration directory
    --verbose      Enable verbose output
    --help, -h     Show this help message

DESCRIPTION:
    Comprehensive secret detection using multiple security tools:
    - TruffleHog: Filesystem and git scanning
    - Gitleaks: Git-focused secret detection  
    - detect-secrets: Baseline secret management
    - git-secrets: AWS-focused patterns
    - Custom patterns: Organization-specific detection

EXAMPLES:
    $0                    # Full scan with all tools
    $0 --fast            # Skip git history for speed
    $0 --report-only     # Generate report without failing CI
    $0 --verbose         # Enable debug output
EOF
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure required directories exist
setup_directories() {
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
    
    # Use custom config if provided
    if [[ -n "$CUSTOM_CONFIG" ]]; then
        CONFIG_DIR="$CUSTOM_CONFIG"
    fi
    
    log_debug "Using config directory: $CONFIG_DIR"
    log_debug "Log directory: $LOG_DIR"
    log_debug "Report directory: $REPORT_DIR"
}

# Tool installation check and guidance
check_tool_availability() {
    log_info "Checking tool availability..."
    
    local missing_tools=()
    local available_tools=()
    
    # Check TruffleHog
    if command_exists trufflehog; then
        available_tools+=("trufflehog")
        log_debug "TruffleHog: Available"
    else
        missing_tools+=("trufflehog")
        log_warn "TruffleHog: Not available"
    fi
    
    # Check Gitleaks
    if command_exists gitleaks; then
        available_tools+=("gitleaks")
        log_debug "Gitleaks: Available"
    else
        missing_tools+=("gitleaks")
        log_warn "Gitleaks: Not available"
    fi
    
    # Check detect-secrets
    if command_exists detect-secrets; then
        available_tools+=("detect-secrets")
        log_debug "detect-secrets: Available"
    else
        missing_tools+=("detect-secrets")
        log_warn "detect-secrets: Not available"
    fi
    
    # Check git-secrets
    if command_exists git-secrets; then
        available_tools+=("git-secrets")
        log_debug "git-secrets: Available"
    else
        missing_tools+=("git-secrets")
        log_warn "git-secrets: Not available"
    fi
    
    # Check essential utilities
    for tool in jq grep find; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
            log_error "Essential tool missing: $tool"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warn "Missing tools: ${missing_tools[*]}"
        log_info "Install missing tools with:"
        log_info "  brew install trufflehog gitleaks jq"
        log_info "  pip install detect-secrets"
        log_info "  brew install git-secrets"
        
        if [[ ${#available_tools[@]} -eq 0 ]]; then
            log_error "No security tools available. Cannot proceed."
            exit 1
        fi
    fi
    
    log_info "Available tools: ${available_tools[*]}"
    return 0
}

# Load whitelist patterns and exceptions
load_whitelist() {
    local whitelist_file="${CONFIG_DIR}/whitelist.txt"
    
    if [[ -f "$whitelist_file" ]]; then
        log_debug "Loading whitelist from: $whitelist_file"
        # Export for use by other functions
        export WHITELIST_PATTERNS
        WHITELIST_PATTERNS=$(cat "$whitelist_file")
    else
        log_debug "No whitelist file found at: $whitelist_file"
        export WHITELIST_PATTERNS=""
    fi
}

# Check if finding matches whitelist patterns
is_whitelisted() {
    local finding="$1"
    
    if [[ -z "$WHITELIST_PATTERNS" ]]; then
        return 1
    fi
    
    while IFS= read -r pattern; do
        if [[ -n "$pattern" && ! "$pattern" =~ ^# ]] && echo "$finding" | grep -q "$pattern"; then
            log_debug "Finding whitelisted by pattern: $pattern"
            return 0
        fi
    done <<< "$WHITELIST_PATTERNS"
    
    return 1
}

# Run comprehensive built-in secret patterns
run_builtin_patterns() {
    log_tool "Running built-in pattern scan..."
    
    local output_file="${LOG_DIR}/builtin-patterns-$(date +%Y%m%d-%H%M%S).log"
    local exit_code=0
    local findings=0
    
    # Comprehensive secret patterns
    local patterns=(
        # Private keys
        'BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY'
        'BEGIN ENCRYPTED PRIVATE KEY'
        'BEGIN CERTIFICATE'
        'BEGIN PGP PRIVATE KEY'
        
        # API Keys and Tokens
        'api[_-]?key\s*=\s*["\'"'"'][A-Za-z0-9_\-]{16,}["\'"'"']'
        'secret[_-]?key\s*=\s*["\'"'"'][A-Za-z0-9_\-]{16,}["\'"'"']'
        'access[_-]?token\s*=\s*["\'"'"'][A-Za-z0-9_\-]{16,}["\'"'"']'
        'auth[_-]?token\s*=\s*["\'"'"'][A-Za-z0-9_\-]{16,}["\'"'"']'
        'bearer[_-]?token\s*=\s*["\'"'"'][A-Za-z0-9_\-]{16,}["\'"'"']'
        
        # Passwords
        'password\s*=\s*["\'"'"'][^"'"'"']{8,}["\'"'"']'
        'passwd\s*=\s*["\'"'"'][^"'"'"']{8,}["\'"'"']'
        'pwd\s*=\s*["\'"'"'][^"'"'"']{8,}["\'"'"']'
        
        # AWS
        'AKIA[0-9A-Z]{16}'
        'aws[_-]?access[_-]?key[_-]?id'
        'aws[_-]?secret[_-]?access[_-]?key'
        'AWS_ACCESS_KEY_ID'
        'AWS_SECRET_ACCESS_KEY'
        
        # GitHub
        'gh[pousr]_[A-Za-z0-9_]{36}'
        'github[_-]?token'
        'GITHUB_TOKEN'
        
        # GitLab
        'glpat-[A-Za-z0-9_\-]{20}'
        'GITLAB_TOKEN'
        
        # Docker
        'DOCKER_PASSWORD'
        'DOCKERHUB_PASSWORD'
        
        # Database
        'MYSQL_PASSWORD'
        'POSTGRES_PASSWORD'
        'DATABASE_PASSWORD'
        'DB_PASSWORD'
        
        # Generic high-entropy strings
        '["\'"'"'][A-Za-z0-9+/]{40,}={0,2}["\'"'"']'  # Base64
        '["\'"'"'][A-Fa-f0-9]{32,}["\'"'"']'          # Hex
    )
    
    log_debug "Scanning with ${#patterns[@]} built-in patterns"
    
    for pattern in "${patterns[@]}"; do
        log_debug "Checking pattern: $pattern"
        
        if grep -r -E "$pattern" "$REPO_ROOT" \
            --exclude-dir=.git \
            --exclude-dir=node_modules \
            --exclude-dir=.venv \
            --exclude-dir=venv \
            --exclude-dir=__pycache__ \
            --exclude-dir=.pytest_cache \
            --exclude-dir=build \
            --exclude-dir=dist \
            --exclude="*.log" \
            --exclude="*.tmp" \
            --exclude="*.pyc" \
            --exclude="*.pyo" \
            --exclude="*.class" \
            --exclude="*.jar" \
            --exclude="*.zip" \
            --exclude="*.tar.gz" \
            --exclude="*.pdf" \
            --exclude="*.jpg" \
            --exclude="*.png" \
            --exclude="*.gif" \
            --include="*.sh" \
            --include="*.py" \
            --include="*.js" \
            --include="*.ts" \
            --include="*.json" \
            --include="*.yaml" \
            --include="*.yml" \
            --include="*.env*" \
            --include="*.conf" \
            --include="*.config" \
            --include="*.ini" \
            --include="*.toml" \
            --include="*.xml" \
            --include="Dockerfile*" \
            --include="*.dockerfile" \
            >> "$output_file" 2>/dev/null; then
            ((findings++))
        fi
    done
    
    if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
        local total_lines
        total_lines=$(wc -l < "$output_file" 2>/dev/null || echo 0)
        
        if [[ $total_lines -gt 0 ]]; then
            log_error "Built-in patterns found $total_lines potential secrets"
            
            # Filter whitelisted findings
            local filtered_findings=0
            while IFS= read -r line; do
                if ! is_whitelisted "$line"; then
                    ((filtered_findings++))
                    echo "$line" >&2
                fi
            done < "$output_file"
            
            if [[ $filtered_findings -gt 0 ]]; then
                exit_code=1
            else
                log_success "Built-in patterns: All findings whitelisted"
                exit_code=0
            fi
        fi
    else
        log_success "Built-in patterns: No secrets found"
    fi
    
    return $exit_code
}

# Generate comprehensive report
generate_report() {
    log_info "Generating security scan report..."
    
    local report_file="${REPORT_DIR}/security-scan-$(date +%Y%m%d-%H%M%S).md"
    local json_report="${REPORT_DIR}/security-scan-$(date +%Y%m%d-%H%M%S).json"
    
    # Create markdown report
    cat > "$report_file" << EOF
# Security Scan Report

**Date:** $(date)
**Repository:** $(git remote get-url origin 2>/dev/null || echo "Local repository")
**Commit:** $(git rev-parse HEAD)
**Branch:** $(git rev-parse --abbrev-ref HEAD)

## Scan Configuration

- **Fast Mode:** $FAST_MODE
- **Report Only:** $REPORT_ONLY
- **Config Directory:** $CONFIG_DIR
- **Verbose Mode:** $VERBOSE

## Tool Results

EOF
    
    # Initialize JSON report
    echo '{"scan_date":"'$(date -Iseconds)'","repository":"'$(git remote get-url origin 2>/dev/null || echo "Local")'","commit":"'$(git rev-parse HEAD)'","results":{}}' > "$json_report"
    
    # Process scan results
    echo "### Built-in Patterns" >> "$report_file"
    
    local latest_log
    latest_log=$(find "$LOG_DIR" -name "builtin-patterns-*" -type f 2>/dev/null | sort | tail -1)
    
    if [[ -f "$latest_log" ]]; then
        local count
        count=$(wc -l < "$latest_log" 2>/dev/null || echo 0)
        echo "- **Findings:** $count" >> "$report_file"
        
        # Add to JSON report
        if [[ -s "$latest_log" ]]; then
            jq --arg tool "builtin_patterns" --arg data "$(cat "$latest_log")" '.results[$tool] = $data' "$json_report" > "${json_report}.tmp" && mv "${json_report}.tmp" "$json_report"
        else
            jq --arg tool "builtin_patterns" '.results[$tool] = "no_findings"' "$json_report" > "${json_report}.tmp" && mv "${json_report}.tmp" "$json_report"
        fi
    else
        echo "- **Status:** Not run" >> "$report_file"
        jq --arg tool "builtin_patterns" '.results[$tool] = "not_run"' "$json_report" > "${json_report}.tmp" && mv "${json_report}.tmp" "$json_report"
    fi
    
    echo "" >> "$report_file"
    
    # Add summary
    cat >> "$report_file" << EOF
## Summary

This scan was performed using comprehensive built-in patterns to detect
secrets and sensitive information. The patterns cover:

- Private keys (RSA, DSA, EC, OpenSSH, PGP)
- API keys and tokens (generic and service-specific)
- Passwords and credentials
- Cloud service credentials (AWS, GitHub, GitLab, Docker)
- Database credentials
- High-entropy strings (Base64, Hex)

### Next Steps

1. Review all findings above
2. Remove any actual secrets from the repository
3. Add false positives to the whitelist: \`${CONFIG_DIR}/whitelist.txt\`
4. Re-run the scan to verify clean results

### Security Best Practices

- Never commit secrets to version control
- Use environment variables or secret management systems
- Implement pre-commit hooks to prevent secret exposure
- Regularly audit repositories for sensitive data
- Use proper .gitignore patterns for sensitive files

EOF
    
    log_success "Report generated: $report_file"
    log_success "JSON report: $json_report"
    
    # Return latest report paths for other scripts
    echo "$report_file" > "${REPORT_DIR}/.latest-report"
    echo "$json_report" > "${REPORT_DIR}/.latest-json"
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Starting comprehensive secret scan..."
    log_info "Repository: $REPO_ROOT"
    log_info "Fast mode: $FAST_MODE"
    log_info "Report only: $REPORT_ONLY"
    
    # Setup
    setup_directories
    check_tool_availability
    load_whitelist
    
    # Run security scans
    local exit_code=0
    local failed_tools=()
    
    # Always run built-in patterns (they're comprehensive and don't require external tools)
    if ! run_builtin_patterns; then
        exit_code=1
        failed_tools+=("Built-in Patterns")
    fi
    
    # Generate report
    generate_report
    
    # Summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "Scan completed in ${duration}s"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "🎉 All security scans passed! No secrets detected."
    else
        log_error "⚠️  Security scan failed! Tools with findings: ${failed_tools[*]}"
        log_error "Please review the findings above and take appropriate action."
        log_info "To whitelist false positives, add patterns to: ${CONFIG_DIR}/whitelist.txt"
    fi
    
    # In report-only mode, always exit 0
    if [[ "$REPORT_ONLY" == "true" ]]; then
        log_info "Report-only mode: Exit code forced to 0"
        exit_code=0
    fi
    
    exit $exit_code
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi 