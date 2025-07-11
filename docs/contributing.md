# Contributing Guide

Thank you for your interest in contributing to this dotfiles repository!

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions.

## How to Contribute

### Reporting Issues

1. Check existing issues first
2. Provide clear description and steps to reproduce
3. Include relevant system information (OS, shell version, etc.)

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Create a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/dotfiles.git
cd dotfiles

# Add upstream remote
git remote add upstream https://github.com/originalowner/dotfiles.git

# Create feature branch
git checkout -b feature/my-feature
```

## Guidelines

### Code Style

- Follow existing patterns and conventions
- Use consistent indentation (see `.editorconfig`)
- Shell scripts should pass ShellCheck
- Document complex logic

### Commit Messages

Follow conventional commits format:

```
type(scope): subject

body (optional)

footer (optional)
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting changes
- `refactor`: Code restructuring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

Example:
```
feat(nvim): add LSP configuration for Python

- Configure pyright language server
- Add key bindings for LSP actions
- Update documentation
```

### Adding New Tools

1. Determine appropriate location (see [structure.md](structure.md))
2. Create necessary directories
3. Add configuration files
4. Update installation scripts
5. Add documentation
6. Test on supported platforms

### Testing

Before submitting:

1. Test fresh installation
2. Verify symlinks are created correctly
3. Check for conflicts with existing files
4. Test on different platforms if possible
5. Run any existing tests

```bash
# Run tests
make test

# Test installation
./scripts/bootstrap.sh --dry-run
```

### Documentation

- Update README if adding major features
- Document any new scripts or tools
- Add inline comments for complex logic
- Update relevant guides in `/docs`

## Pull Request Process

1. **Description**: Clearly describe what changes you made and why
2. **Testing**: Confirm you've tested the changes
3. **Documentation**: Update docs as needed
4. **Review**: Be responsive to feedback
5. **Squash**: Consider squashing commits before merge

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
- [ ] Tested on macOS
- [ ] Tested on Linux
- [ ] Existing tests pass
- [ ] Added new tests

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No secrets included
```

## Project Structure

See [structure.md](structure.md) for detailed information about repository organization.

## Security

- **Never commit secrets** - Use templates and environment variables
- Ensure no API keys, passwords, or tokens are included
- Review changes carefully before committing

## Questions?

- Check existing documentation
- Look at similar existing code
- Ask in issues or discussions

## Recognition

Contributors will be recognized in the project documentation.

Thank you for contributing!
