#!/usr/bin/env bash
# Shell Startup Performance Benchmarking Script
# Helps identify performance bottlenecks in zsh configuration

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
BENCHMARK_RUNS=5
readonly TARGET_TIME_MS=500
readonly FRAMEWORK_TARGET_MS=200

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Convert seconds to milliseconds
seconds_to_ms() {
    local seconds="$1"
    echo "$(echo "$seconds * 1000" | bc -l | cut -d. -f1)"
}

# Run multiple benchmarks and calculate average
benchmark_shell_startup() {
    local total_time=0
    local runs=()
    
    log_info "Running $BENCHMARK_RUNS shell startup benchmarks..."
    
    for i in $(seq 1 $BENCHMARK_RUNS); do
        log_info "Run $i/$BENCHMARK_RUNS..."
        local start_time=$(date +%s.%N)
        zsh -i -c exit 2>/dev/null
        local end_time=$(date +%s.%N)
        local run_time=$(echo "$end_time - $start_time" | bc -l)
        local run_time_ms=$(seconds_to_ms "$run_time")
        
        runs+=("$run_time_ms")
        total_time=$(echo "$total_time + $run_time" | bc -l)
        
        echo "  Run $i: ${run_time_ms}ms"
    done
    
    local avg_time=$(echo "$total_time / $BENCHMARK_RUNS" | bc -l)
    local avg_time_ms=$(seconds_to_ms "$avg_time")
    
    echo ""
    log_info "Benchmark Results:"
    echo "  Average startup time: ${avg_time_ms}ms"
    echo "  Individual runs: ${runs[*]}"
    
    # Performance assessment
    if [[ $avg_time_ms -le $TARGET_TIME_MS ]]; then
        log_success "Performance: EXCELLENT (≤${TARGET_TIME_MS}ms)"
    elif [[ $avg_time_ms -le $((TARGET_TIME_MS * 2)) ]]; then
        log_warning "Performance: NEEDS IMPROVEMENT (≤${TARGET_TIME_MS}ms target)"
    else
        log_error "Performance: POOR (${avg_time_ms}ms >> ${TARGET_TIME_MS}ms target)"
    fi
    
    echo "$avg_time_ms"
}

# Profile zsh startup with zprof
profile_startup() {
    log_info "Profiling zsh startup with zprof..."
    
    # Create temporary profiling script
    local profile_script="/tmp/zsh_profile_$$"
    cat > "$profile_script" << 'EOF'
zmodload zsh/zprof
source ~/.zshrc
zprof
EOF
    
    echo "Top 10 slowest operations:"
    zsh -c "source $profile_script" 2>/dev/null | head -20
    
    rm -f "$profile_script"
}

# Analyze module loading times
benchmark_modules() {
    log_info "Benchmarking individual modules..."
    
    local modules_dir="$DOTFILES_DIR/shell/zsh/modules"
    if [[ ! -d "$modules_dir" ]]; then
        log_error "Modules directory not found: $modules_dir"
        return 1
    fi
    
    echo ""
    echo "Module loading times:"
    
    for module in "$modules_dir"/*.zsh; do
        if [[ -r "$module" ]]; then
            local module_name=$(basename "$module")
            local start_time=$(date +%s.%N)
            zsh -c "source '$module'" 2>/dev/null || true
            local end_time=$(date +%s.%N)
            local load_time=$(echo "$end_time - $start_time" | bc -l)
            local load_time_ms=$(seconds_to_ms "$load_time")
            
            if [[ $load_time_ms -gt 50 ]]; then
                log_warning "  $module_name: ${load_time_ms}ms (slow)"
            else
                echo "  $module_name: ${load_time_ms}ms"
            fi
        fi
    done
}

# Test framework alternatives
compare_frameworks() {
    log_info "Comparing framework alternatives (dry run simulation)..."
    
    echo ""
    echo "Framework startup time estimates:"
    echo "  Oh My Zsh (current): ~2000-5000ms"
    echo "  zinit: ~100-300ms"
    echo "  prezto: ~300-800ms"
    echo "  zsh4humans: ~50-200ms"
    echo "  Minimal (no framework): ~50-150ms"
    echo ""
    echo "Note: These are typical ranges. Actual performance depends on plugins and configuration."
}

# Analyze current Oh My Zsh setup
analyze_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_warning "Oh My Zsh not found"
        return 0
    fi
    
    log_info "Analyzing Oh My Zsh configuration..."
    
    # Check plugins
    local zshrc_file="$HOME/.zshrc"
    local dotfiles_zshrc="$DOTFILES_DIR/shell/.zshrc"
    local prompt_module="$DOTFILES_DIR/shell/zsh/modules/06-prompt.zsh"
    
    echo ""
    echo "Current Oh My Zsh setup:"
    
    if [[ -f "$prompt_module" ]]; then
        local plugins=$(grep -E "^[[:space:]]*plugins=" "$prompt_module" 2>/dev/null | head -1)
        echo "  Plugins: ${plugins:-"Not found in prompt module"}"
        
        local theme=$(grep -E "^[[:space:]]*ZSH_THEME=" "$prompt_module" 2>/dev/null | head -1)
        echo "  Theme: ${theme:-"Not found"}"
    fi
    
    # Check custom directory
    if [[ -d "$HOME/.oh-my-zsh/custom" ]]; then
        local custom_plugins=$(find "$HOME/.oh-my-zsh/custom/plugins" -maxdepth 1 -type d 2>/dev/null | wc -l)
        local custom_themes=$(find "$HOME/.oh-my-zsh/custom/themes" -maxdepth 1 -type f -name "*.zsh-theme" 2>/dev/null | wc -l)
        echo "  Custom plugins: $((custom_plugins - 1))"
        echo "  Custom themes: $custom_themes"
    fi
    
    # Check for common performance issues
    echo ""
    echo "Performance analysis:"
    
    if grep -q "SPACESHIP_PROMPT_ASYNC=false" "$prompt_module" 2>/dev/null; then
        log_warning "  Spaceship async disabled (impacts performance)"
    fi
    
    local plugin_count=$(grep -E "^[[:space:]]*plugins=" "$prompt_module" 2>/dev/null | grep -o '(' | wc -l)
    if [[ $plugin_count -gt 0 ]]; then
        local plugins_line=$(grep -E "^[[:space:]]*plugins=" "$prompt_module" 2>/dev/null)
        local plugin_list=$(echo "$plugins_line" | sed 's/.*(\(.*\)).*/\1/')
        local num_plugins=$(echo "$plugin_list" | tr ' ' '\n' | wc -l)
        
        if [[ $num_plugins -gt 10 ]]; then
            log_warning "  Many plugins loaded: $num_plugins (consider reducing)"
        else
            echo "  Plugin count: $num_plugins (reasonable)"
        fi
    fi
}

# Generate optimization recommendations
generate_recommendations() {
    log_info "Performance optimization recommendations:"
    
    echo ""
    echo "Immediate improvements:"
    echo "  1. Enable Spaceship async mode (SPACESHIP_PROMPT_ASYNC=true)"
    echo "  2. Implement lazy loading for heavy plugins"
    echo "  3. Reduce number of Oh My Zsh plugins"
    echo "  4. Use conditional loading based on available tools"
    echo ""
    echo "Framework alternatives to consider:"
    echo "  1. zinit - Fastest, advanced features, steeper learning curve"
    echo "  2. prezto - Good balance of features and performance"
    echo "  3. zsh4humans - Modern, opinionated, excellent performance"
    echo "  4. Minimal setup - Custom plugin management without framework"
    echo ""
    echo "Next steps:"
    echo "  1. Implement lazy loading in current setup"
    echo "  2. Test framework alternatives"
    echo "  3. Migrate to best-performing option"
}

# Main function
main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Zsh Performance Benchmark       ║${NC}"
    echo -e "${BLUE}║              Framework Analysis        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check dependencies
    if ! command -v bc >/dev/null 2>&1; then
        log_error "bc (calculator) is required but not installed"
        exit 1
    fi
    
    # Run analysis
    local avg_time_ms
    avg_time_ms=$(benchmark_shell_startup)
    
    echo ""
    profile_startup
    
    echo ""
    benchmark_modules
    
    echo ""
    analyze_oh_my_zsh
    
    echo ""
    compare_frameworks
    
    echo ""
    generate_recommendations
    
    echo ""
    log_info "Benchmark complete. Current average startup: ${avg_time_ms}ms"
    
    # Return exit code based on performance
    if [[ $avg_time_ms -le $TARGET_TIME_MS ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle command line arguments
case "${1:-benchmark}" in
    "benchmark"|"")
        main
        ;;
    "quick")
        log_info "Quick benchmark (1 run)..."
        BENCHMARK_RUNS=1
        avg_time_ms=$(benchmark_shell_startup)
        log_info "Quick result: ${avg_time_ms}ms"
        ;;
    "profile")
        profile_startup
        ;;
    "modules")
        benchmark_modules
        ;;
    "compare")
        compare_frameworks
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  benchmark  - Full benchmark and analysis (default)"
        echo "  quick      - Quick single-run benchmark"
        echo "  profile    - Profile with zprof only"
        echo "  modules    - Benchmark individual modules"
        echo "  compare    - Compare framework alternatives"
        echo "  help       - Show this help"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac 