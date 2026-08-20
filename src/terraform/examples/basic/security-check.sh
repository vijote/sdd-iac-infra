#!/bin/bash

echo "🔒 Security Check for Public Repository"
echo "======================================"
echo ""

# Check for potential secrets
echo "🔍 Checking for potential secrets..."

# Patterns that should not be in public repos (excluding documentation)
secrets_patterns=(
    "access_key.*=.*[A-Za-z0-9]{16,}"
    "secret_key.*=.*[A-Za-z0-9]{16,}"
    "password.*=.*[^\\s\\\"]{8,}"
    "token.*=.*[^\\s\\\"]{8,}"
)

found_issues=false

for pattern in "${secrets_patterns[@]}"; do
    if grep -r -E "$pattern" . --include="*.tf" --include="*.md" --include="*.sh" 2>/dev/null; then
        echo "❌ Found potential secret pattern: $pattern"
        found_issues=true
    fi
done

# Check for sensitive files
echo ""
echo "📁 Checking for sensitive files..."

sensitive_files=(
    "*.tfstate"
    "*.tfvars"
    ".env"
    "credentials"
    "key"
)

for file_pattern in "${sensitive_files[@]}"; do
    if ls $file_pattern 2>/dev/null; then
        echo "❌ Found sensitive file: $file_pattern"
        found_issues=true
    fi
done

# Check if .gitignore exists and has proper entries
echo ""
echo "📋 Checking .gitignore..."
if [ -f ".gitignore" ]; then
    echo "✅ .gitignore exists"
    
    required_entries=(
        "*.tfstate"
        "*.tfvars"
        ".env"
        ".terraform/"
    )
    
    for entry in "${required_entries[@]}"; do
        if grep -q "$entry" .gitignore; then
            echo "✅ .gitignore contains: $entry"
        else
            echo "⚠️  .gitignore missing: $entry"
        fi
    done
else
    echo "❌ No .gitignore found"
    found_issues=true
fi

# Summary
echo ""
if [ "$found_issues" = true ]; then
    echo "❌ SECURITY ISSUES FOUND - Fix before committing to public repository!"
    exit 1
else
    echo "✅ No obvious security issues detected"
    echo "🎉 This directory is ready for a public repository!"
fi