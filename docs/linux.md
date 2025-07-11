# Linux Configuration Guide

A comprehensive guide to Linux system configuration that provides consistent development environments across multiple distributions with automated package management, desktop customization, and cross-distribution compatibility.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Distribution Support](#distribution-support)
- [Package Management](#package-management)
- [Desktop Environment Setup](#desktop-environment-setup)
- [Development Environment](#development-environment)
- [Security Configuration](#security-configuration)
- [Performance Optimization](#performance-optimization)
- [Container Integration](#container-integration)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [Reference](#reference)

## Overview

The Linux configuration system provides automated setup across major Linux distributions with intelligent package management, desktop environment customization, and development tool integration. It ensures consistent environments while respecting distribution-specific conventions.

### Key Features

- **🐧 Multi-Distribution**: Support for Ubuntu, Debian, Fedora, CentOS, Arch Linux, and derivatives
- **📦 Smart Package Management**: Unified interface across apt, dnf, pacman, and zypper
- **🎨 Desktop Integration**: GNOME, KDE, XFCE, i3wm customization
- **🔧 Development Ready**: Pre-configured development environments
- **🔒 Security Hardened**: Distribution-appropriate security configurations
- **⚡ Performance Tuned**: Optimized for development workflows

### Supported Distributions

| Distribution | Support Level | Package Manager | Desktop |
|--------------|---------------|-----------------|---------|
| **Ubuntu 20.04+** | Full | apt | GNOME/KDE |
| **Debian 11+** | Full | apt | GNOME/KDE/XFCE |
| **Fedora 35+** | Full | dnf | GNOME/KDE |
| **CentOS/RHEL 8+** | Full | dnf | GNOME |
| **Arch Linux** | Full | pacman | Multiple |
| **openSUSE** | Compatible | zypper | KDE/GNOME |

## Architecture

### Configuration Structure

```
os/linux/
├── detect-distro.sh           # Distribution detection
├── package-managers/          # Package management scripts
│   ├── apt.sh                 # Debian/Ubuntu packages
│   ├── dnf.sh                 # Fedora/RHEL packages
│   ├── pacman.sh              # Arch Linux packages
│   └── zypper.sh              # openSUSE packages
├── desktop/                   # Desktop environment configs
│   ├── gnome/                 # GNOME customization
│   ├── kde/                   # KDE Plasma setup
│   ├── xfce/                  # XFCE configuration
│   └── i3/                    # i3wm setup
├── development/               # Development environments
│   ├── languages.sh           # Programming language setup
│   ├── tools.sh               # Development tools
│   └── containers.sh          # Docker/Podman setup
└── security/                  # Security configurations
    ├── firewall.sh            # Firewall setup
    ├── ssh.sh                 # SSH hardening
    └── users.sh               # User management
```

## Quick Start

### Prerequisites

- Linux distribution (see supported list)
- Internet connection
- sudo privileges
- curl or wget

### Installation

```bash
# Via bootstrap (recommended)
./scripts/bootstrap.sh

# Linux-specific setup
./scripts/setup/linux-setup.sh

# Distribution detection
./os/linux/detect-distro.sh
```

### Basic Configuration

```bash
# Auto-detect and configure
cd os/linux && ./setup-linux.sh

# Specific distribution
./setup-linux.sh --distro ubuntu
./setup-linux.sh --distro fedora

# Desktop environment
./setup-linux.sh --desktop gnome
./setup-linux.sh --desktop kde
```

## Distribution Support

### Ubuntu/Debian (APT)

#### Package Installation
```bash
# os/linux/package-managers/apt.sh

# Update package list
sudo apt update

# Essential development packages
apt_packages=(
    # Build tools
    build-essential
    cmake
    ninja-build
    
    # Version control
    git
    git-lfs
    
    # Editors and tools
    neovim
    tmux
    curl
    wget
    jq
    
    # Languages
    python3
    python3-pip
    nodejs
    npm
    
    # System tools
    htop
    tree
    fd-find
    ripgrep
    bat
    
    # Development
    docker.io
    docker-compose
)

sudo apt install -y "${apt_packages[@]}"

# Snap packages
snap_packages=(
    code
    discord
    slack
)

for package in "${snap_packages[@]}"; do
    sudo snap install "$package" --classic
done
```

#### Ubuntu-Specific Optimizations
```bash
# Enable additional repositories
sudo add-apt-repository ppa:git-core/ppa -y
sudo add-apt-repository ppa:neovim-ppa/unstable -y

# Install Ubuntu-specific tools
sudo apt install -y \
    ubuntu-restricted-extras \
    ubuntu-drivers-common \
    software-properties-common
```

### Fedora/RHEL (DNF)

#### Package Installation
```bash
# os/linux/package-managers/dnf.sh

# Enable RPM Fusion
sudo dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Development packages
dnf_packages=(
    # Build tools
    @development-tools
    cmake
    ninja-build
    
    # Languages
    python3
    python3-pip
    nodejs
    npm
    golang
    rust
    cargo
    
    # Editors
    neovim
    tmux
    
    # System tools
    htop
    tree
    fd-find
    ripgrep
    bat
    
    # Containers
    podman
    podman-compose
)

sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y "${dnf_packages[@]}"

# Flatpak applications
flatpak_apps=(
    com.visualstudio.code
    com.slack.Slack
    com.discordapp.Discord
)

for app in "${flatpak_apps[@]}"; do
    flatpak install -y flathub "$app"
done
```

### Arch Linux (Pacman)

#### Package Installation
```bash
# os/linux/package-managers/pacman.sh

# Update system
sudo pacman -Syu --noconfirm

# Base development packages
pacman_packages=(
    # Build tools
    base-devel
    cmake
    ninja
    
    # Languages
    python
    python-pip
    nodejs
    npm
    go
    rust
    
    # Editors
    neovim
    tmux
    
    # Tools
    git
    curl
    wget
    jq
    htop
    tree
    fd
    ripgrep
    bat
    
    # Containers
    docker
    docker-compose
)

sudo pacman -S --noconfirm "${pacman_packages[@]}"

# AUR helper (yay)
if ! command -v yay >/dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
fi

# AUR packages
yay_packages=(
    visual-studio-code-bin
    slack-desktop
    discord
    1password
)

yay -S --noconfirm "${yay_packages[@]}"
```

## Package Management

### Unified Package Interface

#### Cross-Distribution Package Manager
```bash
# scripts/lib/package-manager.sh

detect_package_manager() {
    if command -v apt >/dev/null; then
        echo "apt"
    elif command -v dnf >/dev/null; then
        echo "dnf"
    elif command -v pacman >/dev/null; then
        echo "pacman"
    elif command -v zypper >/dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

install_packages() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        apt)
            sudo apt update
            sudo apt install -y "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$@"
            ;;
        zypper)
            sudo zypper install -y "$@"
            ;;
        *)
            echo "Unsupported package manager"
            return 1
            ;;
    esac
}

update_system() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        apt)
            sudo apt update && sudo apt upgrade -y
            ;;
        dnf)
            sudo dnf upgrade -y
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        zypper)
            sudo zypper update -y
            ;;
    esac
}
```

### Package Lists by Category

#### Development Tools
```yaml
# packages/development.yml
development:
  apt:
    - build-essential
    - cmake
    - ninja-build
    - git
    - neovim
    - tmux
  dnf:
    - "@development-tools"
    - cmake
    - ninja-build
    - git
    - neovim
    - tmux
  pacman:
    - base-devel
    - cmake
    - ninja
    - git
    - neovim
    - tmux
  zypper:
    - patterns-devel-base-devel_basis
    - cmake
    - ninja
    - git
    - neovim
    - tmux
```

#### Programming Languages
```yaml
# packages/languages.yml
languages:
  python:
    apt: [python3, python3-pip, python3-venv]
    dnf: [python3, python3-pip]
    pacman: [python, python-pip]
    zypper: [python3, python3-pip]
  
  nodejs:
    apt: [nodejs, npm]
    dnf: [nodejs, npm]
    pacman: [nodejs, npm]
    zypper: [nodejs, npm]
  
  rust:
    apt: [rustc, cargo]
    dnf: [rust, cargo]
    pacman: [rust]
    zypper: [rust, cargo]
```

## Desktop Environment Setup

### GNOME Configuration

#### GNOME Extensions and Themes
```bash
# os/linux/desktop/gnome/setup.sh

configure_gnome() {
    # Essential GNOME extensions
    gnome_extensions=(
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "dash-to-dock@micxgx.gmail.com"
        "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        "topicons-plus@rpnullptr.com"
    )
    
    # Install extensions
    for extension in "${gnome_extensions[@]}"; do
        gnome-extensions install "$extension"
        gnome-extensions enable "$extension"
    done
    
    # Configure GNOME settings
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.wm.preferences theme 'Adwaita-dark'
    
    # Keyboard shortcuts
    gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['<Ctrl><Alt>t']"
    gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
    
    # Window management
    gsettings set org.gnome.desktop.wm.preferences focus-mode 'click'
    gsettings set org.gnome.desktop.wm.preferences auto-raise false
    
    # Performance optimizations
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.desktop.interface show-battery-percentage true
}
```

### KDE Plasma Configuration

#### KDE Customization
```bash
# os/linux/desktop/kde/setup.sh

configure_kde() {
    # KDE configuration files
    mkdir -p ~/.config
    
    # Panel configuration
    cat > ~/.config/plasma-org.kde.plasma.desktop-appletsrc << 'EOF'
[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
EOF
    
    # Shortcuts
    kwriteconfig5 --file ~/.config/kglobalshortcutsrc \
        --group "org.kde.konsole.desktop" \
        --key "_launch" "Ctrl+Alt+T,none,Konsole"
    
    # Theme
    kwriteconfig5 --file ~/.config/kdeglobals \
        --group "General" \
        --key "ColorScheme" "BreezeDark"
    
    # Window management
    kwriteconfig5 --file ~/.config/kwinrc \
        --group "Windows" \
        --key "FocusPolicy" "ClickToFocus"
}
```

### i3 Window Manager Setup

#### i3 Configuration
```bash
# os/linux/desktop/i3/config

# i3 config file
set $mod Mod4

# Font
font pango:JetBrains Mono 10

# Start applications
exec --no-startup-id dex --autostart --environment i3
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork
exec --no-startup-id nm-applet

# Key bindings
bindsym $mod+Return exec i3-sensible-terminal
bindsym $mod+Shift+q kill
bindsym $mod+d exec dmenu_run

# Window navigation
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# Workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"

bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4

# Window rules
for_window [class="^.*"] border pixel 2
```

## Development Environment

### Language-Specific Setup

#### Python Development
```bash
# Install Python development tools
setup_python() {
    # Install pyenv for version management
    if ! command -v pyenv >/dev/null; then
        curl https://pyenv.run | bash
    fi
    
    # Install latest Python
    pyenv install 3.11.0
    pyenv global 3.11.0
    
    # Essential Python packages
    pip install --user \
        black \
        flake8 \
        mypy \
        pytest \
        jupyter \
        pipenv \
        poetry
}
```

#### Node.js Development
```bash
# Install Node.js development tools
setup_nodejs() {
    # Install nvm for version management
    if ! command -v nvm >/dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    fi
    
    # Install latest LTS Node.js
    nvm install --lts
    nvm use --lts
    
    # Global packages
    npm install -g \
        typescript \
        eslint \
        prettier \
        @vue/cli \
        create-react-app \
        nodemon
}
```

### Container Development

#### Docker Setup
```bash
# os/linux/development/containers.sh

setup_docker() {
    local distro
    distro=$(lsb_release -si 2>/dev/null || echo "Unknown")
    
    case "$distro" in
        "Ubuntu"|"Debian")
            # Install Docker via apt
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            ;;
        "Fedora")
            # Use Podman (preferred on Fedora)
            sudo dnf install -y podman podman-compose
            ;;
        "Arch")
            sudo pacman -S --noconfirm docker docker-compose
            ;;
    esac
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    # Enable Docker service
    sudo systemctl enable --now docker
}
```

## Security Configuration

### Firewall Setup

#### UFW Configuration (Ubuntu/Debian)
```bash
# Configure UFW firewall
setup_ufw() {
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow development ports
    sudo ufw allow 3000:3999/tcp  # Node.js dev servers
    sudo ufw allow 8000:8999/tcp  # Python dev servers
    
    # Enable firewall
    sudo ufw --force enable
}
```

#### Firewalld Configuration (Fedora/RHEL)
```bash
# Configure firewalld
setup_firewalld() {
    sudo systemctl enable --now firewalld
    
    # Default zone
    sudo firewall-cmd --set-default-zone=public
    
    # Allow SSH
    sudo firewall-cmd --permanent --add-service=ssh
    
    # Development ports
    sudo firewall-cmd --permanent --add-port=3000-3999/tcp
    sudo firewall-cmd --permanent --add-port=8000-8999/tcp
    
    # Reload configuration
    sudo firewall-cmd --reload
}
```

### SSH Hardening

#### Secure SSH Configuration
```bash
# Harden SSH configuration
harden_ssh() {
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    cat << 'EOF' | sudo tee -a /etc/ssh/sshd_config
# Security hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
PrintMotd no
ClientAliveInterval 60
ClientAliveCountMax 3
EOF
    
    sudo systemctl restart sshd
}
```

## Performance Optimization

### System Tuning

#### Kernel Parameters
```bash
# Optimize kernel parameters for development
optimize_kernel() {
    cat << 'EOF' | sudo tee /etc/sysctl.d/99-dev-optimizations.conf
# File system optimizations
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288

# Network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Virtual memory optimizations
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-dev-optimizations.conf
}
```

#### I/O Scheduler Optimization
```bash
# Optimize I/O scheduler for SSDs
optimize_io() {
    # Set deadline scheduler for SSDs
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules
    
    # Set CFQ for HDDs
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="cfq"' | sudo tee -a /etc/udev/rules.d/60-ioschedulers.rules
}
```

### Development Environment Optimization

#### Shell Performance
```bash
# Optimize shell startup
optimize_shell() {
    # Lazy load development tools
    cat << 'EOF' >> ~/.bashrc
# Lazy load pyenv
pyenv() {
    unset -f pyenv
    eval "$(command pyenv init -)"
    pyenv "$@"
}

# Lazy load nvm
nvm() {
    unset -f nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm "$@"
}
EOF
}
```

## Container Integration

### Podman Configuration (Fedora)

#### Rootless Containers
```bash
# Configure rootless Podman
setup_podman() {
    # Enable linger for user
    sudo loginctl enable-linger "$USER"
    
    # Configure user namespaces
    echo "$USER:100000:65536" | sudo tee -a /etc/subuid
    echo "$USER:100000:65536" | sudo tee -a /etc/subgid
    
    # Create systemd directory
    mkdir -p ~/.config/systemd/user
    
    # Configure Podman socket
    systemctl --user enable --now podman.socket
}
```

### Development Containers

#### Container-Based Development
```bash
# Create development container
create_dev_container() {
    local language="$1"
    
    case "$language" in
        "python")
            podman run -it --rm \
                -v "$(pwd):/workspace" \
                -w /workspace \
                python:3.11 bash
            ;;
        "node")
            podman run -it --rm \
                -v "$(pwd):/workspace" \
                -w /workspace \
                -p 3000:3000 \
                node:18 bash
            ;;
        "rust")
            podman run -it --rm \
                -v "$(pwd):/workspace" \
                -w /workspace \
                rust:latest bash
            ;;
    esac
}
```

## Troubleshooting

### Common Issues

#### Package Manager Issues
```bash
# Fix broken packages (APT)
fix_apt() {
    sudo apt --fix-broken install
    sudo apt autoremove
    sudo apt autoclean
    sudo dpkg --configure -a
}

# Fix RPM database (DNF)
fix_dnf() {
    sudo dnf clean all
    sudo dnf makecache
    sudo rpm --rebuilddb
}

# Fix pacman database (Arch)
fix_pacman() {
    sudo pacman -Sy archlinux-keyring
    sudo pacman-key --refresh-keys
    sudo pacman -Syyu
}
```

#### Graphics Issues
```bash
# Install graphics drivers
install_graphics_drivers() {
    local distro
    distro=$(lsb_release -si 2>/dev/null || echo "Unknown")
    
    case "$distro" in
        "Ubuntu")
            sudo ubuntu-drivers autoinstall
            ;;
        "Fedora")
            sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
            ;;
        "Arch")
            sudo pacman -S --noconfirm nvidia nvidia-utils
            ;;
    esac
}
```

### Diagnostic Tools

#### System Information
```bash
# Comprehensive system information
system_info() {
    echo "=== System Information ==="
    echo "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
    
    echo -e "\n=== Services ==="
    systemctl --user is-active docker 2>/dev/null || echo "Docker: inactive"
    systemctl --user is-active podman 2>/dev/null || echo "Podman: inactive"
    
    echo -e "\n=== Development Tools ==="
    command -v git >/dev/null && echo "Git: $(git --version)"
    command -v python3 >/dev/null && echo "Python: $(python3 --version)"
    command -v node >/dev/null && echo "Node.js: $(node --version)"
    command -v nvim >/dev/null && echo "Neovim: $(nvim --version | head -1)"
}
```

## Advanced Usage

### Custom Distribution Support

#### Adding New Distribution
```bash
# Template for new distribution support
add_distribution() {
    local distro_name="$1"
    local package_manager="$2"
    
    mkdir -p "os/linux/distributions/$distro_name"
    
    cat > "os/linux/distributions/$distro_name/packages.sh" << EOF
#!/bin/bash
# Package installation for $distro_name

install_packages() {
    # Essential packages for $distro_name
    $package_manager install -y \\
        git \\
        curl \\
        wget \\
        neovim \\
        tmux
}

setup_development() {
    # Development environment setup
    install_packages
    
    # Additional $distro_name specific setup
}
EOF
    
    chmod +x "os/linux/distributions/$distro_name/packages.sh"
}
```

### Automated Testing

#### VM Testing Setup
```bash
# Test configuration in virtual machines
test_vm_setup() {
    local distro="$1"
    
    # Create test VM with Vagrant
    cat > Vagrantfile << EOF
Vagrant.configure("2") do |config|
  config.vm.box = "$distro"
  config.vm.provision "shell", inline: <<-SHELL
    cd /vagrant
    ./scripts/bootstrap.sh --force
  SHELL
end
EOF
    
    vagrant up
    vagrant ssh -c "cd /vagrant && ./tests/test-linux-setup.sh"
    vagrant destroy -f
}
```

## Reference

### Configuration Files

| File | Purpose | Distribution |
|------|---------|-------------|
| `/etc/apt/sources.list` | APT repositories | Debian/Ubuntu |
| `/etc/dnf/dnf.conf` | DNF configuration | Fedora/RHEL |
| `/etc/pacman.conf` | Pacman configuration | Arch Linux |
| `/etc/systemd/system/` | Service definitions | All systemd |

### Package Managers

| Command | APT | DNF | Pacman | Zypper |
|---------|-----|-----|--------|--------|
| Install | `apt install` | `dnf install` | `pacman -S` | `zypper install` |
| Update | `apt update` | `dnf upgrade` | `pacman -Syu` | `zypper update` |
| Search | `apt search` | `dnf search` | `pacman -Ss` | `zypper search` |
| Remove | `apt remove` | `dnf remove` | `pacman -R` | `zypper remove` |

### Desktop Environments

| Environment | Ubuntu | Fedora | Arch | Config Tool |
|-------------|--------|--------|------|-------------|
| **GNOME** | Default | Default | Available | `gsettings` |
| **KDE** | Kubuntu | Spin | Available | `kwriteconfig5` |
| **XFCE** | Xubuntu | Spin | Available | `xfconf-query` |
| **i3** | Available | Available | Available | Text config |

### Performance Targets

| Metric | Target | Typical |
|--------|--------|---------|
| Boot time | <30s | ~20s |
| Shell startup | <500ms | ~200ms |
| Package install | <5min | ~3min |
| Container start | <10s | ~5s |

This Linux configuration system provides comprehensive support across major distributions while maintaining consistency and performance for development workflows. 