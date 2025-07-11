# ADR-007: Testing Framework and Strategy

**Status**: Accepted  
**Date**: 2024-12-19  
**Deciders**: Matt Spurlin  
**Technical Story**: Implement comprehensive testing framework ensuring reliability, security, and performance across multiple platforms and installation scenarios

## Context and Problem Statement

The dotfiles system requires extensive testing to ensure:
- Reliable installation across different operating systems and environments
- Security validation preventing secret exposure and vulnerability introduction
- Performance regression detection for shell startup and installation times
- Cross-platform compatibility verification
- Integration testing for complex workflows and dependencies
- Continuous validation in CI/CD pipelines
- Easy local testing for development and debugging

Traditional testing approaches for configuration management are often limited to basic syntax validation. A comprehensive strategy is needed that covers functional, security, and performance aspects while being practical for continuous development.

## Decision Drivers

- **Reliability**: High confidence in changes across all supported platforms
- **Automation**: CI/CD integration with comprehensive test coverage
- **Performance**: Regression detection for critical performance metrics
- **Security**: Continuous validation against security vulnerabilities
- **Cross-platform**: Testing across multiple operating systems and architectures
- **Developer Experience**: Fast local testing and debugging capabilities
- **Maintainability**: Easy to extend and maintain test suites
- **Coverage**: Comprehensive testing from unit to end-to-end scenarios

## Considered Options

1. **Multi-Layer Testing with BATS**: Unit tests with BATS, integration with Docker
2. **Shell Script Testing Only**: Basic shell script validation and smoke tests
3. **Container-Only Testing**: Docker/Podman exclusive testing approach
4. **Configuration Management Testing**: Ansible/Chef-style testing tools
5. **Custom Testing Framework**: Purpose-built testing system for dotfiles
6. **Serverspec/InSpec**: Infrastructure testing frameworks

## Decision Outcome

**Chosen option**: "Multi-Layer Testing with BATS, Docker, and Custom Integration Tests"

We implemented a comprehensive testing strategy combining multiple testing approaches to provide thorough validation at different levels of the system.

### Positive Consequences
- Comprehensive coverage from unit tests to full system integration
- Fast local testing with BATS for immediate feedback
- Cross-platform validation through Docker containers
- Security testing integrated into development workflow
- Performance regression detection with benchmarking
- CI/CD integration provides continuous validation
- Easy to extend with new test scenarios
- Clear separation of concerns across test layers

### Negative Consequences
- Complex testing setup with multiple frameworks
- Longer CI/CD pipeline execution times
- Maintenance overhead for multiple test suites
- Learning curve for developers contributing tests
- Resource requirements for comprehensive platform testing

## Pros and Cons of the Options

### Option 1: Multi-Layer Testing (Chosen)
- **Pros**: Comprehensive coverage, fast feedback, platform validation, maintainable
- **Cons**: Complex setup, multiple frameworks, resource intensive

### Option 2: Shell Script Testing Only
- **Pros**: Simple, fast, no dependencies, easy to understand
- **Cons**: Limited coverage, no platform validation, poor error detection

### Option 3: Container-Only Testing
- **Pros**: Platform isolation, reproducible, comprehensive
- **Cons**: Slow feedback, resource intensive, limited local testing

### Option 4: Configuration Management Testing
- **Pros**: Enterprise features, comprehensive validation, proven approach
- **Cons**: Overkill for dotfiles, complex setup, heavy dependencies

### Option 5: Custom Testing Framework
- **Pros**: Perfect fit for requirements, optimized performance
- **Cons**: Development overhead, maintenance burden, limited community

### Option 6: Serverspec/InSpec
- **Pros**: Infrastructure focus, good validation, enterprise ready
- **Cons**: Ruby dependency, overkill for dotfiles, complex setup

## Implementation Details

### Testing Architecture Overview
```bash
tests/
├── unit/                    # BATS unit tests for individual components
│   ├── test-os-detection.bats
│   ├── test-secret-injection.bats
│   ├── test-stow-operations.bats
│   └── test-utilities.bats
├── integration/             # End-to-end integration tests
│   ├── test-fresh-install.sh
│   ├── test-update-workflow.sh
│   ├── test-cross-platform.sh
│   └── test-rollback.sh
├── security/               # Security validation tests
│   ├── scan-secrets.sh
│   ├── check-permissions.sh
│   ├── validate-templates.sh
│   └── git-history-scan.sh
├── performance/            # Performance and benchmark tests
│   ├── benchmark-startup.sh
│   ├── benchmark-install.sh
│   └── regression-detection.sh
└── docker/                 # Container-based testing
    ├── ubuntu/
    ├── fedora/
    ├── arch/
    └── macos/
```

### BATS Unit Testing Framework
```bash
# Example BATS test for OS detection
#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../scripts/lib/detect-os.sh"
}

@test "detect_os_type returns correct OS" {
    case "$(uname -s)" in
        Darwin)
            result="$(detect_os_type)"
            [ "$result" = "macos" ]
            ;;
        Linux)
            result="$(detect_os_type)"
            [ "$result" = "linux" ]
            ;;
    esac
}

@test "detect_package_manager identifies available manager" {
    result="$(detect_package_manager)"
    [ "$result" != "unknown" ]
}

@test "detect_architecture returns valid architecture" {
    result="$(detect_architecture)"
    [[ "$result" =~ ^(x86_64|arm64|arm)$ ]]
}
```

### Integration Testing Strategy
```bash
# Fresh installation test
test_fresh_install() {
    local test_dir=$(mktemp -d)
    local backup_home="$HOME"
    
    export HOME="$test_dir"
    
    # Clone dotfiles
    git clone "$DOTFILES_REPO" "$test_dir/dotfiles"
    cd "$test_dir/dotfiles"
    
    # Run installation
    ./scripts/bootstrap.sh --force --skip-packages
    
    # Validate installation
    validate_symlinks
    validate_shell_config
    validate_git_config
    
    # Cleanup
    export HOME="$backup_home"
    rm -rf "$test_dir"
}
```

### Security Testing Integration
```bash
# Secret scanning with multiple tools
scan_for_secrets() {
    local exit_code=0
    
    # TruffleHog for secret detection
    if command -v trufflehog >/dev/null; then
        trufflehog --regex --entropy=False . || exit_code=1
    fi
    
    # git-secrets for AWS credentials
    if command -v git-secrets >/dev/null; then
        git secrets --scan || exit_code=1
    fi
    
    # Custom pattern matching
    ./scripts/scan-custom-patterns.sh || exit_code=1
    
    return $exit_code
}

# File permission validation
validate_permissions() {
    # Check for overly permissive files
    find . -type f -perm /o+w -not -path './.git/*' | while read -r file; do
        echo "Warning: World-writable file found: $file"
        return 1
    done
    
    # Validate SSH key permissions
    find . -name "*.pem" -o -name "*_rsa" -o -name "*_ed25519" | while read -r key; do
        if [[ $(stat -c %a "$key") != "600" ]]; then
            echo "Error: SSH key has incorrect permissions: $key"
            return 1
        fi
    done
}
```

### Performance Testing and Benchmarking
```bash
# Shell startup time benchmark
benchmark_shell_startup() {
    local iterations=10
    local total_time=0
    
    for ((i=1; i<=iterations; i++)); do
        local start_time=$(date +%s%3N)
        zsh -i -c 'exit' >/dev/null 2>&1
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        total_time=$((total_time + duration))
    done
    
    local average_time=$((total_time / iterations))
    echo "Average shell startup time: ${average_time}ms"
    
    # Assert performance threshold
    if [[ $average_time -gt 500 ]]; then
        echo "ERROR: Shell startup time ${average_time}ms exceeds 500ms threshold"
        return 1
    fi
}

# Installation performance benchmark
benchmark_installation() {
    local start_time=$(date +%s)
    
    # Run full installation
    ./scripts/bootstrap.sh --force
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Installation completed in ${duration} seconds"
    
    # Assert installation time threshold
    if [[ $duration -gt 900 ]]; then  # 15 minutes
        echo "WARNING: Installation time ${duration}s exceeds 15-minute target"
    fi
}
```

### Cross-Platform Docker Testing
```dockerfile
# Ubuntu testing container
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    git \
    curl \
    sudo \
    build-essential

# Create test user
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

# Copy test scripts
COPY --chown=testuser:testuser tests/ /home/testuser/tests/
COPY --chown=testuser:testuser scripts/ /home/testuser/scripts/

# Run tests
CMD ["/home/testuser/tests/integration/test-platform.sh"]
```

### CI/CD Integration
```yaml
# GitHub Actions testing workflow
name: Comprehensive Testing

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install BATS
        run: |
          git clone https://github.com/bats-core/bats-core.git
          cd bats-core && ./install.sh /usr/local
      - name: Run unit tests
        run: make test-unit

  security-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full history for secret scanning
      - name: Run security tests
        run: make test-security

  cross-platform-tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        platform: [ubuntu, fedora, arch]
    steps:
      - uses: actions/checkout@v3
      - name: Test platform ${{ matrix.platform }}
        run: make test-platform-${{ matrix.platform }}

  performance-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run performance benchmarks
        run: make test-performance
```

### Test Automation and Makefile Integration
```makefile
# Test targets for easy execution
.PHONY: test test-unit test-integration test-security test-performance

test: test-unit test-integration test-security test-performance

test-unit:
	@echo "Running unit tests..."
	bats tests/unit/*.bats

test-integration:
	@echo "Running integration tests..."
	./tests/integration/test-all.sh

test-security:
	@echo "Running security tests..."
	./tests/security/scan-all.sh

test-performance:
	@echo "Running performance tests..."
	./tests/performance/benchmark-all.sh

test-platform-%:
	@echo "Testing platform $*..."
	docker-compose -f docker-compose.test.yml run test-$*
```

## Validation Criteria

### Test Coverage Metrics
- Unit test coverage: >90% of critical functions
- Integration test coverage: 100% of installation scenarios
- Security test coverage: 100% of files and configurations
- Performance test coverage: All critical performance paths
- Cross-platform coverage: All supported operating systems

### Success Metrics
```bash
# Test execution standards
Unit tests complete in <2 minutes
Integration tests complete in <10 minutes
Security tests complete in <5 minutes
Performance tests complete in <3 minutes
Full test suite completes in <20 minutes
```

### Quality Gates
- All tests must pass before merge
- Performance regressions trigger automatic alerts
- Security vulnerabilities block deployment
- Cross-platform failures require investigation
- Test failures must be investigated and resolved

### Continuous Improvement
- Monthly review of test effectiveness
- Regular updates to security scanning patterns
- Performance baseline updates for new features
- Addition of tests for reported issues
- Community contribution guidelines for testing

## Links

- [BATS Testing Framework](https://github.com/bats-core/bats-core)
- [Testing Documentation](../testing.md)
- [Test Suite](../../tests/)
- [CI/CD Configuration](../../.github/workflows/)
- [Docker Test Containers](../../docker-compose.test.yml)
- [ADR-009: Security Architecture](009-security-architecture.md)
- [ADR-008: Performance Optimization](008-performance-optimization.md)

## Notes

The multi-layer testing approach has proven essential for maintaining quality and confidence in the dotfiles system. The combination of fast local feedback through BATS and comprehensive validation through integration and cross-platform testing provides the right balance of speed and thoroughness.

Key insights from implementation:
- Unit tests catch most regressions quickly during development
- Integration tests validate real-world usage scenarios
- Security testing prevents accidental secret exposure
- Performance testing ensures user experience remains optimal
- Cross-platform testing catches platform-specific issues early

The testing framework has enabled rapid development while maintaining high quality standards and has been crucial for supporting the project's reliability goals. 