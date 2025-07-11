#!/usr/bin/env bash
# Integration Test Helper Functions
# Extends the base test framework with integration-specific utilities

# Source base test utilities  
TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_HELPERS_PATH="$(cd "$TEST_LIB_DIR/../../helpers" && pwd)"
source "$TEST_HELPERS_PATH/test-utils.sh"
source "$TEST_HELPERS_PATH/mock-tools.sh"
source "$TEST_HELPERS_PATH/env-setup.sh"

# Colors for integration test output
if [[ -t 1 ]]; then
    INTEGRATION_RED=$(tput setaf 1)
    INTEGRATION_GREEN=$(tput setaf 2)
    INTEGRATION_YELLOW=$(tput setaf 3)
    INTEGRATION_BLUE=$(tput setaf 4)
    INTEGRATION_BOLD=$(tput bold)  
    INTEGRATION_RESET=$(tput sgr0)
else
    INTEGRATION_RED=""
    INTEGRATION_GREEN=""
    INTEGRATION_YELLOW=""
    INTEGRATION_BLUE=""
    INTEGRATION_BOLD=""
    INTEGRATION_RESET=""
fi

# Integration-specific logging functions
info() {
    echo "${INTEGRATION_BLUE}[INFO]${INTEGRATION_RESET} $*"
}

success() {
    echo "${INTEGRATION_GREEN}[SUCCESS]${INTEGRATION_RESET} $*"
}

warning() {
    echo "${INTEGRATION_YELLOW}[WARNING]${INTEGRATION_RESET} $*"
}

error() {
    echo "${INTEGRATION_RED}[ERROR]${INTEGRATION_RESET} $*" >&2
}

# Integration test specific variables
readonly INTEGRATION_TEST_TIMEOUT=${TEST_TIMEOUT:-1800}  # 30 minutes default
readonly INTEGRATION_FIXTURES_DIR="$TEST_LIB_DIR/../fixtures"
readonly SAMPLE_CONFIGS_DIR="$INTEGRATION_FIXTURES_DIR/sample-configs"

# Create isolated dotfiles repository for testing
create_test_dotfiles_repo() {
    local repo_name="${1:-minimal-dotfiles}"
    local target_dir="${2:-$TEST_WORKSPACE/test-dotfiles}"
    
    # Copy sample configuration
    local source_dir="$SAMPLE_CONFIGS_DIR/$repo_name"
    if [[ ! -d "$source_dir" ]]; then
        error "Sample configuration not found: $repo_name"
        return 1
    fi
    
    # Create target directory and copy files
    mkdir -p "$target_dir"
    cp -r "$source_dir"/* "$target_dir/"
    
    # Make scripts executable
    find "$target_dir" -name "*.sh" -exec chmod +x {} \;
    
    # Initialize git repository
    if command -v git >/dev/null 2>&1; then
        cd "$target_dir"
        git init --initial-branch=main >/dev/null 2>&1
        git add .
        git commit -m "Initial test dotfiles configuration" >/dev/null 2>&1
        cd - >/dev/null
    fi
    
    echo "$target_dir"
    return 0
}

# Simulate different OS environments
simulate_os_environment() {
    local os_type="$1"
    
    info "Simulating $os_type environment"
    
    case "$os_type" in
        "macos")
            export OSTYPE="darwin21"
            export OS="Darwin"
            mock_command "brew" "echo 'Homebrew 3.6.0'"
            mock_command "sw_vers" "echo 'ProductName: macOS'; echo 'ProductVersion: 12.6'"
            ;;
        "ubuntu")
            export OSTYPE="linux-gnu"
            export OS="Linux"
            create_temp_file "/etc/os-release" "ID=ubuntu\nVERSION_ID=\"20.04\""
            mock_command "lsb_release" "echo 'Ubuntu 20.04 LTS'"
            mock_command "apt" "echo 'apt 2.0.6'"
            ;;
        "debian")
            export OSTYPE="linux-gnu"
            export OS="Linux"
            create_temp_file "/etc/os-release" "ID=debian\nVERSION_ID=\"11\""
            mock_command "apt" "echo 'apt 2.2.4'"
            ;;
        "fedora")
            export OSTYPE="linux-gnu"
            export OS="Linux"
            create_temp_file "/etc/os-release" "ID=fedora\nVERSION_ID=\"36\""
            mock_command "dnf" "echo 'dnf 4.14.0'"
            ;;
        "arch")
            export OSTYPE="linux-gnu"
            export OS="Linux"
            create_temp_file "/etc/os-release" "ID=arch\nNAME=\"Arch Linux\""
            mock_command "pacman" "echo 'Pacman v6.0.1'"
            ;;
        *)
            error "Unknown OS type: $os_type"
            return 1
            ;;
    esac
    
    # Common Linux setup
    if [[ "$os_type" != "macos" ]]; then
        create_temp_file "/etc/passwd" "root:x:0:0:root:/root:/bin/bash\n$USER:x:1000:1000:$USER:/home/$USER:/bin/bash"
        create_temp_file "/proc/version" "Linux version 5.15.0"
    fi
    
    success "Simulated $os_type environment"
    return 0
}

# Create a temporary file in the test environment
create_temp_file() {
    local file_path="$1"
    local content="$2"
    
    # Create directory structure
    local dir_path="$(dirname "$file_path")"
    mkdir -p "$TEST_WORKSPACE$dir_path"
    
    # Create file with content
    echo -e "$content" > "$TEST_WORKSPACE$file_path"
    
    # Mock the file access
    mock_command "cat" "if [[ \"\$1\" == \"$file_path\" ]]; then cat \"$TEST_WORKSPACE$file_path\"; else command cat \"\$@\"; fi"
}

# Mock a command with specific behavior
mock_command() {
    local command="$1"
    local behavior="$2"
    
    # Create mock script
    local mock_script="$TEST_WORKSPACE/bin/$command"
    mkdir -p "$(dirname "$mock_script")"
    
    cat > "$mock_script" << EOF
#!/bin/bash
# Mock for $command
$behavior
EOF
    
    chmod +x "$mock_script"
    
    # Add to PATH
    export PATH="$TEST_WORKSPACE/bin:$PATH"
}

# Verify integration test markers in output
verify_integration_markers() {
    local output="$1"
    local description="${2:-Integration test markers}"
    
    local markers_found=0
    local expected_markers=(
        "INTEGRATION_TEST_MARKER"
        "Bootstrap"
        "Installation"
        "Configuration"
    )
    
    for marker in "${expected_markers[@]}"; do
        if echo "$output" | grep -q "$marker"; then
            ((markers_found++))
        fi
    done
    
    if [[ $markers_found -gt 0 ]]; then
        success "$description: Found $markers_found integration markers"
        return 0
    else
        error "$description: No integration markers found"
        return 1
    fi
}

# Time a command execution
time_command() {
    local description="$1"
    shift
    local command=("$@")
    
    info "Timing: $description"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    "${command[@]}" || exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        success "$description completed in ${duration}s"
    else
        error "$description failed after ${duration}s (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Check if running in CI environment
is_ci_environment() {
    [[ "${CI:-false}" == "true" ]] || [[ "${DOTFILES_CI:-false}" == "true" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Skip test if not in appropriate environment
skip_if_not_supported() {
    local platform="$1"
    local reason="${2:-Platform not supported in current environment}"
    
    case "$platform" in
        "docker")
            if ! command -v docker >/dev/null 2>&1; then
                skip_test "Docker not available: $reason"
                return 0
            fi
            ;;
        "vagrant")
            if ! command -v vagrant >/dev/null 2>&1; then
                skip_test "Vagrant not available: $reason"
                return 0
            fi
            ;;
        "macos")
            if [[ "$OSTYPE" != "darwin"* ]]; then
                skip_test "macOS required: $reason"
                return 0
            fi
            ;;
        "linux")
            if [[ "$OSTYPE" != "linux-gnu" ]]; then
                skip_test "Linux required: $reason"
                return 0
            fi
            ;;
    esac
    
    return 1  # Don't skip
}

# Skip test with message
skip_test() {
    local reason="$1"
    warning "SKIPPED: $reason"
    return 0
}

# Create performance benchmark baseline
create_performance_baseline() {
    local test_name="$1"
    local baseline_file="$TEST_WORKSPACE/performance-baseline-$test_name.json"
    
    cat > "$baseline_file" << EOF
{
    "test_name": "$test_name",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "platform": "${TEST_PLATFORM:-unknown}",
    "baseline_times": {
        "installation": 300,
        "shell_startup": 2,
        "stow_operations": 60
    },
    "thresholds": {
        "installation_max": 900,
        "shell_startup_max": 5,
        "stow_operations_max": 300
    }
}
EOF
    
    echo "$baseline_file"
}

# Compare performance against baseline
compare_performance() {
    local actual_time="$1"
    local baseline_time="$2"
    local test_name="$3"
    
    local variance_percent=$(( (actual_time - baseline_time) * 100 / baseline_time ))
    
    if [[ $variance_percent -le 10 ]]; then
        success "$test_name: Performance within baseline (${variance_percent}% variance)"
        return 0
    elif [[ $variance_percent -le 50 ]]; then
        warning "$test_name: Performance slower than baseline (${variance_percent}% variance)"
        return 0
    else
        error "$test_name: Performance significantly degraded (${variance_percent}% variance)"
        return 1
    fi
}

# Generate integration test report
generate_integration_report() {
    local test_results_dir="${1:-$TEST_WORKSPACE/test-results}"
    local report_file="$test_results_dir/integration-report.json"
    
    mkdir -p "$test_results_dir"
    
    cat > "$report_file" << EOF
{
    "report_type": "integration_test",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "platform": "${TEST_PLATFORM:-unknown}",
    "environment": {
        "ci": $(is_ci_environment && echo "true" || echo "false"),
        "os_type": "${OSTYPE:-unknown}",
        "shell": "${SHELL:-unknown}",
        "user": "${USER:-unknown}"
    },
    "test_session": {
        "start_time": "${TEST_SESSION_START:-unknown}",
        "workspace": "${TEST_WORKSPACE:-unknown}",
        "total_tests": ${TEST_COUNT:-0},
        "passed_tests": ${PASSED_COUNT:-0},
        "failed_tests": ${FAILED_COUNT:-0}
    }
}
EOF
    
    info "Integration test report generated: $report_file"
    echo "$report_file"
}

# Initialize integration test session
init_integration_test_session() {
    info "Initializing integration test session"
    
    # Set integration-specific environment
    export INTEGRATION_TEST=true
    export TEST_SESSION_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create integration test workspace in temp directory
    if [[ -z "${TEST_WORKSPACE:-}" ]]; then
        export TEST_WORKSPACE=$(mktemp -d -t "integration-test-XXXXXX")
        info "Created test workspace: $TEST_WORKSPACE"
    fi
    
    # Set up standard mocks for integration testing
    if command -v setup_standard_mocks >/dev/null 2>&1; then
        setup_standard_mocks
    fi
    
    success "Integration test session initialized"
}

# Clean up integration test session
cleanup_integration_test_session() {
    info "Cleaning up integration test session"
    
    # Generate final report
    generate_integration_report
    
    # Clean up test workspace
    if [[ -n "${TEST_WORKSPACE:-}" ]] && [[ -d "$TEST_WORKSPACE" ]]; then
        rm -rf "$TEST_WORKSPACE"
        info "Cleaned up test workspace: $TEST_WORKSPACE"
    fi
    
    success "Integration test session cleaned up"
} 