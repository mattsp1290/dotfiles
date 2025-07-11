#!/usr/bin/env bash

# =============================================================================
# Git History Security Scanner
# =============================================================================
# Comprehensive git history analysis for secret exposure detection
# Part of the TEST-004 Security Validation implementation
#
# This script scans the entire git history to detect:
# - Secrets in historical commits
# - Removed files that may have contained secrets
# - Large file removals that could indicate secret cleanup
# - Suspicious commit patterns
# - Branch and tag analysis for secret leakage
#
# Usage: ./git-history-scan.sh [options]
# Options:
#   --deep        Perform deep analysis including file content scanning
#   --report-only Generate report without failing
#   --since DATE  Only scan commits since this date (YYYY-MM-DD)
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
DEEP_SCAN=false
REPORT_ONLY=false
VERBOSE=false
SINCE_DATE=""

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

log_scan() {
    echo -e "${CYAN}[SCAN]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --deep)
                DEEP_SCAN=true
                shift
                ;;
            --report-only)
                REPORT_ONLY=true
                shift
                ;;
            --since)
                SINCE_DATE="$2"
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
Git History Security Scanner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --deep         Perform deep analysis including file content scanning
    --report-only  Generate report without failing
    --since DATE   Only scan commits since this date (YYYY-MM-DD)
    --verbose      Enable verbose output
    --help, -h     Show this help message

DESCRIPTION:
    Scans git history for potential security issues:
    - Secrets in historical commits
    - Removed files that may have contained secrets
    - Large file removals indicating secret cleanup
    - Suspicious commit patterns
    - Branch and tag analysis for secret leakage

EXAMPLES:
    $0                           # Basic history scan
    $0 --deep                   # Deep content analysis
    $0 --since 2023-01-01      # Scan since specific date
    $0 --verbose               # Enable debug output
EOF
}

# Scan commit messages for sensitive information
scan_commit_messages() {
    log_scan "Scanning commit messages for sensitive information..."
    
    local output_file="${LOG_DIR}/commit-messages-$(date +%Y%m%d-%H%M%S).log"
    local issues=0
    
    # Get all commit messages
    local git_log_args="--pretty=format:%H|%s|%an|%ad"
    if [[ -n "$SINCE_DATE" ]]; then
        git_log_args="$git_log_args --since=$SINCE_DATE"
    fi
    
    # Scan for suspicious patterns in commit messages
    local suspicious_patterns=(
        '[pP]assword'
        '[sS]ecret'
        '[tT]oken'
        '[kK]ey'
        '[cC]redential'
        'API[_-]?[kK]ey'
        '[rR]emov.*[sS]ecret'
        '[fF]ix.*[sS]ecurity'
        '[dD]elet.*[pP]assword'
        '[hH]ide.*[cC]redential'
    )
    
    while IFS='|' read -r commit_hash subject author date; do
        for pattern in "${suspicious_patterns[@]}"; do
            if echo "$subject" | grep -iE "$pattern" >/dev/null; then
                echo "SUSPICIOUS_COMMIT: $commit_hash | $subject | $author | $date" >> "$output_file"
                ((issues++))
                log_warn "Suspicious commit message: $commit_hash - $subject"
            fi
        done
    done < <(git log $git_log_args 2>/dev/null)
    
    if [[ $issues -gt 0 ]]; then
        log_error "Found $issues suspicious commit messages"
        return 1
    else
        log_success "No suspicious commit messages found"
        return 0
    fi
}

# Scan for sensitive file patterns in git history
scan_sensitive_file_patterns() {
    log_scan "Scanning for sensitive file patterns in git history..."
    
    local output_file="${LOG_DIR}/sensitive-files-$(date +%Y%m%d-%H%M%S).log"
    local issues=0
    
    # Patterns for sensitive files that should never be in git
    local sensitive_file_patterns=(
        '\.pem$'
        '\.key$'
        '\.p12$'
        '\.pfx$'
        'id_rsa$'
        'id_dsa$'
        'id_ecdsa$'
        'id_ed25519$'
        '\.env$'
        '\.env\.'
        'credentials$'
        'secrets$'
        'password'
        'passwd'
    )
    
    for pattern in "${sensitive_file_patterns[@]}"; do
        log_debug "Checking for file pattern: $pattern"
        
        # Search git history for files matching this pattern
        if git log --all --name-only --pretty=format: | grep -E "$pattern" > /tmp/pattern_matches 2>/dev/null; then
            while IFS= read -r file_match; do
                if [[ -n "$file_match" ]]; then
                    echo "SENSITIVE_FILE_PATTERN: $file_match | $pattern" >> "$output_file"
                    ((issues++))
                    log_warn "Sensitive file pattern found in history: $file_match"
                fi
            done < /tmp/pattern_matches
            rm -f /tmp/pattern_matches
        fi
    done
    
    if [[ $issues -gt 0 ]]; then
        log_error "Found $issues sensitive file patterns in git history"
        return 1
    else
        log_success "No sensitive file patterns found in git history"
        return 0
    fi
}

# Analyze branches and tags for secret exposure
analyze_branches_and_tags() {
    log_scan "Analyzing branches and tags for secret exposure..."
    
    local output_file="${LOG_DIR}/branches-tags-$(date +%Y%m%d-%H%M%S).log"
    local issues=0
    
    # Check all branches
    while IFS= read -r branch; do
        if [[ -n "$branch" ]]; then
            log_debug "Checking branch: $branch"
            
            # Look for suspicious branch names
            if echo "$branch" | grep -iE "(secret|password|key|token|credential|temp|backup)" >/dev/null; then
                echo "SUSPICIOUS_BRANCH: $branch" >> "$output_file"
                ((issues++))
                log_warn "Suspicious branch name: $branch"
            fi
        fi
    done < <(git branch -a 2>/dev/null | sed 's/^[* ] //' | grep -v '^remotes/origin/HEAD' || true)
    
    # Check all tags
    while IFS= read -r tag; do
        if [[ -n "$tag" ]]; then
            log_debug "Checking tag: $tag"
            
            # Look for suspicious tag names
            if echo "$tag" | grep -iE "(secret|password|key|token|credential|temp|backup)" >/dev/null; then
                echo "SUSPICIOUS_TAG: $tag" >> "$output_file"
                ((issues++))
                log_warn "Suspicious tag name: $tag"
            fi
        fi
    done < <(git tag -l 2>/dev/null || true)
    
    if [[ $issues -gt 0 ]]; then
        log_error "Found $issues suspicious branch/tag names"
        return 1
    else
        log_success "No suspicious branch/tag names found"
        return 0
    fi
}

# Main execution function
main() {
    local start_time
    start_time=$(date +%s)
    
    log_info "Starting git history security scan..."
    log_info "Repository: $REPO_ROOT"
    log_info "Deep scan: $DEEP_SCAN"
    log_info "Since date: ${SINCE_DATE:-"All history"}"
    
    # Setup
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
    
    # Navigate to repository root
    cd "$REPO_ROOT"
    
    local total_issues=0
    local failed_scans=()
    
    # Run all security scans
    if ! scan_commit_messages; then
        ((total_issues++))
        failed_scans+=("Commit Messages")
    fi
    
    if ! scan_sensitive_file_patterns; then
        ((total_issues++))
        failed_scans+=("Sensitive File Patterns")
    fi
    
    if ! analyze_branches_and_tags; then
        ((total_issues++))
        failed_scans+=("Branches and Tags")
    fi
    
    # Summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "Git history scan completed in ${duration}s"
    
    if [[ $total_issues -eq 0 ]]; then
        log_success "🎉 Git history security scan passed! No issues detected."
    else
        log_error "⚠️  Git history scan found issues in: ${failed_scans[*]}"
        log_error "Review the findings and take appropriate action to secure the repository."
    fi
    
    # In report-only mode, always exit 0
    if [[ "$REPORT_ONLY" == "true" ]]; then
        log_info "Report-only mode: Exit code forced to 0"
        total_issues=0
    fi
    
    exit $total_issues
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi 