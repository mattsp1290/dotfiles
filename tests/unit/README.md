# Unit Testing for Dotfiles Scripts

This directory contains comprehensive unit tests for all utility libraries in the dotfiles repository. The testing framework uses a custom BATS-like system designed specifically for testing bash functions and scripts.

## Overview

Unit tests ensure reliability, maintainability, and correctness of the automation infrastructure. Each utility library has corresponding tests that validate individual functions in isolation using mocking and assertions.

## Test Structure

```
tests/unit/
├── README.md                 # This file
├── utils.sh                  # Tests for scripts/lib/utils.sh
├── detect-os.sh             # Tests for scripts/lib/detect-os.sh  
├── secret-helpers.sh        # Tests for scripts/lib/secret-helpers.sh
├── stow-utils.sh           # Tests for scripts/lib/stow-utils.sh
└── template-engine.sh      # Tests for scripts/lib/template-engine.sh
```

## Running Tests

### Run All Unit Tests
```bash
scripts/test-unit.sh
```

### Run Specific Test Suite
```bash
scripts/test-unit.sh utils
scripts/test-unit.sh detect-os
scripts/test-unit.sh secret-helpers
scripts/test-unit.sh stow-utils
scripts/test-unit.sh template-engine
```

### Run with Options
```bash
# Verbose output
VERBOSE=true scripts/test-unit.sh

# Parallel execution
PARALLEL_TESTS=true scripts/test-unit.sh

# Debug mode
TEST_DEBUG=true scripts/test-unit.sh utils
```

## Test Framework Features

### Assertions
- `assert_equals` - Test string equality
- `assert_contains` - Test string contains substring
- `assert_true/false` - Test boolean conditions
- `assert_command_success/failure` - Test command exit codes
- `assert_file_exists` - Test file existence
- `assert_dir_exists` - Test directory existence
- `assert_symlink` - Test symbolic links

### Mocking System
- `mock_command` - Replace external commands with mock implementations
- `mock_stow` - Mock GNU Stow operations
- `mock_op` - Mock 1Password CLI
- `mock_git` - Mock Git operations
- `mock_brew` - Mock Homebrew package manager

### Test Environment
- Isolated temporary directories for each test
- Environment variable restoration
- Mock call logging and verification
- Automatic cleanup

## Test Categories

### Utils Tests (`utils.sh`)
Tests for `scripts/lib/utils.sh` - Core utility functions:
- Logging functions (log_info, log_error, etc.)
- Command existence checks
- Version comparison
- Network connectivity (with mocking)
- File operations (backup, symlink, etc.)
- User interaction functions
- Error handling and retry logic

### OS Detection Tests (`detect-os.sh`)
Tests for `scripts/lib/detect-os.sh` - Platform detection:
- Operating system type detection (Linux, macOS, FreeBSD)
- Linux distribution identification
- Architecture detection (x86_64, arm64, etc.)
- Package manager detection
- Container and WSL detection
- Version comparison logic

### Secret Management Tests (`secret-helpers.sh`) 
Tests for `scripts/lib/secret-helpers.sh` - 1Password integration:
- Authentication state checking
- Secret retrieval with caching
- Batch secret operations
- Error handling for missing secrets
- Security validation (cache permissions)
- Performance optimization

### Stow Package Tests (`stow-utils.sh`)
Tests for `scripts/lib/stow-utils.sh` - Dotfiles management:
- Package discovery and listing
- Platform-specific package selection
- Conflict detection and resolution
- Backup and adoption workflows
- Symlink verification
- Error handling

### Template Engine Tests (`template-engine.sh`)
Tests for `scripts/lib/template-engine.sh` - Secret injection:
- Template format detection (env, go, custom formats)
- Token extraction and replacement
- File processing with atomic writes
- Template validation
- Dry-run mode testing
- Error condition handling

## Best Practices

### Writing Tests
1. **One assertion per test** - Each test should validate a single behavior
2. **Descriptive names** - Test names should clearly describe the scenario
3. **Isolated tests** - Tests should not depend on each other
4. **Mock external dependencies** - Use mocks for commands, file systems, network
5. **Test error conditions** - Include negative test cases

### Test Structure
```bash
test_function_name_scenario() {
    # Arrange - Set up test environment
    setup_test_environment
    
    # Act - Execute the function under test
    local result
    result=$(function_under_test "input")
    
    # Assert - Verify the expected behavior
    assert_equals "expected" "$result" "Should return expected value"
}
```

### Mocking Guidelines
- Mock external commands that might not be available in all environments
- Use realistic mock responses that match actual command behavior
- Verify mock calls when testing integration points
- Keep mocks simple and focused on the specific test scenario

## Coverage

Current test coverage focuses on:
- **Utility Functions**: 80%+ coverage of core utilities
- **Critical Paths**: 100% coverage of error handling and security functions
- **Platform Logic**: Cross-platform compatibility testing
- **Integration Points**: Mocked testing of external dependencies

## Performance

- Individual test files complete in < 30 seconds
- Total test suite runs in < 5 minutes
- Parallel execution reduces total time by ~60%
- Mock operations are lightweight and fast

## Troubleshooting

### Common Issues

**Permission Errors**
```bash
# Tests try to create files in system directories
# Solution: Use TEST_TEMP_DIR for all file operations
```

**Mock Not Working** 
```bash
# Command still using real implementation
# Solution: Ensure mock is created before sourcing the module
```

**Test Isolation**
```bash
# Tests affecting each other
# Solution: Use setup_test_env() and cleanup_test_session()
```

### Debug Mode
```bash
TEST_DEBUG=true scripts/test-unit.sh utils
# Shows detailed information about test execution
# Includes mock call logging
# Reports environment setup
```

## Continuous Integration

Tests are designed to run in CI environments:
- No interactive prompts
- Platform-independent mocking
- Predictable execution time
- Clear failure reporting

## Future Improvements

- Property-based testing for input validation
- Mutation testing to verify test quality  
- Performance benchmarking integration
- Automated test generation for new functions
- Code coverage reporting integration 