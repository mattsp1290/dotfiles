#!/usr/bin/env bash
# Integration test for complete dotfiles workflow

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"
source "$TEST_DIR/../helpers/mock-tools.sh"
source "$TEST_DIR/../helpers/env-setup.sh"

# Test complete installation workflow
test_complete_installation() {
    create_test_environment "complete_install"
    activate_test_environment
    setup_standard_mocks
    
    # Create a mock dotfiles repository
    mkdir -p "$TEST_DOTFILES_DIR"
    create_dotfiles_structure
    create_test_secrets
    
    # Test bootstrap script
    local bootstrap_script="$DOTFILES_ROOT/scripts/bootstrap.sh"
    assert_file_exists "$bootstrap_script" "Bootstrap script should exist"
    
    # Run bootstrap in dry-run mode
    local output
    output=$(bash "$bootstrap_script" --dry-run install 2>&1 || true)
    
    assert_contains "$output" "Dry run mode" "Should show dry run message"
    assert_not_contains "$output" "ERROR" "Should not show errors in dry run"
}

# Test stow workflow
test_stow_workflow() {
    create_test_environment "stow_workflow"
    activate_test_environment
    setup_standard_mocks
    create_dotfiles_structure
    
    # Test stow-all script
    local stow_script="$DOTFILES_ROOT/scripts/stow-all.sh"
    assert_file_exists "$stow_script" "Stow script should exist"
    
    # Run stow with mocked stow command
    local output
    output=$(bash "$stow_script" --dry-run 2>&1 || true)
    
    assert_contains "$output" "packages would be stowed" "Should show packages to stow"
    
    # Verify mock stow was called
    local stow_calls
    stow_calls=$(get_mock_call_count "stow")
    assert_greater_than "0" "$stow_calls" "Stow should have been called"
}

# Test unstow workflow
test_unstow_workflow() {
    create_test_environment "unstow_workflow"
    activate_test_environment
    setup_standard_mocks
    create_dotfiles_structure
    
    # Create some symlinked files to unstow
    mkdir -p "$TEST_HOME"
    ln -sf "$TEST_DOTFILES_DIR/vim/.vimrc" "$TEST_HOME/.vimrc"
    ln -sf "$TEST_DOTFILES_DIR/zsh/.zshrc" "$TEST_HOME/.zshrc"
    
    # Test unstow-all script
    local unstow_script="$DOTFILES_ROOT/scripts/unstow-all.sh"
    assert_file_exists "$unstow_script" "Unstow script should exist"
    
    # Run unstow
    local output
    output=$(bash "$unstow_script" --dry-run 2>&1 || true)
    
    assert_contains "$output" "packages would be unstowed" "Should show packages to unstow"
}

# Test secret injection workflow
test_secret_injection() {
    create_test_environment "secret_injection"
    activate_test_environment
    setup_standard_mocks
    create_dotfiles_structure
    create_test_secrets
    
    # Mock 1Password CLI to be signed in
    configure_mock "op" "signed_in" "true"
    
    # Test inject-secrets script
    local inject_script="$DOTFILES_ROOT/scripts/inject-secrets.sh"
    assert_file_exists "$inject_script" "Inject secrets script should exist"
    
    # Run secret injection
    local output
    output=$(bash "$inject_script" --dry-run 2>&1 || true)
    
    assert_contains "$output" "templates found" "Should find templates"
    
    # Verify 1Password CLI was called
    local op_calls
    op_calls=$(get_mock_call_count "op")
    assert_greater_than "0" "$op_calls" "1Password CLI should have been called"
}

# Test cross-platform compatibility
test_cross_platform() {
    create_test_environment "cross_platform"
    activate_test_environment
    setup_standard_mocks
    create_dotfiles_structure
    
    # Test macOS
    simulate_os_environment "macos"
    local os_script="$DOTFILES_ROOT/scripts/lib/detect-os.sh"
    
    source "$os_script"
    local detected_os
    detected_os=$(detect_os)
    assert_equals "$detected_os" "macos" "Should detect macOS"
    
    local package_manager
    package_manager=$(detect_package_manager)
    assert_equals "$package_manager" "brew" "Should detect Homebrew"
    
    # Test Ubuntu
    simulate_os_environment "ubuntu"
    detected_os=$(detect_os)
    assert_equals "$detected_os" "ubuntu" "Should detect Ubuntu"
    
    package_manager=$(detect_package_manager)
    assert_equals "$package_manager" "apt" "Should detect APT"
}

# Test error handling
test_error_handling() {
    create_test_environment "error_handling"
    activate_test_environment
    setup_standard_mocks
    
    # Test missing dotfiles directory
    local nonexistent_dir="/nonexistent/dotfiles"
    local stow_script="$DOTFILES_ROOT/scripts/stow-all.sh"
    
    local output
    output=$(DOTFILES_DIR="$nonexistent_dir" bash "$stow_script" --dry-run 2>&1 || true)
    
    assert_contains "$output" "not found\|does not exist" "Should handle missing directory"
    
    # Test stow conflicts
    create_dotfiles_structure
    configure_mock "stow" "conflicts" "true"
    
    output=$(bash "$stow_script" --dry-run 2>&1 || true)
    assert_contains "$output" "conflict\|WARNING" "Should handle stow conflicts"
}

# Test configuration validation
test_config_validation() {
    create_test_environment "config_validation"
    activate_test_environment
    create_dotfiles_structure
    
    # Test template validation script
    local validate_script="$DOTFILES_ROOT/scripts/validate-templates.sh"
    assert_file_exists "$validate_script" "Validate templates script should exist"
    
    # Create some templates to validate
    create_test_secrets
    
    local output
    output=$(bash "$validate_script" 2>&1 || true)
    
    assert_contains "$output" "template\|validation" "Should perform template validation"
}

# Test package filtering
test_package_filtering() {
    create_test_environment "package_filtering"
    activate_test_environment
    setup_standard_mocks
    create_dotfiles_structure
    
    # Create platform-specific packages
    mkdir -p "$TEST_DOTFILES_DIR"/{macos-specific,linux-specific,ignored-package}
    create_test_file "$TEST_DOTFILES_DIR/macos-specific/.testrc" "macos config"
    create_test_file "$TEST_DOTFILES_DIR/linux-specific/.testrc" "linux config"
    create_test_file "$TEST_DOTFILES_DIR/ignored-package/.testrc" "ignored config"
    
    # Create ignore file
    echo "ignored-package" > "$TEST_DOTFILES_DIR/.stow-local-ignore"
    
    # Test on macOS
    simulate_os_environment "macos"
    local output
    output=$(bash "$DOTFILES_ROOT/scripts/stow-all.sh" --dry-run 2>&1 || true)
    
    assert_contains "$output" "macos-specific" "Should include macOS-specific package"
    assert_not_contains "$output" "linux-specific" "Should exclude Linux-specific package"
    assert_not_contains "$output" "ignored-package" "Should exclude ignored package"
}

# Test backup and recovery
test_backup_recovery() {
    create_test_environment "backup_recovery"
    activate_test_environment
    setup_standard_mocks
    create_dotfiles_structure
    
    # Create existing config files
    create_test_file "$TEST_HOME/.vimrc" "existing vim config"
    create_test_file "$TEST_HOME/.zshrc" "existing zsh config"
    
    # Test adoption workflow
    local stow_script="$DOTFILES_ROOT/scripts/stow-all.sh"
    local output
    output=$(bash "$stow_script" --adopt --dry-run 2>&1 || true)
    
    assert_contains "$output" "adopt\|backup" "Should mention adoption or backup"
    
    # Verify original files would be preserved
    assert_file_exists "$TEST_HOME/.vimrc" "Original file should still exist"
    assert_file_contains "$TEST_HOME/.vimrc" "existing vim config" "Original content preserved"
}

# Test doctor functionality
test_doctor_functionality() {
    create_test_environment "doctor"
    activate_test_environment
    setup_standard_mocks
    
    # Test bootstrap doctor mode
    local bootstrap_script="$DOTFILES_ROOT/scripts/bootstrap.sh"
    local output
    output=$(bash "$bootstrap_script" doctor 2>&1 || true)
    
    assert_contains "$output" "diagnostic\|check\|doctor" "Should perform diagnostic checks"
    assert_contains "$output" "prerequisite\|requirement" "Should check prerequisites"
}

# Test help and documentation
test_help_documentation() {
    create_test_environment "help_docs"
    activate_test_environment
    
    # Test that all main scripts have help
    local scripts=("bootstrap.sh" "stow-all.sh" "unstow-all.sh" "inject-secrets.sh")
    
    for script in "${scripts[@]}"; do
        local script_path="$DOTFILES_ROOT/scripts/$script"
        if [[ -f "$script_path" ]]; then
            local help_output
            help_output=$(bash "$script_path" --help 2>&1 || true)
            assert_contains "$help_output" "USAGE\|usage" "Script $script should have usage information"
        fi
    done
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Complete Workflow Integration Tests"
    echo "==========================================="
    
    run_test "Complete Installation Workflow" test_complete_installation
    run_test "Stow Workflow" test_stow_workflow
    run_test "Unstow Workflow" test_unstow_workflow
    run_test "Secret Injection Workflow" test_secret_injection
    run_test "Cross-Platform Compatibility" test_cross_platform
    run_test "Error Handling" test_error_handling
    run_test "Configuration Validation" test_config_validation
    run_test "Package Filtering" test_package_filtering
    run_test "Backup and Recovery" test_backup_recovery
    run_test "Doctor Functionality" test_doctor_functionality
    run_test "Help and Documentation" test_help_documentation
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 