# Integration Testing Documentation

This directory contains comprehensive integration tests for the dotfiles repository, validating end-to-end functionality across different platforms and scenarios.

## Overview

The integration testing infrastructure provides:

- **Fresh Installation Testing**: Complete dotfiles installation from clean state
- **Upgrade Scenario Testing**: Configuration migration and version compatibility
- **Rollback Procedure Testing**: Backup and restore functionality
- **Security Validation**: Secret exposure prevention and permission verification
- **Performance Benchmarking**: Installation time and resource usage validation
- **Cross-Platform Support**: macOS and Linux (Ubuntu, Debian, Fedora, Arch) testing

## Test Structure

```
tests/integration/
├── README.md                          # This documentation
├── fresh-install.sh                   # Fresh installation tests
├── upgrade.sh                         # Upgrade scenario tests
├── rollback.sh                        # Rollback procedure tests
├── security.sh                        # Security validation tests
├── performance.sh                     # Performance benchmarking tests
├── test-complete-workflow.sh          # Complete workflow tests (existing)
├── docker/                            # Docker container configurations
│   ├── Dockerfile.ubuntu-20.04        # Ubuntu 20.04 test environment
│   ├── Dockerfile.ubuntu-22.04        # Ubuntu 22.04 test environment
│   ├── Dockerfile.debian-11           # Debian 11 test environment
│   ├── Dockerfile.fedora-36           # Fedora 36 test environment
│   ├── Dockerfile.arch                # Arch Linux test environment
│   ├── Dockerfile.security            # Security testing environment
│   └── Dockerfile.performance         # Performance testing environment
├── fixtures/                          # Test data and sample configurations
│   └── sample-configs/                # Sample dotfiles configurations
└── reports/                           # Test result templates and reports
```

## Quick Start

### Prerequisites

- **Local Testing**: bash 4.0+, git, stow (for basic tests)
- **Docker Testing**: Docker and Docker Compose
- **macOS VM Testing**: Vagrant with Parallels or VMware (optional)

### Running Tests Locally

#### Individual Test Suites

```bash
# Fresh installation tests
./tests/integration/fresh-install.sh

# Upgrade scenario tests
./tests/integration/upgrade.sh

# Rollback procedure tests
./tests/integration/rollback.sh

# Security validation tests
./tests/integration/security.sh

# Performance benchmarking tests
./tests/integration/performance.sh
```

#### All Tests

```bash
# Run all integration tests
for test in tests/integration/*.sh; do
    if [[ "$test" != *"README"* ]]; then
        echo "Running $test..."
        bash "$test"
    fi
done
```

### Docker-Based Testing

#### Single Platform

```bash
# Test on Ubuntu 20.04
docker-compose -f docker-compose.test.yml run ubuntu-20-04

# Test on specific platform with specific test
docker-compose -f docker-compose.test.yml run ubuntu-22-04 \
    bash -c "tests/integration/fresh-install.sh"
```

#### All Platforms

```bash
# Run tests across all platforms
docker-compose -f docker-compose.test.yml up

# Run with parallel execution
docker-compose -f docker-compose.test.yml up --parallel
```

#### Platform-Specific Testing

```bash
# Ubuntu environments
docker-compose -f docker-compose.test.yml up ubuntu-20-04 ubuntu-22-04

# All Linux distributions
docker-compose -f docker-compose.test.yml up ubuntu-20-04 ubuntu-22-04 debian-11 fedora-36 arch

# Security testing
docker-compose -f docker-compose.test.yml up security-test

# Performance testing
docker-compose -f docker-compose.test.yml up performance-test
```

### macOS VM Testing (Vagrant)

#### Prerequisites Setup

```bash
# Install Vagrant (macOS)
brew install vagrant

# Install VM provider (choose one)
brew install --cask parallels          # Parallels Desktop
brew install --cask vmware-fusion      # VMware Fusion
```

#### Running macOS Tests

```bash
# Test on latest macOS
vagrant up macos-ventura

# Test on specific macOS version
vagrant up macos-monterey

# Run all macOS versions
vagrant up macos-bigsur macos-monterey macos-ventura

# Quick smoke test
vagrant up macos-minimal

# Helper script usage
bash scripts/vagrant-helpers.sh test-all      # Test all macOS versions
bash scripts/vagrant-helpers.sh test-latest   # Test latest macOS only
bash scripts/vagrant-helpers.sh smoke-test    # Quick validation
bash scripts/vagrant-helpers.sh clean         # Destroy all VMs
```

## CI/CD Integration

### GitHub Actions

The integration tests run automatically via GitHub Actions:

- **Pull Requests**: All integration tests on Ubuntu and macOS
- **Main Branch**: Full test suite including security and performance
- **Scheduled**: Daily complete test runs
- **Manual**: Workflow dispatch with configurable test suites

#### Workflow Files

- `.github/workflows/integration.yml`: Main integration testing workflow
- `.github/workflows/tests.yml`: Existing comprehensive test suite

#### Manual Trigger

```bash
# Via GitHub CLI
gh workflow run integration.yml \
    -f test_suite=fresh-install \
    -f platforms=all

# Via GitHub web interface
# Go to Actions tab > Integration Tests > Run workflow
```

## Test Scenarios

### Fresh Installation Tests

Tests complete dotfiles installation from clean state:

- ✅ Basic installation workflow
- ✅ Cross-platform compatibility (macOS, Ubuntu, Debian, Fedora, Arch)
- ✅ Network failure handling
- ✅ Permission issue handling
- ✅ Performance validation (< 15 minutes)
- ✅ Existing file handling
- ✅ Secret template processing
- ✅ Input validation and error handling

### Upgrade Scenario Tests

Tests configuration migration and version compatibility:

- ✅ Basic upgrade from previous versions
- ✅ Configuration format migration
- ✅ Backup preservation during upgrades
- ✅ Selective module upgrades
- ✅ Rollback capability preparation
- ✅ Error handling and recovery
- ✅ Compatibility validation

### Rollback Procedure Tests

Tests backup and restore functionality:

- ✅ Basic rollback to previous state
- ✅ User configuration preservation
- ✅ Rollback validation and verification
- ✅ Selective component rollback
- ✅ Temporary file cleanup
- ✅ Error handling and recovery
- ✅ Symlink restoration
- ✅ Dry-run mode testing

### Security Validation Tests

Tests security aspects of the installation:

- ✅ Secret exposure prevention in logs
- ✅ File permission validation (SSH keys, configs)
- ✅ Authentication flow security
- ✅ Secure temporary file handling
- ✅ Input validation and sanitization
- ✅ Log secret leak detection
- ✅ Privilege escalation prevention
- ✅ Secure network operations

### Performance Benchmarking Tests

Tests performance and resource usage:

- ✅ Installation performance (< 15 minutes target)
- ✅ Shell startup performance (< 5 seconds target)
- ✅ Stow operation performance (< 5 minutes target)
- ✅ Memory usage validation
- ✅ Concurrent operation performance
- ✅ File I/O performance benchmarks
- ✅ Bootstrap script performance

## Configuration

### Environment Variables

```bash
# Test execution
export DOTFILES_CI=true              # Enable CI mode
export TEST_PLATFORM=ubuntu-20.04    # Platform identifier
export TEST_DEBUG=true               # Enable debug output
export TEST_TIMEOUT=1800             # Test timeout (seconds)

# Security testing
export SECURITY_TEST=true            # Enable security-specific tests
export MOCK_SECRETS=true             # Use mock secrets only

# Performance testing
export PERFORMANCE_TEST=true         # Enable performance benchmarks
export BENCHMARK_MODE=true           # Detailed performance metrics
```

### Test Configuration Files

- `tests/helpers/env-setup.sh`: Environment setup utilities
- `tests/helpers/test-utils.sh`: Test framework utilities
- `tests/helpers/assertions.sh`: Test assertion functions
- `tests/helpers/mock-tools.sh`: Mock tool configurations

## Development

### Adding New Tests

1. **Create Test Function**:
   ```bash
   test_new_functionality() {
       create_test_environment "new_test"
       activate_test_environment
       setup_standard_mocks
       
       info "Testing new functionality"
       
       # Test implementation
       local output
       output=$(your_test_command 2>&1 || true)
       
       assert_contains "$output" "expected_output" "Should show expected output"
       assert_not_contains "$output" "error" "Should not show errors"
   }
   ```

2. **Add to Test Runner**:
   ```bash
   run_test "New Functionality" test_new_functionality
   ```

3. **Update Documentation**: Add test description to this README

### Test Environment Management

```bash
# Create isolated test environment
create_test_environment "test_name"
activate_test_environment

# Set up standard mocks
setup_standard_mocks

# Create test files
create_test_file "/path/to/file" "content"

# Mock command behavior
configure_mock "command" "behavior" "true"

# Clean up
cleanup_test_environment
```

### Debugging Tests

```bash
# Enable debug mode
export TEST_DEBUG=true

# Run single test with verbose output
TEST_DEBUG=true ./tests/integration/fresh-install.sh

# Check test logs
cat /tmp/dotfiles-test-*/test.log

# Inspect test environment
ls -la /tmp/dotfiles-test-*/workspace/
```

## Troubleshooting

### Common Issues

#### Docker Tests Failing

```bash
# Check Docker daemon
docker info

# Rebuild containers
docker-compose -f docker-compose.test.yml build --no-cache

# Check container logs
docker-compose -f docker-compose.test.yml logs ubuntu-20-04

# Clean up Docker resources
docker system prune -f
```

#### macOS VM Tests Not Starting

```bash
# Check Vagrant status
vagrant status

# Check VM provider
vagrant --version
parallels-desktop --version  # or vmware-fusion --version

# Destroy and recreate VMs
vagrant destroy -f
vagrant up macos-monterey
```

#### Test Environment Issues

```bash
# Check test dependencies
bash --version     # Should be 4.0+
git --version
stow --version

# Verify test scripts are executable
ls -la tests/integration/*.sh

# Check available disk space
df -h /tmp

# Clean up old test environments
rm -rf /tmp/dotfiles-test-*
```

#### Performance Test Failures

```bash
# Check system resources
top
free -m           # Linux
vm_stat           # macOS

# Run with increased timeouts
TEST_TIMEOUT=3600 ./tests/integration/performance.sh

# Check for background processes affecting performance
ps aux | grep -E "(brew|apt|yum|pacman)"
```

### Debug Information

#### Collecting Debug Information

```bash
# System information
uname -a
cat /etc/os-release    # Linux
sw_vers               # macOS

# Environment variables
env | grep -E "(DOTFILES|TEST)"

# Test framework status
source tests/helpers/test-utils.sh
test_framework_info
```

#### Log Files

- Test execution logs: `/tmp/dotfiles-test-*/test.log`
- Individual test logs: `/tmp/dotfiles-test-*/tests/*.log`
- CI logs: GitHub Actions artifacts
- Docker logs: `docker-compose logs`

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Installation Time | < 15 minutes | Fresh install end-to-end |
| Shell Startup | < 5 seconds | zsh/bash initialization |
| Stow Operations | < 5 minutes | Complete package deployment |
| Memory Usage | < 100MB | Peak during installation |
| Test Suite | < 30 minutes | Complete integration tests |

## Security Considerations

- **No Real Secrets**: Tests use mock secrets only
- **Isolated Environments**: Each test runs in isolation
- **Permission Validation**: File permissions are verified
- **Log Sanitization**: Secrets are filtered from logs
- **Non-Root Execution**: Tests run as regular user
- **Network Security**: HTTPS-only operations

## Contributing

### Test Development Guidelines

1. **Isolation**: Each test must be completely isolated
2. **Deterministic**: Tests should produce consistent results
3. **Fast**: Individual tests should complete quickly
4. **Descriptive**: Clear test names and assertion messages
5. **Cleanup**: Always clean up test resources
6. **Documentation**: Update this README for new test scenarios

### Code Review Checklist

- [ ] Test runs successfully locally
- [ ] Test is properly isolated
- [ ] Assertions are clear and descriptive
- [ ] Error handling is implemented
- [ ] Documentation is updated
- [ ] No real secrets or sensitive data
- [ ] Cross-platform compatibility considered

## Resources

### Documentation

- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/)
- [GitHub Actions Matrix Builds](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Integration Testing Best Practices](https://martinfowler.com/articles/practical-test-pyramid.html)

### Related Files

- `tests/unit/`: Unit test suite
- `scripts/bootstrap.sh`: Main installation script
- `install.sh`: Remote installation entry point
- `Makefile`: Build and test automation
- `.github/workflows/`: CI/CD configurations 