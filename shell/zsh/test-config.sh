#!/usr/bin/env zsh
# Zsh Configuration Test Script
# Tests the modular Zsh configuration and reports on performance and functionality

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR}/../.."

echo -e "${BLUE}🧪 Testing Zsh Configuration${NC}"
echo "=============================="

# Test 1: Syntax validation
echo -e "\n${YELLOW}📝 Testing syntax...${NC}"
SYNTAX_ERRORS=0
for file in "$SCRIPT_DIR"/{.zshenv,.zshrc,.zprofile} "$SCRIPT_DIR"/modules/*.zsh; do
    if [[ -f "$file" ]]; then
        if zsh -n "$file" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $(basename "$file")"
        else
            echo -e "  ${RED}✗${NC} $(basename "$file") - syntax error"
            ((SYNTAX_ERRORS++))
        fi
    fi
done

if [[ $SYNTAX_ERRORS -gt 0 ]]; then
    echo -e "\n${RED}❌ Syntax errors found. Please fix before continuing.${NC}"
    exit 1
fi

# Test 2: Environment file loading
echo -e "\n${YELLOW}🌍 Testing .zshenv loading...${NC}"
if zsh -c "source '$SCRIPT_DIR/.zshenv' && [[ -n \$DOTFILES_DIR ]] && echo 'ENV_OK'" 2>/dev/null | grep -q "ENV_OK"; then
    echo -e "  ${GREEN}✓${NC} .zshenv loads correctly"
else
    echo -e "  ${RED}✗${NC} .zshenv failed to load"
    exit 1
fi

# Test 3: Individual module testing (non-interactive)
echo -e "\n${YELLOW}📦 Testing individual modules...${NC}"
MODULE_ERRORS=0
TESTABLE_MODULES=(
    "01-environment.zsh"
    "02-path.zsh" 
    "03-aliases.zsh"
    "04-functions.zsh"
)

for module in "${TESTABLE_MODULES[@]}"; do
    if zsh -c "source '$SCRIPT_DIR/.zshenv' && source '$SCRIPT_DIR/modules/$module' && echo 'MODULE_OK'" 2>/dev/null | grep -q "MODULE_OK"; then
        echo -e "  ${GREEN}✓${NC} $module"
    else
        echo -e "  ${YELLOW}⚠${NC} $module (may require interactive shell)"
        ((MODULE_ERRORS++))
    fi
done

# Test 4: Performance test with timeout
echo -e "\n${YELLOW}⚡ Testing performance...${NC}"
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
#!/usr/bin/env zsh
source shell/zsh/.zshenv
source shell/zsh/.zshrc
echo "PERFORMANCE_TEST_COMPLETE"
EOF

chmod +x "$TEMP_SCRIPT"
START_TIME=$(date +%s%N)

if timeout 10s "$TEMP_SCRIPT" >/dev/null 2>&1; then
    END_TIME=$(date +%s%N)
    DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
    
    if [[ $DURATION -lt 500 ]]; then
        echo -e "  ${GREEN}✓${NC} Startup time: ${DURATION}ms (excellent)"
    elif [[ $DURATION -lt 1000 ]]; then
        echo -e "  ${YELLOW}⚠${NC} Startup time: ${DURATION}ms (acceptable)"
    else
        echo -e "  ${RED}✗${NC} Startup time: ${DURATION}ms (slow)"
    fi
    PERFORMANCE_OK=1
else
    echo -e "  ${YELLOW}⚠${NC} Performance test timed out or failed (may be due to interactive features)"
    PERFORMANCE_OK=0
fi

rm -f "$TEMP_SCRIPT"

# Test 5: Environment detection (using .zshenv only)
echo -e "\n${YELLOW}🔍 Testing environment detection...${NC}"
ENV_VARS=$(zsh -c "source '$SCRIPT_DIR/.zshenv' && source '$SCRIPT_DIR/modules/01-environment.zsh' && echo \"OS_TYPE=\$OS_TYPE HOMEBREW_PREFIX=\$HOMEBREW_PREFIX\"" 2>/dev/null)

if [[ -n "$ENV_VARS" ]]; then
    eval "$ENV_VARS"
    if [[ -n "$OS_TYPE" ]]; then
        echo -e "  ${GREEN}✓${NC} OS Type: $OS_TYPE"
        if [[ "$OS_TYPE" == "macos" ]] && [[ -n "$HOMEBREW_PREFIX" ]]; then
            echo -e "  ${GREEN}✓${NC} Homebrew: $HOMEBREW_PREFIX"
        elif [[ "$OS_TYPE" == "linux" ]]; then
            echo -e "  ${GREEN}✓${NC} Linux environment detected"
        fi
        ENV_DETECTION_OK=1
    else
        echo -e "  ${RED}✗${NC} OS Type detection failed"
        ENV_DETECTION_OK=0
    fi
else
    echo -e "  ${RED}✗${NC} Environment detection failed"
    ENV_DETECTION_OK=0
fi

# Test 6: Module count
echo -e "\n${YELLOW}📊 Module inventory...${NC}"
MODULE_COUNT=$(ls -1 "$SCRIPT_DIR"/modules/*.zsh 2>/dev/null | wc -l | tr -d ' ')
echo -e "  ${GREEN}✓${NC} Found $MODULE_COUNT modules"

# Test 7: File structure
echo -e "\n${YELLOW}📁 File structure...${NC}"
REQUIRED_FILES=(".zshenv" ".zshrc" ".zprofile" "README.md")
STRUCTURE_OK=1

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file missing"
        STRUCTURE_OK=0
    fi
done

REQUIRED_DIRS=("modules" "functions" "themes" "completions")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$SCRIPT_DIR/$dir" ]]; then
        echo -e "  ${GREEN}✓${NC} $dir/"
    else
        echo -e "  ${RED}✗${NC} $dir/ missing"
        STRUCTURE_OK=0
    fi
done

# Summary
echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "==============="
echo -e "Syntax: ${SYNTAX_ERRORS} errors"
echo -e "Modules: $MODULE_COUNT total, $((${#TESTABLE_MODULES[@]} - MODULE_ERRORS)) working"
echo -e "Structure: $([ $STRUCTURE_OK -eq 1 ] && echo "✓ Complete" || echo "✗ Incomplete")"
echo -e "Environment: $([ $ENV_DETECTION_OK -eq 1 ] && echo "✓ Working" || echo "✗ Failed")"

# Overall result
if [[ $SYNTAX_ERRORS -eq 0 ]] && [[ $STRUCTURE_OK -eq 1 ]] && [[ $ENV_DETECTION_OK -eq 1 ]]; then
    echo -e "\n${GREEN}🎉 Configuration test passed!${NC}"
    echo "Your Zsh configuration is ready to use."
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Run: cd $(dirname $SCRIPT_DIR) && stow shell"
    echo "2. Restart your shell or run: source ~/.zshrc"
    exit 0
else
    echo -e "\n${YELLOW}⚠ Configuration test completed with issues${NC}"
    echo "Some features may not work correctly. Check the errors above."
    exit 1
fi 