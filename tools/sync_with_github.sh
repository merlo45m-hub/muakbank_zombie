#!/bin/bash
# Sync phone project with GitHub
# Usage: bash tools/sync_with_github.sh [pull|push|both]
# Default: both

PROJECT="/storage/emulated/0/Games/Muakbank_zombie"
ACTION="${1:-both}"

echo "=== Sync: $ACTION ==="

case "$ACTION" in
    pull|both)
        echo "--- Pulling from GitHub ---"
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" fetch origin main 2>&1
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" log --oneline -1 origin/main 2>&1
        ;;
    push|both)
        echo "--- Pushing to GitHub ---"
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" push origin main 2>&1
        ;;
    *)
        echo "Usage: bash tools/sync_with_github.sh [pull|push|both]"
        exit 1
        ;;
esac

echo ""
echo "--- Status ---"
git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" status --short 2>&1
