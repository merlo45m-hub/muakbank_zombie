#!/bin/bash
# Git health check — run before any git operation
# Usage: bash tools/git_health_check.sh [project_path]

PROJECT="${1:-/storage/emulated/0/Games/Muakbank_zombie}"
GIT_DIR="$PROJECT/.git"
WORK_TREE="$PROJECT"

echo "=== Git Health Check: $PROJECT ==="

# 1. HEAD exists
if [ -f "$GIT_DIR/HEAD" ]; then
    HEAD_CONTENT=$(cat "$GIT_DIR/HEAD")
    echo "✓ HEAD: $HEAD_CONTENT"
else
    echo "✗ FAIL: .git/HEAD missing"
    exit 1
fi

# 2. Branch ref exists
BRANCH=$(echo "$HEAD_CONTENT" | sed 's|ref: refs/heads/||')
if [ -f "$GIT_DIR/refs/heads/$BRANCH" ]; then
    echo "✓ Branch ref: $BRANCH"
else
    echo "✗ FAIL: refs/heads/$BRANCH missing"
    exit 1
fi

# 3. Safe directory
if git config --global --get-all safe.directory 2>/dev/null | grep -qF "$PROJECT"; then
    echo "✓ Safe directory configured"
else
    echo "✗ WARN: safe.directory not set"
fi

# 4. GitHub auth
if gh auth status 2>/dev/null | grep -q "Logged in"; then
    echo "✓ GitHub auth: active"
else
    echo "✗ FAIL: gh not authenticated"
    exit 1
fi

# 5. Status (no cd — use explicit paths)
STATUS=$(git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" status --short 2>&1)
if [ $? -eq 0 ]; then
    if [ -z "$STATUS" ]; then
        echo "✓ Clean working tree"
    else
        echo "⚠ Changes:"
        echo "$STATUS"
    fi
else
    echo "✗ FAIL: git status — $STATUS"
    exit 1
fi

echo "=== All checks passed ==="
exit 0
