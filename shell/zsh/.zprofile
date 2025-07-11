# Zsh Profile Configuration
# This file is sourced by login shells before .zshrc

# Ensure .zshenv is sourced (some systems might not source it automatically)
[[ -f ~/.zshenv ]] && source ~/.zshenv

# Source /etc/profile if it exists (for system-wide settings)
[[ -f /etc/profile ]] && source /etc/profile

# Source ~/.profile if it exists (for compatibility with other shells)
[[ -f ~/.profile ]] && source ~/.profile

# Additional login-specific setup can go here
# (Most configuration should be in .zshenv or .zshrc instead) 