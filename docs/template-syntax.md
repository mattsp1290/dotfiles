# Template Syntax Reference

This document provides a comprehensive reference for all supported template syntax formats in the secret injection system.

## Supported Formats

### 1. Environment Variable Style (`env`)

**Pattern:** `${SECRET_NAME}`

This is the default and most commonly used format. It matches standard shell variable expansion syntax.

```bash
# Examples
export GITHUB_TOKEN=${GITHUB_TOKEN}
api_key=${ANTHROPIC_API_KEY}
password="${DATABASE_PASSWORD}"

# In configuration files
[credentials]
access_key = ${AWS_ACCESS_KEY_ID}
secret_key = ${AWS_SECRET_ACCESS_KEY}
```

**Advantages:**
- Familiar syntax for shell users
- Clear boundaries with braces
- Works well in most configuration formats
- Safe from partial matches

**Use Cases:**
- Shell scripts and profiles
- Configuration files (INI, TOML, etc.)
- Docker environment files
- General purpose templates

### 2. Simple Environment Style (`env-simple`)

**Pattern:** `$SECRET_NAME`

Simple dollar-prefix format without braces. Requires word boundaries.

```bash
# Examples
export GITHUB_TOKEN=$GITHUB_TOKEN
PATH=$PATH:$HOME/bin
token=$API_TOKEN

# Be careful with concatenation
url="https://api.example.com/v1?key=$API_KEY&format=json"
```

**Advantages:**
- Cleaner appearance
- Common in shell scripts
- Less typing

**Disadvantages:**
- Can be ambiguous in concatenation
- Requires careful word boundary handling

**Use Cases:**
- Simple shell scripts
- Environment variable exports
- Quick command-line usage

### 3. Go Template Style (`go`)

**Pattern:** `{{ op://Employee/SECRET_NAME/field }}`

1Password's native template format, includes vault and field specification.

```yaml
# Examples
github:
  token: {{ op://Employee/GITHUB_TOKEN/credential }}
  
database:
  password: {{ op://Private/DB_PASSWORD/password }}
  
api:
  key: {{ op://Work/API_KEY/credential }}
```

**Advantages:**
- Native 1Password support
- Explicit vault specification
- Field-level granularity
- Clear intent

**Disadvantages:**
- More verbose
- Requires knowledge of vault structure

**Use Cases:**
- 1Password-aware configurations
- When vault specification is important
- Complex secret structures
- Documentation of secret sources

### 4. Custom Markers (`custom`)

**Pattern:** `%%SECRET_NAME%%`

Double percent signs for clear delimitation.

```ini
# Examples
[database]
host = localhost
user = admin
password = %%DB_PASSWORD%%

[api]
endpoint = https://api.example.com
token = %%API_TOKEN%%
```

**Advantages:**
- Very distinctive
- Unlikely to conflict
- Easy to search/replace
- Clear visual markers

**Use Cases:**
- INI configuration files
- Custom application configs
- When other formats conflict
- Legacy system templates

### 5. Double Brace Style (`double-brace`)

**Pattern:** `{{SECRET_NAME}}`

Popular in many templating systems (Handlebars, Jinja2-like).

```yaml
# Examples
server:
  host: {{SERVER_HOST}}
  port: {{SERVER_PORT}}
  
credentials:
  username: {{DB_USERNAME}}
  password: {{DB_PASSWORD}}
  
features:
  api_key: {{FEATURE_API_KEY}}
```

**Advantages:**
- Common in templating systems
- Clean and readable
- Good for YAML/JSON
- Familiar to many developers

**Use Cases:**
- YAML configuration files
- JSON templates
- Application configurations
- CI/CD pipelines

## Format Selection Guide

Choose your format based on:

### File Type Compatibility

| File Type | Recommended Format | Example |
|-----------|-------------------|---------|
| Shell scripts | `env` or `env-simple` | `${VAR}` or `$VAR` |
| YAML files | `double-brace` | `{{VAR}}` |
| INI files | `custom` or `env` | `%%VAR%%` or `${VAR}` |
| JSON files | `double-brace` | `{{VAR}}` |
| Dockerfiles | `env` | `${VAR}` |
| Makefiles | `env` | `${VAR}` |

### Conflict Avoidance

Avoid format conflicts with the file's native syntax:

```bash
# Makefile - use double-brace to avoid Make variable conflict
CC = gcc
API_KEY = {{COMPILER_API_KEY}}

# Shell with existing ${} usage - use custom markers
echo "User home: ${HOME}"
echo "API key: %%API_KEY%%"

# YAML with Go templates - use different format
template: |
  {{ .Values.something }}
  apiKey: %%API_KEY%%
```

## Advanced Patterns

### Mixed Formats

While not recommended, you can mix formats if needed:

```bash
# The system will auto-detect the dominant format
export TOKEN=${GITHUB_TOKEN}  # env format
export KEY=$API_KEY           # env-simple format
```

### Nested Templates

For complex scenarios with nested values:

```yaml
# Using environment variables in URLs
database:
  url: "postgres://user:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# Multiple secrets in one line
connection: "${PROTOCOL}://${USERNAME}:${PASSWORD}@${HOST}"
```

### Conditional Secrets

Templates can include conditional logic:

```bash
# Shell conditionals with secrets
if [[ -n "${WORK_TOKEN}" ]]; then
    export API_ENDPOINT="${WORK_ENDPOINT}"
else
    export API_ENDPOINT="${PERSONAL_ENDPOINT}"
fi
```

## Token Naming Conventions

### Standard Patterns

1. **Service + Type**
   ```
   GITHUB_TOKEN
   GITLAB_TOKEN
   AWS_ACCESS_KEY_ID
   ```

2. **Environment + Service + Type**
   ```
   PROD_DATABASE_PASSWORD
   DEV_API_KEY
   STAGING_SECRET_KEY
   ```

3. **Purpose + Type**
   ```
   DEPLOY_SSH_KEY
   BACKUP_ENCRYPTION_KEY
   MONITORING_API_TOKEN
   ```

### Best Practices

1. **Always use UPPERCASE** for token names
2. **Use underscores** to separate words
3. **Be descriptive** but concise
4. **Include context** when needed
5. **Avoid abbreviations** that might be unclear

## Escaping and Special Characters

### Escaping Token Markers

When you need literal token markers in your template:

```bash
# To get literal ${TEXT}, double the dollar sign
echo "$${TEXT}"  # Outputs: ${TEXT}

# Or use quotes strategically
echo '${TEXT}'   # Outputs: ${TEXT} literally
```

### Special Characters in Values

The injection system handles special characters in secret values:

```bash
# Secrets with special characters are properly escaped
PASSWORD="${COMPLEX_PASSWORD}"  # Even if it contains $, ", ', etc.
```

## Format Auto-Detection

The system automatically detects the template format:

```bash
# Check detected format
scripts/validate-templates.sh mytemplate.tmpl

# Output:
# Format: env (auto-detected)
```

### Detection Priority

When multiple formats are present:
1. `go` format (most specific)
2. `env` format (most common)
3. `double-brace` format
4. `custom` format
5. `env-simple` format (least specific)

## Migration Between Formats

### Converting Formats

To change template formats:

```bash
# Original (env format)
token=${GITHUB_TOKEN}

# Convert to go format
token={{ op://Employee/GITHUB_TOKEN/credential }}

# Convert to custom format
token=%%GITHUB_TOKEN%%
```

### Bulk Conversion

For bulk conversion, use sed or similar tools:

```bash
# Convert env to custom format
sed -i 's/\${([A-Z_]+)\}/%%\1%%/g' template.tmpl

# Convert simple to env format
sed -i 's/\$([A-Z_][A-Z0-9_]*)\b/${\1}/g' template.tmpl
```

## Debugging Templates

### View Token Extraction

```bash
# See what tokens are detected
TEMPLATE_DEBUG=true scripts/inject-secrets.sh --dry-run template.tmpl
```

### Test Format Detection

```bash
# Create test file with different formats
cat > test.tmpl << 'EOF'
env: ${TOKEN1}
simple: $TOKEN2
go: {{ op://Employee/TOKEN3/credential }}
custom: %%TOKEN4%%
double: {{TOKEN5}}
EOF

# Validate to see detection
scripts/validate-templates.sh test.tmpl
```

## Common Pitfalls

### 1. Case Sensitivity
```bash
# WRONG - lowercase
${github_token}

# CORRECT - uppercase
${GITHUB_TOKEN}
```

### 2. Partial Matches
```bash
# WRONG - might match partially
$GITHUB_TOKEN_EXPIRES  # Might match GITHUB_TOKEN

# CORRECT - use braces for clarity
${GITHUB_TOKEN}_EXPIRES
```

### 3. Format Mixing
```bash
# AVOID - mixed formats in one file
token1=${TOKEN1}
token2={{TOKEN2}}
token3=%%TOKEN3%%
```

### 4. Missing Word Boundaries
```bash
# WRONG - no word boundary
prefix$TOKENsuffix

# CORRECT - use braces
prefix${TOKEN}suffix
```

## Performance Considerations

Different formats have similar performance, but:

1. **Simple formats** (`env-simple`) are fastest to parse
2. **Complex formats** (`go`) require more processing
3. **Auto-detection** adds slight overhead
4. **Specific format** selection improves performance

```bash
# Faster - specific format
scripts/inject-secrets.sh --format env template.tmpl

# Slower - auto-detection
scripts/inject-secrets.sh template.tmpl
```

## Future Formats

The template engine is extensible. To request new formats, consider:

1. **Use case** - Why is a new format needed?
2. **Syntax** - What pattern should it match?
3. **Conflicts** - What existing tools use this syntax?
4. **Examples** - Real-world usage examples 