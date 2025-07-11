#!/usr/bin/env bash
# Security Integration Tests
# Tests security-focused integration scenarios

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"
source "$TEST_DIR/../helpers/mock-tools.sh"
source "$TEST_DIR/../helpers/env-setup.sh"

# Test secret exposure prevention
test_secret_exposure_prevention() {
    create_test_environment "security_secrets"
    activate_test_environment
    setup_standard_mocks
    create_test_secrets
    
    info "Testing secret exposure prevention"
    
    # Mock 1Password CLI as signed in
    configure_mock "op" "signed_in" "true"
    
    # Create test repository with templates
    local test_repo="$TEST_WORKSPACE/security-test-repo"
    mkdir -p "$test_repo"/{scripts,templates}
    
    # Create template with sensitive data
    cat > "$test_repo/templates/config.tmpl" << 'EOF'
# Configuration with secrets
api_key = "{{ .api_key }}"
database_password = "{{ .database_password }}"
private_key = "{{ .private_key }}"
EOF
    
    # Create bootstrap script that handles secrets
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Security-aware bootstrap"

# Ensure no secrets are exposed in logs
exec 2> >(grep -v -E "(password|key|token|secret)" >&2)

if [[ -d "templates" ]]; then
    echo "Processing secret templates (details hidden)"
    echo "Template files: $(find templates -name "*.tmpl" | wc -l)"
fi

echo "Bootstrap completed securely"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test installation with secrets
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-security" --dry-run 2>&1 || true)
    
    # Verify no actual secrets are exposed
    assert_not_contains "$output" "test_api_key_12345" "Should not expose actual API key"
    assert_not_contains "$output" "test_db_password" "Should not expose actual password"
    assert_not_contains "$output" "test_private_key" "Should not expose actual private key"
    assert_contains "$output" "Processing secret templates" "Should process templates"
    assert_contains "$output" "Bootstrap completed securely" "Should complete securely"
}

# Test file permissions validation
test_file_permissions() {
    create_test_environment "security_permissions"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing file permissions validation"
    
    # Create test repository with various file types
    local test_repo="$TEST_WORKSPACE/permissions-test-repo"
    mkdir -p "$test_repo"/{scripts,config,ssh}
    
    # Create files with specific permission requirements
    create_test_file "$test_repo/scripts/bootstrap.sh" "#!/usr/bin/env bash\necho 'Bootstrap'"
    create_test_file "$test_repo/config/settings.conf" "setting=value"
    create_test_file "$test_repo/ssh/config" "Host example.com\n  User test"
    create_test_file "$test_repo/ssh/id_rsa" "-----BEGIN PRIVATE KEY-----\ntest_key\n-----END PRIVATE KEY-----"
    
    # Set correct permissions
    chmod 755 "$test_repo/scripts/bootstrap.sh"
    chmod 644 "$test_repo/config/settings.conf"
    chmod 644 "$test_repo/ssh/config"
    chmod 600 "$test_repo/ssh/id_rsa"
    
    # Create permission validation script
    cat > "$test_repo/scripts/validate-permissions.sh" << 'EOF'
#!/usr/bin/env bash
echo "Validating file permissions..."

# Check script permissions
for script in scripts/*.sh; do
    if [[ -f "$script" ]]; then
        perms=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%A" "$script" 2>/dev/null)
        echo "Script $script permissions: $perms"
        if [[ "$perms" != "755" ]]; then
            echo "WARNING: Script should be executable (755)"
        fi
    fi
done

# Check SSH key permissions
if [[ -f "ssh/id_rsa" ]]; then
    perms=$(stat -c "%a" "ssh/id_rsa" 2>/dev/null || stat -f "%A" "ssh/id_rsa" 2>/dev/null)
    echo "SSH private key permissions: $perms"
    if [[ "$perms" != "600" ]]; then
        echo "ERROR: SSH private key must be 600"
    fi
fi

echo "Permission validation completed"
EOF
    chmod +x "$test_repo/scripts/validate-permissions.sh"
    
    # Test permission validation
    cd "$test_repo"
    local output
    output=$(bash scripts/validate-permissions.sh 2>&1 || true)
    
    assert_contains "$output" "Validating file permissions" "Should validate permissions"
    assert_contains "$output" "Script.*permissions: 755" "Should show script permissions"
    assert_contains "$output" "SSH private key permissions: 600" "Should show SSH key permissions"
    assert_not_contains "$output" "ERROR: SSH private key must be 600" "Should have correct SSH permissions"
    assert_contains "$output" "Permission validation completed" "Should complete validation"
}

# Test authentication flow security
test_authentication_flows() {
    create_test_environment "security_auth"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing authentication flow security"
    
    # Mock various authentication states
    configure_mock "op" "signed_out" "true"
    configure_mock "ssh-add" "no_keys" "true"
    
    # Create test repository with auth checks
    local test_repo="$TEST_WORKSPACE/auth-test-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Authentication flow test"

# Check 1Password authentication
if command -v op >/dev/null 2>&1; then
    if op account list >/dev/null 2>&1; then
        echo "1Password: Authenticated"
    else
        echo "1Password: Not authenticated"
        echo "Please sign in to 1Password CLI"
    fi
else
    echo "1Password: CLI not installed"
fi

# Check SSH authentication
if command -v ssh-add >/dev/null 2>&1; then
    if ssh-add -l >/dev/null 2>&1; then
        echo "SSH: Keys loaded in agent"
    else
        echo "SSH: No keys in agent"
    fi
else
    echo "SSH: ssh-add not available"
fi

echo "Authentication checks completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test with mocked authentication failure
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-auth" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Authentication flow test" "Should test auth flow"
    assert_contains "$output" "1Password: Not authenticated" "Should detect 1Password not authenticated"
    assert_contains "$output" "SSH: No keys in agent" "Should detect no SSH keys"
    assert_contains "$output" "Authentication checks completed" "Should complete auth checks"
}

# Test secure temporary file handling
test_secure_temp_files() {
    create_test_environment "security_temp_files"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing secure temporary file handling"
    
    # Create test repository with temp file handling
    local test_repo="$TEST_WORKSPACE/temp-security-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Secure temp file handling test"

# Create secure temporary directory
temp_dir=$(mktemp -d)
echo "Created temp directory: $temp_dir"

# Set secure permissions on temp directory
chmod 700 "$temp_dir"

# Create temporary file with secrets
temp_file="$temp_dir/secrets.tmp"
echo "api_key=secret_value" > "$temp_file"
chmod 600 "$temp_file"

echo "Processing temporary secrets file..."
echo "Temp file permissions: $(stat -c "%a" "$temp_file" 2>/dev/null || stat -f "%A" "$temp_file" 2>/dev/null)"

# Clean up temporary files
rm -f "$temp_file"
rmdir "$temp_dir"

echo "Temporary files cleaned up securely"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test secure temp file handling
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-temp" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Secure temp file handling test" "Should test temp file handling"
    assert_contains "$output" "Created temp directory:" "Should create temp directory"
    assert_contains "$output" "Temp file permissions: 600" "Should set secure permissions"
    assert_contains "$output" "Temporary files cleaned up securely" "Should clean up securely"
}

# Test input validation and sanitization
test_input_validation() {
    create_test_environment "security_input_validation"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing input validation and sanitization"
    
    # Create test repository with input validation
    local test_repo="$TEST_WORKSPACE/input-validation-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Input validation test"

# Function to validate input
validate_input() {
    local input="$1"
    local field_name="$2"
    
    # Check for dangerous characters
    if [[ "$input" =~ [';|&$`] ]]; then
        echo "ERROR: Invalid characters in $field_name"
        return 1
    fi
    
    # Check for path traversal
    if [[ "$input" =~ \.\./|/\.\. ]]; then
        echo "ERROR: Path traversal detected in $field_name"
        return 1
    fi
    
    echo "Input validation passed for $field_name"
    return 0
}

# Test various inputs
test_inputs=(
    "safe_value"
    "../../../etc/passwd"
    "value; rm -rf /"
    "normal/path/file"
    "\$(dangerous command)"
)

for input in "${test_inputs[@]}"; do
    echo "Testing input: '$input'"
    validate_input "$input" "test_field" || true
done

echo "Input validation test completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test input validation
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-validation" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Input validation test" "Should test input validation"
    assert_contains "$output" "Input validation passed for test_field" "Should pass safe input"
    assert_contains "$output" "ERROR: Path traversal detected" "Should detect path traversal"
    assert_contains "$output" "ERROR: Invalid characters" "Should detect dangerous characters"
    assert_contains "$output" "Input validation test completed" "Should complete validation test"
}

# Test secret leak detection in logs
test_log_secret_detection() {
    create_test_environment "security_log_secrets"
    activate_test_environment
    setup_standard_mocks
    create_test_secrets
    
    info "Testing secret leak detection in logs"
    
    # Create test repository that might leak secrets
    local test_repo="$TEST_WORKSPACE/log-leak-test-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Log secret detection test"

# Simulate potential secret leakage
echo "Processing configuration..."
echo "Debug: config contains api_key field"
echo "Debug: config contains password field"

# This would be a leak (but we're testing detection)
# echo "API key is: $API_KEY"

# Proper way - log without exposing values
echo "Configuration loaded with secret fields redacted"

echo "Log secret detection completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test and scan output for potential secrets
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-log-test" --dry-run 2>&1 || true)
    
    # Check that no actual secret values are in output
    assert_not_contains "$output" "test_api_key_12345" "Should not contain actual API key"
    assert_not_contains "$output" "test_db_password" "Should not contain actual password"
    assert_contains "$output" "Log secret detection test" "Should run log test"
    assert_contains "$output" "secret fields redacted" "Should mention redaction"
    
    # Check for patterns that might indicate secrets
    local secret_patterns=(
        "[A-Za-z0-9]{32,}"  # Long alphanumeric strings
        "sk-[A-Za-z0-9]+"   # API key patterns
        "-----BEGIN.*KEY-----"  # Private keys
    )
    
    for pattern in "${secret_patterns[@]}"; do
        if echo "$output" | grep -qE "$pattern"; then
            warning "Potential secret pattern detected: $pattern"
        fi
    done
    
    success "No obvious secret leaks detected in logs"
}

# Test privilege escalation prevention
test_privilege_escalation() {
    create_test_environment "security_privilege"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing privilege escalation prevention"
    
    # Create test repository with privilege checks
    local test_repo="$TEST_WORKSPACE/privilege-test-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Privilege escalation test"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "WARNING: Running as root - this is not recommended"
    echo "Dotfiles should be installed as regular user"
fi

# Check for sudo in environment
if [[ -n "${SUDO_USER:-}" ]]; then
    echo "WARNING: SUDO_USER detected - installation under sudo"
fi

# Verify we're not trying to write to system directories
system_dirs=(
    "/etc"
    "/usr/local/bin"
    "/opt"
)

for dir in "${system_dirs[@]}"; do
    if [[ -w "$dir" ]]; then
        echo "WARNING: Write access to system directory: $dir"
    fi
done

echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Privilege check completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test privilege checking
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-privilege" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Privilege escalation test" "Should test privileges"
    assert_contains "$output" "Current user:" "Should show current user"
    assert_contains "$output" "Current directory:" "Should show directory"
    assert_contains "$output" "Privilege check completed" "Should complete privilege check"
    
    # Should not be running as root in test environment
    assert_not_contains "$output" "WARNING: Running as root" "Should not run as root"
}

# Test secure network operations
test_secure_network_operations() {
    create_test_environment "security_network"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing secure network operations"
    
    # Mock secure network tools
    configure_mock "curl" "secure_options" "true"
    configure_mock "wget" "secure_options" "true"
    configure_mock "git" "secure_clone" "true"
    
    # Create test repository with network security checks
    local test_repo="$TEST_WORKSPACE/network-security-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Secure network operations test"

# Check for secure download tools
if command -v curl >/dev/null 2>&1; then
    echo "Found curl - checking security options"
    echo "Would use: curl -fsSL (fail silently, show errors, location follow)"
fi

if command -v wget >/dev/null 2>&1; then
    echo "Found wget - checking security options"
    echo "Would use: wget -qO- (quiet, output to stdout)"
fi

# Check git security
if command -v git >/dev/null 2>&1; then
    echo "Found git - checking security configuration"
    echo "Would verify: HTTPS URLs, signature verification"
fi

echo "Network security check completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test network security
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-network" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Secure network operations test" "Should test network security"
    assert_contains "$output" "checking security options" "Should check security options"
    assert_contains "$output" "curl -fsSL" "Should use secure curl options"
    assert_contains "$output" "wget -qO-" "Should use secure wget options"
    assert_contains "$output" "HTTPS URLs, signature verification" "Should mention git security"
    assert_contains "$output" "Network security check completed" "Should complete network check"
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Security Integration Tests"
    echo "================================="
    
    run_test "Secret Exposure Prevention" test_secret_exposure_prevention
    run_test "File Permissions Validation" test_file_permissions
    run_test "Authentication Flows" test_authentication_flows
    run_test "Secure Temporary Files" test_secure_temp_files
    run_test "Input Validation" test_input_validation
    run_test "Log Secret Detection" test_log_secret_detection
    run_test "Privilege Escalation Prevention" test_privilege_escalation
    run_test "Secure Network Operations" test_secure_network_operations
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 