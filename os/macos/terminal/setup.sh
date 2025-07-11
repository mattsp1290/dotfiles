#!/bin/bash
# Terminal.app Configuration Script
# Configures macOS Terminal.app with Catppuccin Mocha theme and optimal settings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Terminal.app is running
check_terminal_running() {
    if pgrep -x "Terminal" > /dev/null; then
        log_warning "Terminal.app is currently running"
        read -p "Close Terminal.app to apply settings? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            osascript -e 'tell application "Terminal" to quit'
            sleep 2
        else
            log_error "Cannot apply settings while Terminal.app is running"
            exit 1
        fi
    fi
}

# Create Catppuccin Mocha profile for Terminal.app
create_catppuccin_profile() {
    log_info "Creating Catppuccin Mocha profile for Terminal.app..."
    
    # Profile name
    PROFILE_NAME="Catppuccin Mocha"
    
    # Create new terminal profile
    /usr/libexec/PlistBuddy -c "Add :Window\ Settings:$PROFILE_NAME dict" ~/Library/Preferences/com.apple.Terminal.plist 2>/dev/null || true
    
    # Basic settings
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:name string '$PROFILE_NAME'" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:type string 'Window Settings'" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Font settings - JetBrains Mono
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:Font data YnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5TU2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNsYXNzI0AqAAAAAAAAEBCAAoADXxAMSmV0QnJhaW5zIE1vbm/SExQVFlokY2xhc3NuYW1lWCRjbGFzc2VzVk5TRm9udKIVF1hOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEaG1Ryb290gAEIERojLTI3PEJLUllgaWttdniGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAHAAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Window size
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:columnCount integer 120" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:rowCount integer 40" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Background color (Catppuccin Mocha base)
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:BackgroundColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjExNzY0NzA2MDIgMC4xMTc2NDcwNjAyIDAuMTgwMzkyMTU5OCAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Text color (Catppuccin Mocha text)
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:TextColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjgwMzkyMTU3MjIgMC44Mzk0MDA2OTQ0IDAuOTU2ODYyOTIxOCAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Bold text color
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:TextBoldColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjgwMzkyMTU3MjIgMC44Mzk0MDA2OTQ0IDAuOTU2ODYyOTIxOCAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Selection color (Catppuccin Mocha rosewater)
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:SelectionColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk2MDc4NDQ5NDEgMC44NzQ1MTAxMDE2IDAuODYyNzQ1MjIzNSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Cursor color (Catppuccin Mocha rosewater)
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:CursorColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk2MDc4NDQ5NDEgMC44NzQ1MTAxMDE2IDAuODYyNzQ1MjIzNSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # ANSI colors (Catppuccin Mocha palette)
    # Black (surface1)
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBlackColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjI3MDU4ODIzNTMgMC4yNzgzNjI0NzY4IDAuMzUyOTQxMTc2NSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Red
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIRedColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk1Mjk0MTI1ODggMC41NDUwOTc5OTkyIDAuNjU4ODIzNTc2NSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Green
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIGreenColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjY1MDk4MDQzMTggMC44OTAyNDIzMjgxIDAuNjMxMzcyNjUwOCAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Yellow
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIYellowColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk3NjQ3MDY2MTQgMC44ODYyNzQ1NDkgMC42ODYyNzQ1Mjk4IDEAEAKAA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjdCTE9idHl3foaLlp+qrbG5zM/UAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANc=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Blue
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBlueColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjUzNzI1NDkxNjkgMC43MDU4ODI0MDY2IDAuOTgwMzkyMTU2OSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Magenta
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIMagentaColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk2MDc4NDQ5NDEgMC43NTY4NjI3NjU5IDAuOTA1ODgyNDE2NSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Cyan
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSICyanColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjU4MDM5MjE1MzkgMC44ODYyNzQ1NDkgMC44MzUyOTQxMzI1IDEAEAKAA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjdCTE9idHl3foaLlp+qrbG5zM/UAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANc=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # White
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIWhiteColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjcyOTQxMTgyMDUgMC43NjA3ODQzNjEyIDAuODcwNTg4MjQ0NyAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Bright black
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightBlackColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjM0NTA5ODA0MjEgMC4zNTY4NjI3NjAzIDAuNDM5MjE1Njg5OSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Bright colors (same as normal colors for Catppuccin)
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightRedColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk1Mjk0MTI1ODggMC41NDUwOTc5OTkyIDAuNjU4ODIzNTc2NSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightGreenColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjY1MDk4MDQzMTggMC44OTAyNDIzMjgxIDAuNjMxMzcyNjUwOCAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightYellowColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk3NjQ3MDY2MTQgMC44ODYyNzQ1NDkgMC42ODYyNzQ1Mjk4IDEAEAKABoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjdCTE9idHl3foaLlp+qrbG5zM/UAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANc=" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightBlueColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjUzNzI1NDkxNjkgMC43MDU4ODI0MDY2IDAuOTgwMzkyMTU2OSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightMagentaColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjk2MDc4NDQ5NDEgMC43NTY4NjI3NjU5IDAuOTA1ODgyNDE2NSAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightCyanColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjU4MDM5MjE1MzkgMC44ODYyNzQ1NDkgMC44MzUyOTQxMzI1IDEAEAKABoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjdCTE9idHl3foaLlp+qrbG5zM/UAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANc=" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ANSIBrightWhiteColor data YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECcwLjY1MDk4MDU2OTUgMC42ODIzNTMwNDE1IDAuNzY4NjI3NTc3MiAxABACgAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3PEJITltiaXJ0dneGi5afpqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM4=" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Other settings
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:useOptionAsMetaKey bool true" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ScrollbackLines integer 10000" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:ShowWindowSettingsNameInTitle bool false" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Window\ Settings:$PROFILE_NAME:shellExitAction integer 1" ~/Library/Preferences/com.apple.Terminal.plist
    
    # Set as default profile
    /usr/libexec/PlistBuddy -c "Set :Default\ Window\ Settings string '$PROFILE_NAME'" ~/Library/Preferences/com.apple.Terminal.plist
    /usr/libexec/PlistBuddy -c "Set :Startup\ Window\ Settings string '$PROFILE_NAME'" ~/Library/Preferences/com.apple.Terminal.plist
    
    log_success "Created Catppuccin Mocha profile for Terminal.app"
}

# Apply additional Terminal.app settings
apply_terminal_settings() {
    log_info "Applying additional Terminal.app settings..."
    
    # General settings
    defaults write com.apple.terminal StringEncodings -array 4  # UTF-8
    defaults write com.apple.terminal "Default Window Settings" -string "Catppuccin Mocha"
    defaults write com.apple.terminal "Startup Window Settings" -string "Catppuccin Mocha"
    
    # Shell behavior
    defaults write com.apple.terminal ShellExitAction -int 1  # Close if shell exited cleanly
    defaults write com.apple.terminal SecureKeyboardEntry -bool false
    
    log_success "Applied additional Terminal.app settings"
}

# Main execution
main() {
    log_info "Setting up Terminal.app with Catppuccin Mocha theme..."
    
    # Check if Terminal is running
    check_terminal_running
    
    # Create profile and apply settings
    create_catppuccin_profile
    apply_terminal_settings
    
    log_success "Terminal.app setup complete!"
    log_info "Restart Terminal.app to see the changes"
    log_info "The Catppuccin Mocha profile is now the default"
}

# Run main function
main "$@" 