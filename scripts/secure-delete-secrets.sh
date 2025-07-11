#!/bin/bash
# Secure Secret Deletion Script
# Safely removes secrets after successful migration to 1Password

echo "=== Secure Secret Deletion ==="
echo "Date: $(date)"
echo

echo "WARNING: This will securely delete original secret files!"
echo "Ensure all secrets are migrated and verified first."
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 1
fi

# Check if verification was successful
if [ -f proompting/secrets/migration_log.md ]; then
    if grep -q "✅ All verification tests passed" proompting/secrets/migration_log.md; then
        echo "✓ Verification tests passed"
    else
        echo "❌ Verification tests have not passed or not run"
        echo "   Run ./scripts/verify-secrets.sh first"
        exit 1
    fi
else
    echo "❌ Migration log not found"
    exit 1
fi

echo
echo "Starting secure deletion..."

# Function to securely delete a file
secure_delete() {
    local file="$1"
    if [ -f "$file" ]; then
        # Overwrite with random data (use gshred if available on macOS, otherwise dd)
        if command -v gshred >/dev/null 2>&1; then
            gshred -vfz -n 3 "$file"
        else
            # Use dd for secure overwrite
            size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
            dd if=/dev/urandom of="$file" bs=1024 count=$(( (size / 1024) + 1 )) 2>/dev/null
        fi
        # Remove the file
        rm -f "$file"
        echo "Securely deleted: $file"
    fi
}

# Track deletion stats
deleted_count=0
failed_count=0

# Delete backup files containing secrets
echo
echo "Deleting backup files..."
find proompting/secrets/backup -name "*.bak" -type f | while read file; do
    if secure_delete "$file"; then
        ((deleted_count++))
    else
        ((failed_count++))
    fi
done

# Clean up other sensitive files
echo
echo "Cleaning up template files with examples..."

# Remove any .netrc files that might contain tokens
if [ -f ~/.netrc ]; then
    echo "Found ~/.netrc file"
    read -p "Delete ~/.netrc? (y/n): " delete_netrc
    if [ "$delete_netrc" = "y" ]; then
        if secure_delete ~/.netrc; then
            ((deleted_count++))
        else
            ((failed_count++))
        fi
    fi
fi

# Clear bash history of any secret commands
echo
echo "Clearing command history containing secrets..."
# Remove lines containing common secret patterns
if [ -f ~/.bash_history ]; then
    grep -v -E "(AWS_|AZURE_|ghp_|glpat-|sk-ant-|DD_API|DD_APP)" ~/.bash_history > ~/.bash_history.tmp
    mv ~/.bash_history.tmp ~/.bash_history
fi

if [ -f ~/.zsh_history ]; then
    grep -v -E "(AWS_|AZURE_|ghp_|glpat-|sk-ant-|DD_API|DD_APP)" ~/.zsh_history > ~/.zsh_history.tmp
    mv ~/.zsh_history.tmp ~/.zsh_history
fi

# Clear any temporary files
echo
echo "Cleaning temporary files..."
find /tmp -name "*secret*" -o -name "*credential*" -o -name "*token*" 2>/dev/null | while read tmpfile; do
    if [ -f "$tmpfile" ] && [ -O "$tmpfile" ]; then
        secure_delete "$tmpfile" >/dev/null 2>&1
    fi
done

# Update migration log
echo
echo "Updating migration log..."
cat >> proompting/secrets/migration_log.md << EOF

### Secure Deletion Completed
- Date: $(date)
- Files deleted: $deleted_count
- Failures: $failed_count
- Shell history cleaned: Yes
EOF

echo
echo "=== Secure Deletion Summary ==="
echo "Files deleted: $deleted_count"
echo "Failed deletions: $failed_count"
echo

if [ $failed_count -eq 0 ]; then
    echo "✅ Secure deletion completed successfully"
    echo
    echo "Next steps:"
    echo "1. Review ~/.profile and remove any remaining secrets"
    echo "2. Review ~/.aws/credentials and replace with template"
    echo "3. Run a final security scan to confirm no secrets remain"
    echo "4. Commit the sanitized configuration files"
else
    echo "⚠️  Some files could not be deleted"
    echo "Please manually check and remove any remaining sensitive files"
fi 