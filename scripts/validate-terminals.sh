#!/bin/bash
# Terminal Configuration Validation Script - DEV-004
# Validates terminal emulator configurations and reports issues

set -e

# Script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}=== $1 ===${NC}"; }

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Record test result
record_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TOTAL_TESTS++))
    
    case "$result" in
        "pass")
            ((PASSED_TESTS++))
            log_success "$test_name: $message"
            ;;
        "fail")
            ((FAILED_TESTS++))
            log_error "$test_name: $message"
            ;;
        "warning")
            ((WARNINGS++))
            log_warning "$test_name: $message"
            ;;
    esac
}

# Test color display capability
test_color_display() {
    log_header "Color Display Test"
    
    echo "Testing 256-color support:"
    for i in {0..255}; do
        printf "\033[48;5;%sm%3d\033[0m" "$i" "$i"
        if (( (i + 1) % 16 == 0 )); then
            echo
        fi
    done
    echo
    
    echo -e "\nTesting Catppuccin Mocha colors:"
    echo -e "\033[38;2;205;214;244mText Color (Catppuccin Text)\033[0m"
    echo -e "\033[38;2;245;224;220mCursor Color (Catppuccin Rosewater)\033[0m"
    echo -e "\033[38;2;166;227;161mGreen (Catppuccin Green)\033[0m"
    echo -e "\033[38;2;137;180;250mBlue (Catppuccin Blue)\033[0m"
    echo -e "\033[38;2;243;139;168mRed (Catppuccin Red)\033[0m"
    echo -e "\033[38;2;249;226;175mYellow (Catppuccin Yellow)\033[0m"
    
    record_test "Color Display" "pass" "Colors displayed above"
}

# Test font rendering and ligatures
test_font_rendering() {
    log_header "Font Rendering Test"
    
    echo "Testing programming ligatures (requires programming font):"
    echo "Arrow functions: => -> <-"
    echo "Comparisons: == === != !== >= <="
    echo "Logic: && || !!"
    echo "Misc: /* */ // ## ++ -- **"
    echo "Unicode: ▶ ◀ ▲ ▼ ★ ♠ ♣ ♥ ♦"
    
    # Check if fonts are available
    local fonts_available=0
    local test_fonts=("JetBrains Mono" "Fira Code" "SF Mono" "Menlo")
    
    for font in "${test_fonts[@]}"; do
        if fc-list 2>/dev/null | grep -i "$font" &> /dev/null || \
           system_profiler SPFontsDataType 2>/dev/null | grep -i "$font" &> /dev/null; then
            record_test "Font Available" "pass" "$font is installed"
            ((fonts_available++))
        fi
    done
    
    if [[ $fonts_available -eq 0 ]]; then
        record_test "Font Check" "fail" "No programming fonts found"
    else
        record_test "Font Check" "pass" "$fonts_available programming fonts available"
    fi
}

# Test Unicode support
test_unicode_support() {
    log_header "Unicode Support Test"
    
    echo "Testing Unicode ranges:"
    echo "Basic Latin: ABCabc123"
    echo "Latin Extended: àáâãäåæçèéê"
    echo "Mathematical: ∑∏∫√∞≈≠≤≥"
    echo "Greek: αβγδεζηθικλμνξοπρστυφχψω"
    echo "Arrows: ← → ↑ ↓ ↔ ↕ ⇐ ⇒ ⇑ ⇓"
    echo "Box Drawing: ─│┌┐└┘├┤┬┴┼"
    echo "Block Elements: ▀▄█▌▐░▒▓"
    echo "Powerline Symbols: "
    
    record_test "Unicode Display" "pass" "Unicode characters displayed above"
}

# Validate Alacritty configuration
validate_alacritty() {
    log_header "Alacritty Configuration Validation"
    
    local config_file="$HOME/.config/alacritty/alacritty.yml"
    
    if [[ ! -f "$config_file" ]]; then
        record_test "Alacritty Config" "fail" "Configuration file not found: $config_file"
        return
    fi
    
    # Check if alacritty is installed
    if ! command -v alacritty &> /dev/null; then
        record_test "Alacritty Binary" "warning" "Alacritty not installed"
        return
    fi
    
    # Test configuration syntax
    if alacritty --print-events < /dev/null &> /dev/null; then
        record_test "Alacritty Syntax" "pass" "Configuration syntax is valid"
    else
        record_test "Alacritty Syntax" "fail" "Configuration has syntax errors"
    fi
    
    # Check for key configuration elements
    if grep -q "JetBrains Mono" "$config_file"; then
        record_test "Alacritty Font" "pass" "JetBrains Mono font configured"
    else
        record_test "Alacritty Font" "warning" "JetBrains Mono not found in config"
    fi
    
    if grep -q "#1e1e2e" "$config_file"; then
        record_test "Alacritty Theme" "pass" "Catppuccin theme colors found"
    else
        record_test "Alacritty Theme" "fail" "Catppuccin colors not found"
    fi
}

# Validate Kitty configuration
validate_kitty() {
    log_header "Kitty Configuration Validation"
    
    local config_file="$HOME/.config/kitty/kitty.conf"
    
    if [[ ! -f "$config_file" ]]; then
        record_test "Kitty Config" "fail" "Configuration file not found: $config_file"
        return
    fi
    
    # Check if kitty is installed
    if ! command -v kitty &> /dev/null; then
        record_test "Kitty Binary" "warning" "Kitty not installed"
        return
    fi
    
    # Test configuration syntax
    if timeout 5 kitty --config "$config_file" --check-config &> /dev/null; then
        record_test "Kitty Syntax" "pass" "Configuration syntax is valid"
    else
        record_test "Kitty Syntax" "fail" "Configuration has syntax errors"
    fi
    
    # Check for key configuration elements
    if grep -q "JetBrains Mono" "$config_file"; then
        record_test "Kitty Font" "pass" "JetBrains Mono font configured"
    else
        record_test "Kitty Font" "warning" "JetBrains Mono not found in config"
    fi
    
    if grep -q "#1E1E2E" "$config_file"; then
        record_test "Kitty Theme" "pass" "Catppuccin theme colors found"
    else
        record_test "Kitty Theme" "fail" "Catppuccin colors not found"
    fi
}

# Validate iTerm2 configuration (macOS only)
validate_iterm2() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        return
    fi
    
    log_header "iTerm2 Configuration Validation"
    
    if [[ ! -d "/Applications/iTerm.app" ]]; then
        record_test "iTerm2 Binary" "warning" "iTerm2 not installed"
        return
    fi
    
    local plist_file="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    
    if [[ -f "$plist_file" ]]; then
        record_test "iTerm2 Config" "pass" "Preferences file exists"
        
        # Check for custom profiles
        if plutil -p "$plist_file" 2>/dev/null | grep -q "Window Settings"; then
            record_test "iTerm2 Profiles" "pass" "Custom profiles found"
        else
            record_test "iTerm2 Profiles" "warning" "No custom profiles found"
        fi
    else
        record_test "iTerm2 Config" "warning" "Preferences file not found"
    fi
}

# Validate Terminal.app configuration (macOS only)
validate_terminal_app() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        return
    fi
    
    log_header "Terminal.app Configuration Validation"
    
    local plist_file="$HOME/Library/Preferences/com.apple.Terminal.plist"
    
    if [[ -f "$plist_file" ]]; then
        record_test "Terminal.app Config" "pass" "Preferences file exists"
        
        # Check for Catppuccin profile
        if plutil -p "$plist_file" 2>/dev/null | grep -q "Catppuccin"; then
            record_test "Terminal.app Profile" "pass" "Catppuccin profile found"
        else
            record_test "Terminal.app Profile" "warning" "Catppuccin profile not found"
        fi
    else
        record_test "Terminal.app Config" "warning" "Preferences file not found"
    fi
}

# Test terminal environment variables
test_environment() {
    log_header "Terminal Environment Validation"
    
    # Check TERM variable
    if [[ -n "$TERM" ]]; then
        record_test "TERM Variable" "pass" "TERM=$TERM"
    else
        record_test "TERM Variable" "fail" "TERM variable not set"
    fi
    
    # Check COLORTERM variable
    if [[ "$COLORTERM" == "truecolor" ]]; then
        record_test "COLORTERM" "pass" "True color support enabled"
    else
        record_test "COLORTERM" "warning" "COLORTERM=$COLORTERM (not truecolor)"
    fi
    
    # Check terminal capabilities
    if tput colors &> /dev/null; then
        local colors=$(tput colors)
        if [[ $colors -ge 256 ]]; then
            record_test "Color Support" "pass" "$colors colors supported"
        else
            record_test "Color Support" "warning" "Only $colors colors supported"
        fi
    else
        record_test "Color Support" "fail" "Cannot determine color support"
    fi
}

# Test shell integration
test_shell_integration() {
    log_header "Shell Integration Test"
    
    # Check shell type
    if [[ -n "$ZSH_VERSION" ]]; then
        record_test "Shell Type" "pass" "Zsh detected: $ZSH_VERSION"
    elif [[ -n "$BASH_VERSION" ]]; then
        record_test "Shell Type" "pass" "Bash detected: $BASH_VERSION"
    else
        record_test "Shell Type" "warning" "Unknown shell: $SHELL"
    fi
    
    # Check prompt configuration
    if [[ -n "$PS1" ]]; then
        record_test "Prompt" "pass" "Prompt is configured"
    else
        record_test "Prompt" "warning" "No prompt configuration detected"
    fi
    
    # Check for tmux integration
    if [[ -n "$TMUX" ]]; then
        record_test "Tmux" "pass" "Running inside tmux"
    else
        record_test "Tmux" "pass" "Not running in tmux (normal)"
    fi
}

# Performance test
test_performance() {
    log_header "Performance Test"
    
    # Test terminal startup time
    if command -v alacritty &> /dev/null; then
        local start_time=$(date +%s.%N)
        timeout 10 alacritty -e true &> /dev/null || true
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        if (( $(echo "$duration < 2.0" | bc -l 2>/dev/null || echo 0) )); then
            record_test "Alacritty Startup" "pass" "Fast startup ($duration seconds)"
        else
            record_test "Alacritty Startup" "warning" "Slow startup ($duration seconds)"
        fi
    fi
    
    # Test rendering performance
    echo "Rendering performance test:"
    time (for i in {1..100}; do echo "Line $i with some text and colors: \033[31mRed\033[32mGreen\033[34mBlue\033[0m"; done) 2>&1 | head -1
}

# Generate test report
generate_report() {
    log_header "Validation Report"
    
    echo "Test Results Summary:"
    echo "  Total Tests: $TOTAL_TESTS"
    echo "  Passed: $PASSED_TESTS"
    echo "  Failed: $FAILED_TESTS"
    echo "  Warnings: $WARNINGS"
    echo
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    echo "Success Rate: $success_rate%"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All tests passed! ✅"
    else
        log_warning "$FAILED_TESTS tests failed. See details above."
    fi
    
    if [[ $WARNINGS -gt 0 ]]; then
        log_info "$WARNINGS warnings found. These may not be critical."
    fi
    
    echo
    echo "Next steps:"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo "  • Review failed tests and fix configurations"
        echo "  • Run: $DOTFILES_DIR/scripts/setup-terminals.sh"
    fi
    if [[ $WARNINGS -gt 0 ]]; then
        echo "  • Consider addressing warnings for optimal experience"
        echo "  • Install missing fonts: $DOTFILES_DIR/scripts/setup-terminals.sh --install-fonts"
    fi
    echo "  • Test terminal emulators manually to verify appearance"
}

# Print usage information
usage() {
    cat << EOF
Terminal Validation Script - DEV-004

Validates terminal emulator configurations and reports issues.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -q, --quiet             Suppress output (only show summary)
    -c, --colors            Test color display
    -f, --fonts             Test font rendering
    -p, --performance       Run performance tests
    --terminal NAME         Test specific terminal only

EXAMPLES:
    $0                      Run all validation tests
    $0 --colors             Test color display only
    $0 --terminal alacritty Test Alacritty configuration only

EOF
}

# Main execution
main() {
    local run_colors=true
    local run_fonts=true
    local run_performance=true
    local quiet=false
    local specific_terminal=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -q|--quiet)
                quiet=true
                ;;
            -c|--colors)
                run_colors=true
                run_fonts=false
                run_performance=false
                ;;
            -f|--fonts)
                run_fonts=true
                run_colors=false
                run_performance=false
                ;;
            -p|--performance)
                run_performance=true
                run_colors=false
                run_fonts=false
                ;;
            --terminal)
                specific_terminal="$2"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
    
    echo "Terminal Configuration Validation"
    echo "================================="
    echo
    
    # Run tests based on options
    if [[ "$run_colors" == "true" ]]; then
        test_color_display
        test_unicode_support
    fi
    
    if [[ "$run_fonts" == "true" ]]; then
        test_font_rendering
    fi
    
    # Always run these core validations
    test_environment
    test_shell_integration
    
    # Validate specific terminal or all terminals
    if [[ -n "$specific_terminal" ]]; then
        case "$specific_terminal" in
            "alacritty") validate_alacritty ;;
            "kitty") validate_kitty ;;
            "iterm2") validate_iterm2 ;;
            "terminal_app") validate_terminal_app ;;
            *) log_error "Unknown terminal: $specific_terminal" ;;
        esac
    else
        validate_alacritty
        validate_kitty
        validate_iterm2
        validate_terminal_app
    fi
    
    if [[ "$run_performance" == "true" ]]; then
        test_performance
    fi
    
    # Generate final report
    generate_report
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 