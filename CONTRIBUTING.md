# Contributing to Cross-Platform Dotfiles

We're thrilled that you're interested in contributing to this enterprise-grade dotfiles management system! This project thrives on collaboration and shared expertise from developers around the world.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [Contribution Workflow](#contribution-workflow)
- [Contribution Types](#contribution-types)
- [Development Guidelines](#development-guidelines)
- [Testing Requirements](#testing-requirements)
- [Security Guidelines](#security-guidelines)
- [Documentation Standards](#documentation-standards)
- [Review Process](#review-process)
- [Recognition](#recognition)
- [Support](#support)

---

## Code of Conduct

### Our Pledge

We pledge to make participation in our project and community a harassment-free experience for everyone, regardless of:
- Age, body size, disability, ethnicity, gender identity and expression
- Level of experience, nationality, personal appearance, race, religion
- Sexual identity and orientation, or any other characteristic

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**
- Harassment, trolling, insulting comments, or personal attacks
- Public or private harassment of any kind
- Publishing others' private information without permission
- Any conduct that could reasonably be considered inappropriate

### Enforcement

Report any Code of Conduct violations to the project maintainers. All complaints will be reviewed and investigated promptly and fairly.

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Git** 2.20+ with proper configuration
- **Development tools** for your platform (Xcode CLI tools on macOS, build-essential on Linux)
- **Shell environment** (bash 3.2+, zsh 5.0+, or fish 3.0+)
- **Text editor** with syntax highlighting for Shell, YAML, and Markdown
- **1Password CLI** (for secret management testing)

### Understanding the Architecture

This dotfiles system uses:
- **Modular Design**: Component-based architecture with clear separation of concerns
- **GNU Stow**: For elegant symlink management
- **Template System**: Jinja2-based configuration templating with secret injection
- **Cross-Platform Support**: Intelligent OS detection and platform-specific optimizations
- **Security-First**: Comprehensive secret scanning and validation
- **Enterprise Standards**: Professional-grade testing, CI/CD, and documentation

Review the [Architecture Decision Records](docs/adr/) to understand key design decisions.

---

## Development Environment Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/yourusername/dotfiles.git
cd dotfiles

# Add upstream remote for staying synchronized
git remote add upstream https://github.com/originalowner/dotfiles.git

# Verify remotes
git remote -v
```

### 2. Install Development Dependencies

```bash
# Install development tooling
make dev-setup

# This installs:
# - ShellCheck for shell script linting
# - markdownlint for documentation consistency
# - BATS for shell script testing
# - pre-commit hooks for quality assurance
```

### 3. Set Up Pre-commit Hooks

```bash
# Install pre-commit hooks (automatically runs linting and security checks)
pre-commit install

# Test the hooks
pre-commit run --all-files
```

### 4. Create Development Configuration

```bash
# Create a local development configuration
cp config/personal.yml.example config/personal.dev.yml
$EDITOR config/personal.dev.yml  # Customize for your development setup
```

### 5. Run Initial Tests

```bash
# Run the full test suite
make test

# Run specific test categories
make test-unit          # Unit tests for shell functions
make test-integration   # End-to-end installation tests
make test-security      # Security validation tests
make test-performance   # Performance benchmark tests

# Run security scan
make security-scan
```

---

## Contribution Workflow

### 1. Plan Your Contribution

Before starting work:
- **Check existing issues** to avoid duplication
- **Create an issue** for significant changes to discuss the approach
- **Comment on issues** you'd like to work on to coordinate efforts

### 2. Create a Feature Branch

```bash
# Ensure you're on main and up-to-date
git checkout main
git pull upstream main

# Create a feature branch with descriptive name
git checkout -b feature/add-terraform-configuration
# or
git checkout -b fix/shell-startup-performance
# or
git checkout -b docs/improve-installation-guide
```

### 3. Make Your Changes

- **Follow existing patterns** and conventions
- **Write tests** for new functionality
- **Update documentation** as needed
- **Test thoroughly** on supported platforms

### 4. Commit Your Changes

Use [Conventional Commits](https://conventionalcommits.org/) format:

```bash
# Stage your changes
git add .

# Commit with descriptive message
git commit -m "feat(terraform): add Terraform development environment

- Add Terraform configuration for HashiCorp tools
- Include terraform-ls language server setup
- Add custom aliases for common Terraform commands
- Update package installation for macOS and Linux

Fixes #123"
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting (no functional changes)
- `refactor`: Code restructuring (no functional changes)
- `test`: Test additions or modifications
- `chore`: Maintenance tasks, dependency updates
- `security`: Security improvements or fixes
- `perf`: Performance improvements

### 5. Push and Create Pull Request

```bash
# Push your feature branch
git push origin feature/add-terraform-configuration

# Create Pull Request on GitHub with:
# - Clear title and description
# - Reference to related issues
# - Test results and verification steps
```

---

## Contribution Types

### 🐛 Bug Reports

**Before reporting:**
- Search existing issues for duplicates
- Try to reproduce on a clean system
- Gather relevant system information

**Include in your report:**
- **Clear description** of the bug
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **System information** (OS, shell version, etc.)
- **Relevant logs** or error messages
- **Screenshots** if applicable

**Use the bug report template:**
```markdown
## Bug Description
Clear and concise description of the bug.

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## System Information
- OS: macOS 14.0 / Ubuntu 22.04
- Shell: zsh 5.9
- Dotfiles version: v1.2.3

## Additional Context
Logs, screenshots, or other relevant information
```

### ✨ Feature Requests

**Before requesting:**
- Check if the feature already exists
- Consider if it fits the project scope
- Think about implementation complexity

**Include in your request:**
- **Clear description** of the desired feature
- **Use case** or problem it solves
- **Proposed solution** or implementation ideas
- **Alternatives considered**
- **Additional context** or examples

### 📝 Documentation Improvements

Documentation contributions are highly valued:

**Areas needing help:**
- Fixing typos and grammatical errors
- Adding missing information or examples
- Improving clarity and organization
- Creating tutorials and guides
- Translating documentation

**Documentation standards:**
- Use clear, concise language
- Include practical examples
- Maintain consistent formatting
- Test all code examples
- Follow markdown linting rules

### 🔧 Code Contributions

**High-impact areas:**
- **New platform support** (FreeBSD, Windows WSL2)
- **Additional development tools** (IDEs, frameworks, databases)
- **Performance optimizations** (shell startup, installation speed)
- **Security enhancements** (additional secret patterns, validation)
- **Testing improvements** (coverage, reliability, speed)
- **CI/CD enhancements** (workflows, automation, reporting)

---

## Development Guidelines

### Shell Script Standards

**Style Guide:**
- Use `#!/usr/bin/env bash` shebang for bash scripts
- Use `set -euo pipefail` for error handling
- Quote variables to prevent word splitting: `"$variable"`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Use `$(command)` instead of backticks for command substitution

**Function Documentation:**
```bash
#!/usr/bin/env bash

# Install development tools for the current platform
# Globals:
#   OSTYPE - Operating system type
# Arguments:
#   $1 - Tool category (optional, default: "essential")
# Returns:
#   0 - Success
#   1 - Installation failed
install_development_tools() {
    local category="${1:-essential}"
    
    case "$OSTYPE" in
        darwin*)
            brew bundle install --file="Brewfile.${category}"
            ;;
        linux-gnu*)
            apt-get install -y $(cat "packages/${category}.txt")
            ;;
        *)
            echo "Unsupported platform: $OSTYPE" >&2
            return 1
            ;;
    esac
}
```

**Error Handling:**
```bash
# Good: Proper error handling
if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is required but not installed" >&2
    exit 1
fi

# Good: Validation
if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found: $config_file" >&2
    return 1
fi
```

**ShellCheck Compliance:**
- All shell scripts must pass ShellCheck without warnings
- Disable specific warnings only when necessary with comments
- Use shellcheck disable comments sparingly and with justification

### Configuration File Standards

**YAML Files:**
- Use 2-space indentation
- Quote strings containing special characters
- Use consistent key naming (snake_case)
- Include comments for complex configurations

**Template Files:**
- Use `.j2` extension for Jinja2 templates
- Include template validation in tests
- Document template variables
- Handle missing variables gracefully

### Cross-Platform Compatibility

**OS Detection:**
```bash
# Reliable OS detection
detect_os() {
    case "$OSTYPE" in
        darwin*)    echo "macos" ;;
        linux-gnu*) echo "linux" ;;
        freebsd*)   echo "freebsd" ;;
        *)          echo "unknown" ;;
    esac
}
```

**Platform-Specific Code:**
```bash
# Platform-specific installation
case "$(detect_os)" in
    macos)
        brew install package-name
        ;;
    linux)
        if command -v apt-get >/dev/null; then
            apt-get install package-name
        elif command -v dnf >/dev/null; then
            dnf install package-name
        fi
        ;;
esac
```

---

## Testing Requirements

### Test Categories

**Unit Tests** (`tests/unit/`):
- Test individual functions and scripts
- Use BATS (Bash Automated Testing System)
- Mock external dependencies
- Fast execution (<1 second per test)

**Integration Tests** (`tests/integration/`):
- Test complete workflows
- Test cross-component interactions
- May require more time and resources
- Test on multiple platforms

**Security Tests** (`tests/security/`):
- Secret exposure detection
- File permission validation
- Template security testing
- Git history analysis

**Performance Tests** (`tests/performance/`):
- Shell startup time benchmarks
- Installation speed measurement
- Resource usage monitoring
- Performance regression detection

### Writing Tests

**BATS Test Example:**
```bash
#!/usr/bin/env bats

# Test file: tests/unit/test_shell_functions.bats

setup() {
    # Load functions to test
    source "$BATS_TEST_DIRNAME/../shell/functions.sh"
    
    # Create temporary directory
    export TMPDIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary files
    rm -rf "$TMPDIR"
}

@test "detect_os returns correct OS" {
    # Mock OSTYPE for testing
    export OSTYPE="darwin21.0"
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "macos" ]
}

@test "install_package handles missing package manager" {
    # Test error handling
    export PATH="/bin:/usr/bin"  # Remove package managers from PATH
    run install_package "nonexistent-package"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No supported package manager found" ]]
}
```

**Test Organization:**
- One test file per script/module
- Group related tests in the same file
- Use descriptive test names
- Test both success and failure cases
- Include edge cases and error conditions

### Running Tests

```bash
# Run all tests
make test

# Run specific test categories
make test-unit
make test-integration
make test-security
make test-performance

# Run tests for specific component
bats tests/unit/test_shell_functions.bats

# Run tests with verbose output
make test VERBOSE=1

# Run tests and generate coverage report
make test-coverage
```

### Test Requirements for New Features

**Required for all new features:**
- Unit tests with >90% coverage
- Integration tests for end-to-end workflows
- Security tests if handling sensitive data
- Performance tests if affecting startup time

**Test must verify:**
- Correct behavior with valid inputs
- Error handling with invalid inputs
- Cross-platform compatibility
- No regression in existing functionality

---

## Security Guidelines

### Secret Management

**Never commit secrets:**
- API keys, tokens, passwords
- Private keys, certificates
- Personal information
- System-specific paths or usernames

**Use templates instead:**
```yaml
# Good: Template with secret reference
github:
  token: "{{ op://Personal/GitHub/api_token }}"
  
# Bad: Hardcoded secret
github:
  token: "ghp_xxxxxxxxxxxxxxxxxxxx"
```

**Secret Detection:**
```bash
# Run secret scan before committing
make security-scan

# Manual secret scan
./tests/security/scan-secrets.sh --comprehensive

# Check specific files
./tests/security/scan-secrets.sh file1.sh file2.yaml
```

### File Permissions

**Secure defaults:**
- Configuration files: `644` (readable by owner/group)
- Scripts: `755` (executable by owner, readable by others)
- Private keys: `600` (readable by owner only)
- SSH directory: `700` (accessible by owner only)

**Permission validation:**
```bash
# Check file permissions
./tests/security/check-permissions.sh

# Fix permissions automatically
./tests/security/check-permissions.sh --fix
```

### Template Security

**Prevent injection attacks:**
- Validate all template variables
- Escape special characters
- Use allowlists for variable values
- Test template rendering with malicious inputs

**Template testing:**
```bash
# Test template security
./tests/security/template-security-test.sh

# Validate specific template
dotfiles template validate config/ssh/config.j2
```

---

## Documentation Standards

### Markdown Guidelines

**Formatting:**
- Use ATX-style headers (`#` instead of `===`)
- One sentence per line for easier diffs
- Use fenced code blocks with language specification
- Include alt text for images
- Use tables for structured data

**Content Standards:**
- Write for your audience (assume basic terminal knowledge)
- Use active voice and clear language
- Include practical examples
- Link to related documentation
- Keep information current

**Linting:**
```bash
# Lint markdown files
make lint-docs

# Fix common markdown issues
make fix-docs

# Check specific file
markdownlint docs/installation.md
```

### Code Documentation

**Inline Comments:**
```bash
# Good: Explain why, not what
# Disable strict mode temporarily to handle legacy systems
set +e
legacy_command_that_might_fail
set -e

# Bad: Obvious comment
# Set variable to username
username="$(whoami)"
```

**Function Documentation:**
- Include purpose and behavior
- Document parameters and return values
- Provide usage examples
- Note any side effects or requirements

### README Updates

**When to update README:**
- Adding new major features
- Changing installation procedures
- Modifying requirements or compatibility
- Adding new platform support

**README sections to consider:**
- Feature list updates
- Installation instruction changes
- Configuration example updates
- Troubleshooting section additions

---

## Review Process

### Automated Checks

**Continuous Integration:**
- All tests must pass on supported platforms
- Security scans must show no new vulnerabilities
- Code must pass linting requirements
- Documentation must be valid and properly formatted

**Pre-commit Hooks:**
- ShellCheck for shell scripts
- markdownlint for documentation
- Secret scanning for new files
- YAML validation for configuration files

### Manual Review

**Code Review Criteria:**
- **Functionality**: Does the code work as intended?
- **Quality**: Is the code well-written and maintainable?
- **Security**: Are there any security concerns?
- **Performance**: Does it impact system performance?
- **Compatibility**: Does it work across supported platforms?
- **Documentation**: Is it properly documented?

**Review Timeline:**
- Simple fixes: 1-2 days
- New features: 3-7 days
- Major changes: 1-2 weeks
- Security fixes: Prioritized, <24 hours

### Addressing Review Feedback

**Best practices:**
- Respond promptly to review comments
- Ask questions if feedback is unclear
- Make requested changes in separate commits
- Update tests when changing functionality
- Communicate any challenges or blockers

**Common feedback types:**
- **Style**: Formatting, naming, organization
- **Functionality**: Logic errors, edge cases
- **Performance**: Optimization opportunities
- **Security**: Potential vulnerabilities
- **Documentation**: Missing or unclear docs

---

## Recognition

### Contributor Recognition

**Contributors are recognized through:**
- [CONTRIBUTORS.md](CONTRIBUTORS.md) listing with contribution details
- GitHub contributors page prominence
- Release notes acknowledgments for significant contributions
- Special recognition for major features, fixes, or ongoing support

**Types of contributions valued:**
- Code contributions (features, fixes, optimizations)
- Documentation improvements (guides, examples, clarity)
- Testing enhancements (coverage, reliability, new test types)
- Community support (helping users, reviewing PRs)
- Translations and accessibility improvements

### Maintainer Path

**Becoming a maintainer:**
- Consistent high-quality contributions over time
- Deep understanding of project architecture and goals
- Community involvement and support
- Demonstrated commitment to project values

**Maintainer responsibilities:**
- Code review and merge decisions
- Issue triage and community support
- Release planning and management
- Architectural decision participation

---

## Support

### Getting Help

**Before asking for help:**
- Read existing documentation thoroughly
- Search issues and discussions for similar questions
- Try to reproduce the issue on a clean system
- Gather relevant system information and logs

**Where to get help:**
- **GitHub Discussions**: General questions, ideas, and community support
- **GitHub Issues**: Bug reports and specific problems
- **Documentation**: Comprehensive guides and references
- **Code Examples**: Look at existing implementations for patterns

### Asking Good Questions

**Include in your question:**
- Clear description of what you're trying to achieve
- What you've already tried
- Specific error messages or unexpected behavior
- Relevant system information (OS, shell, versions)
- Minimal example that reproduces the issue

**Question template:**
```markdown
## What I'm trying to do
Brief description of your goal

## What I've tried
- Attempted solution 1
- Attempted solution 2
- Searched documentation for X, Y, Z

## Current behavior
What's happening now

## Expected behavior
What should happen instead

## System information
- OS: macOS 14.0
- Shell: zsh 5.9
- Dotfiles version: v1.2.3

## Additional context
Logs, config files, or other relevant information
```

### Community Guidelines

**Being a good community member:**
- Help others when you can
- Be patient with beginners
- Share knowledge and experiences
- Provide constructive feedback
- Follow the Code of Conduct

**Helping others:**
- Point to relevant documentation
- Provide working examples
- Explain the reasoning behind solutions
- Be encouraging and supportive
- Follow up to ensure problems are resolved

---

## Final Notes

### Project Vision

This dotfiles repository aims to be the gold standard for developer environment management—secure, reliable, and user-friendly while maintaining enterprise-grade quality and professional standards.

### Your Impact

Every contribution, no matter how small, helps make this project better for the entire community:
- **Bug fixes** improve reliability for all users
- **Documentation improvements** help newcomers get started
- **New features** expand what's possible
- **Performance optimizations** benefit everyone
- **Security enhancements** protect all users

### Thank You

Thank you for taking the time to read this contributing guide and for considering contributing to this project. Your involvement makes this community stronger and helps developers worldwide create better development environments.

**Ready to contribute?** 
1. Fork the repository
2. Set up your development environment
3. Find an issue to work on or propose a new feature
4. Follow the contribution workflow
5. Submit your pull request

Welcome to the community! 🚀

---

**Questions?** Feel free to ask in [GitHub Discussions](https://github.com/yourusername/dotfiles/discussions) or create an issue.

**Found this helpful?** Star the repository and share it with others who might benefit from a professional dotfiles setup. 