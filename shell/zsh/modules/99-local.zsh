# Local Overrides Module
# Machine-specific configurations and overrides

# This file serves as a template for local customizations
# Copy this to ~/.zshrc.local for machine-specific settings

# Example local configurations:

# Machine-specific environment variables
# export CUSTOM_VAR="value"

# Machine-specific aliases
# alias custom-command='some command'

# Machine-specific functions
# custom-function() {
#     echo "This is a custom function"
# }

# Work-specific configurations
# if [[ "$(hostname)" == "work-machine" ]]; then
#     export WORK_SPECIFIC_VAR="value"
#     alias work-alias='work command'
# fi

# Development environment overrides
# export EDITOR="code"  # Override default editor
# export BROWSER="firefox"  # Override default browser

# Additional PATH entries
# export PATH="$HOME/custom/bin:$PATH"

# Load work-specific configurations if they exist
if [[ -f "$HOME/.zshrc.work" ]]; then
    source "$HOME/.zshrc.work"
fi

# Load project-specific configurations if they exist
if [[ -f "$HOME/.zshrc.projects" ]]; then
    source "$HOME/.zshrc.projects"
fi

# Load secret configurations (should use secret injection instead)
# if [[ -f "$HOME/.zshrc.secrets" ]]; then
#     source "$HOME/.zshrc.secrets"
# fi

# Performance testing (uncomment to enable)
# if [[ -n "$ZSH_STARTUP_TIME" ]]; then
#     echo "Zsh startup time: $(( $(date +%s%N) - $ZSH_STARTUP_TIME )) nanoseconds"
# fi

# Additional integrations that might be machine-specific
# Source gitsign configuration if it exists
if [[ -f "$HOME/.config/gitsign/include.sh" ]]; then
    source "$HOME/.config/gitsign/include.sh"
fi

# Load any additional local modules
if [[ -d "$HOME/.config/zsh/local" ]]; then
    for local_module in "$HOME/.config/zsh/local"/*.zsh; do
        [[ -r "$local_module" ]] && source "$local_module"
    done
fi 