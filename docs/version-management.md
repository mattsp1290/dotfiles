# Version Management with ASDF

This guide covers using ASDF as a unified version manager for multiple programming languages and tools in your development environment.

## Overview

ASDF (Another System Definition Facility) is a command-line tool that manages multiple runtime versions for multiple languages and tools. It provides a single interface for managing versions of Node.js, Python, Ruby, Go, Terraform, and many other development tools.

## Benefits of ASDF

- **Single Tool**: Manage all language versions with one tool
- **Project-Specific Versions**: Automatically switch versions per project
- **Global Defaults**: Set global default versions
- **Shell Integration**: Seamless integration with your shell
- **Plugin Ecosystem**: Extensive plugin support for many tools
- **Reproducible Environments**: Share exact versions via `.tool-versions` files

## Installation

ASDF is automatically installed by the cross-platform tools system:

```bash
# Via main installation script
scripts/install-tools.sh asdf

# Or via individual ASDF script
tools/scripts/install-asdf.sh install
```

### Manual Installation

If automatic installation fails:

```bash
# Clone ASDF repository
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

# Add to shell configuration
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.zshrc

# Restart shell
source ~/.zshrc
```

## Core Concepts

### Plugins

Plugins add support for specific languages or tools. Each plugin provides installation, version detection, and environment setup for its tool.

### Versions

Each plugin can manage multiple versions of its tool. Versions are installed on-demand and can be set globally or per-project.

### Tool-Versions File

The `.tool-versions` file specifies which versions to use. ASDF automatically reads this file when entering a directory.

## Basic Usage

### Managing Plugins

```bash
# List available plugins
asdf plugin list all

# Add a plugin
asdf plugin add nodejs
asdf plugin add python
asdf plugin add ruby

# List installed plugins
asdf plugin list

# Update a plugin
asdf plugin update nodejs

# Remove a plugin
asdf plugin remove nodejs
```

### Managing Versions

```bash
# List available versions for a tool
asdf list all nodejs

# Install a specific version
asdf install nodejs 20.12.0
asdf install python 3.12.2

# List installed versions
asdf list nodejs
asdf list python

# Uninstall a version
asdf uninstall nodejs 18.0.0
```

### Setting Versions

```bash
# Set global version (default for all projects)
asdf global nodejs 20.12.0
asdf global python 3.12.2

# Set local version (for current project)
asdf local nodejs 18.19.0
asdf local python 3.11.7

# Check current versions
asdf current

# Check version for specific tool
asdf current nodejs
```

## Supported Tools

### Core Programming Languages

| Tool | Plugin Name | Description |
|------|-------------|-------------|
| Node.js | `nodejs` | JavaScript runtime |
| Python | `python` | Python interpreter |
| Ruby | `ruby` | Ruby interpreter |
| Go | `golang` | Go compiler |
| Rust | `rust` | Rust toolchain |
| Java | `java` | Java Development Kit |
| PHP | `php` | PHP interpreter |
| .NET | `dotnet` | .NET SDK |

### Infrastructure Tools

| Tool | Plugin Name | Description |
|------|-------------|-------------|
| Terraform | `terraform` | Infrastructure as Code |
| kubectl | `kubectl` | Kubernetes CLI |
| Helm | `helm` | Kubernetes package manager |
| AWS CLI | `awscli` | Amazon Web Services CLI |
| Google Cloud CLI | `gcloud` | Google Cloud Platform CLI |
| Azure CLI | `azure-cli` | Microsoft Azure CLI |

### Development Utilities

| Tool | Plugin Name | Description |
|------|-------------|-------------|
| direnv | `direnv` | Environment variable manager |
| jq | `jq` | JSON processor |
| yq | `yq` | YAML processor |
| GitHub CLI | `github-cli` | GitHub command line interface |
| git-delta | `git-delta` | Enhanced git diff viewer |

## Configuration

### Default Tool Versions

The global default versions are defined in `config/asdf/.tool-versions`:

```
# Core Programming Languages
nodejs 20.12.0
python 3.12.2
ruby 3.3.0
golang 1.22.1

# Infrastructure Tools
terraform 1.7.4
kubectl 1.29.3
helm 3.14.3

# Additional Tools
awscli 2.15.30
gcloud 468.0.0
azure-cli 2.58.0

# Utilities
direnv 2.34.0
jq 1.7.1
yq 4.42.1
```

### Project-Specific Versions

Create a `.tool-versions` file in your project directory:

```bash
# Example .tool-versions for a Node.js project
nodejs 18.19.0
python 3.11.7
terraform 1.6.6
```

### Environment Variables

ASDF respects these environment variables:

- `ASDF_DATA_DIR`: Where ASDF stores tools (default: `~/.asdf`)
- `ASDF_CONFIG_FILE`: ASDF configuration file location
- `ASDF_DEFAULT_TOOL_VERSIONS_FILENAME`: Tool versions filename (default: `.tool-versions`)

## Advanced Usage

### Shell Integration

ASDF integrates with your shell to automatically switch versions:

```bash
# Check if ASDF is properly integrated
which node
# Should show: ~/.asdf/shims/node

# Verify version switching works
cd /path/to/project/with/tool-versions
node --version
# Should show the version specified in .tool-versions
```

### Custom Install Locations

```bash
# Install to custom location
ASDF_DATA_DIR=/custom/path asdf install nodejs 20.12.0

# Use different tool-versions filename
ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=.versions asdf current
```

### Reshimming

After installing packages that provide executables:

```bash
# Rebuild shims for all tools
asdf reshim

# Rebuild shims for specific tool
asdf reshim nodejs

# Example: After installing a global npm package
npm install -g typescript
asdf reshim nodejs
```

### Legacy Version Files

ASDF can read version files from other version managers:

```bash
# Enable legacy version files globally
echo "legacy_version_file = yes" >> ~/.asdfrc

# Now ASDF will read .nvmrc, .python-version, etc.
```

## Best Practices

### 1. Use .tool-versions Files

Always specify tool versions in your projects:

```bash
# Create .tool-versions for new project
cd my-project
asdf local nodejs 20.12.0
asdf local python 3.12.2
git add .tool-versions
git commit -m "Add tool versions"
```

### 2. Keep Global Versions Updated

Regularly update your global defaults:

```bash
# Check for newer versions
asdf list all nodejs | tail -5

# Update to latest stable
asdf install nodejs 20.13.0
asdf global nodejs 20.13.0
```

### 3. Use Specific Versions

Avoid using `latest` or version ranges:

```bash
# Good: Specific version
nodejs 20.12.0

# Avoid: Vague versions
nodejs latest
nodejs 20
```

### 4. Document Version Requirements

Include version requirements in your project README:

```markdown
## Requirements

- Node.js 20.12.0 (managed via ASDF)
- Python 3.12.2 (managed via ASDF)

Install versions with:
```bash
asdf install
```

### 5. Team Synchronization

Ensure your team uses the same versions:

```bash
# Install all tools from .tool-versions
asdf install

# Verify versions match
asdf current
```

## Troubleshooting

### Common Issues

**ASDF command not found**:
```bash
# Check if ASDF is in PATH
echo $PATH | grep asdf

# Source ASDF manually
source ~/.asdf/asdf.sh

# Check shell configuration
grep asdf ~/.zshrc
```

**Tool not switching versions**:
```bash
# Check shims directory
ls -la ~/.asdf/shims/

# Reshim if needed
asdf reshim

# Verify .tool-versions is read
asdf current
```

**Plugin installation fails**:
```bash
# Update plugin repository
asdf plugin update --all

# Install plugin dependencies (varies by plugin)
# For nodejs on Ubuntu/Debian:
sudo apt-get install dirmngr gpg curl gawk

# For python:
sudo apt-get install build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev \
    liblzma-dev python3-openssl git
```

**Version installation fails**:
```bash
# Check plugin documentation
asdf plugin info nodejs

# Install with verbose output
ASDF_NODEJS_VERBOSE_INSTALL=true asdf install nodejs 20.12.0

# Check system dependencies
# Each plugin may have specific requirements
```

### Debugging

```bash
# Enable debug output
export ASDF_DEBUG=1
asdf current

# Check ASDF info
asdf info

# Verify plugin configuration
asdf plugin list --urls
```

## Integration with Development Workflow

### CI/CD Integration

**GitHub Actions**:
```yaml
- name: Setup ASDF
  uses: asdf-vm/actions/setup@v2

- name: Install tools
  run: asdf install

- name: Run tests
  run: |
    npm test
    python -m pytest
```

**Docker Integration**:
```dockerfile
FROM ubuntu:22.04

# Install ASDF
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
ENV PATH="$HOME/.asdf/bin:$HOME/.asdf/shims:$PATH"

# Copy tool versions and install
COPY .tool-versions .
RUN asdf plugin add nodejs && \
    asdf plugin add python && \
    asdf install
```

### IDE Integration

**VS Code**:
```json
{
  "terminal.integrated.env.osx": {
    "PATH": "${env:HOME}/.asdf/shims:${env:PATH}"
  },
  "terminal.integrated.env.linux": {
    "PATH": "${env:HOME}/.asdf/shims:${env:PATH}"
  }
}
```

## Migration from Other Version Managers

### From nvm (Node.js)

```bash
# Export current Node.js version
echo "nodejs $(node --version | sed 's/v//')" >> .tool-versions

# Install ASDF Node.js plugin
asdf plugin add nodejs

# Import GPG keys (required for Node.js)
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

# Install version
asdf install nodejs $(node --version | sed 's/v//')

# Remove nvm
rm -rf ~/.nvm
# Remove nvm from shell configuration
```

### From pyenv (Python)

```bash
# Export current Python version
echo "python $(python --version | cut -d' ' -f2)" >> .tool-versions

# Install ASDF Python plugin
asdf plugin add python

# Install version
asdf install python $(python --version | cut -d' ' -f2)

# Remove pyenv
rm -rf ~/.pyenv
# Remove pyenv from shell configuration
```

### From rbenv (Ruby)

```bash
# Export current Ruby version
echo "ruby $(ruby --version | cut -d' ' -f2)" >> .tool-versions

# Install ASDF Ruby plugin
asdf plugin add ruby

# Install version
asdf install ruby $(ruby --version | cut -d' ' -f2)

# Remove rbenv
rm -rf ~/.rbenv
# Remove rbenv from shell configuration
```

## Performance Optimization

### Shim Performance

```bash
# Check shim performance
time node --version

# If slow, consider using direnv for frequently used tools
echo 'use asdf' > .envrc
direnv allow
```

### Plugin Management

```bash
# Remove unused plugins
asdf plugin remove unused-plugin

# Clean up old versions
asdf uninstall nodejs 16.0.0

# Update plugins periodically
asdf plugin update --all
```

## See Also

- [ASDF Official Documentation](https://asdf-vm.com/)
- [ASDF Plugin List](https://github.com/asdf-vm/asdf-plugins)
- [Cross-Platform Tools](tools.md)
- [Cloud Setup Guide](cloud-setup.md) 