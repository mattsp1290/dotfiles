#!/usr/bin/env bash
# Mock framework for external tools
# Provides mock implementations of external dependencies for testing

set -euo pipefail

# Source test utilities
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Mock state tracking
MOCK_COMMANDS=()
MOCK_CALL_LOG=""

# Initialize mock logging
init_mock_logging() {
    # Set up mock call log in temp directory
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        MOCK_CALL_LOG="$TEST_TEMP_DIR/mock_calls.log"
        mkdir -p "$(dirname "$MOCK_CALL_LOG")"
        touch "$MOCK_CALL_LOG"
    else
        # Fallback to system temp
        MOCK_CALL_LOG="/tmp/mock_calls_$$.log"
        touch "$MOCK_CALL_LOG"
    fi
}

# Log mock command call
log_mock_call() {
    local cmd="$1"
    shift
    
    # Only log if we have a valid log file
    if [[ -n "$MOCK_CALL_LOG" && -f "$MOCK_CALL_LOG" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $cmd $*" >> "$MOCK_CALL_LOG"
    fi
}

# Get mock call count for command
get_mock_call_count() {
    local cmd="$1"
    if [[ -n "$MOCK_CALL_LOG" && -f "$MOCK_CALL_LOG" ]]; then
        grep -c "^[^ ]* [^ ]* $cmd" "$MOCK_CALL_LOG" || echo "0"
    else
        echo "0"
    fi
}

# Check if command was called with specific arguments
was_called_with() {
    local cmd="$1"
    shift
    local args="$*"
    
    if [[ -n "$MOCK_CALL_LOG" && -f "$MOCK_CALL_LOG" ]]; then
        grep -q "^[^ ]* [^ ]* $cmd $args" "$MOCK_CALL_LOG"
    else
        return 1
    fi
}

# Mock GNU Stow
mock_stow() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock GNU Stow implementation
STOW_VERSION="2.3.1"
STOW_TARGET_DIR="${HOME}"
STOW_DIR="${PWD}"
SIMULATE_CONFLICTS="${MOCK_STOW_CONFLICTS:-false}"
VERBOSE=false
DRY_RUN=false
OPERATION=""
PACKAGES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -V|--version)
            echo "stow (GNU Stow) $STOW_VERSION"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--no|--simulate)
            DRY_RUN=true
            shift
            ;;
        -t|--target)
            STOW_TARGET_DIR="$2"
            shift 2
            ;;
        -d|--dir)
            STOW_DIR="$2"
            shift 2
            ;;
        -S|--stow)
            OPERATION="stow"
            shift
            ;;
        -D|--delete)
            OPERATION="unstow"
            shift
            ;;
        -R|--restow)
            OPERATION="restow"
            shift
            ;;
        --adopt)
            OPERATION="adopt"
            shift
            ;;
        -*)
            echo "stow: unknown option $1" >&2
            exit 1
            ;;
        *)
            PACKAGES+=("$1")
            shift
            ;;
    esac
done

# Default operation is stow
if [[ -z "$OPERATION" ]]; then
    OPERATION="stow"
fi

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "stow" "$@"
fi

# Simulate conflicts if requested
if [[ "$SIMULATE_CONFLICTS" == "true" && "$OPERATION" == "stow" ]]; then
    echo "stow: WARNING! stowing $* would cause conflicts:" >&2
    echo "  * existing target is not owned by stow: .testrc" >&2
    exit 1
fi

# Simulate operations
for package in "${PACKAGES[@]}"; do
    package_dir="$STOW_DIR/$package"
    
    if [[ ! -d "$package_dir" ]]; then
        echo "stow: ERROR: no such package $package" >&2
        exit 1
    fi
    
    case "$OPERATION" in
        stow)
            if [[ "$VERBOSE" == "true" ]]; then
                echo "LINK: $package/.testrc => $STOW_TARGET_DIR/.testrc" >&2
            fi
            if [[ "$DRY_RUN" == "false" ]]; then
                mkdir -p "$STOW_TARGET_DIR"
                ln -sf "$package_dir/.testrc" "$STOW_TARGET_DIR/.testrc" 2>/dev/null || true
            fi
            ;;
        unstow)
            if [[ "$VERBOSE" == "true" ]]; then
                echo "UNLINK: $STOW_TARGET_DIR/.testrc" >&2
            fi
            if [[ "$DRY_RUN" == "false" ]]; then
                rm -f "$STOW_TARGET_DIR/.testrc" 2>/dev/null || true
            fi
            ;;
        restow)
            if [[ "$VERBOSE" == "true" ]]; then
                echo "UNLINK: $STOW_TARGET_DIR/.testrc" >&2
                echo "LINK: $package/.testrc => $STOW_TARGET_DIR/.testrc" >&2
            fi
            if [[ "$DRY_RUN" == "false" ]]; then
                rm -f "$STOW_TARGET_DIR/.testrc" 2>/dev/null || true
                mkdir -p "$STOW_TARGET_DIR"
                ln -sf "$package_dir/.testrc" "$STOW_TARGET_DIR/.testrc" 2>/dev/null || true
            fi
            ;;
        adopt)
            if [[ "$VERBOSE" == "true" ]]; then
                echo "ADOPT: $STOW_TARGET_DIR/.testrc => $package/.testrc" >&2
            fi
            if [[ "$DRY_RUN" == "false" ]]; then
                mv "$STOW_TARGET_DIR/.testrc" "$package_dir/.testrc" 2>/dev/null || true
                ln -sf "$package_dir/.testrc" "$STOW_TARGET_DIR/.testrc" 2>/dev/null || true
            fi
            ;;
    esac
done'

    mock_command "stow" "$mock_script"
    MOCK_COMMANDS+=("stow")
}

# Mock 1Password CLI
mock_op() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock 1Password CLI implementation
OP_VERSION="2.12.0"
SIGNED_IN="${MOCK_OP_SIGNED_IN:-true}"
SIMULATE_ERROR="${MOCK_OP_ERROR:-false}"

# Parse arguments
case "${1:-}" in
    --version)
        echo "$OP_VERSION"
        exit 0
        ;;
    signin|auth)
        if [[ "$SIMULATE_ERROR" == "true" ]]; then
            echo "Error: Authentication failed" >&2
            exit 1
        fi
        if [[ "$SIGNED_IN" == "true" ]]; then
            echo "Signed in successfully"
        else
            echo "Error: Not signed in" >&2
            exit 1
        fi
        ;;
    whoami)
        if [[ "$SIGNED_IN" == "true" ]]; then
            echo "testuser@example.com"
        else
            echo "Error: Not signed in" >&2
            exit 1
        fi
        ;;
    read|item)
        if [[ "$SIGNED_IN" != "true" ]]; then
            echo "Error: Not signed in" >&2
            exit 1
        fi
        
        # Mock secret values
        case "${2:-}" in
            "op://Development/API Keys/github_token")
                echo "ghp_mock_token_123456789"
                ;;
            "op://Development/API Keys/openai_key")
                echo "sk-mock_openai_key_987654321"
                ;;
            *)
                echo "mock_secret_value"
                ;;
        esac
        ;;
    inject)
        if [[ "$SIGNED_IN" != "true" ]]; then
            echo "Error: Not signed in" >&2
            exit 1
        fi
        
        # Simple injection simulation
        while IFS= read -r line; do
            if [[ "$line" == *"op://"* ]]; then
                echo "${line//op:\/\/*/mock_injected_value}"
            else
                echo "$line"
            fi
        done
        ;;
    *)
        echo "op: unknown command ${1:-}" >&2
        exit 1
        ;;
esac

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "op" "$@"
fi'

    mock_command "op" "$mock_script"
    MOCK_COMMANDS+=("op")
}

# Mock Git
mock_git() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock Git implementation
GIT_VERSION="2.39.0"

case "${1:-}" in
    --version)
        echo "git version $GIT_VERSION"
        exit 0
        ;;
    clone)
        # Mock git clone
        local repo="${2:-}"
        local target="${3:-.}"
        
        if [[ -z "$repo" ]]; then
            echo "fatal: You must specify a repository to clone." >&2
            exit 1
        fi
        
        mkdir -p "$target/.git"
        echo "Cloning into '"'"'$target'"'"'..."
        echo "Mock repository cloned successfully"
        ;;
    status)
        echo "On branch main"
        echo "nothing to commit, working tree clean"
        ;;
    config)
        case "${2:-}" in
            user.name)
                echo "Test User"
                ;;
            user.email)
                echo "test@example.com"
                ;;
            *)
                echo ""
                ;;
        esac
        ;;
    *)
        echo "Mock git command: $*"
        ;;
esac

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "git" "$@"
fi'

    mock_command "git" "$mock_script"
    MOCK_COMMANDS+=("git")
}

# Mock Homebrew
mock_brew() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock Homebrew implementation
BREW_VERSION="4.0.0"

case "${1:-}" in
    --version)
        echo "Homebrew $BREW_VERSION"
        exit 0
        ;;
    install)
        shift
        for package in "$@"; do
            echo "Installing $package..."
            echo "$package installed successfully"
        done
        ;;
    list)
        echo "gnu-stow"
        echo "git"
        echo "curl"
        ;;
    info)
        local package="${2:-}"
        echo "$package: Mock package info"
        echo "Installed: Yes"
        ;;
    update)
        echo "Updated Homebrew"
        ;;
    *)
        echo "Mock brew command: $*"
        ;;
esac

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "brew" "$@"
fi'

    mock_command "brew" "$mock_script"
    MOCK_COMMANDS+=("brew")
}

# Mock APT (Ubuntu/Debian package manager)
mock_apt() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock APT implementation
case "${1:-}" in
    update)
        echo "Reading package lists..."
        echo "All packages are up to date."
        ;;
    install)
        shift
        for package in "$@"; do
            echo "Installing $package..."
            echo "$package installed successfully"
        done
        ;;
    list)
        echo "stow/now 2.3.1-1 amd64 [installed]"
        echo "git/now 2.34.1-1 amd64 [installed]"
        ;;
    show)
        local package="${2:-}"
        echo "Package: $package"
        echo "State: installed"
        ;;
    *)
        echo "Mock apt command: $*"
        ;;
esac

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "apt" "$@"
fi'

    mock_command "apt" "$mock_script"
    MOCK_COMMANDS+=("apt")
}

# Mock YUM/DNF (Red Hat/Fedora package manager)
mock_dnf() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock DNF implementation
case "${1:-}" in
    update)
        echo "Updating package repository..."
        echo "Complete!"
        ;;
    install)
        shift
        for package in "$@"; do
            echo "Installing $package..."
            echo "$package installed successfully"
        done
        ;;
    list)
        echo "stow.x86_64    2.3.1-3.fc36    @fedora"
        echo "git.x86_64     2.37.1-1.fc36   @fedora"
        ;;
    info)
        local package="${2:-}"
        echo "Name         : $package"
        echo "Description  : Mock package"
        ;;
    *)
        echo "Mock dnf command: $*"
        ;;
esac

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "dnf" "$@"
fi'

    mock_command "dnf" "$mock_script"
    MOCK_COMMANDS+=("dnf")
}

# Mock curl
mock_curl() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock curl implementation
SIMULATE_NETWORK_ERROR="${MOCK_CURL_ERROR:-false}"

if [[ "$SIMULATE_NETWORK_ERROR" == "true" ]]; then
    echo "curl: (7) Failed to connect to example.com port 443: Connection refused" >&2
    exit 7
fi

# Simple mock responses
case "${*}" in
    *"--version"*)
        echo "curl 7.85.0 (x86_64-apple-darwin21.0) libcurl/7.85.0"
        ;;
    *"install.sh"*)
        echo "#!/usr/bin/env bash"
        echo "echo Mock install script"
        ;;
    *)
        echo "Mock HTTP response"
        ;;
esac

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "curl" "$@"
fi'

    mock_command "curl" "$mock_script"
    MOCK_COMMANDS+=("curl")
}

# Mock wget
mock_wget() {
    local mock_script='#!/usr/bin/env bash
set -euo pipefail

# Mock wget implementation
SIMULATE_NETWORK_ERROR="${MOCK_WGET_ERROR:-false}"

if [[ "$SIMULATE_NETWORK_ERROR" == "true" ]]; then
    echo "wget: unable to resolve host address" >&2
    exit 1
fi

# Parse basic wget arguments
OUTPUT_FILE=""
URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            echo "GNU Wget 1.21.3"
            exit 0
            ;;
        -O|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -q|--quiet)
            shift
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

# Generate mock content
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "Mock downloaded content" > "$OUTPUT_FILE"
else
    echo "Mock downloaded content"
fi

# Log the call
source "'"$(dirname "${BASH_SOURCE[0]}")"'/test-utils.sh" 2>/dev/null || true
if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
    log_mock_call "wget" "$@"
fi'

    mock_command "wget" "$mock_script"
    MOCK_COMMANDS+=("wget")
}

# Set up all standard mocks
setup_standard_mocks() {
    init_mock_logging
    
    mock_stow
    mock_git
    mock_curl
    mock_wget
    
    # Mock package managers based on OS
    case "$(uname -s)" in
        Darwin)
            mock_brew
            ;;
        Linux)
            mock_apt
            mock_dnf
            ;;
    esac
    
    test_debug "Standard mocks set up: ${MOCK_COMMANDS[*]}"
}

# Configure mock behavior
configure_mock() {
    local tool="$1"
    local behavior="$2"
    local value="${3:-}"
    
    case "$tool" in
        stow)
            case "$behavior" in
                conflicts)
                    export MOCK_STOW_CONFLICTS="$value"
                    ;;
            esac
            ;;
        op)
            case "$behavior" in
                signed_in)
                    export MOCK_OP_SIGNED_IN="$value"
                    ;;
                error)
                    export MOCK_OP_ERROR="$value"
                    ;;
            esac
            ;;
        curl)
            case "$behavior" in
                network_error)
                    export MOCK_CURL_ERROR="$value"
                    ;;
            esac
            ;;
        wget)
            case "$behavior" in
                network_error)
                    export MOCK_WGET_ERROR="$value"
                    ;;
            esac
            ;;
    esac
    
    test_debug "Configured mock $tool: $behavior = $value"
}

# Reset mock state
reset_mocks() {
    # Clear environment variables
    unset MOCK_STOW_CONFLICTS MOCK_OP_SIGNED_IN MOCK_OP_ERROR
    unset MOCK_CURL_ERROR MOCK_WGET_ERROR
    
    # Clear call log
    if [[ -f "$MOCK_CALL_LOG" ]]; then
        > "$MOCK_CALL_LOG"
    fi
    
    test_debug "Mock state reset"
}

# Clean up mocks
cleanup_mocks() {
    reset_mocks
    
    # Remove mock binaries from PATH
    for cmd in "${MOCK_COMMANDS[@]}"; do
        local mock_path="$TEST_TEMP_DIR/mock_bin/$cmd"
        if [[ -f "$mock_path" ]]; then
            rm -f "$mock_path"
        fi
    done
    
    restore_path
    MOCK_COMMANDS=()
    
    test_debug "Mocks cleaned up"
} 