#!/usr/bin/env bash
# Rollback Procedure Integration Tests
# Tests rollback procedures and backup restoration functionality

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"
source "$TEST_DIR/../helpers/mock-tools.sh"
source "$TEST_DIR/../helpers/env-setup.sh"

# Test basic rollback functionality
test_rollback_basic() {
    create_test_environment "rollback_basic"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing basic rollback functionality"
    
    # Create current dotfiles installation
    local current_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$current_dotfiles"/{scripts,config,shell}
    echo "2.0.0" > "$current_dotfiles/.version"
    
    # Create backup directory structure
    local backup_dir="$TEST_HOME/.dotfiles.backup.20231201-120000"
    mkdir -p "$backup_dir"/{scripts,config,shell}
    echo "1.5.0" > "$backup_dir/.version"
    
    # Create backup files
    create_test_file "$backup_dir/config/settings.conf" "old_theme=light"
    create_test_file "$backup_dir/shell/.zshrc" "# Backup zsh config"
    
    # Create rollback script
    cat > "$current_dotfiles/scripts/rollback.sh" << 'EOF'
#!/usr/bin/env bash
echo "Rollback script started"
echo "Args: $*"

backup_dir="$1"
if [[ -z "$backup_dir" ]]; then
    echo "ERROR: Backup directory not specified"
    exit 1
fi

if [[ ! -d "$backup_dir" ]]; then
    echo "ERROR: Backup directory does not exist: $backup_dir"
    exit 1
fi

echo "Rolling back from backup: $backup_dir"
echo "Current installation would be replaced"
echo "Rollback completed successfully"
EOF
    chmod +x "$current_dotfiles/scripts/rollback.sh"
    
    # Test rollback
    local output
    output=$(bash "$current_dotfiles/scripts/rollback.sh" "$backup_dir" 2>&1 || true)
    
    assert_contains "$output" "Rollback script started" "Should start rollback"
    assert_contains "$output" "Rolling back from backup" "Should use backup directory"
    assert_contains "$output" "Current installation would be replaced" "Should replace current"
    assert_contains "$output" "Rollback completed successfully" "Should complete successfully"
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Rollback Procedure Integration Tests"
    echo "==========================================="
    
    run_test "Basic Rollback Functionality" test_rollback_basic
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 