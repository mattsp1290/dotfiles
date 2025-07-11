# ADR-004: Symlink Management Strategy

**Status**: Accepted  
**Date**: 2024-12-19  
**Deciders**: Matt Spurlin  
**Technical Story**: Implement reliable, maintainable symlink management for dotfiles deployment across multiple platforms and configurations

## Context and Problem Statement

The dotfiles system requires a robust mechanism for creating and managing symlinks between repository files and their target locations in the user's system. The solution must handle:
- Complex directory structures with nested configurations
- Conflict detection and resolution when target files exist
- Cross-platform compatibility with different filesystem behaviors
- Easy installation and removal of configurations
- Selective deployment of configuration subsets
- Backup and restoration of existing configurations
- Integration with version control and testing workflows

Manual symlink management becomes error-prone and unmaintainable as the number of configuration files grows. A systematic approach is needed to ensure reliability and ease of maintenance.

## Decision Drivers

- **Reliability**: Predictable symlink creation without conflicts
- **Maintainability**: Easy to understand and modify symlink structure
- **Conflict Resolution**: Built-in handling of existing files and directories
- **Package Organization**: Logical grouping of related configurations
- **Cross-platform**: Consistent behavior across operating systems
- **Reversibility**: Easy removal and restoration capabilities
- **Tool Maturity**: Stable, well-tested solution with community support
- **Integration**: Compatibility with our repository structure and workflows

## Considered Options

1. **GNU Stow**: Symlink farm manager with package-based organization
2. **Manual Symlinks**: Custom shell scripts for symlink creation
3. **chezmoi**: Comprehensive dotfiles manager with templating
4. **yadm**: Yet Another Dotfiles Manager with Git integration
5. **dotbot**: Declarative dotfiles installer with YAML configuration
6. **homeshick**: Git dotfiles synchronizer with Bash implementation

## Decision Outcome

**Chosen option**: "GNU Stow with Custom Wrapper Scripts"

We selected GNU Stow as the foundation for symlink management, enhanced with custom wrapper scripts for improved automation and validation.

### Positive Consequences
- Simple, predictable symlink behavior following established patterns
- Package-based organization aligns perfectly with our repository structure
- Built-in conflict detection prevents accidental file overwrites
- Mature, stable tool with decades of development and testing
- Wide availability across package managers and distributions
- Easy to understand folding rules for nested directory structures
- Excellent reversibility - symlinks can be cleanly removed
- Minimal dependencies and lightweight implementation

### Negative Consequences
- Additional dependency that must be installed on target systems
- Learning curve for understanding Stow's folding and unfolding rules
- Less flexible than custom scripting approaches
- Directory structure must conform to Stow's expectations
- Some edge cases require custom handling outside of Stow

## Pros and Cons of the Options

### Option 1: GNU Stow (Chosen)
- **Pros**: Battle-tested, predictable behavior, conflict detection, package organization, reversible
- **Cons**: Additional dependency, learning curve, structure constraints

### Option 2: Manual Symlinks
- **Pros**: No dependencies, complete control, simple to understand
- **Cons**: Error-prone, no conflict detection, maintenance burden, reinventing solutions

### Option 3: chezmoi
- **Pros**: Powerful templating, multi-machine support, comprehensive features
- **Cons**: Steeper learning curve, more complex than needed, requires Go runtime

### Option 4: yadm  
- **Pros**: Git-based workflow, encryption support, simple concept
- **Cons**: More complex than needed, less intuitive structure, limited package management

### Option 5: dotbot
- **Pros**: Declarative configuration, flexible, good documentation
- **Cons**: YAML dependency, less mature, requires Python, more complex setup

### Option 6: homeshick
- **Pros**: Pure Bash, Git integration, castle concept
- **Cons**: Less mature, limited conflict handling, Bash-specific

## Implementation Details

### Stow Package Structure
```bash
dotfiles/
├── home/                    # Stow package for $HOME files
│   ├── .bashrc             # → ~/.bashrc
│   ├── .zshrc              # → ~/.zshrc
│   └── .gitconfig          # → ~/.gitconfig
├── config/                  # Stow package for ~/.config files  
│   ├── git/                # → ~/.config/git/
│   ├── nvim/               # → ~/.config/nvim/
│   └── ssh/                # → ~/.config/ssh/
└── shell/                   # Stow package for shell configurations
    ├── zsh/                # → ~/.config/shell/zsh/
    └── bash/               # → ~/.config/shell/bash/
```

### Stow Wrapper Scripts
```bash
# Automated stowing with validation
./scripts/stow-all.sh          # Deploy all packages
./scripts/unstow-all.sh        # Remove all symlinks
./scripts/stow-package.sh      # Deploy specific package
```

### Enhanced Stow Operations
```bash
# Pre-flight validation
validate_stow_packages() {
    # Check for conflicts before deployment
    # Validate directory structure compliance
    # Ensure required permissions
}

# Intelligent conflict resolution
resolve_conflicts() {
    # Backup existing files
    # Prompt for overwrite decisions
    # Create merge opportunities
}

# Post-deployment verification
verify_stow_deployment() {
    # Validate all symlinks are correct
    # Check file permissions
    # Test configuration loading
}
```

### Cross-Platform Considerations
```bash
# Handle platform-specific symlink behaviors
case "$(detect_os_type)" in
    macos)
        # macOS-specific symlink handling
        STOW_FLAGS="--no-folding"
        ;;
    linux)
        # Linux symlink optimization
        STOW_FLAGS="--verbose=2"
        ;;
    wsl)
        # WSL symlink compatibility
        export WSLENV="$WSLENV:STOW_DIR/p"
        ;;
esac
```

### Backup and Recovery System
```bash
# Create backups before stowing
backup_existing_configs() {
    local backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
    # Save existing configurations
    # Create restoration script
}

# Restore from backups
restore_configs() {
    # Unstow current configurations
    # Restore backed up files
    # Verify restoration success
}
```

### Package-Specific Stowing
```bash
# Selective deployment by component
stow_component() {
    local component="$1"
    case "$component" in
        shell)
            stow_packages "shell" "home"
            ;;
        editors)
            stow_packages "config"
            ;;
        git)
            stow_packages "home" "config"
            ;;
    esac
}
```

### Conflict Detection and Resolution
```bash
# Enhanced conflict detection
detect_stow_conflicts() {
    # Identify existing files that would conflict
    # Categorize conflicts (file vs directory)
    # Suggest resolution strategies
    # Create conflict report
}

# Interactive conflict resolution
resolve_interactive() {
    # Present conflict details to user
    # Offer resolution options (backup, merge, skip)
    # Execute chosen resolution
    # Validate results
}
```

## Validation Criteria

### Functional Validation
```bash
# Test stow operations
make test-stow

# Validate symlink integrity
./scripts/validate-symlinks.sh

# Test conflict handling
./tests/integration/test-stow-conflicts.sh
```

### Success Metrics
- All configuration files successfully symlinked to correct locations
- No broken symlinks after deployment
- Conflict detection works for all edge cases
- Unstowing cleanly removes all symlinks without orphans
- Package-based deployment allows selective installation
- Cross-platform symlink behavior is consistent

### Performance Validation
```bash
# Stow performance benchmarks
time ./scripts/stow-all.sh     # Should complete in <30 seconds
time ./scripts/unstow-all.sh   # Should complete in <10 seconds

# Validation performance
time ./scripts/validate-symlinks.sh  # Should complete in <5 seconds
```

### Integration Validation
- Stow packages work correctly with repository structure
- Installation scripts integrate seamlessly with Stow operations
- Template system works with stowed configurations
- Testing framework validates stowed configurations
- Backup system preserves existing configurations

## Links

- [GNU Stow Documentation](https://www.gnu.org/software/stow/)
- [Stow Usage Guide](../stow-usage.md)
- [Stow Scripts](../../scripts/stow-all.sh)
- [Symlink Validation](../../scripts/validate-symlinks.sh)
- [ADR-001: Repository Structure](001-repository-structure.md)
- [ADR-003: Installation Approach](003-installation-approach.md)

## Notes

GNU Stow's package-based approach aligns perfectly with our functional repository structure, making it an ideal choice for symlink management. The tool's maturity and widespread adoption provide confidence in long-term maintainability.

The wrapper scripts address Stow's limitations while preserving its core strengths. Custom conflict resolution and validation enhance the user experience without sacrificing Stow's simplicity.

Key implementation insights:
- Stow's folding behavior must be well understood to predict symlink structure
- Package boundaries should align with logical configuration groupings
- Conflict detection before deployment prevents user frustration
- Cross-platform testing is essential due to filesystem differences
- Backup creation before major changes provides safety and confidence 