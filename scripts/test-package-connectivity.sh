#!/usr/bin/env bash
# Package Manager Connectivity Test Script
# Tests connectivity and performance of package manager registries

set -euo pipefail

# Logging setup
log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*" >&2
}

# Test results
TEST_RESULTS=()

# Add test result
add_result() {
    local registry="$1"
    local status="$2"
    local time="$3"
    local message="$4"
    TEST_RESULTS+=("$registry|$status|$time|$message")
}

# Test URL connectivity with timing
test_url() {
    local url="$1"
    local name="${2:-$url}"
    local timeout="${3:-10}"
    
    log_info "Testing $name connectivity..."
    
    local start_time
    start_time=$(date +%s.%N)
    
    if curl -s --head --max-time "$timeout" "$url" >/dev/null 2>&1; then
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        add_result "$name" "✅ OK" "${duration}s" "Accessible"
        return 0
    else
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        add_result "$name" "❌ FAIL" "${duration}s" "Not accessible"
        return 1
    fi
}

# Test npm registries
test_npm_registries() {
    log_info "Testing npm registries..."
    
    local registries=(
        "https://registry.npmjs.org/|Official npm Registry"
        "https://registry.yarnpkg.com/|Yarn Registry"
        "https://npm.pkg.github.com/|GitHub Packages"
        "https://registry.npmjs.cf/|Cloudflare Mirror"
    )
    
    for registry_info in "${registries[@]}"; do
        IFS='|' read -r url name <<< "$registry_info"
        test_url "$url" "$name (npm)" 15
    done
    
    # Test npm search functionality if npm is available
    if command -v npm >/dev/null 2>&1; then
        log_info "Testing npm search functionality..."
        local start_time
        start_time=$(date +%s.%N)
        
        if timeout 30 npm search --no-progress lodash 2>/dev/null | grep -q lodash; then
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "npm search" "✅ OK" "${duration}s" "Search functionality works"
        else
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "npm search" "❌ FAIL" "${duration}s" "Search functionality failed"
        fi
    fi
}

# Test pip indexes
test_pip_indexes() {
    log_info "Testing pip indexes..."
    
    local indexes=(
        "https://pypi.org/simple/|Official PyPI"
        "https://pypi.python.org/simple/|Legacy PyPI"
        "https://pypi.douban.com/simple/|Douban Mirror"
        "https://mirrors.aliyun.com/pypi/simple/|Aliyun Mirror"
    )
    
    for index_info in "${indexes[@]}"; do
        IFS='|' read -r url name <<< "$index_info"
        test_url "$url" "$name (pip)" 15
    done
    
    # Test pip functionality if pip is available
    if command -v pip >/dev/null 2>&1; then
        log_info "Testing pip package info functionality..."
        local start_time
        start_time=$(date +%s.%N)
        
        if timeout 30 pip show pip >/dev/null 2>&1; then
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "pip show" "✅ OK" "${duration}s" "Package info works"
        else
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "pip show" "❌ FAIL" "${duration}s" "Package info failed"
        fi
    fi
}

# Test gem sources
test_gem_sources() {
    log_info "Testing gem sources..."
    
    local sources=(
        "https://rubygems.org/|Official RubyGems"
        "https://gems.ruby-china.com/|Ruby China Mirror"
        "https://rubygems.org/api/v1/gems/rails.json|RubyGems API"
    )
    
    for source_info in "${sources[@]}"; do
        IFS='|' read -r url name <<< "$source_info"
        test_url "$url" "$name (gem)" 15
    done
    
    # Test gem functionality if gem is available
    if command -v gem >/dev/null 2>&1; then
        log_info "Testing gem search functionality..."
        local start_time
        start_time=$(date +%s.%N)
        
        if timeout 30 gem search rails >/dev/null 2>&1; then
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "gem search" "✅ OK" "${duration}s" "Search functionality works"
        else
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "gem search" "❌ FAIL" "${duration}s" "Search functionality failed"
        fi
    fi
}

# Test cargo registries
test_cargo_registries() {
    log_info "Testing cargo registries..."
    
    local registries=(
        "https://crates.io/|Official Crates.io"
        "https://index.crates.io/|Crates.io Index"
        "https://github.com/rust-lang/crates.io-index|GitHub Index Repository"
    )
    
    for registry_info in "${registries[@]}"; do
        IFS='|' read -r url name <<< "$registry_info"
        test_url "$url" "$name (cargo)" 15
    done
    
    # Test cargo functionality if cargo is available
    if command -v cargo >/dev/null 2>&1; then
        log_info "Testing cargo search functionality..."
        local start_time
        start_time=$(date +%s.%N)
        
        if timeout 30 cargo search serde --limit 1 >/dev/null 2>&1; then
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "cargo search" "✅ OK" "${duration}s" "Search functionality works"
        else
            local end_time
            end_time=$(date +%s.%N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            add_result "cargo search" "❌ FAIL" "${duration}s" "Search functionality failed"
        fi
    fi
}

# Test network configuration
test_network_config() {
    log_info "Testing network configuration..."
    
    # Test DNS resolution
    local start_time
    start_time=$(date +%s.%N)
    
    if nslookup registry.npmjs.org >/dev/null 2>&1; then
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        add_result "DNS Resolution" "✅ OK" "${duration}s" "DNS working correctly"
    else
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        add_result "DNS Resolution" "❌ FAIL" "${duration}s" "DNS resolution issues"
    fi
    
    # Test basic internet connectivity
    start_time=$(date +%s.%N)
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        add_result "Internet Connectivity" "✅ OK" "${duration}s" "Internet accessible"
    else
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        add_result "Internet Connectivity" "❌ FAIL" "${duration}s" "No internet access"
    fi
    
    # Check for proxy settings
    if [[ -n "${http_proxy:-}" ]] || [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${https_proxy:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
        add_result "Proxy Configuration" "ℹ️ INFO" "0s" "Proxy settings detected"
    else
        add_result "Proxy Configuration" "ℹ️ INFO" "0s" "No proxy settings"
    fi
}

# Print test results
print_results() {
    log_info "Connectivity Test Results:"
    echo "================================================="
    printf "%-30s %-10s %-10s %s\n" "Registry/Service" "Status" "Time" "Message"
    echo "================================================="
    
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r registry status time message <<< "$result"
        printf "%-30s %-10s %-10s %s\n" "$registry" "$status" "$time" "$message"
    done
    
    echo "================================================="
    
    # Count results
    local ok_count=0
    local fail_count=0
    local info_count=0
    
    for result in "${TEST_RESULTS[@]}"; do
        case "$result" in
            *"✅ OK"*)
                ((ok_count++))
                ;;
            *"❌ FAIL"*)
                ((fail_count++))
                ;;
            *"ℹ️ INFO"*)
                ((info_count++))
                ;;
        esac
    done
    
    echo "Summary: $ok_count OK, $fail_count Failed, $info_count Info"
    
    if [[ $fail_count -gt 0 ]]; then
        log_warn "Some connectivity tests failed. Check network configuration."
        return 1
    else
        log_success "All connectivity tests passed!"
        return 0
    fi
}

# Main test function
main() {
    local test_type="${1:-all}"
    
    log_info "Starting package manager connectivity tests..."
    log_info "Test type: $test_type"
    
    case "$test_type" in
        all)
            test_network_config
            test_npm_registries
            test_pip_indexes
            test_gem_sources
            test_cargo_registries
            ;;
        npm)
            test_npm_registries
            ;;
        pip)
            test_pip_indexes
            ;;
        gem)
            test_gem_sources
            ;;
        cargo)
            test_cargo_registries
            ;;
        network)
            test_network_config
            ;;
        *)
            log_error "Unknown test type: $test_type"
            show_help
            exit 1
            ;;
    esac
    
    print_results
}

# Help function
show_help() {
    cat << EOF
Package Manager Connectivity Test Script

Usage: $0 [TEST_TYPE]

TEST_TYPES:
    all         Test all package managers and network (default)
    npm         Test only npm registries
    pip         Test only pip indexes
    gem         Test only gem sources
    cargo       Test only cargo registries
    network     Test only network configuration

DESCRIPTION:
    This script tests connectivity to package manager registries and measures
    response times. Use this to diagnose connectivity issues or compare
    mirror performance.

EXAMPLES:
    $0              # Test all package managers
    $0 npm          # Test only npm
    $0 network      # Test only network configuration
EOF
}

# Parse command line arguments
case "${1:-all}" in
    -h|--help)
        show_help
        exit 0
        ;;
    all|npm|pip|gem|cargo|network)
        main "$1"
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 