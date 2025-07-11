# Package Manager Troubleshooting Guide

This guide helps diagnose and resolve common issues with package manager configurations.

## Quick Diagnosis

### Run Automatic Validation

Start with automated diagnostics:

```bash
# Basic validation
./scripts/validate-package-managers.sh

# Full connectivity testing
./scripts/test-package-connectivity.sh

# Individual package manager testing
./scripts/test-package-connectivity.sh npm
./scripts/test-package-connectivity.sh pip
./scripts/test-package-connectivity.sh gem
./scripts/test-package-connectivity.sh cargo
```

### Check Configuration Loading

Verify each package manager can load its configuration:

```bash
npm config list
pip config list  
gem environment
cargo --version
```

## npm Troubleshooting

### Common npm Issues

#### Registry Connection Timeouts

**Symptoms:**
- `npm install` hangs or times out
- Error: `ETIMEDOUT` or `ENOTFOUND`

**Solutions:**
1. **Check registry connectivity:**
   ```bash
   curl -I https://registry.npmjs.org/
   npm config get registry
   ```

2. **Try alternative registry:**
   ```bash
   npm config set registry https://registry.npmjs.org/
   # Or for faster mirrors:
   # npm config set registry https://registry.npmjs.cf/
   ```

3. **Adjust timeout settings:**
   ```bash
   npm config set fetch-timeout 300000
   npm config set fetch-retry-maxtimeout 120000
   ```

#### Authentication Issues

**Symptoms:**
- `403 Forbidden` errors
- `401 Unauthorized` errors

**Solutions:**
1. **Check authentication token:**
   ```bash
   npm whoami
   npm config get //registry.npmjs.org/:_authToken
   ```

2. **Re-authenticate:**
   ```bash
   npm login
   # Or set token directly:
   npm config set //registry.npmjs.org/:_authToken YOUR_TOKEN
   ```

#### Cache Corruption

**Symptoms:**
- Unexpected package versions
- Installation failures with cached packages

**Solutions:**
1. **Clear npm cache:**
   ```bash
   npm cache clean --force
   npm cache verify
   ```

2. **Check cache location:**
   ```bash
   npm config get cache
   ls -la $(npm config get cache)
   ```

#### Package Lock Issues

**Symptoms:**
- `package-lock.json` conflicts
- Inconsistent dependency versions

**Solutions:**
1. **Regenerate package lock:**
   ```bash
   rm package-lock.json node_modules/
   npm install
   ```

2. **Verify lock file settings:**
   ```bash
   npm config get package-lock
   npm config get package-lock-only
   ```

### npm Enterprise/Corporate Issues

#### Proxy Configuration

**Symptoms:**
- Connection failures in corporate networks
- `ENOTFOUND` errors for registry

**Solutions:**
1. **Configure proxy:**
   ```bash
   npm config set proxy http://proxy.company.com:8080
   npm config set https-proxy http://proxy.company.com:8080
   ```

2. **Set no-proxy for internal hosts:**
   ```bash
   npm config set noproxy localhost,127.0.0.1,.company.com
   ```

#### SSL Certificate Issues

**Symptoms:**
- `CERT_UNTRUSTED` errors
- SSL handshake failures

**Solutions:**
1. **Disable strict SSL (temporary):**
   ```bash
   npm config set strict-ssl false
   ```

2. **Configure CA certificates:**
   ```bash
   npm config set cafile /path/to/company-ca.pem
   ```

## pip Troubleshooting

### Common pip Issues

#### SSL Certificate Errors

**Symptoms:**
- `SSL: CERTIFICATE_VERIFY_FAILED`
- Certificate verification errors

**Solutions:**
1. **Add trusted hosts:**
   ```bash
   pip config set global.trusted-host "pypi.org pypi.python.org files.pythonhosted.org"
   ```

2. **Update certificates:**
   ```bash
   pip install --upgrade certifi
   ```

3. **Use system certificates:**
   ```bash
   pip config set global.cert /etc/ssl/certs/ca-certificates.crt
   ```

#### Virtual Environment Requirements

**Symptoms:**
- `ERROR: To modify pip, please run the following command: ...`
- Permission denied errors

**Solutions:**
1. **Create and activate virtual environment:**
   ```bash
   python -m venv myenv
   source myenv/bin/activate  # On Windows: myenv\Scripts\activate
   ```

2. **Disable virtual environment requirement (not recommended):**
   ```bash
   pip config unset global.require-virtualenv
   ```

#### Index Connection Issues

**Symptoms:**
- Timeouts connecting to PyPI
- `Could not find a version that satisfies the requirement`

**Solutions:**
1. **Test index connectivity:**
   ```bash
   curl -I https://pypi.org/simple/
   pip config get global.index-url
   ```

2. **Try alternative indexes:**
   ```bash
   pip config set global.index-url https://pypi.python.org/simple/
   # Or add extra indexes:
   pip config set global.extra-index-url "https://pypi.python.org/simple/"
   ```

3. **Increase timeout:**
   ```bash
   pip config set global.timeout 300
   ```

#### Cache Issues

**Symptoms:**
- Stale package versions
- Disk space issues with large cache

**Solutions:**
1. **Clear pip cache:**
   ```bash
   pip cache purge
   pip cache info
   ```

2. **Adjust cache settings:**
   ```bash
   pip config set global.cache-dir ~/.cache/pip
   pip config set global.no-cache-dir true  # Disable caching
   ```

### pip Enterprise/Corporate Issues

#### Corporate Index Configuration

**Symptoms:**
- Cannot access internal packages
- Authentication failures with corporate PyPI

**Solutions:**
1. **Configure corporate index:**
   ```bash
   pip config set global.index-url https://pypi.company.com/simple/
   pip config set global.trusted-host pypi.company.com
   ```

2. **Use multiple indexes:**
   ```bash
   pip config set global.extra-index-url "https://pypi.org/simple/ https://pypi.company.com/simple/"
   ```

## gem Troubleshooting

### Common gem Issues

#### Source Connectivity

**Symptoms:**
- `Unable to download data from https://rubygems.org/`
- Network timeouts

**Solutions:**
1. **Check gem sources:**
   ```bash
   gem sources --list
   gem sources --check-sources
   ```

2. **Update gem sources:**
   ```bash
   gem sources --remove https://rubygems.org/
   gem sources --add https://rubygems.org/
   ```

3. **Test source connectivity:**
   ```bash
   curl -I https://rubygems.org/
   ```

#### Permission Issues

**Symptoms:**
- `Permission denied` during gem installation
- `You don't have write permissions for /usr/bin`

**Solutions:**
1. **Use user installation:**
   ```bash
   gem install --user-install package_name
   # Or configure globally:
   echo 'gem: --user-install' >> ~/.gemrc
   ```

2. **Check gem environment:**
   ```bash
   gem environment
   gem environment gemdir
   ```

#### SSL Issues

**Symptoms:**
- `SSL_CONNECT returned=1 errno=0 state=error`
- Certificate verification errors

**Solutions:**
1. **Update RubyGems:**
   ```bash
   gem update --system
   ```

2. **Configure SSL verification:**
   ```bash
   gem install --trust-policy HighSecurity package_name
   ```

3. **Check SSL configuration in .gemrc:**
   ```yaml
   :ssl_verify_mode: 1
   :ssl_ca_cert: /path/to/ca-bundle.crt
   ```

#### Build Failures

**Symptoms:**
- `Failed to build gem native extension`
- Compilation errors during installation

**Solutions:**
1. **Install development tools:**
   ```bash
   # macOS:
   xcode-select --install
   
   # Ubuntu/Debian:
   sudo apt-get install build-essential ruby-dev
   
   # CentOS/RHEL:
   sudo yum groupinstall "Development Tools"
   sudo yum install ruby-devel
   ```

2. **Check for missing dependencies:**
   ```bash
   gem dependency package_name
   ```

### gem Enterprise/Corporate Issues

#### Corporate Gem Sources

**Symptoms:**
- Cannot access internal gems
- Authentication failures

**Solutions:**
1. **Add corporate gem source:**
   ```bash
   gem sources --add https://gems.company.com/
   gem sources --list
   ```

2. **Configure authentication:**
   ```bash
   bundle config https://gems.company.com/ username:password
   ```

## cargo Troubleshooting

### Common cargo Issues

#### Registry Connection Issues

**Symptoms:**
- `Updating crates.io index` hangs
- `failed to get ` package from registry

**Solutions:**
1. **Test crates.io connectivity:**
   ```bash
   curl -I https://crates.io/
   cargo search --limit 1 serde
   ```

2. **Update cargo registry:**
   ```bash
   cargo update
   rm -rf ~/.cargo/registry/index/github.com-*
   cargo search --limit 1 serde  # This will re-download the index
   ```

3. **Check cargo configuration:**
   ```bash
   cargo --version
   cat ~/.cargo/config.toml
   ```

#### Build Failures

**Symptoms:**
- Compilation errors
- Linker failures
- Missing system dependencies

**Solutions:**
1. **Check Rust toolchain:**
   ```bash
   rustc --version
   cargo --version
   rustup show
   ```

2. **Update Rust toolchain:**
   ```bash
   rustup update
   ```

3. **Install system dependencies:**
   ```bash
   # macOS:
   xcode-select --install
   
   # Ubuntu/Debian:
   sudo apt-get install build-essential
   
   # CentOS/RHEL:
   sudo yum groupinstall "Development Tools"
   ```

#### Network Issues

**Symptoms:**
- Git dependency failures
- Timeout downloading crates

**Solutions:**
1. **Configure git authentication:**
   ```bash
   git config --global credential.helper store
   ```

2. **Adjust network settings in cargo config:**
   ```toml
   [net]
   retry = 5
   git-fetch-with-cli = true
   ```

3. **Use cargo offline mode:**
   ```bash
   cargo build --offline
   ```

### cargo Enterprise/Corporate Issues

#### Corporate Registries

**Symptoms:**
- Cannot access internal crates
- Authentication failures with corporate registry

**Solutions:**
1. **Configure corporate registry:**
   ```toml
   [registries]
   company = { index = "https://crates.company.com/git/index" }
   
   [source.company]
   registry = "https://crates.company.com/"
   ```

2. **Set default registry:**
   ```toml
   [registry]
   default = "company"
   ```

## Network and Environment Issues

### Proxy Configuration

#### Detecting Proxy Requirements

Check if you're behind a corporate proxy:

```bash
# Check environment variables
echo $http_proxy $https_proxy $HTTP_PROXY $HTTPS_PROXY

# Test direct connectivity
curl -I https://registry.npmjs.org/
curl -I https://pypi.org/
curl -I https://rubygems.org/
curl -I https://crates.io/
```

#### Configuring Proxies

**System-wide proxy (recommended):**
```bash
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080
export no_proxy=localhost,127.0.0.1,.company.com
```

**Per-tool proxy configuration:**
```bash
# npm
npm config set proxy http://proxy.company.com:8080
npm config set https-proxy http://proxy.company.com:8080

# pip
pip config set global.proxy http://proxy.company.com:8080

# gem
echo ':http_proxy: http://proxy.company.com:8080' >> ~/.gemrc

# cargo
echo '[http]' >> ~/.cargo/config.toml
echo 'proxy = "http://proxy.company.com:8080"' >> ~/.cargo/config.toml
```

### DNS Resolution Issues

#### Symptoms
- `ENOTFOUND` errors
- Intermittent connectivity failures

#### Solutions
1. **Test DNS resolution:**
   ```bash
   nslookup registry.npmjs.org
   nslookup pypi.org
   nslookup rubygems.org
   nslookup crates.io
   ```

2. **Try alternative DNS servers:**
   ```bash
   # Temporarily use Google DNS
   sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4
   ```

3. **Flush DNS cache:**
   ```bash
   # macOS
   sudo dscacheutil -flushcache
   
   # Linux
   sudo systemctl restart systemd-resolved
   ```

## Performance Issues

### Slow Download Speeds

#### Diagnosis
```bash
# Test download speeds
./scripts/test-package-connectivity.sh

# Check for mirrors
npm config get registry
pip config get global.index-url
gem sources --list
```

#### Solutions
1. **Use regional mirrors:**
   ```bash
   # npm (China mirror example)
   npm config set registry https://registry.npm.taobao.org/
   
   # pip (China mirror example)  
   pip config set global.index-url https://pypi.douban.com/simple/
   
   # gem (China mirror example)
   gem sources --add https://gems.ruby-china.com/
   ```

2. **Optimize parallel downloads:**
   ```bash
   # npm - increase maxsockets
   npm config set maxsockets 50
   
   # gem - increase concurrent downloads (already configured)
   echo ':concurrent_downloads: 16' >> ~/.gemrc
   ```

### Large Cache Sizes

#### Check cache sizes
```bash
du -sh $(npm config get cache)
du -sh $(pip config get global.cache-dir)
du -sh ~/.gem
du -sh ~/.cargo
```

#### Clean up caches
```bash
npm cache clean --force
pip cache purge
gem cleanup
cargo clean
```

## Getting Additional Help

### Community Resources

- **npm:** [npm Community](https://github.com/npm/cli/issues)
- **pip:** [pip Issues](https://github.com/pypa/pip/issues)
- **gem:** [RubyGems Support](https://guides.rubygems.org/)
- **cargo:** [Cargo Book](https://doc.rust-lang.org/cargo/)

### Professional Support

For enterprise environments, consider:
- npm Enterprise
- PyPI Enterprise/Private indexes
- Private gem servers
- Corporate Rust registry solutions

### Additional Diagnostics

Run comprehensive diagnostics:
```bash
# Full system validation
./scripts/validate-package-managers.sh --connectivity

# Export configuration for analysis
npm config list > npm-config.txt
pip config list > pip-config.txt
gem environment > gem-env.txt
cargo --version --verbose > cargo-info.txt
```

### Reporting Issues

When reporting issues, include:
1. Operating system and version
2. Package manager versions
3. Full error messages
4. Network environment details (corporate/proxy/etc.)
5. Relevant configuration files
6. Output from validation scripts 