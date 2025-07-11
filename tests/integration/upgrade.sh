#!/usr/bin/env bash
# Upgrade Scenario Integration Tests
# Tests upgrade scenarios with version migration and configuration preservation

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"
source "$TEST_DIR/../helpers/mock-tools.sh"
source "$TEST_DIR/../helpers/env-setup.sh"

# Test basic upgrade scenario
test_upgrade_basic() {
    create_test_environment "upgrade_basic"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing basic upgrade scenario"
    
    # Create "old version" dotfiles installation
    local old_dotfiles="$TEST_HOME/.dotfiles-old"
    mkdir -p "$old_dotfiles"/{scripts,config,shell}
    
    # Create old version marker
    echo "1.0.0" > "$old_dotfiles/.version"
    
    # Create old configuration files
    create_test_file "$old_dotfiles/config/old-config.conf" "old_setting=true"
    create_test_file "$old_dotfiles/shell/.zshrc.old" "# Old zsh config"
    
    # Create symlinks from old installation
    ln -sf "$old_dotfiles/config/old-config.conf" "$TEST_HOME/.old-config"
    ln -sf "$old_dotfiles/shell/.zshrc.old" "$TEST_HOME/.zshrc"
    
    # Create new version repository
    local new_dotfiles="$TEST_WORKSPACE/new-dotfiles"
    mkdir -p "$new_dotfiles"/{scripts,config,shell}
    
    # Create new version with migration support
    echo "2.0.0" > "$new_dotfiles/.version"
    
    cat > "$new_dotfiles/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Upgrade bootstrap started"
echo "Args: $*"

# Check for existing installation
if [[ -f "$HOME/.dotfiles-old/.version" ]]; then
    old_version=$(cat "$HOME/.dotfiles-old/.version")
    echo "Found existing installation: version $old_version"
    echo "Performing upgrade migration..."
fi

echo "Upgrade bootstrap completed"
EOF
    chmod +x "$new_dotfiles/scripts/bootstrap.sh"
    
    # Test upgrade
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$new_dotfiles" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Found existing installation" "Should detect old installation"
    assert_contains "$output" "version 1.0.0" "Should detect old version"
    assert_contains "$output" "Performing upgrade migration" "Should perform migration"
    assert_contains "$output" "Upgrade bootstrap completed" "Should complete upgrade"
}

# Test upgrade with configuration migration
test_upgrade_config_migration() {
    create_test_environment "upgrade_config_migration"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing upgrade with configuration migration"
    
    # Create old dotfiles with specific configurations
    local old_dotfiles="$TEST_HOME/.dotfiles-v1"
    mkdir -p "$old_dotfiles"/{config,shell}
    
    # Old configuration format
    cat > "$old_dotfiles/config/settings.conf" << 'EOF'
# Old format configuration
theme=dark
editor=vim
shell=zsh
deprecated_setting=true
EOF
    
    # Old shell configuration
    cat > "$old_dotfiles/shell/.zshrc" << 'EOF'
# Old zsh configuration
export OLD_FORMAT="true"
alias old_alias="echo old"
# Some old specific settings
EOF
    
    echo "1.5.0" > "$old_dotfiles/.version"
    
    # Create new version with migration script
    local new_dotfiles="$TEST_WORKSPACE/new-dotfiles-v2"
    mkdir -p "$new_dotfiles"/{scripts,config,shell}
    
    cat > "$new_dotfiles/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Configuration migration bootstrap"

# Check for old configurations
if [[ -f "$HOME/.dotfiles-v1/config/settings.conf" ]]; then
    echo "Migrating old configuration format..."
    
    # Read old settings
    if grep -q "deprecated_setting=true" "$HOME/.dotfiles-v1/config/settings.conf"; then
        echo "Removing deprecated setting"
    fi
    
    if grep -q "theme=dark" "$HOME/.dotfiles-v1/config/settings.conf"; then
        echo "Preserving theme setting"
    fi
    
    echo "Configuration migration completed"
fi

echo "Migration bootstrap finished"
EOF
    chmod +x "$new_dotfiles/scripts/bootstrap.sh"
    
    echo "2.0.0" > "$new_dotfiles/.version"
    
    # Test migration
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$new_dotfiles" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Migrating old configuration" "Should perform config migration"
    assert_contains "$output" "Removing deprecated setting" "Should handle deprecated settings"
    assert_contains "$output" "Preserving theme setting" "Should preserve valid settings"
    assert_contains "$output" "Configuration migration completed" "Should complete migration"
}

# Test upgrade with backup preservation
test_upgrade_backup_preservation() {
    create_test_environment "upgrade_backup"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing upgrade with backup preservation"
    
    # Create existing dotfiles installation
    local existing_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$existing_dotfiles"/{config,shell}
    
    # Create important user configurations
    create_test_file "$existing_dotfiles/config/user-settings.json" '{"important": "data"}'
    create_test_file "$existing_dotfiles/shell/.zshrc" "# User customizations"
    echo "1.8.0" > "$existing_dotfiles/.version"
    
    # Create test files that user has customized
    create_test_file "$TEST_HOME/.gitconfig" "[user]\n\tname = Test User"
    create_test_file "$TEST_HOME/.vimrc" "\" User vim settings"
    
    # Create new version repository
    local new_repo="$TEST_WORKSPACE/upgrade-repo"
    mkdir -p "$new_repo/scripts"
    
    cat > "$new_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Backup preservation upgrade"

# Check for existing installation
if [[ -d "$HOME/.dotfiles" ]]; then
    echo "Creating backup of existing installation..."
    backup_dir="$HOME/.dotfiles.backup.$(date +%Y%m%d-%H%M%S)"
    echo "Backup would be created at: $backup_dir"
    
    # Check for user customizations
    if [[ -f "$HOME/.gitconfig" ]]; then
        echo "Preserving user .gitconfig"
    fi
    
    if [[ -f "$HOME/.vimrc" ]]; then
        echo "Preserving user .vimrc"
    fi
fi

echo "Backup preservation completed"
EOF
    chmod +x "$new_repo/scripts/bootstrap.sh"
    
    echo "2.1.0" > "$new_repo/.version"
    
    # Test upgrade with backup
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$new_repo" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Creating backup" "Should create backup"
    assert_contains "$output" "Backup would be created at" "Should show backup location"
    assert_contains "$output" "Preserving user .gitconfig" "Should preserve user configs"
    assert_contains "$output" "Preserving user .vimrc" "Should preserve user customizations"
}

# Test selective upgrade scenarios
test_upgrade_selective() {
    create_test_environment "upgrade_selective"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing selective upgrade scenarios"
    
    # Create modular dotfiles installation
    local existing_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$existing_dotfiles"/{vim,zsh,git,tmux,scripts}
    
    # Create module version tracking
    echo "vim=1.0.0" > "$existing_dotfiles/.module-versions"
    echo "zsh=1.2.0" >> "$existing_dotfiles/.module-versions"
    echo "git=1.1.0" >> "$existing_dotfiles/.module-versions"
    echo "tmux=1.0.0" >> "$existing_dotfiles/.module-versions"
    
    # Create upgrade repository
    local upgrade_repo="$TEST_WORKSPACE/selective-upgrade"
    mkdir -p "$upgrade_repo/scripts"
    
    cat > "$upgrade_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Selective upgrade bootstrap"

# Check module versions
if [[ -f "$HOME/.dotfiles/.module-versions" ]]; then
    echo "Checking module versions..."
    
    while IFS='=' read -r module version; do
        echo "Current $module version: $version"
        
        # Simulate version comparison
        case "$module" in
            vim)
                if [[ "$version" < "2.0.0" ]]; then
                    echo "Upgrading $module from $version to 2.0.0"
                fi
                ;;
            zsh)
                if [[ "$version" < "1.5.0" ]]; then
                    echo "Upgrading $module from $version to 1.5.0"
                fi
                ;;
            git)
                echo "Git module is up to date"
                ;;
            tmux)
                if [[ "$version" < "1.2.0" ]]; then
                    echo "Upgrading $module from $version to 1.2.0"
                fi
                ;;
        esac
    done < "$HOME/.dotfiles/.module-versions"
fi

echo "Selective upgrade completed"
EOF
    chmod +x "$upgrade_repo/scripts/bootstrap.sh"
    
    # Test selective upgrade
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$upgrade_repo" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Checking module versions" "Should check module versions"
    assert_contains "$output" "Upgrading vim from 1.0.0 to 2.0.0" "Should upgrade vim"
    assert_contains "$output" "Upgrading zsh from 1.2.0 to 1.5.0" "Should upgrade zsh"
    assert_contains "$output" "Git module is up to date" "Should skip up-to-date modules"
    assert_contains "$output" "Upgrading tmux from 1.0.0 to 1.2.0" "Should upgrade tmux"
}

# Test upgrade rollback capabilities
test_upgrade_rollback_capability() {
    create_test_environment "upgrade_rollback"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing upgrade rollback capabilities"
    
    # Create existing installation with rollback support
    local existing_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$existing_dotfiles"/{scripts,config}
    
    # Create rollback preparation script
    cat > "$existing_dotfiles/scripts/prepare-rollback.sh" << 'EOF'
#!/usr/bin/env bash
echo "Preparing rollback checkpoint..."
rollback_dir="$HOME/.dotfiles.rollback"
mkdir -p "$rollback_dir"
echo "Rollback data prepared"
EOF
    chmod +x "$existing_dotfiles/scripts/prepare-rollback.sh"
    
    echo "1.9.0" > "$existing_dotfiles/.version"
    
    # Create upgrade repository with rollback awareness
    local upgrade_repo="$TEST_WORKSPACE/rollback-aware-upgrade"
    mkdir -p "$upgrade_repo/scripts"
    
    cat > "$upgrade_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Rollback-aware upgrade bootstrap"

# Check if rollback preparation is available
if [[ -f "$HOME/.dotfiles/scripts/prepare-rollback.sh" ]]; then
    echo "Running rollback preparation..."
    bash "$HOME/.dotfiles/scripts/prepare-rollback.sh"
    echo "Rollback checkpoint created"
fi

echo "Proceeding with upgrade..."
echo "Upgrade includes rollback capability"

echo "Rollback-aware upgrade completed"
EOF
    chmod +x "$upgrade_repo/scripts/bootstrap.sh"
    
    echo "2.0.0" > "$upgrade_repo/.version"
    
    # Test rollback-aware upgrade
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$upgrade_repo" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Running rollback preparation" "Should prepare rollback"
    assert_contains "$output" "Rollback checkpoint created" "Should create rollback checkpoint"
    assert_contains "$output" "rollback capability" "Should mention rollback capability"
}

# Test upgrade error handling
test_upgrade_error_handling() {
    create_test_environment "upgrade_errors"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing upgrade error handling"
    
    # Create problematic existing installation
    local existing_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$existing_dotfiles"
    echo "corrupted" > "$existing_dotfiles/.version"
    
    # Create broken symlinks
    ln -sf "/nonexistent/file" "$TEST_HOME/.broken-link"
    
    # Create upgrade repository with error handling
    local upgrade_repo="$TEST_WORKSPACE/error-handling-upgrade"
    mkdir -p "$upgrade_repo/scripts"
    
    cat > "$upgrade_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Error-handling upgrade bootstrap"

# Check for corrupted installation
if [[ -f "$HOME/.dotfiles/.version" ]]; then
    version=$(cat "$HOME/.dotfiles/.version")
    if [[ "$version" == "corrupted" ]]; then
        echo "WARNING: Detected corrupted installation"
        echo "Attempting recovery..."
        echo "Recovery procedures would be executed"
    fi
fi

# Check for broken symlinks
if [[ -L "$HOME/.broken-link" ]] && [[ ! -e "$HOME/.broken-link" ]]; then
    echo "WARNING: Found broken symlink"
    echo "Broken symlink would be cleaned up"
fi

echo "Error handling completed"
EOF
    chmod +x "$upgrade_repo/scripts/bootstrap.sh"
    
    # Test error handling upgrade
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$upgrade_repo" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "WARNING: Detected corrupted installation" "Should detect corruption"
    assert_contains "$output" "Attempting recovery" "Should attempt recovery"
    assert_contains "$output" "WARNING: Found broken symlink" "Should detect broken symlinks"
    assert_contains "$output" "would be cleaned up" "Should clean up broken links"
}

# Test upgrade compatibility validation
test_upgrade_compatibility() {
    create_test_environment "upgrade_compatibility"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing upgrade compatibility validation"
    
    # Create old installation with compatibility requirements
    local existing_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$existing_dotfiles"
    echo "0.5.0" > "$existing_dotfiles/.version"
    echo "min_bash_version=4.0" > "$existing_dotfiles/.requirements"
    echo "requires_git=true" >> "$existing_dotfiles/.requirements"
    
    # Create upgrade repository with compatibility checks
    local upgrade_repo="$TEST_WORKSPACE/compatibility-upgrade"
    mkdir -p "$upgrade_repo/scripts"
    
    cat > "$upgrade_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Compatibility validation upgrade"

# Check existing version compatibility
if [[ -f "$HOME/.dotfiles/.version" ]]; then
    old_version=$(cat "$HOME/.dotfiles/.version")
    echo "Upgrading from version: $old_version"
    
    # Version compatibility check
    if [[ "$old_version" < "1.0.0" ]]; then
        echo "WARNING: Upgrading from very old version"
        echo "Additional migration steps required"
    fi
fi

# System compatibility checks
echo "Checking system compatibility..."
bash_version=$(bash --version | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
echo "Bash version: $bash_version"

if command -v git >/dev/null 2>&1; then
    git_version=$(git --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "Git version: $git_version"
fi

echo "Compatibility validation completed"
EOF
    chmod +x "$upgrade_repo/scripts/bootstrap.sh"
    
    echo "2.0.0" > "$upgrade_repo/.version"
    
    # Test compatibility validation
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$upgrade_repo" --directory "$TEST_HOME/.dotfiles" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Upgrading from version: 0.5.0" "Should show old version"
    assert_contains "$output" "WARNING: Upgrading from very old version" "Should warn about old version"
    assert_contains "$output" "Additional migration steps required" "Should mention migration steps"
    assert_contains "$output" "Checking system compatibility" "Should check system compatibility"
    assert_contains "$output" "Bash version:" "Should check bash version"
    assert_contains "$output" "Git version:" "Should check git version"
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Upgrade Scenario Integration Tests"
    echo "========================================="
    
    run_test "Basic Upgrade Scenario" test_upgrade_basic
    run_test "Configuration Migration" test_upgrade_config_migration
    run_test "Backup Preservation" test_upgrade_backup_preservation
    run_test "Selective Upgrade" test_upgrade_selective
    run_test "Rollback Capability" test_upgrade_rollback_capability
    run_test "Error Handling" test_upgrade_error_handling
    run_test "Compatibility Validation" test_upgrade_compatibility
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 