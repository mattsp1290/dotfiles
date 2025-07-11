#!/usr/bin/env bash
# Unit tests for stow package detection functionality

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../../helpers/test-utils.sh"
source "$TEST_DIR/../../helpers/assertions.sh"
source "$TEST_DIR/../../helpers/mock-tools.sh"
source "$TEST_DIR/../../helpers/env-setup.sh"

# Source the code being tested
source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"

# Test package detection
test_package_detection_basic() {
    create_test_environment "package_detection"
    activate_test_environment
    create_dotfiles_structure
    
    # Test basic package detection
    local packages
    packages=$(get_available_packages "$TEST_DOTFILES_DIR")
    
    assert_contains "$packages" "vim" "Should detect vim package"
    assert_contains "$packages" "zsh" "Should detect zsh package"
    assert_contains "$packages" "git" "Should detect git package"
    assert_contains "$packages" "tmux" "Should detect tmux package"
    assert_contains "$packages" "ssh" "Should detect ssh package"
}

# Test platform-specific package detection
test_platform_specific_packages() {
    create_test_environment "platform_packages"
    activate_test_environment
    create_dotfiles_structure
    
    # Create platform-specific packages
    mkdir -p "$TEST_DOTFILES_DIR"/{macos-only,linux-only,ubuntu-only}
    create_test_file "$TEST_DOTFILES_DIR/macos-only/.testrc" "macos config"
    create_test_file "$TEST_DOTFILES_DIR/linux-only/.testrc" "linux config"
    create_test_file "$TEST_DOTFILES_DIR/ubuntu-only/.testrc" "ubuntu config"
    
    # Test macOS detection
    simulate_os_environment "macos"
    local macos_packages
    macos_packages=$(get_platform_packages "$TEST_DOTFILES_DIR")
    assert_contains "$macos_packages" "macos-only" "Should detect macOS-only package"
    assert_not_contains "$macos_packages" "linux-only" "Should not detect linux-only package"
    
    # Test Linux detection
    simulate_os_environment "ubuntu"
    local linux_packages
    linux_packages=$(get_platform_packages "$TEST_DOTFILES_DIR")
    assert_contains "$linux_packages" "linux-only" "Should detect linux-only package"
    assert_contains "$linux_packages" "ubuntu-only" "Should detect ubuntu-only package"
    assert_not_contains "$linux_packages" "macos-only" "Should not detect macOS-only package"
}

# Test package filtering
test_package_filtering() {
    create_test_environment "package_filtering"
    activate_test_environment
    create_dotfiles_structure
    
    # Create packages with ignore patterns
    mkdir -p "$TEST_DOTFILES_DIR"/{test-package,ignored-package,temp-package}
    create_test_file "$TEST_DOTFILES_DIR/test-package/.testrc" "test config"
    create_test_file "$TEST_DOTFILES_DIR/ignored-package/.testrc" "ignored config"
    create_test_file "$TEST_DOTFILES_DIR/temp-package/.testrc" "temp config"
    
    # Create .stow-local-ignore file
    cat > "$TEST_DOTFILES_DIR/.stow-local-ignore" << 'EOF'
ignored-package
temp-*
.git
.DS_Store
EOF
    
    local filtered_packages
    filtered_packages=$(filter_packages "$TEST_DOTFILES_DIR" "test-package ignored-package temp-package")
    
    assert_contains "$filtered_packages" "test-package" "Should include test-package"
    assert_not_contains "$filtered_packages" "ignored-package" "Should filter ignored-package"
    assert_not_contains "$filtered_packages" "temp-package" "Should filter temp-package"
}

# Test package validation
test_package_validation() {
    create_test_environment "package_validation"
    activate_test_environment
    create_dotfiles_structure
    
    # Test valid package
    assert_true "validate_package '$TEST_DOTFILES_DIR/vim'" "vim package should be valid"
    
    # Test invalid package (doesn't exist)
    assert_false "validate_package '$TEST_DOTFILES_DIR/nonexistent'" "nonexistent package should be invalid"
    
    # Test empty package (no files)
    mkdir -p "$TEST_DOTFILES_DIR/empty-package"
    assert_false "validate_package '$TEST_DOTFILES_DIR/empty-package'" "empty package should be invalid"
}

# Test package conflict detection
test_package_conflicts() {
    create_test_environment "package_conflicts"
    activate_test_environment
    create_dotfiles_structure
    setup_standard_mocks
    
    # Create conflicting file in target
    create_test_file "$TEST_HOME/.vimrc" "existing vim config"
    
    # Test conflict detection
    configure_mock "stow" "conflicts" "true"
    
    local conflicts
    conflicts=$(detect_conflicts "$TEST_DOTFILES_DIR" "$TEST_HOME" "vim")
    
    assert_not_equals "$conflicts" "" "Should detect conflicts"
    assert_contains "$conflicts" ".vimrc" "Should detect .vimrc conflict"
}

# Test package dependency resolution
test_package_dependencies() {
    create_test_environment "package_deps"
    activate_test_environment
    create_dotfiles_structure
    
    # Create package with dependencies
    mkdir -p "$TEST_DOTFILES_DIR/dependent-package"
    cat > "$TEST_DOTFILES_DIR/dependent-package/.stow-dependencies" << 'EOF'
vim
git
EOF
    create_test_file "$TEST_DOTFILES_DIR/dependent-package/.testrc" "dependent config"
    
    local dependencies
    dependencies=$(get_package_dependencies "$TEST_DOTFILES_DIR/dependent-package")
    
    assert_contains "$dependencies" "vim" "Should detect vim dependency"
    assert_contains "$dependencies" "git" "Should detect git dependency"
}

# Test package ordering
test_package_ordering() {
    create_test_environment "package_ordering"
    activate_test_environment
    create_dotfiles_structure
    
    # Create packages with priorities
    mkdir -p "$TEST_DOTFILES_DIR"/{high-priority,low-priority,normal-priority}
    
    echo "1" > "$TEST_DOTFILES_DIR/high-priority/.stow-priority"
    echo "99" > "$TEST_DOTFILES_DIR/low-priority/.stow-priority"
    # normal-priority has no priority file (default: 50)
    
    create_test_file "$TEST_DOTFILES_DIR/high-priority/.testrc" "high"
    create_test_file "$TEST_DOTFILES_DIR/low-priority/.testrc" "low"
    create_test_file "$TEST_DOTFILES_DIR/normal-priority/.testrc" "normal"
    
    local ordered_packages
    ordered_packages=$(order_packages "$TEST_DOTFILES_DIR" "low-priority high-priority normal-priority")
    
    # Should be ordered by priority: high (1), normal (50), low (99)
    local first_package
    first_package=$(echo "$ordered_packages" | cut -d' ' -f1)
    assert_equals "$first_package" "high-priority" "High priority package should be first"
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Stow Package Detection Tests"
    echo "===================================="
    
    run_test "Basic Package Detection" test_package_detection_basic
    run_test "Platform-Specific Packages" test_platform_specific_packages
    run_test "Package Filtering" test_package_filtering
    run_test "Package Validation" test_package_validation
    run_test "Package Conflicts" test_package_conflicts
    run_test "Package Dependencies" test_package_dependencies
    run_test "Package Ordering" test_package_ordering
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 