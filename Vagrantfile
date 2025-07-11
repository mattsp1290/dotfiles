# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile for macOS dotfiles integration testing
# Requires macOS host with Vagrant and appropriate VM provider

Vagrant.configure("2") do |config|
  # Common configuration for all VMs
  config.vm.synced_folder ".", "/vagrant", type: "rsync",
    rsync__exclude: [".git/", "node_modules/", ".DS_Store"]
  
  # Disable automatic updates to keep test environment stable
  config.vm.box_check_update = false
  
  # Configure SSH settings
  config.ssh.insert_key = false
  config.ssh.forward_agent = true

  # macOS Big Sur Testing Environment
  config.vm.define "macos-bigsur" do |bigsur|
    # Note: macOS boxes require specific licensing considerations
    # This is a placeholder - actual macOS boxes need proper licensing
    bigsur.vm.box = "macos-bigsur-base"
    bigsur.vm.hostname = "macos-bigsur-test"
    
    bigsur.vm.provider "parallels" do |prl|
      prl.name = "Dotfiles Test - macOS Big Sur"
      prl.memory = 4096
      prl.cpus = 2
      prl.customize ["set", :id, "--nested-virt", "on"]
    end

    bigsur.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["displayname"] = "Dotfiles Test - macOS Big Sur"
      vmware.vmx["memsize"] = "4096"
      vmware.vmx["numvcpus"] = "2"
    end

    # Provision testing environment
    bigsur.vm.provision "shell", inline: <<-SHELL
      echo "Setting up macOS Big Sur testing environment..."
      
      # Check if Homebrew is installed
      if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      
      # Install essential tools for testing
      brew install git stow
      
      # Set up test user git configuration
      git config --global user.name "Test User"
      git config --global user.email "test@example.com"
      
      echo "macOS Big Sur environment ready"
    SHELL

    # Run integration tests
    bigsur.vm.provision "shell", privileged: false, inline: <<-SHELL
      cd /vagrant
      echo "Running macOS integration tests..."
      
      # Set environment variables
      export DOTFILES_CI=true
      export TEST_PLATFORM=macos-bigsur
      
      # Run tests
      if [[ -x tests/integration/fresh-install.sh ]]; then
        echo "Running fresh installation tests..."
        tests/integration/fresh-install.sh
      fi
      
      if [[ -x tests/integration/upgrade.sh ]]; then
        echo "Running upgrade tests..."
        tests/integration/upgrade.sh
      fi
      
      echo "macOS integration tests completed"
    SHELL
  end

  # macOS Monterey Testing Environment
  config.vm.define "macos-monterey" do |monterey|
    monterey.vm.box = "macos-monterey-base"
    monterey.vm.hostname = "macos-monterey-test"
    
    monterey.vm.provider "parallels" do |prl|
      prl.name = "Dotfiles Test - macOS Monterey"
      prl.memory = 4096
      prl.cpus = 2
      prl.customize ["set", :id, "--nested-virt", "on"]
    end

    monterey.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["displayname"] = "Dotfiles Test - macOS Monterey"
      vmware.vmx["memsize"] = "4096"
      vmware.vmx["numvcpus"] = "2"
    end

    # Provision testing environment
    monterey.vm.provision "shell", inline: <<-SHELL
      echo "Setting up macOS Monterey testing environment..."
      
      # Install/update Homebrew
      if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      else
        echo "Updating Homebrew..."
        brew update
      fi
      
      # Install testing dependencies
      brew install git stow curl wget
      
      # Install additional tools for comprehensive testing
      brew install jq shellcheck
      
      # Set up git configuration
      git config --global user.name "Test User"
      git config --global user.email "test@example.com"
      git config --global init.defaultBranch main
      
      echo "macOS Monterey environment ready"
    SHELL

    # Run comprehensive tests
    monterey.vm.provision "shell", privileged: false, inline: <<-SHELL
      cd /vagrant
      echo "Running comprehensive macOS integration tests..."
      
      export DOTFILES_CI=true
      export TEST_PLATFORM=macos-monterey
      
      # Test fresh installation
      if [[ -x tests/integration/fresh-install.sh ]]; then
        echo "=== Fresh Installation Tests ==="
        tests/integration/fresh-install.sh
      fi
      
      # Test upgrade scenarios
      if [[ -x tests/integration/upgrade.sh ]]; then
        echo "=== Upgrade Tests ==="
        tests/integration/upgrade.sh
      fi
      
      # Test rollback procedures
      if [[ -x tests/integration/rollback.sh ]]; then
        echo "=== Rollback Tests ==="
        tests/integration/rollback.sh
      fi
      
      # Test performance
      if [[ -x tests/integration/performance.sh ]]; then
        echo "=== Performance Tests ==="
        tests/integration/performance.sh
      fi
      
      echo "Comprehensive macOS tests completed"
    SHELL
  end

  # macOS Ventura Testing Environment
  config.vm.define "macos-ventura" do |ventura|
    ventura.vm.box = "macos-ventura-base"
    ventura.vm.hostname = "macos-ventura-test"
    
    ventura.vm.provider "parallels" do |prl|
      prl.name = "Dotfiles Test - macOS Ventura"
      prl.memory = 6144
      prl.cpus = 4
      prl.customize ["set", :id, "--nested-virt", "on"]
    end

    ventura.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["displayname"] = "Dotfiles Test - macOS Ventura"
      vmware.vmx["memsize"] = "6144"
      vmware.vmx["numvcpus"] = "4"
    end

    # Advanced provisioning for latest macOS
    ventura.vm.provision "shell", inline: <<-SHELL
      echo "Setting up macOS Ventura testing environment..."
      
      # Install Xcode command line tools if not present
      if ! xcode-select -p >/dev/null 2>&1; then
        echo "Installing Xcode command line tools..."
        xcode-select --install
        # Wait for installation to complete
        until xcode-select -p >/dev/null 2>&1; do
          sleep 5
        done
      fi
      
      # Install Homebrew
      if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this session
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      
      # Install comprehensive testing dependencies
      brew install git stow curl wget jq shellcheck bash zsh
      
      # Install additional development tools
      brew install gh tree htop
      
      # Configure git
      git config --global user.name "Test User"
      git config --global user.email "test@example.com"
      git config --global init.defaultBranch main
      
      echo "macOS Ventura environment ready for testing"
    SHELL

    # Performance and security focused testing
    ventura.vm.provision "shell", privileged: false, inline: <<-SHELL
      cd /vagrant
      echo "Running advanced macOS integration tests..."
      
      export DOTFILES_CI=true
      export TEST_PLATFORM=macos-ventura
      export PERFORMANCE_TEST=true
      export SECURITY_TEST=true
      
      # Create test results directory
      mkdir -p test-results/macos-ventura
      
      # Run all test suites with detailed reporting
      test_suites=(
        "fresh-install.sh"
        "upgrade.sh" 
        "rollback.sh"
        "security.sh"
        "performance.sh"
      )
      
      for suite in "${test_suites[@]}"; do
        if [[ -x "tests/integration/$suite" ]]; then
          echo "=== Running $suite ==="
          if tests/integration/"$suite" > "test-results/macos-ventura/${suite%.sh}.log" 2>&1; then
            echo "✅ $suite completed successfully"
          else
            echo "❌ $suite failed - check logs"
          fi
        fi
      done
      
      echo "Advanced macOS integration tests completed"
      echo "Results saved to test-results/macos-ventura/"
    SHELL
  end

  # Minimal testing environment for quick validation
  config.vm.define "macos-minimal" do |minimal|
    minimal.vm.box = "macos-monterey-base"
    minimal.vm.hostname = "macos-minimal-test"
    
    minimal.vm.provider "parallels" do |prl|
      prl.name = "Dotfiles Test - Minimal"
      prl.memory = 2048
      prl.cpus = 2
    end

    minimal.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["displayname"] = "Dotfiles Test - Minimal"
      vmware.vmx["memsize"] = "2048"
      vmware.vmx["numvcpus"] = "2"
    end

    # Minimal setup for quick smoke tests
    minimal.vm.provision "shell", inline: <<-SHELL
      echo "Setting up minimal macOS testing environment..."
      
      # Install only essential tools
      if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      
      brew install git stow
      git config --global user.name "Test User"
      git config --global user.email "test@example.com"
      
      echo "Minimal environment ready"
    SHELL

    # Quick smoke tests only
    minimal.vm.provision "shell", privileged: false, inline: <<-SHELL
      cd /vagrant
      echo "Running quick smoke tests..."
      
      export DOTFILES_CI=true
      export TEST_PLATFORM=macos-minimal
      
      # Run basic installation test only
      if [[ -x tests/integration/fresh-install.sh ]]; then
        tests/integration/fresh-install.sh
      fi
      
      echo "Smoke tests completed"
    SHELL
  end
end

# Helper script creation for easier VM management
File.write("scripts/vagrant-helpers.sh", <<~SCRIPT)
#!/usr/bin/env bash
# Vagrant helper scripts for dotfiles testing

case "$1" in
  "test-all")
    echo "Running tests on all macOS environments..."
    vagrant up macos-bigsur macos-monterey macos-ventura
    ;;
  "test-latest")
    echo "Running tests on latest macOS..."
    vagrant up macos-ventura
    ;;
  "smoke-test")
    echo "Running smoke tests..."
    vagrant up macos-minimal
    ;;
  "clean")
    echo "Destroying all test VMs..."
    vagrant destroy -f
    ;;
  *)
    echo "Usage: $0 {test-all|test-latest|smoke-test|clean}"
    echo ""
    echo "Commands:"
    echo "  test-all    - Test on all macOS versions"
    echo "  test-latest - Test on latest macOS only"
    echo "  smoke-test  - Quick validation test"
    echo "  clean       - Destroy all test VMs"
    ;;
esac
SCRIPT

# Make helper script executable
File.chmod("scripts/vagrant-helpers.sh", 0755) if File.exist?("scripts/vagrant-helpers.sh") 