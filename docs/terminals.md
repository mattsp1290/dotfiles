# Terminal Emulator Configurations - DEV-004

Complete guide to terminal emulator configurations with Catppuccin Mocha theme and optimal development settings.

## Overview

This configuration provides consistent terminal theming and optimal performance across multiple terminal emulators:

- **Alacritty** - Cross-platform GPU-accelerated terminal
- **Kitty** - Fast, featureful terminal emulator
- **iTerm2** - Advanced macOS terminal emulator
- **Terminal.app** - Built-in macOS terminal

All terminals are configured with:
- **Catppuccin Mocha theme** - Consistent with editor theme
- **JetBrains Mono font** - Programming font with ligatures
- **Optimized performance** - Fast rendering and low latency
- **Shell integration** - Enhanced zsh/bash compatibility

## Quick Start

### Automatic Setup
```bash
# Configure all available terminals
./scripts/setup-terminals.sh

# Install programming fonts first
./scripts/setup-terminals.sh --install-fonts

# Configure specific terminal only
./scripts/setup-terminals.sh -t alacritty

# Dry run (preview changes)
./scripts/setup-terminals.sh --dry-run
```

### Validation
```bash
# Validate all configurations
./scripts/validate-terminals.sh

# Test color display
./scripts/validate-terminals.sh --colors

# Test specific terminal
./scripts/validate-terminals.sh --terminal kitty
```

## Terminal Configurations

### Alacritty Configuration

**Location**: `config/alacritty/alacritty.yml`

**Features**:
- GPU-accelerated rendering
- True color support (24-bit)
- Configurable key bindings
- Live config reload
- Cross-platform compatibility

**Installation**:
```bash
# macOS
brew install --cask alacritty

# Ubuntu/Debian
sudo apt install alacritty

# Arch Linux
sudo pacman -S alacritty
```

**Key Settings**:
- Font: JetBrains Mono, 13pt
- Background opacity: 95%
- Scrollback: 10,000 lines
- Shell: zsh with login

### Kitty Configuration

**Location**: `config/kitty/kitty.conf`

**Features**:
- High performance rendering
- Advanced tab and window management
- Image display support
- Remote control capabilities
- Extensive customization

**Installation**:
```bash
# macOS
brew install --cask kitty

# Ubuntu/Debian
sudo apt install kitty

# From source
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
```

**Key Settings**:
- Font: JetBrains Mono, 13pt with ligatures
- Tab style: Powerline with slanted edges
- Background opacity: 95%
- Shell integration enabled

### iTerm2 Configuration (macOS)

**Location**: `os/macos/iterm2/`

**Features**:
- Advanced profiles and themes
- Hotkey windows
- Shell integration
- Split panes and tabs
- Automatic color switching

**Installation**:
```bash
# macOS
brew install --cask iterm2
```

**Setup**:
1. Open iTerm2 → Preferences (⌘,)
2. Go to General → Preferences
3. Check "Load preferences from a custom folder or URL"
4. Set folder to: `$DOTFILES_DIR/os/macos/iterm2/`
5. Restart iTerm2

### Terminal.app Configuration (macOS)

**Location**: `os/macos/terminal/setup.sh`

**Features**:
- Built-in macOS terminal
- Catppuccin Mocha profile
- Optimized for fallback scenarios
- System integration

**Setup**:
```bash
# Run the setup script
./os/macos/terminal/setup.sh
```

## Color Scheme

All terminals use the **Catppuccin Mocha** color scheme for consistency:

### Core Colors
| Color | Hex | Usage |
|-------|-----|--------|
| Base | `#1e1e2e` | Background |
| Text | `#cdd6f4` | Foreground |
| Rosewater | `#f5e0dc` | Cursor/Selection |
| Red | `#f38ba8` | Error messages |
| Green | `#a6e3a1` | Success messages |
| Yellow | `#f9e2af` | Warnings |
| Blue | `#89b4fa` | Information |

### ANSI Colors (0-15)
Complete 16-color palette ensures compatibility with all terminal applications.

## Font Configuration

### Primary Font: JetBrains Mono

**Features**:
- Programming ligatures (→, ≠, ≥, etc.)
- Excellent readability
- Complete Unicode coverage
- Multiple weights and styles

**Installation**:
```bash
# macOS (via Homebrew)
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono

# Manual installation
# Download from: https://github.com/JetBrains/JetBrainsMono
```

### Fallback Fonts
1. Fira Code
2. SF Mono (macOS)
3. Menlo (macOS)
4. Consolas (Windows)
5. System monospace

## Performance Optimization

### Alacritty
- Hardware acceleration enabled
- Minimal input delay (3ms)
- Efficient scrollback management
- Optimized rendering pipeline

### Kitty
- GPU acceleration
- Efficient font rendering
- Minimal repaint delay (10ms)
- Sync to monitor refresh rate

### General Optimizations
- Reduced scrollback when not needed
- Disabled unnecessary visual effects
- Optimized color calculations
- Efficient memory usage

## Keyboard Shortcuts

### Common Shortcuts (All Terminals)
| Shortcut | Action |
|----------|--------|
| `Cmd+C` | Copy |
| `Cmd+V` | Paste |
| `Cmd+T` | New tab/window |
| `Cmd+W` | Close tab/window |
| `Cmd++` | Increase font size |
| `Cmd+-` | Decrease font size |
| `Cmd+0` | Reset font size |

### Alacritty Specific
| Shortcut | Action |
|----------|--------|
| `Cmd+F` | Search forward |
| `Cmd+B` | Search backward |
| `Cmd+K` | Clear screen |

### Kitty Specific
| Shortcut | Action |
|----------|--------|
| `Cmd+Enter` | New window |
| `Cmd+]` | Next window |
| `Cmd+[` | Previous window |
| `Cmd+.` | Move tab forward |
| `Cmd+,` | Move tab backward |

## Shell Integration

### Zsh Integration
- Prompt theming with Catppuccin colors
- True color support
- Terminal title updates
- History sharing between sessions

### Bash Integration
- Simplified prompt with git integration
- Color support for ls, grep, etc.
- Terminal title management

### Environment Variables
```bash
export TERM="xterm-256color"
export COLORTERM="truecolor"
```

## Troubleshooting

### Common Issues

#### Colors Not Displaying Correctly
1. Check `COLORTERM` environment variable:
   ```bash
   echo $COLORTERM  # Should show "truecolor"
   ```
2. Verify terminal supports 24-bit color:
   ```bash
   ./scripts/validate-terminals.sh --colors
   ```
3. Update terminal to latest version

#### Font Issues
1. Verify font installation:
   ```bash
   # macOS
   system_profiler SPFontsDataType | grep -i jetbrains
   
   # Linux
   fc-list | grep -i jetbrains
   ```
2. Clear font cache (Linux):
   ```bash
   fc-cache -fv
   ```
3. Restart terminal application

#### Performance Issues
1. Check hardware acceleration:
   - Alacritty: Verify GPU support
   - Kitty: Check GPU acceleration settings
2. Reduce background opacity
3. Decrease scrollback buffer size
4. Close unnecessary tabs/windows

#### Configuration Not Loading
1. Check file paths and permissions
2. Verify configuration syntax:
   ```bash
   ./scripts/validate-terminals.sh
   ```
3. Review terminal logs for errors
4. Reset to default configuration and reapply

### Validation Tools

#### Quick Validation
```bash
# Check all configurations
./scripts/validate-terminals.sh

# Specific tests
./scripts/validate-terminals.sh --colors
./scripts/validate-terminals.sh --fonts
./scripts/validate-terminals.sh --performance
```

#### Manual Tests
```bash
# Test true color support
echo -e "\033[38;2;255;100;0mTRUECOLOR\033[0m"

# Test 256 colors
for i in {0..255}; do printf "\x1b[48;5;%sm%3d\e[0m " "$i" "$i"; if (( i == 15 )) || (( i > 15 )) && (( (i-15) % 6 == 0 )); then printf "\n"; fi; done

# Test font ligatures
echo "=> -> != == >= <= && ||"
```

## Customization

### Changing Colors
1. Edit theme file: `themes/terminal/catppuccin-mocha.yaml`
2. Update terminal configs with new colors
3. Restart terminals to apply changes

### Font Customization
1. Update font family in terminal configs
2. Adjust font size for your display
3. Configure ligature settings if needed

### Performance Tuning
1. Adjust repaint delay in configs
2. Modify scrollback buffer size
3. Enable/disable hardware acceleration

### Adding New Terminals
1. Create configuration in appropriate directory
2. Add terminal to setup script
3. Include validation in validation script
4. Update documentation

## Advanced Configuration

### tmux Integration
All terminals are configured to work seamlessly with tmux:
- True color pass-through
- Mouse support
- Proper key binding handling
- Terminal title updates

### SSH and Remote Work
Optimized for remote development:
- Reduced latency settings
- Efficient rendering
- Proper locale handling
- Color preservation over SSH

### Multi-Monitor Setup
- Proper DPI handling
- Consistent font rendering
- Appropriate window sizing
- Color accuracy across displays

## Migration and Backup

### Backup Existing Configurations
```bash
# Automatic backup
./scripts/setup-terminals.sh --backup

# Manual backup
mkdir -p ~/.config/terminal-backups/$(date +%Y%m%d)
cp ~/.config/alacritty/alacritty.yml ~/.config/terminal-backups/$(date +%Y%m%d)/
cp ~/.config/kitty/kitty.conf ~/.config/terminal-backups/$(date +%Y%m%d)/
```

### Restore Configurations
```bash
# From backup
cp ~/.config/terminal-backups/YYYYMMDD/* ~/.config/

# From dotfiles
./scripts/setup-terminals.sh --force
```

## Contributing

### Adding New Features
1. Update relevant configuration files
2. Add validation tests
3. Update documentation
4. Test across all terminals

### Reporting Issues
Include the following information:
- Terminal emulator and version
- Operating system
- Configuration file locations
- Error messages or unexpected behavior
- Output of validation script

## References

- [Alacritty Documentation](https://github.com/alacritty/alacritty)
- [Kitty Documentation](https://sw.kovidgoyal.net/kitty/)
- [iTerm2 Documentation](https://iterm2.com/documentation.html)
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)
- [JetBrains Mono Font](https://github.com/JetBrains/JetBrainsMono)

## Support

For issues with terminal configurations:
1. Run validation script to identify problems
2. Check troubleshooting section above
3. Review configuration files for syntax errors
4. Consult terminal-specific documentation
5. Report persistent issues with full context 