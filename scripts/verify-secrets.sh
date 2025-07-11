#!/bin/bash
# Secret Migration Verification Script
# Tests that all migrated secrets are accessible and performant

source scripts/lib/secret-helpers.sh

echo "=== Secret Migration Verification ==="
echo "Date: $(date)"
echo "Account: $(op account get --format json | jq -r .email)"
echo

# Count total tests
total_tests=0
passed_tests=0

# Test AWS access
echo -n "Testing AWS credentials... "
if AWS_ACCESS_KEY_ID=$(get_secret AWS_ACCESS_KEY_ID credential Employee) && [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

# Test Azure Service Principal
echo -n "Testing Azure Service Principal... "
if get_secret AZURE_CLIENT_ID credential Employee >/dev/null 2>&1 && \
   get_secret AZURE_CLIENT_SECRET credential Employee >/dev/null 2>&1; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

# Test Azure Storage
echo -n "Testing Azure storage keys... "
if get_secret AZURE_STORAGE_MATTLOGGER credential Employee >/dev/null 2>&1; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

# Test Git tokens
echo -n "Testing GitHub token... "
if get_secret GITHUB_TOKEN credential Employee >/dev/null 2>&1; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

echo -n "Testing GitLab token... "
if get_secret GITLAB_TOKEN credential Employee >/dev/null 2>&1; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

# Test API keys
echo -n "Testing Datadog keys... "
if get_secret DD_API_KEY credential Employee >/dev/null 2>&1 && \
   get_secret DD_APP_KEY credential Employee >/dev/null 2>&1; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

echo -n "Testing Anthropic API key... "
if get_secret ANTHROPIC_API_KEY credential Employee >/dev/null 2>&1; then
    echo "✓ Pass"
    ((passed_tests++))
else
    echo "✗ Fail"
fi
((total_tests++))

# Performance test
echo -n "Testing retrieval performance... "
start_time=$(date +%s%N)
get_secret AWS_ACCESS_KEY_ID credential Employee >/dev/null 2>&1
end_time=$(date +%s%N)
elapsed_ms=$(( (end_time - start_time) / 1000000 ))

if [ $elapsed_ms -lt 100 ]; then
    echo "✓ Pass (${elapsed_ms}ms)"
    ((passed_tests++))
else
    echo "✗ Fail (${elapsed_ms}ms > 100ms)"
fi
((total_tests++))

echo
echo "=== Verification Summary ==="
echo "Total tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $((total_tests - passed_tests))"
echo "Success rate: $(( passed_tests * 100 / total_tests ))%"

# Update verification status in migration log
if [ $passed_tests -eq $total_tests ]; then
    echo "- All secrets verified: $(date)" >> proompting/secrets/migration_log.md
    echo
    echo "✓ All secrets successfully migrated and verified!"
else
    echo "- Verification incomplete: $passed_tests/$total_tests passed at $(date)" >> proompting/secrets/migration_log.md
    echo
    echo "⚠️  Some secrets failed verification. Please check the output above."
fi 