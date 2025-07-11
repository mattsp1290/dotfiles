#!/usr/bin/env bash
# Fresh Installation Integration Tests
# Tests complete dotfiles installation from clean state

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"
source "$TEST_DIR/../helpers/mock-tools.sh"
source "$TEST_DIR/../helpers/env-setup.sh"

# Test fresh installation from scratch
test_fresh_installation_basic() {
    create_test_environment "fresh_install_basic"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing basic fresh installation workflow"
    
    # Mock a completely clean system
    export PATH="/usr/bin:/bin"
    unset DOTFILES_DIR DOTFILES_ROOT
    
    # Create minimal test repository structure
    local test_repo="$TEST_WORKSPACE/test-dotfiles"
    mkdir -p "$test_repo"/{scripts,config,shell}
    
    # Create minimal bootstrap script
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Bootstrap script executed with args: $*"
echo "Current directory: $(pwd)"
echo "Environment variables:"
env | grep -E "^(HOME|USER|DOTFILES)" || true
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test install.sh with test repository
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Bootstrap script executed" "Bootstrap should be executed"
    assert_contains "$output" "install" "Install command should be passed"
    assert_not_contains "$output" "ERROR" "Should not show errors"
}

# Test fresh installation with prerequisites missing
test_fresh_installation_missing_prereqs() {
    create_test_environment "fresh_install_no_prereqs"
    activate_test_environment
    
    info "Testing fresh installation with missing prerequisites"
    
    # Mock missing git
    configure_mock "git" "missing" "true"
    
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --dry-run 2>&1 || true)
    
    assert_contains "$output" "Git is not installed\|git.*required" "Should detect missing git"
    assert_contains "$output" "WARNING\|installed during setup" "Should warn about git"
}

# Test fresh installation with different OS environments
test_fresh_installation_cross_platform() {
    local platforms=("macos" "ubuntu" "debian" "fedora" "arch")
    
    for platform in "${platforms[@]}"; do
        create_test_environment "fresh_install_${platform}"
        activate_test_environment
        setup_standard_mocks
        
        info "Testing fresh installation on $platform"
        
        # Simulate platform environment
        simulate_os_environment "$platform"
        
        # Source OS detection
        source "$DOTFILES_ROOT/scripts/lib/detect-os.sh"
        
        local detected_os
        detected_os=$(detect_os)
        assert_equals "$detected_os" "$platform" "Should detect $platform correctly"
        
        # Test package manager detection
        local expected_pm
        case "$platform" in
            macos) expected_pm="brew" ;;
            ubuntu|debian) expected_pm="apt" ;;
            fedora) expected_pm="dnf" ;;
            arch) expected_pm="pacman" ;;
        esac
        
        local detected_pm
        detected_pm=$(detect_package_manager)
        assert_equals "$detected_pm" "$expected_pm" "Should detect $expected_pm for $platform"
        
        cleanup_test_environment
    done
}

# Test fresh installation with network issues
test_fresh_installation_network_issues() {
    create_test_environment "fresh_install_network"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing fresh installation with network issues"
    
    # Mock network failures
    configure_mock "curl" "network_error" "true"
    configure_mock "wget" "network_error" "true"
    configure_mock "git" "clone_fail" "true"
    
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "https://fake.example.com/repo.git" 2>&1 || true)
    
    assert_contains "$output" "Failed\|error\|unable" "Should handle network failures gracefully"
}

# Test fresh installation with permissions issues
test_fresh_installation_permissions() {
    create_test_environment "fresh_install_perms"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing fresh installation with permission issues"
    
    # Create read-only target directory
    local readonly_dir="$TEST_HOME/.dotfiles-readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir"
    
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --directory "$readonly_dir" --dry-run 2>&1 || true)
    
    # Should handle gracefully in dry-run mode
    assert_contains "$output" "Dry run mode\|would clone" "Should show dry-run behavior"
    
    # Clean up
    chmod 755 "$readonly_dir" 2>/dev/null || true
}

# Test fresh installation performance
test_fresh_installation_performance() {
    create_test_environment "fresh_install_perf"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing fresh installation performance"
    
    # Create test repository with realistic structure
    local test_repo="$TEST_WORKSPACE/perf-dotfiles"
    mkdir -p "$test_repo"/{scripts,config,shell,vim,zsh,git,tmux}
    
    # Create bootstrap script that simulates real work
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Simulating installation steps..."
for i in {1..10}; do
    echo "Processing step $i/10"
    sleep 0.1
done
echo "Installation completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Time the installation
    local start_time=$(date +%s)
    
    cd "$DOTFILES_ROOT"
    bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-perf" --dry-run >/dev/null 2>&1 || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should complete within reasonable time (allowing for test overhead)
    assert_less_than "$duration" "30" "Installation should complete within 30 seconds"
    
    info "Installation completed in ${duration}s"
}

# Test fresh installation with existing dotfiles
test_fresh_installation_existing_files() {
    create_test_environment "fresh_install_existing"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing fresh installation with existing dotfiles"
    
    # Create existing dotfiles
    create_test_file "$TEST_HOME/.vimrc" "existing vim config"
    create_test_file "$TEST_HOME/.zshrc" "existing zsh config"
    create_test_file "$TEST_HOME/.gitconfig" "existing git config"
    
    # Create test repository
    local test_repo="$TEST_WORKSPACE/existing-dotfiles"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Checking for existing files..."
for file in .vimrc .zshrc .gitconfig; do
    if [[ -f "$HOME/$file" ]]; then
        echo "Found existing file: $file"
    fi
done
echo "Bootstrap completed with existing files check"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-existing" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Found existing file" "Should detect existing files"
    assert_contains "$output" "Bootstrap completed" "Should complete successfully"
    
    # Verify original files still exist
    assert_file_exists "$TEST_HOME/.vimrc" "Original .vimrc should still exist"
    assert_file_contains "$TEST_HOME/.vimrc" "existing vim config" "Original content preserved"
}

# Test fresh installation with secret templates
test_fresh_installation_secrets() {
    create_test_environment "fresh_install_secrets"
    activate_test_environment
    setup_standard_mocks
    create_test_secrets
    
    info "Testing fresh installation with secret templates"
    
    # Mock 1Password CLI as signed in
    configure_mock "op" "signed_in" "true"
    
    # Create test repository with templates
    local test_repo="$TEST_WORKSPACE/secrets-dotfiles"
    mkdir -p "$test_repo"/{scripts,templates}
    
    # Create template file
    cat > "$test_repo/templates/test-config.tmpl" << 'EOF'
# Test configuration with secrets
api_key = "{{ .api_key }}"
database_url = "{{ .database_url }}"
EOF
    
    # Create bootstrap that mentions templates
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Processing secret templates..."
if [[ -d "templates" ]]; then
    echo "Found $(find templates -name "*.tmpl" | wc -l) template files"
fi
echo "Bootstrap with secrets completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-secrets" --dry-run 2>&1 || true)
    
    assert_contains "$output" "template files" "Should detect template files"
    assert_contains "$output" "Bootstrap with secrets completed" "Should complete successfully"
}

# Test installation validation
test_fresh_installation_validation() {
    create_test_environment "fresh_install_validation"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing fresh installation validation"
    
    # Test with invalid repository URL
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "not-a-valid-url" --dry-run 2>&1 || true)
    
    # Should handle invalid URLs gracefully
    assert_not_contains "$output" "FATAL ERROR" "Should not crash on invalid URL"
    
    # Test with invalid directory path
    output=$(bash install.sh --directory "/invalid/path/that/cannot/be/created" --dry-run 2>&1 || true)
    
    # Should validate directory paths
    assert_not_contains "$output" "FATAL ERROR" "Should not crash on invalid directory"
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Fresh Installation Integration Tests"
    echo "==========================================="
    
    run_test "Basic Fresh Installation" test_fresh_installation_basic
    run_test "Missing Prerequisites" test_fresh_installation_missing_prereqs
    run_test "Cross-Platform Installation" test_fresh_installation_cross_platform
    run_test "Network Issues Handling" test_fresh_installation_network_issues
    run_test "Permission Issues" test_fresh_installation_permissions
    run_test "Installation Performance" test_fresh_installation_performance
    run_test "Existing Files Handling" test_fresh_installation_existing_files
    run_test "Secret Templates" test_fresh_installation_secrets
    run_test "Installation Validation" test_fresh_installation_validation
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 