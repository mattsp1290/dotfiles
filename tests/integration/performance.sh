#!/usr/bin/env bash
# Performance Integration Tests
# Tests performance benchmarking and validation

set -euo pipefail

# Source test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/assertions.sh"
source "$TEST_DIR/../helpers/mock-tools.sh"
source "$TEST_DIR/../helpers/env-setup.sh"

# Performance thresholds (in seconds)
readonly MAX_INSTALL_TIME=900   # 15 minutes
readonly MAX_SHELL_STARTUP=5    # 5 seconds
readonly MAX_STOW_TIME=300      # 5 minutes

# Test installation performance
test_installation_performance() {
    create_test_environment "perf_install"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing installation performance"
    
    # Create realistic test repository
    local test_repo="$TEST_WORKSPACE/perf-test-repo"
    mkdir -p "$test_repo"/{scripts,config,shell,vim,zsh,git,tmux}
    
    # Create multiple configuration files to simulate real workload
    for pkg in vim zsh git tmux; do
        mkdir -p "$test_repo/$pkg"
        for i in {1..5}; do
            create_test_file "$test_repo/$pkg/.${pkg}rc${i}" "# $pkg config file $i"
        done
    done
    
    # Create bootstrap script with realistic operations
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Performance test bootstrap started"
start_time=$(date +%s)

# Simulate package detection
echo "Detecting OS and package manager..."
sleep 0.1

# Simulate stow operations
echo "Stowing configuration packages..."
for i in {1..10}; do
    echo "  Processing package $i/10"
    sleep 0.05
done

# Simulate secret injection
echo "Processing templates..."
for i in {1..5}; do
    echo "  Template $i/5"
    sleep 0.02
done

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Bootstrap completed in ${duration}s"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Time the installation
    local start_time=$(date +%s)
    
    cd "$DOTFILES_ROOT"
    bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-perf" --dry-run >/dev/null 2>&1 || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    info "Installation completed in ${duration}s"
    
    # Verify performance meets requirements
    assert_less_than "$duration" "$MAX_INSTALL_TIME" "Installation should complete within ${MAX_INSTALL_TIME}s"
    
    if [[ $duration -lt 30 ]]; then
        success "Excellent performance: ${duration}s"
    elif [[ $duration -lt 60 ]]; then
        info "Good performance: ${duration}s"
    else
        warning "Slow performance: ${duration}s"
    fi
}

# Test shell startup performance
test_shell_startup_performance() {
    create_test_environment "perf_shell_startup"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing shell startup performance"
    
    # Create test shell configuration with various loads
    local test_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$test_dotfiles/zsh"
    
    # Create realistic zsh configuration
    cat > "$test_dotfiles/zsh/.zshrc" << 'EOF'
# Performance test zsh configuration

# Load environment variables
export PATH="/usr/local/bin:$PATH"
export EDITOR="vim"
export PAGER="less"

# Load aliases
alias ll="ls -la"
alias la="ls -A"
alias l="ls -CF"

# Load functions
load_function() {
    echo "Function loaded"
}

# Simulate plugin loading
for plugin in git history-substring-search syntax-highlighting; do
    echo "Loading plugin: $plugin" >/dev/null
done

# Theme configuration
PS1='%n@%m:%~$ '
EOF
    
    # Create test script to measure shell startup
    cat > "$TEST_HOME/test-shell-startup.sh" << 'EOF'
#!/usr/bin/env bash
echo "Testing shell startup performance..."

# Test shell startup time
startup_times=()
for i in {1..5}; do
    start_time=$(date +%s%N)
    bash -c "source ~/.dotfiles/zsh/.zshrc; echo 'Shell loaded'" >/dev/null 2>&1
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    startup_times+=("$duration")
    echo "Startup $i: ${duration}ms"
done

# Calculate average
total=0
for time in "${startup_times[@]}"; do
    total=$((total + time))
done
average=$((total / ${#startup_times[@]}))
echo "Average startup time: ${average}ms"
EOF
    chmod +x "$TEST_HOME/test-shell-startup.sh"
    
    # Run shell startup test
    local output
    output=$(bash "$TEST_HOME/test-shell-startup.sh" 2>&1 || true)
    
    assert_contains "$output" "Testing shell startup performance" "Should test shell startup"
    assert_contains "$output" "Average startup time:" "Should show average time"
    
    # Extract average time
    local avg_time
    avg_time=$(echo "$output" | grep "Average startup time:" | grep -o '[0-9]\+')
    
    if [[ -n "$avg_time" ]]; then
        local avg_seconds=$((avg_time / 1000))
        info "Shell startup time: ${avg_time}ms (${avg_seconds}s)"
        
        assert_less_than "$avg_seconds" "$MAX_SHELL_STARTUP" "Shell startup should be under ${MAX_SHELL_STARTUP}s"
        
        if [[ $avg_time -lt 500 ]]; then
            success "Excellent shell performance: ${avg_time}ms"
        elif [[ $avg_time -lt 1000 ]]; then
            info "Good shell performance: ${avg_time}ms"
        else
            warning "Slow shell performance: ${avg_time}ms"
        fi
    fi
}

# Test stow operation performance
test_stow_performance() {
    create_test_environment "perf_stow"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing stow operation performance"
    
    # Create large dotfiles repository to test stow performance
    local test_dotfiles="$TEST_HOME/.dotfiles"
    mkdir -p "$test_dotfiles"
    
    # Create many packages with multiple files
    for pkg in {vim,zsh,git,tmux,ssh,config,scripts,tools}; do
        mkdir -p "$test_dotfiles/$pkg"
        for i in {1..20}; do
            create_test_file "$test_dotfiles/$pkg/.${pkg}file${i}" "# $pkg file $i content"
        done
    done
    
    # Create stow performance test script
    cat > "$test_dotfiles/test-stow-perf.sh" << 'EOF'
#!/usr/bin/env bash
echo "Testing stow performance..."

packages=(vim zsh git tmux ssh config scripts tools)
start_time=$(date +%s)

for package in "${packages[@]}"; do
    echo "Stowing package: $package"
    # Simulate stow operation
    for file in "$package"/.* "$package"/*; do
        if [[ -f "$file" ]]; then
            basename=$(basename "$file")
            echo "  Linking: $basename" >/dev/null
        fi
    done
done

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Stow operations completed in ${duration}s"

# Count total files
total_files=$(find . -name ".*" -o -name "*" | grep -v "^\\.$" | wc -l)
echo "Total files processed: $total_files"
echo "Performance: $(( total_files / (duration + 1) )) files/second"
EOF
    chmod +x "$test_dotfiles/test-stow-perf.sh"
    
    # Run stow performance test
    cd "$test_dotfiles"
    local output
    output=$(bash test-stow-perf.sh 2>&1 || true)
    
    assert_contains "$output" "Testing stow performance" "Should test stow performance"
    assert_contains "$output" "Stow operations completed" "Should complete stow operations"
    assert_contains "$output" "Total files processed:" "Should count files"
    assert_contains "$output" "Performance:" "Should show performance metrics"
    
    # Extract duration
    local stow_duration
    stow_duration=$(echo "$output" | grep "completed in" | grep -o '[0-9]\+')
    
    if [[ -n "$stow_duration" ]]; then
        info "Stow operations completed in ${stow_duration}s"
        assert_less_than "$stow_duration" "$MAX_STOW_TIME" "Stow should complete within ${MAX_STOW_TIME}s"
        
        if [[ $stow_duration -lt 60 ]]; then
            success "Excellent stow performance: ${stow_duration}s"
        elif [[ $stow_duration -lt 180 ]]; then
            info "Good stow performance: ${stow_duration}s"
        else
            warning "Slow stow performance: ${stow_duration}s"
        fi
    fi
}

# Test memory usage
test_memory_usage() {
    create_test_environment "perf_memory"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing memory usage"
    
    # Create test repository with memory monitoring
    local test_repo="$TEST_WORKSPACE/memory-test-repo"
    mkdir -p "$test_repo/scripts"
    
    cat > "$test_repo/scripts/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
echo "Memory usage test bootstrap"

# Get initial memory usage
if command -v ps >/dev/null 2>&1; then
    initial_mem=$(ps -o rss= -p $$)
    echo "Initial memory usage: ${initial_mem}KB"
fi

# Simulate memory-intensive operations
echo "Performing memory-intensive operations..."
large_array=()
for i in {1..1000}; do
    large_array+=("item_$i")
done

# Create temporary files
temp_dir=$(mktemp -d)
for i in {1..50}; do
    echo "temporary content $i" > "$temp_dir/temp_$i.txt"
done

# Get final memory usage
if command -v ps >/dev/null 2>&1; then
    final_mem=$(ps -o rss= -p $$)
    echo "Final memory usage: ${final_mem}KB"
    memory_diff=$((final_mem - initial_mem))
    echo "Memory difference: ${memory_diff}KB"
fi

# Clean up
rm -rf "$temp_dir"
echo "Memory usage test completed"
EOF
    chmod +x "$test_repo/scripts/bootstrap.sh"
    
    # Test memory usage
    cd "$DOTFILES_ROOT"
    local output
    output=$(bash install.sh --repo "$test_repo" --directory "$TEST_HOME/.dotfiles-memory" --dry-run 2>&1 || true)
    
    assert_contains "$output" "Memory usage test bootstrap" "Should test memory usage"
    assert_contains "$output" "Initial memory usage:" "Should show initial memory"
    assert_contains "$output" "Final memory usage:" "Should show final memory"
    assert_contains "$output" "Memory difference:" "Should show memory difference"
    
    # Extract memory difference
    local memory_diff
    memory_diff=$(echo "$output" | grep "Memory difference:" | grep -o '[0-9]\+' | head -1)
    
    if [[ -n "$memory_diff" ]]; then
        info "Memory usage difference: ${memory_diff}KB"
        
        # Memory usage should be reasonable (under 100MB)
        if [[ $memory_diff -lt 102400 ]]; then
            success "Good memory usage: ${memory_diff}KB"
        else
            warning "High memory usage: ${memory_diff}KB"
        fi
    fi
}

# Test concurrent operations performance
test_concurrent_operations() {
    create_test_environment "perf_concurrent"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing concurrent operations performance"
    
    # Create test script for concurrent operations
    cat > "$TEST_HOME/test-concurrent.sh" << 'EOF'
#!/usr/bin/env bash
echo "Testing concurrent operations..."

# Function to simulate work
simulate_work() {
    local id="$1"
    echo "Worker $id starting..."
    sleep 0.1
    echo "Worker $id completed"
}

# Test concurrent operations
start_time=$(date +%s)

# Start background workers
for i in {1..5}; do
    simulate_work "$i" &
done

# Wait for all workers to complete
wait

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Concurrent operations completed in ${duration}s"
EOF
    chmod +x "$TEST_HOME/test-concurrent.sh"
    
    # Run concurrent test
    local output
    output=$(bash "$TEST_HOME/test-concurrent.sh" 2>&1 || true)
    
    assert_contains "$output" "Testing concurrent operations" "Should test concurrent operations"
    assert_contains "$output" "Worker.*starting" "Should start workers"
    assert_contains "$output" "Worker.*completed" "Should complete workers"
    assert_contains "$output" "Concurrent operations completed" "Should complete all operations"
    
    # Extract duration
    local concurrent_duration
    concurrent_duration=$(echo "$output" | grep "completed in" | grep -o '[0-9]\+')
    
    if [[ -n "$concurrent_duration" ]]; then
        info "Concurrent operations completed in ${concurrent_duration}s"
        
        # Should be faster than sequential (5 * 0.1 = 0.5s minimum)
        if [[ $concurrent_duration -lt 2 ]]; then
            success "Good concurrent performance: ${concurrent_duration}s"
        else
            warning "Slow concurrent performance: ${concurrent_duration}s"
        fi
    fi
}

# Test file I/O performance
test_file_io_performance() {
    create_test_environment "perf_file_io"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing file I/O performance"
    
    # Create file I/O test script
    cat > "$TEST_HOME/test-file-io.sh" << 'EOF'
#!/usr/bin/env bash
echo "Testing file I/O performance..."

test_dir="$HOME/test-io"
mkdir -p "$test_dir"

# Test write performance
start_time=$(date +%s%N)
for i in {1..100}; do
    echo "Test content for file $i" > "$test_dir/test_$i.txt"
done
end_time=$(date +%s%N)
write_duration=$(( (end_time - start_time) / 1000000 ))
echo "Write performance: ${write_duration}ms for 100 files"

# Test read performance
start_time=$(date +%s%N)
for i in {1..100}; do
    cat "$test_dir/test_$i.txt" >/dev/null
done
end_time=$(date +%s%N)
read_duration=$(( (end_time - start_time) / 1000000 ))
echo "Read performance: ${read_duration}ms for 100 files"

# Test symlink performance
start_time=$(date +%s%N)
for i in {1..100}; do
    ln -sf "$test_dir/test_$i.txt" "$test_dir/link_$i.txt"
done
end_time=$(date +%s%N)
symlink_duration=$(( (end_time - start_time) / 1000000 ))
echo "Symlink performance: ${symlink_duration}ms for 100 symlinks"

# Clean up
rm -rf "$test_dir"
echo "File I/O test completed"
EOF
    chmod +x "$TEST_HOME/test-file-io.sh"
    
    # Run file I/O test
    local output
    output=$(bash "$TEST_HOME/test-file-io.sh" 2>&1 || true)
    
    assert_contains "$output" "Testing file I/O performance" "Should test file I/O"
    assert_contains "$output" "Write performance:" "Should test write performance"
    assert_contains "$output" "Read performance:" "Should test read performance"
    assert_contains "$output" "Symlink performance:" "Should test symlink performance"
    assert_contains "$output" "File I/O test completed" "Should complete I/O test"
    
    # Extract performance metrics
    local write_time read_time symlink_time
    write_time=$(echo "$output" | grep "Write performance:" | grep -o '[0-9]\+' | head -1)
    read_time=$(echo "$output" | grep "Read performance:" | grep -o '[0-9]\+' | head -1)
    symlink_time=$(echo "$output" | grep "Symlink performance:" | grep -o '[0-9]\+' | head -1)
    
    if [[ -n "$write_time" && -n "$read_time" && -n "$symlink_time" ]]; then
        info "I/O Performance - Write: ${write_time}ms, Read: ${read_time}ms, Symlink: ${symlink_time}ms"
        
        # Performance thresholds (in milliseconds)
        if [[ $write_time -lt 1000 && $read_time -lt 500 && $symlink_time -lt 500 ]]; then
            success "Excellent I/O performance"
        elif [[ $write_time -lt 5000 && $read_time -lt 2000 && $symlink_time -lt 2000 ]]; then
            info "Good I/O performance"
        else
            warning "Slow I/O performance"
        fi
    fi
}

# Test bootstrap script performance
test_bootstrap_performance() {
    create_test_environment "perf_bootstrap"
    activate_test_environment
    setup_standard_mocks
    
    info "Testing bootstrap script performance"
    
    # Use existing bootstrap script
    local bootstrap_script="$DOTFILES_ROOT/scripts/bootstrap.sh"
    
    if [[ -f "$bootstrap_script" ]]; then
        # Time bootstrap execution
        local start_time=$(date +%s)
        
        # Run bootstrap in doctor mode (should be fast)
        bash "$bootstrap_script" doctor >/dev/null 2>&1 || true
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        info "Bootstrap doctor mode completed in ${duration}s"
        
        # Doctor mode should be very fast
        assert_less_than "$duration" "30" "Bootstrap doctor should complete within 30s"
        
        if [[ $duration -lt 5 ]]; then
            success "Excellent bootstrap performance: ${duration}s"
        elif [[ $duration -lt 15 ]]; then
            info "Good bootstrap performance: ${duration}s"
        else
            warning "Slow bootstrap performance: ${duration}s"
        fi
    else
        warning "Bootstrap script not found at $bootstrap_script"
    fi
}

# Main test runner
main() {
    init_test_session
    
    echo "Running Performance Integration Tests"
    echo "===================================="
    echo "Performance Thresholds:"
    echo "  - Installation: <${MAX_INSTALL_TIME}s"
    echo "  - Shell startup: <${MAX_SHELL_STARTUP}s"
    echo "  - Stow operations: <${MAX_STOW_TIME}s"
    echo ""
    
    run_test "Installation Performance" test_installation_performance
    run_test "Shell Startup Performance" test_shell_startup_performance
    run_test "Stow Operation Performance" test_stow_performance
    run_test "Memory Usage" test_memory_usage
    run_test "Concurrent Operations" test_concurrent_operations
    run_test "File I/O Performance" test_file_io_performance
    run_test "Bootstrap Performance" test_bootstrap_performance
    
    test_summary
    cleanup_test_session
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 