#!/usr/bin/env bash
# Utility Functions Library
# Common functions for logging, error handling, and system operations

set -euo pipefail

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m' # No Color

# Unicode symbols (with fallbacks)
if locale charmap 2>/dev/null | grep -q "UTF-8"; then
    export CHECK_MARK="✓"
    export CROSS_MARK="✗"
    export ARROW="→"
    export BULLET="•"
else
    export CHECK_MARK="[OK]"
    export CROSS_MARK="[X]"
    export ARROW="->"
    export BULLET="*"
fi

# Logging levels
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_SUCCESS=2
export LOG_LEVEL_WARNING=3
export LOG_LEVEL_ERROR=4
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Logging functions
log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo -e "${DIM}[DEBUG]${NC} $1" >&2
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_SUCCESS ]] && echo -e "${GREEN}${CHECK_MARK} [SUCCESS]${NC} $1"
}

log_warning() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARNING ]] && echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && echo -e "${RED}${CROSS_MARK} [ERROR]${NC} $1" >&2
}

# Progress indication
show_progress() {
    local message="$1"
    echo -ne "${BLUE}${ARROW}${NC} ${message}..."
}

end_progress() {
    local status="${1:-success}"
    if [[ "$status" == "success" ]]; then
        echo -e " ${GREEN}done${NC}"
    else
        echo -e " ${RED}failed${NC}"
    fi
}

# Spinner for long-running operations
spinner() {
    local pid=$1
    local message="${2:-Working}"
    local spinstr='|/-\'
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    wait $pid
    return $?
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if function exists
function_exists() {
    declare -f "$1" >/dev/null 2>&1
}

# Check for required commands
check_required_commands() {
    local missing_commands=()
    
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}

# Version comparison (simplified, uses sort -V if available)
version_ge() {
    # Check if first version is greater than or equal to second
    local version1="$1"
    local version2="$2"
    
    if command_exists sort && echo | sort -V >/dev/null 2>&1; then
        [[ "$version1" = "$(echo -e "$version1\n$version2" | sort -V | tail -1)" ]]
    else
        # Fallback to simple string comparison
        [[ "$version1" = "$version2" ]] || [[ "$version1" > "$version2" ]]
    fi
}

# Network connectivity check
check_network() {
    local test_host="${1:-8.8.8.8}"
    local timeout="${2:-5}"
    
    if command_exists ping; then
        ping -c 1 -W "$timeout" "$test_host" >/dev/null 2>&1
    elif command_exists curl; then
        curl -s --connect-timeout "$timeout" "http://$test_host" >/dev/null 2>&1
    elif command_exists wget; then
        wget -q --timeout="$timeout" --spider "http://$test_host" >/dev/null 2>&1
    else
        log_warning "No suitable command found for network check"
        return 0  # Assume network is available
    fi
}

# Check if we have internet access
has_internet() {
    check_network "google.com" || check_network "github.com" || check_network "8.8.8.8"
}

# Download a file with progress
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-Downloading}"
    
    show_progress "$description"
    
    if command_exists curl; then
        if curl -fsSL "$url" -o "$output" 2>/dev/null; then
            end_progress "success"
            return 0
        fi
    elif command_exists wget; then
        if wget -q "$url" -O "$output" 2>/dev/null; then
            end_progress "success"
            return 0
        fi
    fi
    
    end_progress "failed"
    return 1
}

# Create a temporary directory
create_temp_dir() {
    local prefix="${1:-dotfiles}"
    local temp_dir
    
    if command_exists mktemp; then
        temp_dir=$(mktemp -d -t "${prefix}.XXXXXX")
    else
        temp_dir="/tmp/${prefix}.$$"
        mkdir -p "$temp_dir"
    fi
    
    echo "$temp_dir"
}

# Clean up temporary files on exit
cleanup_on_exit() {
    local temp_dir="$1"
    trap "rm -rf '$temp_dir'" EXIT INT TERM
}

# Prompt for user confirmation
confirm() {
    local message="${1:-Continue?}"
    local default="${2:-n}"
    
    local prompt
    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt="$message [Y/n] "
    else
        prompt="$message [y/N] "
    fi
    
    read -r -p "$prompt" response
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Prompt for user input with default
prompt_input() {
    local message="$1"
    local default="$2"
    local variable_name="$3"
    
    local prompt="$message"
    if [[ -n "$default" ]]; then
        prompt="$prompt [$default]"
    fi
    prompt="$prompt: "
    
    read -r -p "$prompt" response
    
    if [[ -z "$response" ]] && [[ -n "$default" ]]; then
        response="$default"
    fi
    
    if [[ -n "$variable_name" ]]; then
        eval "$variable_name='$response'"
    else
        echo "$response"
    fi
}

# Get script directory (works with symlinks)
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir
    
    # Resolve symlinks
    while [[ -h "$source" ]]; do
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    echo "$dir"
}

# Check disk space
check_disk_space() {
    local required_mb="${1:-100}"
    local path="${2:-$HOME}"
    
    local available_kb
    if command_exists df; then
        available_kb=$(df -k "$path" | awk 'NR==2 {print $4}')
        local available_mb=$((available_kb / 1024))
        
        if [[ $available_mb -lt $required_mb ]]; then
            log_error "Insufficient disk space. Required: ${required_mb}MB, Available: ${available_mb}MB"
            return 1
        fi
    else
        log_warning "Cannot check disk space (df command not found)"
    fi
    
    return 0
}

# Safe file backup
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup}"
    
    if [[ -f "$file" ]]; then
        local backup_name="${file}${backup_suffix}"
        local counter=1
        
        # Find a unique backup name
        while [[ -e "$backup_name" ]]; do
            backup_name="${file}${backup_suffix}.${counter}"
            ((counter++))
        done
        
        cp -p "$file" "$backup_name"
        log_info "Backed up $file to $backup_name"
    fi
}

# Create directory with parent directories
ensure_dir() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

# Symlink with backup
safe_symlink() {
    local source="$1"
    local target="$2"
    
    # Check if source exists
    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi
    
    # If target exists and is not a symlink, back it up
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        backup_file "$target"
        rm -f "$target"
    elif [[ -L "$target" ]]; then
        # Remove existing symlink
        rm -f "$target"
    fi
    
    # Create the symlink
    ln -s "$source" "$target"
    log_debug "Created symlink: $target -> $source"
}

# Run command with timeout
run_with_timeout() {
    local timeout="$1"
    shift
    
    if command_exists timeout; then
        timeout "$timeout" "$@"
    elif command_exists gtimeout; then
        gtimeout "$timeout" "$@"
    else
        # Fallback: run without timeout
        "$@"
    fi
}

# Retry a command
retry_command() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    shift 2
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Export all utility functions (silenced to avoid startup output)
export -f log_debug log_info log_success log_warning log_error >/dev/null 2>&1
export -f show_progress end_progress spinner >/dev/null 2>&1
export -f command_exists function_exists check_required_commands >/dev/null 2>&1
export -f version_ge check_network has_internet download_file >/dev/null 2>&1
export -f create_temp_dir cleanup_on_exit >/dev/null 2>&1
export -f confirm prompt_input >/dev/null 2>&1
export -f get_script_dir check_disk_space >/dev/null 2>&1
export -f backup_file ensure_dir safe_symlink >/dev/null 2>&1
export -f run_with_timeout retry_command >/dev/null 2>&1 