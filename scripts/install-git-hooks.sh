#!/bin/bash
# Git Hooks Installer for CLAUDE.md v2025.01 Compliance
# Run this script to install pre-commit hooks

set -e

echo "🔧 Installing Git hooks for CLAUDE_VERSION: v2025.01"
echo "=================================================="

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository. Run this from the repository root."
    exit 1
fi

# Create hooks directory if it doesn't exist
HOOKS_DIR=".git/hooks"
mkdir -p "$HOOKS_DIR"

# Install pre-commit hook
SOURCE_HOOK="scripts/git-hooks/pre-commit"
TARGET_HOOK="$HOOKS_DIR/pre-commit"

if [ ! -f "$SOURCE_HOOK" ]; then
    echo "❌ Error: Source hook not found at $SOURCE_HOOK"
    exit 1
fi

# Backup existing hook if it exists
if [ -f "$TARGET_HOOK" ]; then
    echo "📋 Backing up existing pre-commit hook..."
    cp "$TARGET_HOOK" "$TARGET_HOOK.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Copy and make executable
echo "📥 Installing pre-commit hook..."
cp "$SOURCE_HOOK" "$TARGET_HOOK"
chmod +x "$TARGET_HOOK"

echo ""
echo "✅ Git hooks installation complete!"
echo ""
echo "The pre-commit hook will now:"
echo "  🔍 Check Swift files for 300-line limit compliance"
echo "  🧹 Run SwiftLint checks on staged files"
echo "  📝 Validate commit message format"
echo ""
echo "To test the hook:"
echo "  git add <some-file> && git commit -m 'test: verify pre-commit hook'"
echo ""
echo "To temporarily bypass the hook (NOT RECOMMENDED):"
echo "  git commit --no-verify"
echo ""
echo "For more information, see CLAUDE.md v2025.01"