#!/usr/bin/env bash
# OS Detection Library
# Provides functions for detecting operating system, distribution, version, and package managers

set -euo pipefail

# Cache variables to avoid repeated detection
_OS_TYPE=""
_OS_DISTRIBUTION=""
_OS_VERSION=""
_OS_CODENAME=""
_OS_ARCH=""
_PACKAGE_MANAGER=""
_INIT_SYSTEM=""

# Detect the base OS type (Linux, macOS, BSD)
detect_os_type() {
    if [[ -n "$_OS_TYPE" ]]; then
        echo "$_OS_TYPE"
        return 0
    fi
    
    local os_type="unknown"
    
    case "$OSTYPE" in
        linux*)   os_type="linux" ;;
        darwin*)  os_type="macos" ;;
        freebsd*) os_type="freebsd" ;;
        openbsd*) os_type="openbsd" ;;
        netbsd*)  os_type="netbsd" ;;
        msys*)    os_type="windows" ;;
        cygwin*)  os_type="windows" ;;
    esac
    
    # Additional detection for edge cases
    if [[ "$os_type" == "unknown" ]]; then
        if [[ -f /etc/os-release ]] || [[ -f /usr/lib/os-release ]]; then
            os_type="linux"
        elif [[ -f /System/Library/CoreServices/SystemVersion.plist ]]; then
            os_type="macos"
        fi
    fi
    
    _OS_TYPE="$os_type"
    echo "$os_type"
}

# Detect Linux distribution
detect_linux_distribution() {
    if [[ -n "$_OS_DISTRIBUTION" ]]; then
        echo "$_OS_DISTRIBUTION"
        return 0
    fi
    
    local distro="unknown"
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        distro="${ID:-unknown}"
    elif [[ -f /usr/lib/os-release ]]; then
        . /usr/lib/os-release
        distro="${ID:-unknown}"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        distro="${DISTRIB_ID:-unknown}"
    elif [[ -f /etc/debian_version ]]; then
        distro="debian"
    elif [[ -f /etc/fedora-release ]]; then
        distro="fedora"
    elif [[ -f /etc/redhat-release ]]; then
        if grep -q "CentOS" /etc/redhat-release; then
            distro="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            distro="rhel"
        elif grep -q "Fedora" /etc/redhat-release; then
            distro="fedora"
        fi
    elif [[ -f /etc/arch-release ]]; then
        distro="arch"
    elif [[ -f /etc/gentoo-release ]]; then
        distro="gentoo"
    elif [[ -f /etc/SuSE-release ]] || [[ -f /etc/SUSE-brand ]]; then
        distro="suse"
    elif [[ -f /etc/alpine-release ]]; then
        distro="alpine"
    fi
    
    # Normalize distribution names
    distro=$(echo "$distro" | tr '[:upper:]' '[:lower:]')
    
    _OS_DISTRIBUTION="$distro"
    echo "$distro"
}

# Get OS version
detect_os_version() {
    if [[ -n "$_OS_VERSION" ]]; then
        echo "$_OS_VERSION"
        return 0
    fi
    
    local version="unknown"
    local os_type=$(detect_os_type)
    
    case "$os_type" in
        linux)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                version="${VERSION_ID:-unknown}"
            elif [[ -f /usr/lib/os-release ]]; then
                . /usr/lib/os-release
                version="${VERSION_ID:-unknown}"
            elif [[ -f /etc/lsb-release ]]; then
                . /etc/lsb-release
                version="${DISTRIB_RELEASE:-unknown}"
            fi
            ;;
        macos)
            version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
            ;;
        *)
            version="unknown"
            ;;
    esac
    
    _OS_VERSION="$version"
    echo "$version"
}

# Get OS codename (for Linux distributions)
detect_os_codename() {
    if [[ -n "$_OS_CODENAME" ]]; then
        echo "$_OS_CODENAME"
        return 0
    fi
    
    local codename="unknown"
    
    if [[ $(detect_os_type) == "linux" ]]; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"
        elif [[ -f /usr/lib/os-release ]]; then
            . /usr/lib/os-release
            codename="${VERSION_CODENAME:-unknown}"
        elif [[ -f /etc/lsb-release ]]; then
            . /etc/lsb-release
            codename="${DISTRIB_CODENAME:-unknown}"
        fi
    fi
    
    _OS_CODENAME="$codename"
    echo "$codename"
}

# Detect system architecture
detect_architecture() {
    if [[ -n "$_OS_ARCH" ]]; then
        echo "$_OS_ARCH"
        return 0
    fi
    
    local arch="unknown"
    local machine=$(uname -m 2>/dev/null || echo "unknown")
    
    case "$machine" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        i?86)
            arch="x86"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7*|armv6*)
            arch="arm"
            ;;
        *)
            arch="$machine"
            ;;
    esac
    
    _OS_ARCH="$arch"
    echo "$arch"
}

# Detect package manager
detect_package_manager() {
    if [[ -n "$_PACKAGE_MANAGER" ]]; then
        echo "$_PACKAGE_MANAGER"
        return 0
    fi
    
    local pm="unknown"
    local os_type=$(detect_os_type)
    
    case "$os_type" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                pm="brew"
            elif command -v port >/dev/null 2>&1; then
                pm="macports"
            fi
            ;;
        linux)
            # Check for package managers in order of preference
            if command -v apt-get >/dev/null 2>&1; then
                pm="apt"
            elif command -v dnf >/dev/null 2>&1; then
                pm="dnf"
            elif command -v yum >/dev/null 2>&1; then
                pm="yum"
            elif command -v pacman >/dev/null 2>&1; then
                pm="pacman"
            elif command -v zypper >/dev/null 2>&1; then
                pm="zypper"
            elif command -v apk >/dev/null 2>&1; then
                pm="apk"
            elif command -v emerge >/dev/null 2>&1; then
                pm="portage"
            elif command -v snap >/dev/null 2>&1; then
                pm="snap"
            fi
            ;;
    esac
    
    _PACKAGE_MANAGER="$pm"
    echo "$pm"
}

# Detect init system (for Linux)
detect_init_system() {
    if [[ -n "$_INIT_SYSTEM" ]]; then
        echo "$_INIT_SYSTEM"
        return 0
    fi
    
    local init="unknown"
    
    if [[ $(detect_os_type) == "linux" ]]; then
        if [[ -d /run/systemd/system ]]; then
            init="systemd"
        elif command -v openrc-run >/dev/null 2>&1; then
            init="openrc"
        elif [[ -f /sbin/init ]] && /sbin/init --version 2>&1 | grep -q upstart; then
            init="upstart"
        elif [[ -f /etc/init.d/cron ]] && [[ ! -h /etc/init.d/cron ]]; then
            init="sysvinit"
        fi
    fi
    
    _INIT_SYSTEM="$init"
    echo "$init"
}

# Check if running in a container
is_container() {
    if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
        return 0
    fi
    
    if [[ -n "${container:-}" ]]; then
        return 0
    fi
    
    if grep -q "docker\|lxc\|containerd" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Check if running in WSL
is_wsl() {
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        return 0
    fi
    
    if grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Check if running on Apple Silicon
is_apple_silicon() {
    if [[ $(detect_os_type) == "macos" ]] && [[ $(detect_architecture) == "arm64" ]]; then
        return 0
    fi
    return 1
}

# Get a comprehensive OS string
get_os_string() {
    local os_type=$(detect_os_type)
    local result="$os_type"
    
    case "$os_type" in
        linux)
            local distro=$(detect_linux_distribution)
            local version=$(detect_os_version)
            result="$distro $version"
            ;;
        macos)
            local version=$(detect_os_version)
            result="macOS $version"
            if is_apple_silicon; then
                result="$result (Apple Silicon)"
            fi
            ;;
    esac
    
    echo "$result"
}

# Get minimum required OS version for a given OS
get_minimum_os_version() {
    local os_type="${1:-$(detect_os_type)}"
    
    case "$os_type" in
        macos)
            echo "12.0"  # macOS Monterey
            ;;
        linux)
            local distro=$(detect_linux_distribution)
            case "$distro" in
                ubuntu) echo "20.04" ;;
                debian) echo "11" ;;
                fedora) echo "36" ;;
                arch)   echo "rolling" ;;
                *)      echo "unknown" ;;
            esac
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Compare version strings (returns 0 if version1 >= version2)
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Handle 'rolling' or 'unknown' versions
    if [[ "$version1" == "rolling" ]] || [[ "$version2" == "rolling" ]]; then
        return 0
    fi
    
    if [[ "$version1" == "unknown" ]] || [[ "$version2" == "unknown" ]]; then
        return 1
    fi
    
    # Use sort -V if available, otherwise fall back to simple comparison
    if command -v sort >/dev/null 2>&1 && echo | sort -V >/dev/null 2>&1; then
        [[ "$version1" = "$(echo -e "$version1\n$version2" | sort -V | tail -1)" ]]
    else
        [[ "$version1" = "$version2" ]] || [[ "$version1" > "$version2" ]]
    fi
}

# Check if the current OS version meets minimum requirements
check_os_compatibility() {
    local current_version=$(detect_os_version)
    local minimum_version=$(get_minimum_os_version)
    
    if [[ "$minimum_version" == "unknown" ]] || [[ "$current_version" == "unknown" ]]; then
        return 0  # Assume compatible if we can't determine
    fi
    
    version_compare "$current_version" "$minimum_version"
}

# Export functions for use in other scripts
export -f detect_os_type
export -f detect_linux_distribution
export -f detect_os_version
export -f detect_os_codename
export -f detect_architecture
export -f detect_package_manager
export -f detect_init_system
export -f is_container
export -f is_wsl
export -f is_apple_silicon
export -f get_os_string
export -f get_minimum_os_version
export -f version_compare
export -f check_os_compatibility 