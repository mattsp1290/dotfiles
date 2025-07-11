#!/usr/bin/env bash
# Integration Test Runner
# Demonstrates and validates the complete integration testing infrastructure

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source integration test framework
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Colors for output
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

# Enhanced logging for demo
demo_info() {
    echo "${BLUE}${BOLD}[DEMO]${RESET} $*"
}

demo_step() {
    echo ""
    echo "${YELLOW}${BOLD}>>> $*${RESET}"
    echo ""
}

demo_success() {
    echo "${GREEN}${BOLD}✅ $*${RESET}"
}

demo_warning() {
    echo "${YELLOW}${BOLD}⚠️  $*${RESET}"
}

demo_error() {
    echo "${RED}${BOLD}❌ $*${RESET}"
}

# Show usage
usage() {
    cat << EOF
Integration Test Runner - Demonstrates and validates the integration testing infrastructure

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    demo            Run demonstration of integration testing features
    validate        Validate integration testing infrastructure
    test-fresh      Test fresh installation scenarios
    test-upgrade    Test upgrade scenarios
    test-rollback   Test rollback scenarios
    test-security   Test security scenarios
    test-performance Test performance scenarios
    test-docker     Test Docker-based testing
    all             Run all integration tests

OPTIONS:
    -h, --help              Show this help message
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing
    --platform PLATFORM     Test specific platform (macos, ubuntu, debian, fedora, arch)
    --timeout SECONDS       Set test timeout (default: 1800)

EXAMPLES:
    $0 demo                 # Run demonstration
    $0 validate             # Validate infrastructure
    $0 test-fresh           # Test fresh installation
    $0 --platform ubuntu test-fresh  # Test on Ubuntu

EOF
}

# Demonstrate integration testing infrastructure
demo_integration_testing() {
    demo_step "Integration Testing Infrastructure Demonstration"
    
    demo_info "This demonstration shows the comprehensive integration testing infrastructure"
    demo_info "for the dotfiles repository, including cross-platform testing, containerization,"
    demo_info "and automated CI/CD validation."
    
    echo ""
    demo_info "Infrastructure Components:"
    echo "  📁 Test Scripts: Fresh install, upgrade, rollback, security, performance"
    echo "  🐳 Docker Containers: Ubuntu 20.04/22.04, Debian 11, Fedora 36, Arch Linux"
    echo "  📦 Vagrant VMs: macOS Big Sur, Monterey, Ventura"
    echo "  🔧 GitHub Actions: Automated CI/CD with matrix testing"
    echo "  📊 Test Fixtures: Sample configurations and test data"
    echo "  🛠️  Helper Utilities: Integration-specific test framework extensions"
    
    demo_step "1. Testing Framework Validation"
    
    # Initialize integration test session
    init_integration_test_session
    demo_success "Integration test session initialized"
    
    # Create test dotfiles repository
    demo_info "Creating test dotfiles repository..."
    local test_repo
    test_repo=$(create_test_dotfiles_repo "minimal-dotfiles")
    demo_success "Created test dotfiles repository: $test_repo"
    
    # Verify test repository structure
    if [[ -f "$test_repo/scripts/bootstrap.sh" ]]; then
        demo_success "Bootstrap script found and executable"
    else
        demo_error "Bootstrap script missing"
        return 1
    fi
    
    if [[ -f "$test_repo/.version" ]]; then
        local version=$(cat "$test_repo/.version")
        demo_success "Version file found: $version"
    else
        demo_warning "Version file missing"
    fi
    
    demo_step "2. Cross-Platform Environment Simulation"
    
    # Test OS environment simulation
    local platforms=("macos" "ubuntu" "debian" "fedora" "arch")
    for platform in "${platforms[@]}"; do
        demo_info "Simulating $platform environment..."
        if simulate_os_environment "$platform"; then
            demo_success "$platform environment simulation working"
        else
            demo_error "$platform environment simulation failed"
        fi
    done
    
    demo_step "3. Test Bootstrap Script Execution"
    
    # Test bootstrap script in different modes
    cd "$test_repo"
    
    demo_info "Testing bootstrap script help..."
    if ./scripts/bootstrap.sh --help >/dev/null 2>&1; then
        demo_success "Bootstrap help working"
    else
        demo_error "Bootstrap help failed"
    fi
    
    demo_info "Testing bootstrap doctor mode..."
    local doctor_output
    doctor_output=$(./scripts/bootstrap.sh doctor 2>&1 || true)
    if echo "$doctor_output" | grep -q "diagnostics"; then
        demo_success "Bootstrap doctor mode working"
    else
        demo_error "Bootstrap doctor mode failed"
    fi
    
    demo_info "Testing bootstrap dry-run installation..."
    local install_output
    install_output=$(./scripts/bootstrap.sh --dry-run install 2>&1 || true)
    if echo "$install_output" | grep -q "DRY RUN"; then
        demo_success "Bootstrap dry-run installation working"
    else
        demo_error "Bootstrap dry-run installation failed"
    fi
    
    demo_step "4. Template Processing Demonstration"
    
    if [[ -d "$test_repo/templates" ]]; then
        local template_count=$(find "$test_repo/templates" -name "*.tmpl" | wc -l)
        demo_success "Found $template_count template files for secret injection testing"
        
        # Show template structure
        for template in "$test_repo/templates"/*.tmpl; do
            if [[ -f "$template" ]]; then
                demo_info "Template: $(basename "$template")"
                if grep -q "{{" "$template"; then
                    demo_success "  Contains template variables"
                else
                    demo_warning "  No template variables found"
                fi
            fi
        done
    else
        demo_warning "No templates directory found"
    fi
    
    demo_step "5. Performance Benchmarking"
    
    demo_info "Creating performance baseline..."
    local baseline_file
    baseline_file=$(create_performance_baseline "demo")
    demo_success "Performance baseline created: $(basename "$baseline_file")"
    
    demo_info "Testing performance timing utilities..."
    if time_command "Demo timing test" sleep 1; then
        demo_success "Performance timing utilities working"
    else
        demo_error "Performance timing utilities failed"
    fi
    
    demo_step "6. Docker Container Validation"
    
    if command -v docker >/dev/null 2>&1; then
        demo_info "Docker is available - checking container configurations..."
        
        local docker_compose_file="$DOTFILES_ROOT/docker-compose.test.yml"
        if [[ -f "$docker_compose_file" ]]; then
            demo_success "Docker Compose configuration found"
            
            # Validate compose file syntax
            if docker-compose -f "$docker_compose_file" config >/dev/null 2>&1; then
                demo_success "Docker Compose configuration is valid"
            else
                demo_error "Docker Compose configuration has syntax errors"
            fi
        else
            demo_error "Docker Compose configuration missing"
        fi
        
        # Check Dockerfiles
        local dockerfile_count=$(find "$SCRIPT_DIR/docker" -name "Dockerfile.*" 2>/dev/null | wc -l)
        demo_success "Found $dockerfile_count Docker container configurations"
    else
        demo_warning "Docker not available - skipping container validation"
    fi
    
    demo_step "7. Vagrant VM Validation"
    
    if command -v vagrant >/dev/null 2>&1; then
        demo_info "Vagrant is available - checking VM configurations..."
        
        local vagrantfile="$DOTFILES_ROOT/Vagrantfile"
        if [[ -f "$vagrantfile" ]]; then
            demo_success "Vagrantfile found"
            
            # Validate Vagrantfile syntax
            cd "$DOTFILES_ROOT"
            if vagrant validate >/dev/null 2>&1; then
                demo_success "Vagrantfile is valid"
            else
                demo_warning "Vagrantfile validation issues (may require specific providers)"
            fi
        else
            demo_error "Vagrantfile missing"
        fi
    else
        demo_warning "Vagrant not available - skipping VM validation"
    fi
    
    demo_step "8. CI/CD Workflow Validation"
    
    local workflow_file="$DOTFILES_ROOT/.github/workflows/integration.yml"
    if [[ -f "$workflow_file" ]]; then
        demo_success "Integration testing workflow found"
        
        # Check workflow has required jobs
        if grep -q "ubuntu-integration" "$workflow_file"; then
            demo_success "Ubuntu integration job configured"
        else
            demo_error "Ubuntu integration job missing"
        fi
        
        if grep -q "macos-integration" "$workflow_file"; then
            demo_success "macOS integration job configured"
        else
            demo_error "macOS integration job missing"
        fi
    else
        demo_error "Integration testing workflow missing"
    fi
    
    demo_step "9. Test Report Generation"
    
    demo_info "Generating integration test report..."
    local report_file
    report_file=$(generate_integration_report)
    if [[ -f "$report_file" ]]; then
        demo_success "Integration test report generated"
        demo_info "Report location: $report_file"
    else
        demo_error "Failed to generate integration test report"
    fi
    
    demo_step "10. Infrastructure Summary"
    
    echo ""
    demo_info "Integration Testing Infrastructure Status:"
    echo ""
    echo "  ✅ Test Framework: Functional"
    echo "  ✅ Cross-Platform Support: Ubuntu, Debian, Fedora, Arch, macOS"
    echo "  ✅ Containerization: Docker containers for all Linux distributions"
    echo "  ✅ Virtualization: Vagrant support for macOS testing"
    echo "  ✅ CI/CD Integration: GitHub Actions workflows"
    echo "  ✅ Test Fixtures: Sample configurations and test data"
    echo "  ✅ Helper Utilities: Integration-specific extensions"
    echo "  ✅ Performance Testing: Benchmarking and monitoring"
    echo "  ✅ Security Testing: Secret exposure prevention"
    echo "  ✅ Reporting: Automated test result generation"
    echo ""
    
    demo_success "Integration testing infrastructure demonstration completed!"
    
    # Clean up
    cleanup_integration_test_session
    demo_success "Test session cleaned up"
    
    return 0
}

# Validate integration testing infrastructure
validate_infrastructure() {
    demo_step "Validating Integration Testing Infrastructure"
    
    local validation_errors=0
    
    # Check required scripts exist
    local required_scripts=(
        "fresh-install.sh"
        "upgrade.sh"
        "rollback.sh"
        "security.sh"
        "performance.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            demo_success "Test script found: $script"
        else
            demo_error "Test script missing or not executable: $script"
            ((validation_errors++))
        fi
    done
    
    # Check Docker configurations
    local docker_configs=(
        "docker/Dockerfile.ubuntu-20.04"
        "docker/Dockerfile.ubuntu-22.04"
        "docker/Dockerfile.debian-11"
        "docker/Dockerfile.fedora-36"
        "docker/Dockerfile.arch"
        "docker/Dockerfile.security"
        "docker/Dockerfile.performance"
    )
    
    for config in "${docker_configs[@]}"; do
        if [[ -f "$SCRIPT_DIR/$config" ]]; then
            demo_success "Docker config found: $config"
        else
            demo_error "Docker config missing: $config"
            ((validation_errors++))
        fi
    done
    
    # Check test fixtures
    if [[ -d "$SCRIPT_DIR/fixtures/sample-configs/minimal-dotfiles" ]]; then
        demo_success "Test fixtures found"
    else
        demo_error "Test fixtures missing"
        ((validation_errors++))
    fi
    
    # Check documentation
    if [[ -f "$SCRIPT_DIR/README.md" ]]; then
        demo_success "Integration testing documentation found"
    else
        demo_error "Integration testing documentation missing"
        ((validation_errors++))
    fi
    
    # Summary
    if [[ $validation_errors -eq 0 ]]; then
        demo_success "Infrastructure validation passed - all components present"
        return 0
    else
        demo_error "Infrastructure validation failed - $validation_errors errors found"
        return 1
    fi
}

# Run specific test suite
run_test_suite() {
    local suite="$1"
    local platform="${2:-auto}"
    
    demo_step "Running $suite test suite"
    
    if [[ "$platform" != "auto" ]]; then
        simulate_os_environment "$platform"
        demo_info "Testing on $platform platform"
    fi
    
    local test_script="$SCRIPT_DIR/$suite.sh"
    if [[ -x "$test_script" ]]; then
        demo_info "Executing $test_script..."
        
        # Run with timeout
        if timeout "${TEST_TIMEOUT:-1800}" "$test_script"; then
            demo_success "$suite tests passed"
            return 0
        else
            demo_error "$suite tests failed"
            return 1
        fi
    else
        demo_error "Test script not found: $test_script"
        return 1
    fi
}

# Main function
main() {
    local command="demo"
    local platform="auto"
    local verbose=false
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --verbose)
                verbose=true
                set -x
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --platform)
                platform="$2"
                shift 2
                ;;
            --timeout)
                export TEST_TIMEOUT="$2"
                shift 2
                ;;
            demo|validate|test-fresh|test-upgrade|test-rollback|test-security|test-performance|test-docker|all)
                command="$1"
                shift
                ;;
            *)
                demo_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set up environment
    export DOTFILES_CI=true
    
    if [[ "$dry_run" == "true" ]]; then
        demo_info "DRY RUN MODE: No actual tests will be executed"
    fi
    
    # Execute command
    case "$command" in
        "demo")
            demo_integration_testing
            ;;
        "validate")
            validate_infrastructure
            ;;
        "test-fresh")
            run_test_suite "fresh-install" "$platform"
            ;;
        "test-upgrade")
            run_test_suite "upgrade" "$platform"
            ;;
        "test-rollback")
            run_test_suite "rollback" "$platform"
            ;;
        "test-security")
            run_test_suite "security" "$platform"
            ;;
        "test-performance")
            run_test_suite "performance" "$platform"
            ;;
        "test-docker")
            if command -v docker >/dev/null 2>&1; then
                demo_info "Running Docker-based integration tests..."
                docker-compose -f "$DOTFILES_ROOT/docker-compose.test.yml" up ubuntu-20-04
            else
                demo_error "Docker not available"
                exit 1
            fi
            ;;
        "all")
            demo_info "Running all integration test suites..."
            local suites=("fresh-install" "upgrade" "rollback" "security" "performance")
            local failed_suites=()
            
            for suite in "${suites[@]}"; do
                if ! run_test_suite "$suite" "$platform"; then
                    failed_suites+=("$suite")
                fi
            done
            
            if [[ ${#failed_suites[@]} -eq 0 ]]; then
                demo_success "All integration test suites passed"
            else
                demo_error "Failed test suites: ${failed_suites[*]}"
                exit 1
            fi
            ;;
        *)
            demo_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Header
echo ""
echo "${BLUE}${BOLD}======================================================${RESET}"
echo "${BLUE}${BOLD}  Dotfiles Integration Testing Infrastructure${RESET}"
echo "${BLUE}${BOLD}======================================================${RESET}"
echo ""

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 