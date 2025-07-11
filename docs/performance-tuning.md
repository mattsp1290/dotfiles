# Performance Tuning Guide

This guide provides strategies and best practices for optimizing the performance of the secret injection system.

## Performance Benchmarks

### Baseline Performance

Without optimization:
- First secret retrieval: ~600-700ms
- Subsequent retrievals: ~600-700ms (no caching)
- Template processing: ~50-100ms per file
- Batch processing: Linear time (n × single file time)

### Optimized Performance

With caching and optimization:
- First secret retrieval: ~600-700ms
- Cached retrieval: ~5-10ms
- Batch retrieval: ~700ms + (n × 10ms)
- Template processing: ~20-50ms per file

## Caching Strategy

### Enable Caching

Caching is enabled by default and provides dramatic performance improvements:

```bash
# Verify caching is enabled (default)
echo $OP_CACHE_ENABLED  # Should be "true" or empty

# Explicitly enable
export OP_CACHE_ENABLED=true

# Disable if needed (not recommended)
export OP_CACHE_ENABLED=false
```

### Configure Cache TTL

Adjust cache lifetime based on your security requirements:

```bash
# Default: 5 minutes (300 seconds)
export OP_CACHE_TTL=300

# Longer cache for development (30 minutes)
export OP_CACHE_TTL=1800

# Shorter cache for production (1 minute)
export OP_CACHE_TTL=60

# Very long cache for CI/CD pipelines (2 hours)
export OP_CACHE_TTL=7200
```

### Pre-warm Cache

Load commonly used secrets before processing templates:

```bash
# Warm cache with common secrets
scripts/inject-secrets.sh --warm-cache template.tmpl

# Or use the load-secrets script
source scripts/load-secrets.sh

# Manual cache warming
scripts/load-secrets.sh Employee print >/dev/null
```

### Cache Location

The cache is stored in secure temporary files:

```bash
# Default location
ls -la /tmp/op-cache-*

# Clear cache manually
rm -rf /tmp/op-cache-*

# Monitor cache size
du -sh /tmp/op-cache-*
```

## Batch Processing Optimization

### Use Batch Scripts

Process multiple files together for better performance:

```bash
# SLOW - Individual processing
for file in *.template; do
    scripts/inject-secrets.sh "$file"
done

# FAST - Batch processing
scripts/inject-all.sh

# FAST - Recursive processing
scripts/inject-secrets.sh -r templates/
```

### Parallel Processing

For large numbers of templates, consider parallel processing:

```bash
# Process templates in parallel (4 jobs)
find . -name "*.template" -print0 | \
    xargs -0 -P 4 -I {} scripts/inject-secrets.sh {}

# Using GNU parallel
find . -name "*.template" | \
    parallel -j 4 scripts/inject-secrets.sh {}
```

### Batch Secret Retrieval

Retrieve multiple secrets at once:

```bash
# SLOW - Individual retrieval
GITHUB_TOKEN=$(get_secret GITHUB_TOKEN credential)
AWS_KEY=$(get_secret AWS_ACCESS_KEY_ID credential)
API_KEY=$(get_secret ANTHROPIC_API_KEY credential)

# FAST - Batch retrieval
eval "$(get_secrets_batch Employee \
    GITHUB_TOKEN:credential \
    AWS_ACCESS_KEY_ID:credential \
    ANTHROPIC_API_KEY:credential)"
```

## Template Optimization

### Minimize Token Count

Reduce the number of unique tokens in templates:

```bash
# SLOW - Many unique tokens
server1_key=${SERVER1_API_KEY}
server2_key=${SERVER2_API_KEY}
server3_key=${SERVER3_API_KEY}

# FAST - Reuse tokens where possible
api_key=${GENERAL_API_KEY}
# Or use environment-specific tokens
api_key=${ENV_API_KEY}
```

### Specify Format Explicitly

Avoid auto-detection overhead:

```bash
# SLOWER - Auto-detection
scripts/inject-secrets.sh template.tmpl

# FASTER - Explicit format
scripts/inject-secrets.sh --format env template.tmpl
```

### Group Related Templates

Organize templates to process related files together:

```
templates/
├── quick/          # Fast-processing templates
│   └── env.tmpl    # Few tokens
├── standard/       # Normal templates  
│   └── config.tmpl # Average token count
└── complex/        # Slow templates
    └── full.tmpl   # Many tokens
```

## 1Password CLI Optimization

### Session Management

Maintain 1Password sessions to avoid re-authentication:

```bash
# Create long-lived session
export OP_SESSION_TIMEOUT=43200  # 12 hours

# Keep session alive
eval $(op signin)

# Add to shell profile for auto-renewal
if ! op account get >/dev/null 2>&1; then
    eval $(op signin)
fi
```

### Vault Selection

Use specific vaults to reduce search time:

```bash
# SLOWER - Default vault search
get_secret MY_SECRET

# FASTER - Specific vault
get_secret MY_SECRET credential Employee
```

### Account Optimization

If using multiple accounts, specify the account:

```bash
# Set default account
export OP_ACCOUNT_ALIAS=work

# Or specify in commands
op item get SECRET --account work
```

## Shell Integration Optimization

### Lazy Loading

Load secrets only when needed:

```bash
# SLOW - Load all at startup
source scripts/load-secrets.sh

# FAST - Lazy loading function
load_github_token() {
    [[ -z "$GITHUB_TOKEN" ]] && \
        export GITHUB_TOKEN=$(get_secret_cached GITHUB_TOKEN credential)
}

# Use when needed
load_github_token
git push
```

### Conditional Loading

Load secrets based on context:

```bash
# Only load work secrets at work
if [[ "$USER" == "work-user" ]]; then
    source scripts/load-secrets.sh Employee
fi

# Load based on directory
if [[ "$PWD" =~ work-projects ]]; then
    load_work_secrets
fi
```

### Background Loading

Load secrets asynchronously:

```bash
# Load secrets in background
{
    source scripts/load-secrets.sh 2>/dev/null
} &

# Continue with other initialization
# ...

# Wait if secrets needed
wait
```

## Monitoring Performance

### Built-in Timing

Use the timing wrapper to measure performance:

```bash
# Time secret retrieval
time_function get_secret_cached GITHUB_TOKEN credential

# Time template processing
time scripts/inject-secrets.sh template.tmpl
```

### Debug Output

Enable debug mode for performance insights:

```bash
# See what's happening
TEMPLATE_DEBUG=true scripts/inject-secrets.sh template.tmpl

# Verbose output
scripts/inject-secrets.sh --verbose template.tmpl
```

### Cache Statistics

Monitor cache effectiveness:

```bash
# Create cache stats function
cache_stats() {
    local cache_dir="/tmp/op-cache-$$"
    if [[ -d "$cache_dir" ]]; then
        echo "Cache entries: $(find "$cache_dir" -name "*.cache" | wc -l)"
        echo "Cache size: $(du -sh "$cache_dir" | cut -f1)"
        echo "Oldest entry: $(find "$cache_dir" -name "*.timestamp" -exec stat -f %m {} \; | sort -n | head -1 | xargs -I {} date -r {})"
    else
        echo "No cache found"
    fi
}
```

## Common Performance Issues

### Issue: Slow First Run

**Symptoms:** First template processing takes several seconds

**Solutions:**
```bash
# Pre-warm cache on shell startup
echo "warm_cache >/dev/null 2>&1 &" >> ~/.bashrc

# Or create a startup script
cat > ~/.config/autostart/warm-secrets.sh << 'EOF'
#!/bin/bash
source ~/dotfiles/scripts/load-secrets.sh
EOF
```

### Issue: Cache Misses

**Symptoms:** Performance doesn't improve after first run

**Solutions:**
```bash
# Check cache is working
ls -la /tmp/op-cache-*

# Increase cache TTL
export OP_CACHE_TTL=3600

# Check for cache key mismatches
TEMPLATE_DEBUG=true scripts/inject-secrets.sh template.tmpl
```

### Issue: Large Templates

**Symptoms:** Templates with many tokens are slow

**Solutions:**
```bash
# Split large templates
# Before: one file with 50 tokens
# After: 5 files with 10 tokens each

# Process in parallel
find templates/ -name "*.tmpl" | parallel scripts/inject-secrets.sh {}
```

## Performance Best Practices

### 1. Development Environment

```bash
# ~/.bashrc or ~/.zshrc
export OP_CACHE_TTL=1800  # 30 minutes
export OP_CACHE_ENABLED=true

# Warm cache on startup
(warm_cache 2>/dev/null &)
```

### 2. CI/CD Pipeline

```bash
# Long cache for pipeline duration
export OP_CACHE_TTL=7200  # 2 hours

# Pre-warm all required secrets
scripts/load-secrets.sh Employee print > /tmp/secrets.env
source /tmp/secrets.env

# Process all templates at once
scripts/inject-all.sh --no-backup
```

### 3. Production Deployment

```bash
# Short cache for security
export OP_CACHE_TTL=60  # 1 minute

# No background warming
export OP_CACHE_ENABLED=false  # Consider disabling

# Explicit secret retrieval
get_secret PROD_API_KEY credential Production
```

## Advanced Optimization

### Custom Cache Implementation

For extreme performance needs, implement custom caching:

```bash
# Redis-backed cache
cache_get_redis() {
    local key="$1"
    redis-cli GET "op:$key" 2>/dev/null
}

cache_set_redis() {
    local key="$1"
    local value="$2"
    local ttl="${3:-300}"
    redis-cli SETEX "op:$key" "$ttl" "$value" >/dev/null
}
```

### Compiled Templates

Pre-process templates for faster runtime:

```bash
# Generate shell script from template
compile_template() {
    local template="$1"
    local output="${template%.tmpl}.sh"
    
    echo "#!/bin/bash" > "$output"
    echo "# Generated from $template" >> "$output"
    
    # Extract all tokens
    tokens=$(extract_tokens "$(cat "$template")" env)
    
    # Generate retrieval code
    while IFS= read -r token; do
        echo "export $token=\$(get_secret_cached $token credential)" >> "$output"
    done <<< "$tokens"
    
    # Add template processing
    echo "cat << 'EOF'" >> "$output"
    cat "$template" >> "$output"
    echo "EOF" >> "$output"
}
```

## Troubleshooting Performance

### Performance Checklist

1. ✓ Is caching enabled?
2. ✓ Is cache TTL appropriate?
3. ✓ Are you signed in to 1Password?
4. ✓ Are you using batch processing?
5. ✓ Are templates optimized?
6. ✓ Is the format specified explicitly?
7. ✓ Are secrets pre-warmed?

### Performance Debugging

```bash
# Full performance analysis
analyze_performance() {
    echo "=== Performance Analysis ==="
    echo "Cache enabled: $OP_CACHE_ENABLED"
    echo "Cache TTL: $OP_CACHE_TTL"
    echo "Cache location: /tmp/op-cache-$$"
    cache_stats
    echo ""
    echo "=== Timing Tests ==="
    echo -n "Cold retrieval: "
    time_function get_secret TEST_SECRET credential 2>&1 | grep "Execution time"
    echo -n "Cached retrieval: "
    time_function get_secret_cached TEST_SECRET credential 2>&1 | grep "Execution time"
}
``` 