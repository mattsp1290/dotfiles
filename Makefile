# Dotfiles Makefile
# Common operations for managing dotfiles

.PHONY: help install uninstall test clean update check validate

# Default target
help:
	@echo "Dotfiles Management Commands:"
	@echo "  make install    - Install all dotfiles via Stow"
	@echo "  make uninstall  - Remove all symlinks"
	@echo "  make test       - Run all tests"
	@echo "  make clean      - Clean generated files"
	@echo "  make update     - Update repository and submodules"
	@echo "  make check      - Check for common issues"
	@echo "  make validate   - Validate structure and configurations"

# Install dotfiles
install:
	@echo "Installing dotfiles..."
	@./scripts/bootstrap.sh

# Uninstall dotfiles
uninstall:
	@echo "Removing dotfiles symlinks..."
	@stow -D -t ~ config home shell 2>/dev/null || true
	@echo "Symlinks removed. Original files preserved."

# Run tests
test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	@for test in tests/unit/*.sh; do \
		[ -f "$$test" ] && bash "$$test" || true; \
	done

test-integration:
	@echo "Running integration tests..."
	@for test in tests/integration/*.sh; do \
		[ -f "$$test" ] && bash "$$test" || true; \
	done

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@find . -name "*.zwc" -delete
	@find . -name ".zcompdump*" -delete
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete."

# Update repository
update:
	@echo "Updating repository..."
	@git pull --rebase
	@git submodule update --init --recursive

# Check for common issues
check:
	@echo "Checking for common issues..."
	@echo -n "Checking for secrets... "
	@! grep -r "password\|api_key\|secret" --exclude-dir=.git --exclude-dir=docs --exclude="*.md" . 2>/dev/null || echo "WARNING: Possible secrets found!"
	@echo "OK"
	@echo -n "Checking for broken symlinks... "
	@find ~ -maxdepth 2 -type l -xtype l 2>/dev/null | grep -q . && echo "WARNING: Broken symlinks found!" || echo "OK"
	@echo -n "Checking Stow conflicts... "
	@stow -n -v -R -t ~ config 2>&1 | grep -q "conflict" && echo "WARNING: Stow conflicts detected!" || echo "OK"

# Validate structure
validate:
	@echo "Validating repository structure..."
	@[ -d "config" ] && echo "✓ config/ directory exists" || echo "✗ config/ directory missing"
	@[ -d "home" ] && echo "✓ home/ directory exists" || echo "✗ home/ directory missing"
	@[ -d "shell" ] && echo "✓ shell/ directory exists" || echo "✗ shell/ directory missing"
	@[ -d "scripts" ] && echo "✓ scripts/ directory exists" || echo "✗ scripts/ directory missing"
	@[ -f "scripts/bootstrap.sh" ] && echo "✓ bootstrap.sh exists" || echo "✗ bootstrap.sh missing"
	@[ -f ".gitignore" ] && echo "✓ .gitignore exists" || echo "✗ .gitignore missing"
	@[ -f ".stow-local-ignore" ] && echo "✓ .stow-local-ignore exists" || echo "✗ .stow-local-ignore missing"
	@echo "Validation complete."

# Install specific package
install-%:
	@echo "Installing $*..."
	@stow -v -R -t ~ $*

# Uninstall specific package
uninstall-%:
	@echo "Uninstalling $*..."
	@stow -D -t ~ $* 