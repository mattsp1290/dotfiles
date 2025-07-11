# Dotfiles Testing Framework

A comprehensive testing framework for validating dotfiles configuration, installation scripts, and cross-platform compatibility.

## Overview

The testing framework provides:

- **Unit Tests**: Test individual components and functions
- **Integration Tests**: Test complete workflows and interactions
- **Performance Tests**: Benchmark installation and configuration performance
- **Cross-platform Testing**: Validate compatibility across different operating systems
- **Mock Framework**: Simulate external dependencies and tools
- **Test Environment Isolation**: Clean, isolated test environments for each test
- **Comprehensive Reporting**: Multiple output formats (text, HTML, JSON)

## Quick Start

### Running Tests

```bash
# Run all tests
./scripts/test-dotfiles.sh

# Run only unit tests
./scripts/test-dotfiles.sh --type unit

# Run tests matching a pattern
./scripts/test-dotfiles.sh --pattern "stow.*"

# Run with verbose output
./scripts/test-dotfiles.sh --verbose

# Generate HTML report
./scripts/test-dotfiles.sh --report test-results.html

# Dry run to see what would be executed
./scripts/test-dotfiles.sh --dry-run
```

### Test Runner Options

```
USAGE:
    test-dotfiles.sh [OPTIONS] [PATTERN]

OPTIONS:
    -h, --help              Show help message
    -t, --type TYPE         Test type: unit, integration, performance, all (default: all)
    -p, --pattern PATTERN   Run tests matching pattern (regex)
    -j, --jobs JOBS         Number of parallel jobs (default: 4)
    -v, --verbose           Enable verbose output
    -n, --dry-run           Show what would be run without executing
    -c, --coverage          Enable code coverage analysis
    -b, --benchmark         Run performance benchmarks
    -r, --report FILE       Write test report to file
    --no-exit-on-failure    Continue running tests after failures
    --timeout SECONDS       Test timeout in seconds (default: 300)

TEST TYPES:
    unit                    Run unit tests only
    integration            Run integration tests only
    performance            Run performance tests only
    all                    Run all tests (default)
```

## Framework Architecture

### Core Components

1. **Test Utilities** (`tests/helpers/test-utils.sh`)
   - Test environment setup and teardown
   - Test execution framework
   - Logging and output formatting
   - Test session management

2. **Assertions Library** (`tests/helpers/assertions.sh`)
   - Basic assertions (true/false, equality)
   - String assertions (contains, matches, regex)
   - Numeric assertions (greater than, less than)
   - File system assertions (exists, permissions, symlinks)
   - Command assertions (exit codes, output)
   - Environment assertions (variables, paths)

3. **Mock Framework** (`tests/helpers/mock-tools.sh`)
   - Mock external commands and tools
   - Configurable behavior and responses
   - Call tracking and verification
   - Standard mocks for common tools (Stow, 1Password, Git, etc.)

4. **Environment Setup** (`tests/helpers/env-setup.sh`)
   - Isolated test environments
   - OS environment simulation
   - Test fixture management
   - Configuration templates

### Test Structure

```
tests/
├── helpers/           # Test framework components
│   ├── test-utils.sh     # Core test utilities
│   ├── assertions.sh     # Assertion library
│   ├── mock-tools.sh     # Mock framework
│   └── env-setup.sh      # Environment setup
├── unit/              # Unit tests
│   ├── bootstrap/        # Bootstrap script tests
│   ├── stow/            # Stow utility tests
│   └── lib/             # Library function tests
├── integration/       # Integration tests
│   └── workflows/       # Complete workflow tests
└── performance/       # Performance benchmarks
    └── benchmarks/      # Benchmark scripts
```

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bash
# Test description

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"

# Test function
test_my_functionality() {
    # Setup test environment
    setup_test_env
    
    # Test assertions
    assert_equals "expected" "actual" "Description of test"
    assert_true "command_that_should_succeed" "Should succeed"
    assert_file_exists "/path/to/file" "File should exist"
    
    # Cleanup
    teardown_test_env
}

# Main test runner
main() {
    init_test_session
    
    echo "Running My Tests"
    echo "================"
    
    run_test "My Functionality" test_my_functionality
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Available Assertions

#### Basic Assertions
- `assert_true "condition" "message"`
- `assert_false "condition" "message"`
- `assert_equals "expected" "actual" "message"`
- `assert_not_equals "expected" "actual" "message"`

#### String Assertions
- `assert_contains "haystack" "needle" "message"`
- `assert_not_contains "haystack" "needle" "message"`
- `assert_matches "string" "pattern" "message"`
- `assert_not_matches "string" "pattern" "message"`

#### Numeric Assertions
- `assert_numeric_equals "expected" "actual" "message"`
- `assert_greater_than "expected" "actual" "message"`
- `assert_less_than "expected" "actual" "message"`

#### File System Assertions
- `assert_file_exists "path" "message"`
- `assert_file_not_exists "path" "message"`
- `assert_dir_exists "path" "message"`
- `assert_dir_not_exists "path" "message"`
- `assert_symlink "path" "message"`
- `assert_symlink_target "link" "target" "message"`

#### Command Assertions
- `assert_command_success "command" "message"`
- `assert_command_failure "command" "message"`
- `assert_command_output "command" "expected_output" "message"`

#### Environment Assertions
- `assert_env_set "variable" "message"`
- `assert_env_unset "variable" "message"`
- `assert_env_equals "variable" "expected_value" "message"`

### Using Mocks

```bash
# Mock external commands
mock_command "git" 'echo "Mocked git output"'
mock_command "stow" 'exit 0'  # Always succeed

# Use standard mocks
setup_standard_mocks  # Sets up common tool mocks

# Configure mock behavior
configure_mock "curl" "network_error" "true"
configure_mock "op" "signed_in" "false"

# Verify mock calls
assert_mock_called "git" "clone"
assert_mock_call_count "stow" 3
```

### Test Environment

```bash
# Create isolated test environment
setup_test_env

# Environment variables available in tests:
# $HOME - Test home directory
# $DOTFILES_DIR - Test dotfiles directory
# $XDG_CONFIG_HOME - Test config directory
# $XDG_DATA_HOME - Test data directory
# $XDG_CACHE_HOME - Test cache directory

# Create test files
create_test_file "$HOME/.testrc" "test content"
create_test_package "vim"  # Creates a test dotfiles package

# Cleanup
teardown_test_env
```

## Current Test Status

### Working Tests
- ✅ **Framework Verification**: Basic framework functionality
- ✅ **Test Runner**: Command-line interface and test discovery
- ✅ **Assertion Library**: All assertion types working
- ✅ **Mock Framework**: Command mocking and verification
- ✅ **Environment Isolation**: Clean test environments

### Tests in Development
- 🔄 **OS Detection**: Platform-specific functionality (needs OS simulation improvements)
- 🔄 **Stow Package Detection**: Package discovery and validation
- 🔄 **Integration Workflows**: End-to-end testing

### Test Coverage
- Core framework: 100%
- Utilities library: 80%
- Bootstrap scripts: 60%
- Stow integration: 70%

## Continuous Integration

The framework integrates with GitHub Actions for automated testing:

```yaml
# .github/workflows/tests.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: ./scripts/test-dotfiles.sh --report test-results.json
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: test-results-${{ matrix.os }}
          path: test-results.json
```

## Troubleshooting

### Common Issues

1. **Readonly Variable Errors**
   - Ensure test framework is sourced only once
   - Check for conflicting variable declarations

2. **Mock Command Not Found**
   - Verify mock is set up before use
   - Check PATH modifications in test environment

3. **Test Environment Conflicts**
   - Use `setup_test_env` and `teardown_test_env` properly
   - Avoid global state modifications

4. **Assertion Failures**
   - Use `TEST_DEBUG=true` for detailed output
   - Check assertion syntax and parameters

### Debug Mode

```bash
# Enable debug output
TEST_DEBUG=true ./scripts/test-dotfiles.sh

# Run single test with debug
TEST_DEBUG=true bash tests/unit/test-framework-verification.sh
```

## Contributing

### Adding New Tests

1. Create test file in appropriate directory (`tests/unit/`, `tests/integration/`, etc.)
2. Follow naming convention: `test-*.sh`
3. Use the standard test structure
4. Add comprehensive assertions
5. Include cleanup in test functions
6. Update this documentation

### Test Guidelines

- **Isolation**: Each test should be independent
- **Cleanup**: Always clean up test artifacts
- **Assertions**: Use descriptive assertion messages
- **Mocking**: Mock external dependencies
- **Documentation**: Document complex test logic

### Performance Considerations

- Use parallel execution for independent tests
- Mock expensive operations
- Clean up large test artifacts
- Set appropriate timeouts

## Examples

See the following test files for examples:
- `tests/unit/test-framework-verification.sh` - Basic framework usage
- `tests/unit/bootstrap/test-os-detection.sh` - OS detection testing
- `tests/unit/stow/test-package-detection.sh` - Package validation
- `tests/integration/test-complete-workflow.sh` - End-to-end workflows 