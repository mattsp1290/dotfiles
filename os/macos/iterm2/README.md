# iTerm2 Configuration

This directory contains iTerm2 configuration files and profiles for consistent terminal setup on macOS.

## Quick Setup

### Export Current Preferences
```bash
# Export current iTerm2 preferences
defaults export com.googlecode.iterm2 ~/Desktop/com.googlecode.iterm2.plist
```

### Import Preferences
```bash
# Import iTerm2 preferences
defaults import com.googlecode.iterm2 "$DOTFILES_DIR/os/macos/iterm2/com.googlecode.iterm2.plist"
```

### Manual Configuration

1. Open iTerm2 → Preferences (⌘,)
2. Go to General → Preferences
3. Check "Load preferences from a custom folder or URL"
4. Set the folder to: `$DOTFILES_DIR/os/macos/iterm2/`
5. Restart iTerm2

## Features

- **Catppuccin Mocha theme** - Consistent with editor and other terminals
- **JetBrains Mono font** - Programming font with ligatures
- **Optimized performance** - Fast rendering and low latency
- **Custom key bindings** - Consistent with other terminal emulators
- **Multiple profiles** - Development, presentation, and minimal profiles
- **Shell integration** - Enhanced zsh integration

## Profiles

### Development Profile
- Full feature set with status bar
- Transparent background for visual appeal
- All productivity features enabled

### Presentation Profile
- Clean appearance for screen sharing
- Larger font size for visibility
- Minimal distractions

### Minimal Profile
- Fastest performance
- Reduced visual elements
- Optimized for SSH/remote work

## Customization

To customize colors or add new profiles:

1. Make changes in iTerm2 preferences
2. Export updated preferences:
   ```bash
   defaults export com.googlecode.iterm2 "$DOTFILES_DIR/os/macos/iterm2/com.googlecode.iterm2.plist"
   ```
3. Commit changes to dotfiles repository

## Troubleshooting

### Preferences Not Loading
- Ensure iTerm2 is completely quit before importing
- Check file permissions on the plist file
- Verify the path in iTerm2 preferences

### Font Issues
- Ensure JetBrains Mono is installed system-wide
- Fallback fonts: Fira Code, SF Mono, Menlo

### Performance Issues
- Disable transparency if experiencing lag
- Reduce scrollback buffer size
- Check for background processes affecting performance 