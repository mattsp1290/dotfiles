#!/usr/bin/env bash
# Environment setup utilities for dotfiles testing framework
# Manages test environments, fixtures, and configurations

set -euo pipefail

# Source test utilities
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Environment constants
readonly TEST_ENV_PREFIX="dotfiles_env_"
readonly FIXTURE_DIR="$TEST_ROOT_DIR/fixtures"

# Environment state
CURRENT_TEST_ENV=""
TEST_ENVIRONMENTS=()

# Create new test environment
create_test_environment() {
    local env_name="${1:-$(date +%s)}"
    local env_dir="$TEST_TEMP_DIR/env_$env_name"
    
    mkdir -p "$env_dir"
    CURRENT_TEST_ENV="$env_dir"
    TEST_ENVIRONMENTS+=("$env_dir")
    
    # Set up basic directory structure
    mkdir -p "$env_dir"/{home,dotfiles,config,data,cache}
    mkdir -p "$env_dir/dotfiles"/{vim,zsh,git,tmux}
    
    test_debug "Created test environment: $env_dir"
    echo "$env_dir"
}

# Activate test environment
activate_test_environment() {
    local env_dir="${1:-$CURRENT_TEST_ENV}"
    
    if [[ ! -d "$env_dir" ]]; then
        test_error "Test environment does not exist: $env_dir"
        return 1
    fi
    
    # Set environment variables
    export TEST_HOME="$env_dir/home"
    export TEST_DOTFILES_DIR="$env_dir/dotfiles"
    export TEST_XDG_CONFIG_HOME="$env_dir/config"
    export TEST_XDG_DATA_HOME="$env_dir/data"
    export TEST_XDG_CACHE_HOME="$env_dir/cache"
    
    # Change to environment directory
    cd "$env_dir"
    CURRENT_TEST_ENV="$env_dir"
    
    test_debug "Activated test environment: $env_dir"
}

# Deactivate test environment
deactivate_test_environment() {
    unset TEST_HOME TEST_DOTFILES_DIR TEST_XDG_CONFIG_HOME
    unset TEST_XDG_DATA_HOME TEST_XDG_CACHE_HOME
    
    cd "$TEST_ORIGINAL_PWD"
    CURRENT_TEST_ENV=""
    
    test_debug "Deactivated test environment"
}

# Create test dotfiles structure
create_dotfiles_structure() {
    local base_dir="${1:-$TEST_DOTFILES_DIR}"
    
    # Create package directories
    local packages=("vim" "zsh" "git" "tmux" "ssh")
    
    for package in "${packages[@]}"; do
        mkdir -p "$base_dir/$package"
        
        case "$package" in
            vim)
                create_vim_package "$base_dir/$package"
                ;;
            zsh)
                create_zsh_package "$base_dir/$package"
                ;;
            git)
                create_git_package "$base_dir/$package"
                ;;
            tmux)
                create_tmux_package "$base_dir/$package"
                ;;
            ssh)
                create_ssh_package "$base_dir/$package"
                ;;
        esac
    done
    
    test_debug "Created dotfiles structure in: $base_dir"
}

# Create vim package
create_vim_package() {
    local package_dir="$1"
    
    cat > "$package_dir/.vimrc" << 'EOF'
" Test vim configuration
set nocompatible
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab

" Basic key mappings
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Test plugin configuration
if has('syntax')
    syntax enable
endif
EOF
    
    mkdir -p "$package_dir/.vim"/{colors,plugin,autoload}
    
    cat > "$package_dir/.vim/plugin/test.vim" << 'EOF'
" Test vim plugin
if exists('g:loaded_test_plugin')
    finish
endif
let g:loaded_test_plugin = 1

command! TestCommand echo "Test plugin loaded"
EOF
}

# Create zsh package
create_zsh_package() {
    local package_dir="$1"
    
    cat > "$package_dir/.zshrc" << 'EOF'
# Test zsh configuration
export ZSH_THEME="test"
export EDITOR="vim"
export PAGER="less"

# Aliases
alias ll='ls -la'
alias la='ls -la'
alias grep='grep --color=auto'

# Functions
test_function() {
    echo "Test function called with: $*"
}

# Test plugin loading
if [[ -f ~/.zsh/plugins/test.zsh ]]; then
    source ~/.zsh/plugins/test.zsh
fi
EOF
    
    mkdir -p "$package_dir/.zsh"/{themes,plugins,functions}
    
    cat > "$package_dir/.zsh/plugins/test.zsh" << 'EOF'
# Test zsh plugin
export TEST_PLUGIN_LOADED=1

test_plugin_function() {
    echo "Test plugin function"
}
EOF
}

# Create git package
create_git_package() {
    local package_dir="$1"
    
    cat > "$package_dir/.gitconfig" << 'EOF'
[user]
    name = Test User
    email = test@example.com

[core]
    editor = vim
    pager = less
    excludesfile = ~/.gitignore_global

[push]
    default = simple

[pull]
    rebase = false

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --decorate
EOF
    
    cat > "$package_dir/.gitignore_global" << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/
EOF
}

# Create tmux package
create_tmux_package() {
    local package_dir="$1"
    
    cat > "$package_dir/.tmux.conf" << 'EOF'
# Test tmux configuration
set -g default-terminal "screen-256color"
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Window and pane settings
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Key bindings
bind | split-window -h
bind - split-window -v
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M'
EOF
}

# Create ssh package
create_ssh_package() {
    local package_dir="$1"
    
    mkdir -p "$package_dir/.ssh"
    
    cat > "$package_dir/.ssh/config" << 'EOF'
# Test SSH configuration
Host test-server
    HostName test.example.com
    User testuser
    Port 22
    IdentityFile ~/.ssh/test_key

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ForwardAgent yes
EOF
    
    # Create mock SSH key files (empty for testing)
    touch "$package_dir/.ssh/test_key"
    touch "$package_dir/.ssh/test_key.pub"
    chmod 600 "$package_dir/.ssh/test_key"
    chmod 644 "$package_dir/.ssh/test_key.pub"
}

# Create test configuration files
create_test_configs() {
    local config_dir="${1:-$TEST_XDG_CONFIG_HOME}"
    
    mkdir -p "$config_dir"/{nvim,alacritty,kitty,code}
    
    # Neovim config
    cat > "$config_dir/nvim/init.vim" << 'EOF'
" Test Neovim configuration
set number
set relativenumber
set tabstop=2
set shiftwidth=2
set expandtab
EOF
    
    # Alacritty config
    cat > "$config_dir/alacritty/alacritty.yml" << 'EOF'
# Test Alacritty configuration
window:
  padding:
    x: 10
    y: 10

font:
  normal:
    family: monospace
  size: 12.0

colors:
  primary:
    background: '0x2e3440'
    foreground: '0xd8dee9'
EOF
    
    test_debug "Created test configurations in: $config_dir"
}

# Create test secrets templates
create_test_secrets() {
    local secrets_dir="${1:-$TEST_DOTFILES_DIR/templates}"
    
    mkdir -p "$secrets_dir"
    
    cat > "$secrets_dir/.env.template" << 'EOF'
# Test environment secrets template
GITHUB_TOKEN="op://Development/API Keys/github_token"
OPENAI_API_KEY="op://Development/API Keys/openai_key"
DATABASE_URL="op://Development/Database/connection_string"
EOF
    
    cat > "$secrets_dir/.gitconfig.template" << 'EOF'
[user]
    name = Test User
    email = test@example.com
    signingkey = "op://Development/GPG Keys/git_signing_key"

[github]
    user = testuser
    token = "op://Development/API Keys/github_token"
EOF
    
    test_debug "Created test secrets templates in: $secrets_dir"
}

# Simulate OS environment
simulate_os_environment() {
    local os_type="${1:-macos}"
    local os_version="${2:-latest}"
    
    case "$os_type" in
        macos)
            export OSTYPE="darwin21"
            export SIMULATED_OS="Darwin"
            export SIMULATED_VERSION="12.6"
            # Mock macOS-specific commands
            mock_command "sw_vers" 'echo "ProductName: macOS"; echo "ProductVersion: 12.6"'
            mock_command "defaults" 'echo "Mock defaults command"'
            ;;
        ubuntu)
            export OSTYPE="linux-gnu"
            export SIMULATED_OS="Linux"
            export SIMULATED_VERSION="20.04"
            # Mock Ubuntu-specific files
            mkdir -p "$TEST_TEMP_DIR/etc"
            echo "Ubuntu 20.04.5 LTS" > "$TEST_TEMP_DIR/etc/os-release"
            ;;
        fedora)
            export OSTYPE="linux-gnu"
            export SIMULATED_OS="Linux"
            export SIMULATED_VERSION="36"
            # Mock Fedora-specific files
            mkdir -p "$TEST_TEMP_DIR/etc"
            echo "Fedora Linux 36" > "$TEST_TEMP_DIR/etc/os-release"
            ;;
        arch)
            export OSTYPE="linux-gnu"
            export SIMULATED_OS="Linux"
            export SIMULATED_VERSION="rolling"
            # Mock Arch-specific files
            mkdir -p "$TEST_TEMP_DIR/etc"
            echo "Arch Linux" > "$TEST_TEMP_DIR/etc/os-release"
            ;;
    esac
    
    test_debug "Simulated OS environment: $os_type $os_version"
}

# Create test fixture from template
create_fixture() {
    local fixture_name="$1"
    local target_path="${2:-$CURRENT_TEST_ENV}"
    local fixture_path="$FIXTURE_DIR/$fixture_name"
    
    if [[ ! -d "$fixture_path" ]]; then
        test_error "Fixture not found: $fixture_name"
        return 1
    fi
    
    cp -r "$fixture_path"/* "$target_path/"
    test_debug "Applied fixture '$fixture_name' to: $target_path"
}

# Save current environment as fixture
save_as_fixture() {
    local fixture_name="$1"
    local source_path="${2:-$CURRENT_TEST_ENV}"
    local fixture_path="$FIXTURE_DIR/$fixture_name"
    
    mkdir -p "$fixture_path"
    cp -r "$source_path"/* "$fixture_path/"
    
    test_debug "Saved fixture '$fixture_name' from: $source_path"
}

# List available fixtures
list_fixtures() {
    if [[ -d "$FIXTURE_DIR" ]]; then
        find "$FIXTURE_DIR" -maxdepth 1 -type d -exec basename {} \; | grep -v "^fixtures$" | sort
    fi
}

# Validate environment setup
validate_environment() {
    local env_dir="${1:-$CURRENT_TEST_ENV}"
    
    local errors=()
    
    # Check required directories
    local required_dirs=("home" "dotfiles" "config" "data" "cache")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$env_dir/$dir" ]]; then
            errors+=("Missing directory: $dir")
        fi
    done
    
    # Check environment variables
    local required_vars=("TEST_HOME" "TEST_DOTFILES_DIR")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            errors+=("Missing environment variable: $var")
        fi
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        test_error "Environment validation failed:"
        for error in "${errors[@]}"; do
            test_error "  - $error"
        done
        return 1
    fi
    
    test_debug "Environment validation passed"
    return 0
}

# Clean up all test environments
cleanup_test_environments() {
    for env_dir in "${TEST_ENVIRONMENTS[@]}"; do
        if [[ -d "$env_dir" ]]; then
            rm -rf "$env_dir"
            test_debug "Cleaned up test environment: $env_dir"
        fi
    done
    
    TEST_ENVIRONMENTS=()
    CURRENT_TEST_ENV=""
    deactivate_test_environment
} 