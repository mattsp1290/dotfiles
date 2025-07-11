# Local Overrides Module - Bash Compatible
# Machine-specific customizations and local configuration

# This file provides a place for local customizations that shouldn't be committed
# to version control. It's loaded last to allow overriding any previous settings.

# Example local customizations (uncomment and modify as needed):

# Custom aliases for this machine
# alias work='cd /path/to/work/directory'
# alias myproject='cd /path/to/my/project'

# Machine-specific environment variables
# export LOCAL_DEV_SERVER="http://localhost:3000"
# export CUSTOM_API_KEY="your-api-key-here"

# Custom functions for this machine
# myfunction() {
#     echo "This is a local function"
# }

# Override default behavior
# alias ls='ls -la'  # Always show hidden files and detailed info
# export EDITOR='code'  # Use VS Code as default editor

# Add local bin directories (if they exist)
if [[ -d "$HOME/local/bin" ]]; then
    export PATH="$HOME/local/bin:$PATH"
fi

if [[ -d "/usr/local/sbin" ]]; then
    export PATH="/usr/local/sbin:$PATH"
fi

# Work-specific configurations
if [[ "$HOSTNAME" == *"work"* ]] || [[ "$HOSTNAME" == *"corp"* ]]; then
    # Work machine specific settings
    export WORK_MODE=true
    
    # Example work-specific aliases
    # alias vpn='sudo openconnect your-vpn-server'
    # alias deploy='./scripts/deploy.sh'
fi

# Development machine configurations
if [[ "$USER" == "dev" ]] || [[ -f "$HOME/.dev_machine" ]]; then
    # Development machine specific settings
    export DEV_MODE=true
    
    # Example dev-specific settings
    # export DEBUG=true
    # export LOG_LEVEL=debug
fi

# Load machine-specific file if it exists
# This allows for even more specific local configuration
if [[ -f "$HOME/.bashrc.$(hostname)" ]]; then
    source "$HOME/.bashrc.$(hostname)"
fi

# Load project-specific configurations
# If you're in a project directory with a .bashrc file, source it
if [[ -f "$PWD/.bashrc" ]] && [[ "$PWD" != "$HOME" ]]; then
    # Only source if it's safe (owned by user and not world-writable)
    if [[ -O "$PWD/.bashrc" ]] && [[ ! -w "$PWD/.bashrc" || "$(stat -c '%a' "$PWD/.bashrc" 2>/dev/null)" != *[2367]* ]]; then
        source "$PWD/.bashrc"
    fi
fi

# Performance: Load local completions if they exist
if [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
    for completion in "$HOME/.local/share/bash-completion/completions"/*; do
        [[ -r "$completion" ]] && source "$completion"
    done
fi

# Load additional local modules if directory exists
if [[ -d "$HOME/.bash/local" ]]; then
    for local_module in "$HOME/.bash/local"/*.bash; do
        [[ -r "$local_module" ]] && source "$local_module"
    done
fi

# Note: This file is meant to be customized for your specific needs.
# The examples above are just suggestions - uncomment and modify as needed.
# You can also create additional files in ~/.bash/local/ for more organization. 