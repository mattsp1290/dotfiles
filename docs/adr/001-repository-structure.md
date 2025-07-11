# ADR-001: Repository Structure and Organization

**Status**: Accepted  
**Date**: 2024-12-19  
**Deciders**: Matt Spurlin  
**Technical Story**: Design scalable, maintainable directory structure for cross-platform dotfiles management

## Context and Problem Statement

The dotfiles repository needs a clear, logical directory structure that supports:
- Cross-platform compatibility (macOS, Linux, WSL)
- Maintainable component separation
- Scalable growth as new tools are added
- Clear understanding for contributors
- Integration with GNU Stow for symlink management
- XDG Base Directory Specification compliance

Without a well-defined structure, configurations become difficult to maintain, components interfere with each other, and cross-platform support becomes unwieldy.

## Decision Drivers

- **Maintainability**: Clear separation of concerns for easy updates
- **Cross-platform support**: Platform-specific configurations without conflicts
- **Scalability**: Structure that grows cleanly with new components
- **Contributor experience**: Intuitive organization for new team members
- **Tool integration**: Compatibility with GNU Stow and other tools
- **Standards compliance**: Adherence to XDG specifications where applicable
- **Testing isolation**: Independent testing of components

## Considered Options

1. **Flat Structure**: All configuration files in repository root
2. **Category-based Structure**: Group by tool category (editors/, shells/, etc.)
3. **XDG-only Structure**: Strict adherence to XDG Base Directory Specification
4. **Functional Separation**: Organize by function and target location
5. **Hybrid Platform Structure**: Platform directories with functional sub-organization

## Decision Outcome

**Chosen option**: "Functional Separation with Platform-Specific Directories"

We adopted a hybrid structure that separates configurations by their target location and function, with platform-specific directories for OS-dependent configurations.

### Positive Consequences
- Clear mapping between repository structure and target system
- Easy to understand which files go where
- Platform-specific optimizations without conflicts
- Component isolation enables independent testing
- Scales well with new tools and configurations
- Supports GNU Stow's package-based approach
- Facilitates selective installation of components

### Negative Consequences
- More complex than flat structure
- Requires documentation for contributors
- Some duplication across platform directories
- Need to maintain consistency across similar configurations

## Pros and Cons of the Options

### Option 1: Flat Structure
- **Pros**: Simple to understand, no nested directories, easy file discovery
- **Cons**: Becomes unwieldy with many files, no logical grouping, hard to maintain, poor tool integration

### Option 2: Category-based Structure  
- **Pros**: Logical grouping, easy to find related tools, clear boundaries
- **Cons**: Doesn't map to target locations, complex cross-category dependencies, harder Stow integration

### Option 3: XDG-only Structure
- **Pros**: Standards compliant, future-proof, clear specification
- **Cons**: Not all tools support XDG, forces non-standard locations, limited platform flexibility

### Option 4: Functional Separation (Chosen)
- **Pros**: Clear target mapping, excellent Stow integration, component isolation, scalable
- **Cons**: More directories to manage, requires understanding of structure

### Option 5: Hybrid Platform Structure
- **Pros**: Maximum platform optimization, clear separation
- **Cons**: Most complex structure, potential for duplication, harder to maintain consistency

## Implementation Details

### Final Directory Structure
```
dotfiles/
├── home/                    # Files symlinked to $HOME
├── config/                  # XDG_CONFIG_HOME files  
├── shell/                   # Shell-specific configurations
│   ├── zsh/                # Zsh with Oh My Zsh
│   ├── bash/               # Bash compatibility
│   └── shared/             # Cross-shell utilities
├── scripts/                 # Installation and utility scripts
│   ├── lib/                # Shared libraries
│   └── setup/              # Component installers
├── templates/              # Files requiring processing
├── os/                     # OS-specific configurations
│   ├── macos/              # macOS system preferences
│   └── linux/              # Linux distribution packages
├── tests/                  # Testing framework
├── docs/                   # Documentation
│   └── adr/                # Architecture Decision Records
├── themes/                 # Visual themes
├── tools/                  # Development tools
└── private/                # Git-ignored personal files
```

### Key Design Principles
1. **Target-based organization**: Directory names reflect target locations
2. **Platform separation**: OS-specific files isolated in `os/` directory
3. **Component boundaries**: Clear separation between different tools
4. **Stow compatibility**: Each major directory can be a Stow package
5. **XDG compliance**: `config/` directory follows XDG specification
6. **Shared resources**: Common libraries in `scripts/lib/`

### Migration Strategy
- Existing configurations mapped to new structure
- Stow packages created for each major directory
- Symlink validation ensures correct target placement
- Backup strategy preserves existing configurations

## Validation Criteria

### Success Metrics
- All components can be installed independently
- Clear mapping from repository to target system
- Stow packages work without conflicts
- New contributors can understand structure within 15 minutes
- Platform-specific features work correctly
- Test suite validates structure integrity

### Verification Tests
```bash
# Structure validation
make test-structure

# Stow package validation  
./scripts/test-stow-packages.sh

# Cross-platform compatibility
./tests/integration/test-all-platforms.sh
```

## Links

- [GNU Stow Documentation](https://www.gnu.org/software/stow/)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Repository Structure Guide](../structure.md)
- [ADR-004: Symlink Management](004-symlink-management.md)
- [Installation Documentation](../installation.md)

## Notes

This structure has evolved through multiple iterations and represents lessons learned from maintaining dotfiles across multiple machines and platforms. The functional separation provides the best balance of clarity, maintainability, and tool integration while supporting the project's cross-platform goals. 