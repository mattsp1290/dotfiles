# Customization Guide

This guide explains how to customize and extend the dotfiles configuration to match your preferences and workflow.

## Personal Configuration File

Create `~/.config/dotfiles/personal.yml` for your customizations:

```yaml
# Personal Information
user:
  name: "Your Name"
  email: "your.email@example.com"
  github_username: "yourusername"

# Shell Preferences  
shell:
  default: "zsh"
  theme: "powerlevel10k"
  plugins:
    - git
    - docker
    - kubectl
    - terraform

# Development Tools
tools:
  editor: "nvim"
  terminal: "alacritty"
  multiplexer: "tmux"
  
# Git Configuration
git:
  default_branch: "main"
  signing_key: "{{ op://Personal/Git GPG Key/private_key }}"
  merge_tool: "vimdiff"

# SSH Configuration  
ssh:
  key_algorithm: "ed25519"
  hosts:
    work:
      hostname: "work.example.com"
      user: "{{ op://Work/SSH/username }}"
      key: "~/.ssh/work_ed25519"

# Package Preferences
packages:
  programming:
    - python
    - nodejs  
    - go
    - rust
  tools:
    - docker
    - kubernetes-cli
    - terraform
    - ansible
```

## Environment-Specific Profiles

### Work Profile (`~/.config/dotfiles/profiles/work.yml`)

```yaml
extends: "base"

git:
  user:
    name: "Your Name"
    email: "your.name@company.com"
  
ssh:
  hosts:
    work-server:
      hostname: "server.company.com"
      user: "{{ op://Work/SSH/username }}"

tools:
  additional:
    - company-vpn-client
    - enterprise-security-tools
```

### Personal Profile (`~/.config/dotfiles/profiles/personal.yml`)

```yaml
extends: "base"

git:
  user:
    name: "Your Name"  
    email: "your.personal@email.com"
    
shell:
  aliases:
    homelab: "ssh homelab.local"
    backup: "rsync -av ~ /backup/drive/"
```

## Component-Specific Customization

### Shell Customization

```bash
# Add custom aliases (automatically loaded)
echo 'alias myapp="cd ~/code/myapp && code ."' >> ~/.config/shell/aliases.local

# Add custom functions
cat >> ~/.config/shell/functions.local << 'EOF'
# Quick project switcher
proj() {
  cd "$HOME/code/$1" && code .
}
EOF

# Add environment variables
echo 'export MY_API_KEY="{{ op://Personal/API Keys/my_service }}"' >> ~/.config/shell/env.local
```

### Git Customization

```bash
# Add custom Git aliases
git config --global alias.changelog "log --oneline --decorate --graph"
git config --global alias.unstage "reset HEAD --"

# Configure signing
git config --global user.signingkey "$(op read 'op://Personal/Git GPG Key/key_id')"
git config --global commit.gpgsign true
```

### Editor Configuration

```bash
# Neovim custom configuration
mkdir -p ~/.config/nvim/lua/custom
cat >> ~/.config/nvim/lua/custom/init.lua << 'EOF'
-- Custom Neovim configuration
vim.opt.relativenumber = true
vim.opt.wrap = false

-- Custom keybindings
vim.keymap.set('n', '<leader>t', ':terminal<CR>')
EOF
```

## Theme and Appearance Customization

### Terminal Themes

```bash
# Switch to different color scheme
dotfiles theme set dracula
dotfiles theme set nord
dotfiles theme set solarized-dark

# List available themes
dotfiles theme list

# Create custom theme
dotfiles theme create mytheme --base-theme dracula
```

### Shell Prompt Customization

```bash
# Powerlevel10k configuration
p10k configure

# Or use custom prompt
echo 'PROMPT="%F{blue}%n@%m%f:%F{green}%~%f$ "' >> ~/.config/shell/prompt.local
```

## Secret Management

### 1Password Integration

```bash
# Reference secrets in templates
git_signing_key: "{{ op://Personal/Git GPG Key/private_key }}"
api_token: "{{ op://Work/API Tokens/github_token }}"

# Inject secrets into configurations
dotfiles secrets inject
dotfiles secrets validate
```

### Local Overrides

All configuration files support local overrides:

- `~/.config/shell/aliases.local`
- `~/.config/shell/functions.local`
- `~/.config/shell/env.local`
- `~/.config/git/config.local`
- `~/.config/ssh/config.local`

## Advanced Customization

### Custom Stow Packages

Create your own stow packages in the repository:

```bash
# Create custom package
mkdir -p ~/.dotfiles/mypackage/.config/myapp
echo "custom_config = true" > ~/.dotfiles/mypackage/.config/myapp/config.yml

# Stow the package
cd ~/.dotfiles
stow mypackage
```

### Custom Installation Scripts

Add custom setup scripts:

```bash
# Create custom setup script
cat > ~/.dotfiles/scripts/setup/my-tools.sh << 'EOF'
#!/usr/bin/env bash

# Install custom tools
if command -v brew &> /dev/null; then
    brew install my-custom-tool
elif command -v apt &> /dev/null; then
    sudo apt install my-custom-tool
fi
EOF

chmod +x ~/.dotfiles/scripts/setup/my-tools.sh
```

### Custom Templates

Create custom templates in `~/.dotfiles/templates/`:

```yaml
# ~/.dotfiles/templates/myapp/config.yaml.tmpl
database:
  host: "{{ op://Personal/Database/host }}"
  password: "{{ op://Personal/Database/password }}"
  
api:
  key: "{{ op://Personal/API Keys/myapp }}"
```

## Testing Customizations

```bash
# Test shell configuration
bash ~/.dotfiles/shell/bash/test-config.bash
zsh ~/.dotfiles/shell/zsh/test-config.sh

# Test template rendering
dotfiles template validate
dotfiles template render --dry-run

# Run security scan
dotfiles security scan
```

## Sharing Customizations

### Team Configurations

Create team-specific configurations:

```bash
# Create team profile
mkdir -p ~/.dotfiles/profiles/team
cat > ~/.dotfiles/profiles/team/base.yml << 'EOF'
git:
  user:
    name: "Team Name"
    email: "team@company.com"
    
ssh:
  hosts:
    team-server:
      hostname: "team.company.com"
      user: "deploy"
EOF
```

### Contributing Back

If you create useful customizations, consider contributing them back:

1. Fork the repository
2. Add your customization
3. Test thoroughly
4. Submit a pull request

For more information, see [contributing.md](contributing.md).