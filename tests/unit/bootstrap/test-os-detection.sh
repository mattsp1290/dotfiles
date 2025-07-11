#!/usr/bin/env bash
# Unit tests for OS detection functionality

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../../helpers/test-utils.sh"
source "$TEST_DIR/../../helpers/assertions.sh"
source "$TEST_DIR/../../helpers/mock-tools.sh"
source "$TEST_DIR/../../helpers/env-setup.sh"

# Source the code being tested
source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"

# Test basic OS detection
test_detect_os_basic() {
    create_test_environment "os_detection"
    activate_test_environment
    
    # Test macOS detection
    simulate_os_environment "macos"
    local detected_os
    detected_os=$(detect_os_type)
    assert_equals "$detected_os" "macos" "Should detect macOS"
    
    # Test Ubuntu detection
    simulate_os_environment "ubuntu"
    detected_os=$(detect_os_type)
    assert_equals "$detected_os" "ubuntu" "Should detect Ubuntu"
    
    # Test Fedora detection
    simulate_os_environment "fedora"
    detected_os=$(detect_os_type)
    assert_equals "$detected_os" "fedora" "Should detect Fedora"
}

# Test OS version detection
test_detect_os_version() {
    create_test_environment "os_version"
    activate_test_environment
    
    # Test macOS version
    simulate_os_environment "macos" "12.6"
    local version
    version=$(detect_os_version)
    assert_equals "$version" "12.6" "Should detect macOS version"
    
    # Test Ubuntu version
    simulate_os_environment "ubuntu" "20.04"
    version=$(detect_os_version)
    assert_equals "$version" "20.04" "Should detect Ubuntu version"
}

# Test architecture detection
test_detect_architecture() {
    create_test_environment "architecture"
    activate_test_environment
    
    # Mock uname for different architectures
    mock_command "uname" 'case "$1" in -m) echo "x86_64";; *) echo "unknown";; esac'
    
    local arch
    arch=$(detect_architecture)
    assert_equals "$arch" "x86_64" "Should detect x86_64 architecture"
    
    # Mock ARM architecture
    mock_command "uname" 'case "$1" in -m) echo "arm64";; *) echo "unknown";; esac'
    
    arch=$(detect_architecture)
    assert_equals "$arch" "arm64" "Should detect ARM64 architecture"
}

# Test package manager detection
test_detect_package_manager() {
    create_test_environment "package_manager"
    activate_test_environment
    
    # Test Homebrew detection (macOS)
    simulate_os_environment "macos"
    setup_standard_mocks
    
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)
    assert_equals "$pkg_mgr" "brew" "Should detect Homebrew on macOS"
    
    # Test APT detection (Ubuntu)
    simulate_os_environment "ubuntu"
    
    pkg_mgr=$(detect_package_manager)
    assert_equals "$pkg_mgr" "apt" "Should detect APT on Ubuntu"
    
    # Test DNF detection (Fedora)
    simulate_os_environment "fedora"
    
    pkg_mgr=$(detect_package_manager)
    assert_equals "$pkg_mgr" "dnf" "Should detect DNF on Fedora"
}

# Test OS compatibility checking
test_check_os_compatibility() {
    create_test_environment "os_compatibility"
    activate_test_environment
    
    # Test supported OS
    simulate_os_environment "macos" "12.6"
    assert_true "check_os_compatibility" "macOS 12.6 should be compatible"
    
    # Test minimum version check
    simulate_os_environment "macos" "10.14"
    assert_false "check_os_compatibility" "macOS 10.14 should not be compatible"
    
    # Test supported Linux
    simulate_os_environment "ubuntu" "20.04"
    assert_true "check_os_compatibility" "Ubuntu 20.04 should be compatible"
}

# Test container detection
test_is_container() {
    create_test_environment "container_detection"
    activate_test_environment
    
    # Test normal environment
    assert_false "is_container" "Normal environment should not be detected as container"
    
    # Test Docker container
    create_test_file "$TEST_TEMP_DIR/.dockerenv" ""
    assert_true "is_container" "Should detect Docker container"
    
    # Clean up
    rm -f "$TEST_TEMP_DIR/.dockerenv"
    
    # Test via cgroup
    mkdir -p "$TEST_TEMP_DIR/proc/1"
    echo "1:name=systemd:/docker/container_id" > "$TEST_TEMP_DIR/proc/1/cgroup"
    
    # Mock /proc/1/cgroup
    mock_command "cat" "echo '1:name=systemd:/docker/container_id'"
    
    assert_true "is_container" "Should detect container via cgroup"
}

# Test WSL detection
test_is_wsl() {
    create_test_environment "wsl_detection"
    activate_test_environment
    
    # Test normal Linux
    simulate_os_environment "ubuntu"
    assert_false "is_wsl" "Normal Ubuntu should not be detected as WSL"
    
    # Test WSL environment
    mkdir -p "$TEST_TEMP_DIR/proc"
    echo "Microsoft" > "$TEST_TEMP_DIR/proc/version"
    
    # Mock /proc/version
    mock_command "cat" 'echo "Linux version 5.4.0-Microsoft (Microsoft@Microsoft.com)"'
    
    assert_true "is_wsl" "Should detect WSL environment"
}

# Test shell detection
test_detect_shell() {
    create_test_environment "shell_detection"
    activate_test_environment
    
    # Test bash
    export SHELL="/bin/bash"
    local shell
    shell=$(detect_shell)
    assert_equals "$shell" "bash" "Should detect bash shell"
    
    # Test zsh
    export SHELL="/bin/zsh"
    shell=$(detect_shell)
    assert_equals "$shell" "zsh" "Should detect zsh shell"
    
    # Test fish
    export SHELL="/usr/local/bin/fish"
    shell=$(detect_shell)
    assert_equals "$shell" "fish" "Should detect fish shell"
}

# Test minimum version checking
test_version_comparison() {
    create_test_environment "version_comparison"
    activate_test_environment
    
    # Test equal versions
    assert_true "version_gte '2.3.1' '2.3.1'" "Equal versions should be gte"
    
    # Test greater version
    assert_true "version_gte '2.4.0' '2.3.1'" "Greater version should be gte"
    
    # Test lesser version
    assert_false "version_gte '2.2.0' '2.3.1'" "Lesser version should not be gte"
    
    # Test different format versions
    assert_true "version_gte '12.6' '12.0'" "macOS versions should compare correctly"
    assert_false "version_gte '11.7' '12.0'" "macOS versions should compare correctly"
}

# Test OS string formatting
test_get_os_string() {
    create_test_environment "os_string"
    activate_test_environment
    
    # Test macOS string
    simulate_os_environment "macos" "12.6"
    local os_string
    os_string=$(get_os_string)
    assert_matches "$os_string" "macOS.*12\.6" "Should format macOS string correctly"
    
    # Test Ubuntu string
    simulate_os_environment "ubuntu" "20.04"
    os_string=$(get_os_string)
    assert_matches "$os_string" "Ubuntu.*20\.04" "Should format Ubuntu string correctly"
}

# Test hardware detection
test_detect_hardware() {
    create_test_environment "hardware_detection"
    activate_test_environment
    
    # Mock system_profiler for Mac
    simulate_os_environment "macos"
    mock_command "system_profiler" 'echo "Model Name: MacBook Pro"; echo "Chip: Apple M1"'
    
    local hardware
    hardware=$(detect_hardware)
    assert_contains "$hardware" "MacBook Pro" "Should detect Mac hardware"
    
    # Mock lscpu for Linux
    simulate_os_environment "ubuntu"
    mock_command "lscpu" 'echo "Model name: Intel(R) Core(TM) i7-8550U"'
    
    hardware=$(detect_hardware)
    assert_contains "$hardware" "Intel" "Should detect Intel hardware"
}

# Test environment capability detection
test_detect_capabilities() {
    create_test_environment "capabilities"
    activate_test_environment
    setup_standard_mocks
    
    # Test GUI capability
    export DISPLAY=":0"
    assert_true "has_gui" "Should detect GUI capability with DISPLAY set"
    
    unset DISPLAY
    assert_false "has_gui" "Should not detect GUI capability without DISPLAY"
    
    # Test network capability
    configure_mock "curl" "network_error" "false"
    assert_true "has_network" "Should detect network capability"
    
    configure_mock "curl" "network_error" "true"
    assert_false "has_network" "Should not detect network with error"
}

# Main test runner
main() {
    init_test_session
    
    echo "Running OS Detection Tests"
    echo "=========================="
    
    run_test "Basic OS Detection" test_detect_os_basic
    run_test "OS Version Detection" test_detect_os_version
    run_test "Architecture Detection" test_detect_architecture
    run_test "Package Manager Detection" test_detect_package_manager
    run_test "OS Compatibility Checking" test_check_os_compatibility
    run_test "Container Detection" test_is_container
    run_test "WSL Detection" test_is_wsl
    run_test "Shell Detection" test_detect_shell
    run_test "Version Comparison" test_version_comparison
    run_test "OS String Formatting" test_get_os_string
    run_test "Hardware Detection" test_detect_hardware
    run_test "Environment Capabilities" test_detect_capabilities
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 