# Bash Configuration

A performance-optimized, modular bash configuration that provides feature parity with the zsh setup while maintaining fast startup times and cross-platform compatibility.

## Overview

This bash compatibility layer provides:

- **Modular Architecture**: Clean separation of concerns with numbered modules
- **Performance Optimized**: Lazy loading for expensive tools (<500ms startup target)
- **Cross-Platform**: Works on macOS and Linux with graceful degradation
- **Feature Parity**: Essential functionality from zsh configuration
- **Easy Maintenance**: Clear structure for customization and extension

## Features

### Core Functionality
- Environment variable management with XDG compliance
- Optimized PATH management with tool detection
- Comprehensive aliases for productivity and safety
- Essential shell functions for common tasks
- Git-aware prompt with performance focus
- Bash completion with lazy loading for heavy tools

### Tool Integration
- Version manager support (ASDF, pyenv, rbenv, nodenv) with lazy loading
- Git integration with status and branch information
- Docker and container tool aliases
- Cloud CLI support (AWS, GCP, Azure)
- Development tool shortcuts and helpers
- 1Password CLI integration

### Performance Features
- Conditional loading based on available tools
- Minimal startup overhead with lazy loading
- Efficient completion setup
- Smart caching where applicable
- Fast OS and tool detection

## Installation

### Prerequisites

**Required:**
- bash 4.0+ (bash 5.0+ recommended)
- git

**Recommended:**
- bash-completion package
- Modern bash version via Homebrew (macOS)

### Setup

1. **Via Stow (Recommended):**
   ```bash
   cd $DOTFILES_DIR
   stow shell
   ```

2. **Manual Installation:**
   ```bash
   # Link the main configuration files
   ln -sf $DOTFILES_DIR/shell/bash/.bashrc ~/.bashrc
   ln -sf $DOTFILES_DIR/shell/bash/.bash_profile ~/.bash_profile
   ```

3. **Test the Configuration:**
   ```bash
   # Run the test suite
   bash $DOTFILES_DIR/shell/bash/test-config.bash
   
   # Test startup performance
   time bash -i -c exit
   ```

## Configuration Structure

```
shell/bash/
├── .bashrc                 # Main configuration entry point
├── .bash_profile          # Login shell configuration  
├── modules/               # Modular configuration files
│   ├── 01-environment.bash    # Environment variables
│   ├── 02-path.bash          # PATH management
│   ├── 03-aliases.bash       # Command aliases
│   ├── 04-functions.bash     # Shell functions
│   ├── 05-completion.bash    # Completion system
│   ├── 06-prompt.bash        # Prompt configuration
│   └── 99-local.bash         # Local overrides
├── functions/             # Additional functions
├── completion/            # Custom completion scripts
├── test-config.bash       # Configuration testing
└── README.md             # This file
```

## Usage

### Basic Commands

The configuration provides numerous aliases and functions:

```bash
# Directory navigation
.. ..                # cd ../../
mkcd newdir          # mkdir -p newdir && cd newdir

# File operations
extract archive.zip  # Extract various archive formats
backup file.txt      # Create timestamped backup

# Git shortcuts
g                    # git
gs                   # git status
gcom "message"       # git add -A && git commit -m "message"
gnew branch-name     # git checkout -b branch-name

# System information
weather              # Current weather
duh                  # Disk usage, human readable, sorted
listening            # Show listening ports

# Development
serve                # Start HTTP server on port 8000
json                 # Pretty print JSON
```

### Tool Integration

#### Version Managers (Lazy Loaded)
```bash
# These will automatically initialize the respective version manager on first use
python              # Initializes pyenv if available
ruby                # Initializes rbenv if available  
node                # Initializes nodenv if available
asdf                # Initializes ASDF if available
```

#### Cloud Tools
```bash
# AWS
aws                 # AWS CLI (lazy loaded completion)

# Kubernetes  
k                   # kubectl alias
kgp                 # kubectl get pods

# Terraform
tf                  # terraform alias
tfi                 # terraform init
```

#### Docker
```bash
d                   # docker
dc                  # docker-compose
dps                 # docker ps
```

## Customization

### Local Overrides

Create local customizations in `~/.bashrc.local`:

```bash
# Custom aliases
alias work='cd /path/to/work'

# Custom environment variables
export CUSTOM_VAR="value"

# Custom functions
myfunction() {
    echo "Custom function"
}
```

### Machine-Specific Configuration

The configuration supports machine-specific files:

```bash
# Hostname-specific configuration
~/.bashrc.$(hostname)

# Local modules directory
~/.bash/local/*.bash
```

### Project-Specific Configuration

Place a `.bashrc` file in your project directory for project-specific settings (loaded automatically with safety checks).

## Performance

### Startup Time Optimization

The configuration uses several techniques to maintain fast startup:

1. **Lazy Loading**: Expensive tools only initialize when first used
2. **Conditional Loading**: Features only load if tools are available
3. **Minimal External Commands**: Reduced subprocess calls during startup
4. **Efficient Completion**: Heavy completions load on-demand

### Benchmarking

Test startup performance:

```bash
# Basic timing
time bash -i -c exit

# Detailed profiling (uncomment profiling lines in .bashrc)
# time bash -i -c exit

# Run full test suite
bash $DOTFILES_DIR/shell/bash/test-config.bash
```

Target startup time: **<500ms**

## Compatibility

### Bash Versions

- **bash 4.0+**: Basic functionality (associative arrays available)
- **bash 5.0+**: Full functionality (recommended)
- **bash 3.2**: Limited support (macOS default)

### Platform Support

- **macOS**: Full support (Homebrew bash recommended)
- **Linux**: Full support (most distributions)
- **Windows**: Via WSL or Git Bash

### Tool Compatibility

The configuration gracefully handles missing tools:

- Essential features work without optional tools
- Tool-specific aliases only activate if tools are available
- Fallback behaviors for missing dependencies

## Troubleshooting

### Common Issues

1. **Slow Startup**: Check which tools are being loaded
   ```bash
   # Enable debug mode
   export BASH_DEBUG=1
   time bash -i -c exit
   ```

2. **Missing Completions**: Install bash-completion package
   ```bash
   # macOS
   brew install bash-completion
   
   # Ubuntu/Debian
   sudo apt install bash-completion
   ```

3. **PATH Issues**: Check PATH order in `02-path.bash`
   ```bash
   echo $PATH | tr ':' '\n'
   ```

### Debug Mode

Enable debug output:

```bash
export BASH_DEBUG=1
source ~/.bashrc
```

## Migration

### From Zsh

The bash configuration provides similar functionality to the zsh setup:

- Most aliases and functions work identically
- Environment variables are preserved
- Tool integration functions similarly
- Prompt provides git information

### From Other Bash Setups

1. Backup existing configuration:
   ```bash
   cp ~/.bashrc ~/.bashrc.backup
   cp ~/.bash_profile ~/.bash_profile.backup
   ```

2. Install this configuration
3. Migrate custom settings to `~/.bashrc.local`

## Development

### Adding New Modules

1. Create a new file in `modules/` with appropriate number prefix
2. Follow existing module patterns
3. Test with `test-config.bash`
4. Update this README

### Testing

```bash
# Run test suite
bash test-config.bash

# Test specific functionality
bash -c "source .bashrc && declare -f function_name"
```

## Contributing

1. Follow the existing modular structure
2. Maintain bash 4.0+ compatibility
3. Include performance considerations
4. Test on both macOS and Linux
5. Update documentation

## License

Part of the dotfiles repository. See main repository LICENSE for details. 