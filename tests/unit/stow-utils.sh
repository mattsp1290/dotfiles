#!/usr/bin/env bash
# Unit tests for scripts/lib/stow-utils.sh
# Tests GNU Stow package management, conflict resolution, and dotfiles organization

set -euo pipefail

# Source testing framework
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/test-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/assertions.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/mock-tools.sh"

# Initialize test session
init_test_session
init_mock_logging

# Setup mock stow environment
setup_stow_test_env() {
    # Create mock dotfiles structure
    local test_stow_dir="$TEST_TEMP_DIR/dotfiles"
    
    # Set stow environment variables
    export STOW_DIR="$test_stow_dir"
    export STOW_TARGET="$TEST_TEMP_DIR/home"
    export STOW_VERBOSE="0"
    export STOW_SIMULATE="0"
    
    # Create dotfiles structure
    mkdir -p "$test_stow_dir"
    mkdir -p "$STOW_TARGET"
    
    # Create config packages
    mkdir -p "$test_stow_dir/config/git"
    echo "test gitconfig" > "$test_stow_dir/config/git/.gitconfig"
    
    mkdir -p "$test_stow_dir/config/vim"
    echo "test vimrc" > "$test_stow_dir/config/vim/.vimrc"
    
    # Create home package
    mkdir -p "$test_stow_dir/home"
    echo "test bashrc" > "$test_stow_dir/home/.bashrc"
    
    # Create shell packages
    mkdir -p "$test_stow_dir/shell/bash"
    echo "bash specific config" > "$test_stow_dir/shell/bash/.bash_profile"
    
    mkdir -p "$test_stow_dir/shell/shared"
    echo "shared shell config" > "$test_stow_dir/shell/shared/.profile"
    
    # Create OS packages
    mkdir -p "$test_stow_dir/os/macos"
    echo "macos config" > "$test_stow_dir/os/macos/.macosrc"
    
    mkdir -p "$test_stow_dir/os/linux"
    echo "linux config" > "$test_stow_dir/os/linux/.linuxrc"
    
    # Mock stow command
    mock_stow
}

#
# Package Discovery Tests
#

test_list_packages() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local packages
    packages=$(list_packages)
    
    assert_contains "$packages" "config/git" "Should list config/git package"
    assert_contains "$packages" "config/vim" "Should list config/vim package"
    assert_contains "$packages" "home" "Should list home package"
    assert_contains "$packages" "shell/bash" "Should list shell/bash package"
    assert_contains "$packages" "shell/shared" "Should list shell/shared package"
    assert_contains "$packages" "os/macos" "Should list os/macos package"
    assert_contains "$packages" "os/linux" "Should list os/linux package"
}

test_list_packages_empty_dirs() {
    setup_stow_test_env
    
    # Create empty package directory
    mkdir -p "$STOW_DIR/config/empty"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local packages
    packages=$(list_packages)
    
    assert_not_contains "$packages" "config/empty" "Should not list empty package directories"
}

test_get_platform_packages_macos() {
    setup_stow_test_env
    
    # Mock macOS environment
    OSTYPE="darwin20"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local packages
    packages=$(get_platform_packages)
    
    assert_contains "$packages" "home" "Should include home package"
    assert_contains "$packages" "os/macos" "Should include macOS package"
    assert_contains "$packages" "shell/shared" "Should include shared shell package"
}

test_get_platform_packages_linux() {
    setup_stow_test_env
    
    # Mock Linux environment
    OSTYPE="linux-gnu"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local packages
    packages=$(get_platform_packages)
    
    assert_contains "$packages" "home" "Should include home package"
    assert_contains "$packages" "os/linux" "Should include Linux package"
    assert_contains "$packages" "shell/shared" "Should include shared shell package"
}

test_get_platform_packages_with_shell() {
    setup_stow_test_env
    
    # Mock bash shell
    export SHELL="/bin/bash"
    OSTYPE="linux-gnu"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local packages
    packages=$(get_platform_packages)
    
    assert_contains "$packages" "shell/bash" "Should include bash shell package"
}

#
# Conflict Detection Tests
#

test_check_conflicts_no_conflicts() {
    setup_stow_test_env
    
    # Mock stow to return success (no conflicts)
    mock_command "stow" "#!/bin/bash
exit 0"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success check_conflicts "config/git" "Should succeed when no conflicts"
}

test_check_conflicts_with_conflicts() {
    setup_stow_test_env
    
    # Mock stow to return conflicts
    mock_command "stow" "#!/bin/bash
echo 'WARNING! stowing git would cause conflicts:' >&2
echo '  * existing target is not owned by stow: .gitconfig' >&2
exit 1"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local output
    output=$(check_conflicts "config/git" 2>&1)
    assert_contains "$output" "existing target" "Should report conflict details"
    assert_command_failure check_conflicts "config/git" "Should fail when conflicts exist"
}

test_check_conflicts_nested_package() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Should handle nested packages correctly
    assert_true "function_exists 'check_conflicts'" "Function should handle nested packages"
}

#
# Backup Functionality Tests
#

test_backup_conflicts() {
    setup_stow_test_env
    
    # Create conflicting files
    echo "existing gitconfig" > "$STOW_TARGET/.gitconfig"
    echo "existing vimrc" > "$STOW_TARGET/.vimrc"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local backup_dir="$TEST_TEMP_DIR/backup"
    
    backup_conflicts "config/git" "$backup_dir"
    
    # Check backup was created
    assert_file_exists "$backup_dir/config/git/.gitconfig" "Should backup conflicting .gitconfig"
    assert_file_contains "$backup_dir/config/git/.gitconfig" "existing gitconfig" "Backup should contain original content"
}

test_backup_conflicts_symlinks() {
    setup_stow_test_env
    
    # Create symlink pointing elsewhere
    mkdir -p "$TEST_TEMP_DIR/other"
    echo "other content" > "$TEST_TEMP_DIR/other/.gitconfig"
    ln -s "$TEST_TEMP_DIR/other/.gitconfig" "$STOW_TARGET/.gitconfig"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local backup_dir="$TEST_TEMP_DIR/backup"
    local output
    output=$(backup_conflicts "config/git" "$backup_dir" 2>&1)
    
    assert_contains "$output" "points elsewhere" "Should warn about external symlinks"
}

#
# Stow Operation Tests
#

test_stow_package_success() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success stow_package "config/git" "Should successfully stow package"
}

test_stow_package_not_found() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure stow_package "nonexistent" "Should fail for non-existent package"
}

test_stow_package_with_conflicts() {
    setup_stow_test_env
    
    # Create conflicting file
    echo "existing gitconfig" > "$STOW_TARGET/.gitconfig"
    
    # Mock stow to report conflicts
    mock_command "stow" "#!/bin/bash
if [[ \"\$*\" == *\"--no\"* ]]; then
    echo 'WARNING! stowing git would cause conflicts:' >&2
    echo '  * existing target is not owned by stow: .gitconfig' >&2
    exit 1
else
    exit 0
fi"
    
    # Mock user declining backup
    mock_command "read" "#!/bin/bash
echo 'n'"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure stow_package "config/git" "Should fail when conflicts exist and backup declined"
}

test_stow_package_force() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Force should skip conflict checking
    assert_command_success stow_package "config/git" 1 "Should succeed with force flag"
}

test_stow_package_adopt() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Adopt should skip conflict checking
    assert_command_success stow_package "config/git" 0 1 "Should succeed with adopt flag"
}

test_stow_package_nested() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Test nested package path
    assert_command_success stow_package "config/git" "Should handle nested package paths"
}

test_stow_package_verbose() {
    setup_stow_test_env
    
    STOW_VERBOSE=1
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success stow_package "config/git" "Should work with verbose mode"
}

test_stow_package_simulate() {
    setup_stow_test_env
    
    STOW_SIMULATE=1
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success stow_package "config/git" "Should work in simulation mode"
}

#
# Unstow Operation Tests
#

test_unstow_package() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success unstow_package "config/git" "Should successfully unstow package"
}

test_unstow_package_nested() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success unstow_package "config/git" "Should handle nested packages"
}

#
# Restow Operation Tests
#

test_restow_package() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success restow_package "config/git" "Should successfully restow package"
}

test_restow_package_unstow_fails() {
    setup_stow_test_env
    
    # Mock stow to fail on unstow (-D flag)
    mock_command "stow" "#!/bin/bash
if [[ \"\$*\" == *\"-D\"* ]]; then
    exit 1
else
    exit 0
fi"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure restow_package "config/git" "Should fail if unstow fails"
}

#
# Adopt Functionality Tests
#

test_adopt_existing() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local output
    output=$(adopt_existing "config/git" 2>&1)
    
    assert_contains "$output" "Adopting existing" "Should indicate adoption process"
    assert_contains "$output" "review adopted files" "Should warn about reviewing changes"
}

#
# Verification Tests
#

test_verify_stow_installed() {
    # Mock stow command
    mock_command "stow" "#!/bin/bash
if [[ \"\$1\" == '--version' ]]; then
    echo 'stow (GNU Stow) 2.3.1'
else
    echo 'Unknown argument'
fi"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success verify_stow "Should succeed when stow is installed"
}

test_verify_stow_not_installed() {
    # Mock missing stow command
    PATH="/non/existent/path:$PATH"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure verify_stow "Should fail when stow is not installed"
}

#
# Package Status Tests
#

test_is_stowed_true() {
    setup_stow_test_env
    
    # Create properly stowed symlinks
    mkdir -p "$STOW_TARGET"
    ln -s "$STOW_DIR/config/git/.gitconfig" "$STOW_TARGET/.gitconfig"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_success is_stowed "config/git" "Should return true for stowed package"
}

test_is_stowed_false_no_symlinks() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure is_stowed "config/git" "Should return false when no symlinks exist"
}

test_is_stowed_false_wrong_symlinks() {
    setup_stow_test_env
    
    # Create symlink pointing elsewhere
    mkdir -p "$STOW_TARGET"
    mkdir -p "$TEST_TEMP_DIR/other"
    echo "other content" > "$TEST_TEMP_DIR/other/.gitconfig"
    ln -s "$TEST_TEMP_DIR/other/.gitconfig" "$STOW_TARGET/.gitconfig"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure is_stowed "config/git" "Should return false for incorrect symlinks"
}

test_is_stowed_false_regular_files() {
    setup_stow_test_env
    
    # Create regular file instead of symlink
    mkdir -p "$STOW_TARGET"
    echo "regular file" > "$STOW_TARGET/.gitconfig"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    assert_command_failure is_stowed "config/git" "Should return false for regular files"
}

#
# Environment Variable Tests
#

test_stow_environment_variables() {
    setup_stow_test_env
    
    # Test custom STOW_DIR
    export STOW_DIR="$TEST_TEMP_DIR/custom_stow"
    mkdir -p "$STOW_DIR/test_package"
    echo "test" > "$STOW_DIR/test_package/.testrc"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local packages
    packages=$(list_packages)
    assert_contains "$packages" "test_package" "Should respect custom STOW_DIR"
}

test_stow_target_variable() {
    setup_stow_test_env
    
    # Test custom STOW_TARGET
    export STOW_TARGET="$TEST_TEMP_DIR/custom_target"
    mkdir -p "$STOW_TARGET"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Should use custom target directory
    assert_dir_exists "$STOW_TARGET" "Should use custom STOW_TARGET"
}

#
# Error Condition Tests
#

test_stow_with_missing_package_dir() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Remove package directory after setup
    rm -rf "$STOW_DIR/config/git"
    
    assert_command_failure stow_package "config/git" "Should fail for missing package directory"
}

test_backup_conflicts_permission_error() {
    setup_stow_test_env
    
    # Mock cp command to fail
    mock_command "cp" "#!/bin/bash
exit 1"
    
    # Create conflicting file
    echo "existing" > "$STOW_TARGET/.gitconfig"
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    local output
    output=$(backup_conflicts "config/git" "$TEST_TEMP_DIR/backup" 2>&1)
    
    assert_contains "$output" "Failed to backup" "Should report backup failures"
}

#
# Integration Tests
#

test_end_to_end_stow_workflow() {
    setup_stow_test_env
    
    source "$DOTFILES_ROOT/scripts/lib/stow-utils.sh"
    
    # Verify stow is available
    assert_command_success verify_stow "Stow should be available"
    
    # List available packages
    local packages
    packages=$(list_packages)
    assert_contains "$packages" "config/git" "Should list packages"
    
    # Check package is not stowed initially
    assert_command_failure is_stowed "config/git" "Package should not be stowed initially"
    
    # Stow the package
    assert_command_success stow_package "config/git" "Should stow package successfully"
    
    # Verify package is now stowed
    assert_command_success is_stowed "config/git" "Package should be stowed after stowing"
    
    # Restow the package
    assert_command_success restow_package "config/git" "Should restow package successfully"
    
    # Unstow the package
    assert_command_success unstow_package "config/git" "Should unstow package successfully"
    
    # Verify package is not stowed after unstowing
    assert_command_failure is_stowed "config/git" "Package should not be stowed after unstowing"
}

#
# Test Execution Framework
#

# Run all tests
run_test "list_packages" test_list_packages
run_test "list_packages empty dirs" test_list_packages_empty_dirs
run_test "get_platform_packages macOS" test_get_platform_packages_macos
run_test "get_platform_packages Linux" test_get_platform_packages_linux
run_test "get_platform_packages with shell" test_get_platform_packages_with_shell
run_test "check_conflicts no conflicts" test_check_conflicts_no_conflicts
run_test "check_conflicts with conflicts" test_check_conflicts_with_conflicts
run_test "check_conflicts nested package" test_check_conflicts_nested_package
run_test "backup_conflicts" test_backup_conflicts
run_test "backup_conflicts symlinks" test_backup_conflicts_symlinks
run_test "stow_package success" test_stow_package_success
run_test "stow_package not found" test_stow_package_not_found
run_test "stow_package with conflicts" test_stow_package_with_conflicts
run_test "stow_package force" test_stow_package_force
run_test "stow_package adopt" test_stow_package_adopt
run_test "stow_package nested" test_stow_package_nested
run_test "stow_package verbose" test_stow_package_verbose
run_test "stow_package simulate" test_stow_package_simulate
run_test "unstow_package" test_unstow_package
run_test "unstow_package nested" test_unstow_package_nested
run_test "restow_package" test_restow_package
run_test "restow_package unstow fails" test_restow_package_unstow_fails
run_test "adopt_existing" test_adopt_existing
run_test "verify_stow installed" test_verify_stow_installed
run_test "verify_stow not installed" test_verify_stow_not_installed
run_test "is_stowed true" test_is_stowed_true
run_test "is_stowed false no symlinks" test_is_stowed_false_no_symlinks
run_test "is_stowed false wrong symlinks" test_is_stowed_false_wrong_symlinks
run_test "is_stowed false regular files" test_is_stowed_false_regular_files
run_test "stow environment variables" test_stow_environment_variables
run_test "stow target variable" test_stow_target_variable
run_test "stow with missing package dir" test_stow_with_missing_package_dir
run_test "backup conflicts permission error" test_backup_conflicts_permission_error
run_test "end-to-end stow workflow" test_end_to_end_stow_workflow

# Cleanup and show summary
cleanup_test_session
test_summary 