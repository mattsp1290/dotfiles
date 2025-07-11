# Templates Directory

This directory contains template files for configuration files that need secret injection. Templates allow you to store configuration files in version control without exposing sensitive information.

## Template Formats

The secret injection system supports multiple template formats:

### 1. Environment Variable Style (Default)
```bash
# ${SECRET_NAME} format
export GITHUB_TOKEN=${GITHUB_TOKEN}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
```

### 2. Simple Environment Style
```bash
# $SECRET_NAME format (be careful with word boundaries)
export GITHUB_TOKEN=$GITHUB_TOKEN
api_key=$ANTHROPIC_API_KEY
```

### 3. Go Template Style (1Password Native)
```bash
# {{ op://Employee/SECRET_NAME/field }} format
github_token={{ op://Employee/GITHUB_TOKEN/credential }}
aws_key={{ op://Employee/AWS_ACCESS_KEY_ID/credential }}
```

### 4. Custom Markers
```bash
# %%SECRET_NAME%% format
[credentials]
token = %%GITHUB_TOKEN%%
api_key = %%ANTHROPIC_API_KEY%%
```

### 5. Double Brace Style
```bash
# {{SECRET_NAME}} format
password: {{DATABASE_PASSWORD}}
api_key: {{API_KEY}}
```

## Usage

### Processing a Single Template
```bash
# Process a template file
../scripts/inject-secrets.sh aws/credentials.tmpl

# Output to specific file
../scripts/inject-secrets.sh -o ~/.aws/credentials aws/credentials.tmpl

# Dry run to preview changes
../scripts/inject-secrets.sh --dry-run shell/profile.tmpl
```

### Batch Processing
```bash
# Process all templates in this directory
../scripts/inject-all.sh

# Dry run first
../scripts/inject-all.sh --dry-run
```

### Validating Templates
```bash
# Validate syntax and check secrets
../scripts/validate-templates.sh aws/credentials.tmpl

# Validate without checking if secrets exist
../scripts/validate-templates.sh --no-check shell/profile.tmpl
```

## Creating Templates

1. Copy your configuration file to this directory
2. Add an appropriate extension (.template, .tmpl, or .tpl)
3. Replace sensitive values with template tokens
4. Test with dry-run mode
5. Add to version control

## Best Practices

1. **Use UPPERCASE** for secret names (e.g., `GITHUB_TOKEN`, not `github_token`)
2. **Be consistent** with your template format within a file
3. **Test templates** with dry-run mode before applying
4. **Document** which secrets are required for each template
5. **Use descriptive names** for your secrets in 1Password

## Directory Structure

```
templates/
├── README.md          # This file
├── aws/              # AWS configuration templates
│   └── credentials.tmpl
├── shell/            # Shell configuration templates
│   ├── profile.tmpl
│   └── env.tmpl
├── git/              # Git configuration templates
│   └── config.tmpl
└── ssh/              # SSH configuration templates
    └── config.tmpl
```

## Required Secrets

The templates in this directory may require the following secrets:

### Common Secrets
- `GITHUB_TOKEN` - GitHub personal access token
- `GITLAB_TOKEN` - GitLab personal access token
- `ANTHROPIC_API_KEY` - Anthropic API key
- `OPENAI_API_KEY` - OpenAI API key

### AWS Secrets
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `AWS_SESSION_TOKEN` - AWS session token (optional)

### Work-specific Secrets
- `DATADOG_API_KEY` - Datadog API key
- `DATADOG_APP_KEY` - Datadog application key

## Troubleshooting

### Template not processing
- Check file extension (.template, .tmpl, or .tpl)
- Verify template syntax with `validate-templates.sh`
- Ensure you're signed in to 1Password

### Secrets not found
- Check secret name spelling (case-sensitive)
- Verify secret exists in 1Password Employee vault
- Try using `--vault` option for different vaults

### Performance issues
- Use `--warm-cache` to preload common secrets
- Set `OP_CACHE_TTL` for longer cache duration
- Process templates in batch with `inject-all.sh` 