#!/bin/bash
# One-command VPS export wrapper
# Pushes latest to GitHub → VPS pulls → Godot exports Android APK → APK copied to phone
# Usage: bash tools/export_on_vps.sh [push|pull|export|full]
# Default: full (push + pull + export + copy)

set -e

PROJECT="/storage/emulated/0/Games/Muakbank_zombie"
VPS="root@162.35.174.155"
VPS_KEY="$HOME/.ssh/id_ed25519"
VPS_GODOT="/root/Godot_v4.7-stable_linux.x86_64"
VPS_PROJECT="/root/muakbank_zombie"
PHONE_APK_DIR="/storage/emulated/0/Download"
ACTION="${1:-full}"

echo "========================================"
echo "  VPS Export: $ACTION"
echo "========================================"
echo ""

# Function to run command on VPS
vps() {
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$VPS_KEY" \
        "$VPS" "$1" 2>&1
}

case "$ACTION" in
    push)
        echo "--- [1/4] Pushing to GitHub ---"
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" push origin main 2>&1
        echo "✓ Pushed"
        ;;
    pull)
        echo "--- [2/4] Pulling on VPS ---"
        vps "cd $VPS_PROJECT && git pull origin main" 2>&1
        echo "✓ VPS pulled"
        ;;
    export)
        echo "--- [3/4] Exporting Android APK on VPS ---"
        vps "cd $VPS_PROJECT && $VPS_GODOT --headless --export-release 'Muakbank Zombie' --export-path /root/builds/muakbank_latest.apk" 2>&1
        echo "✓ Exported"
        ;;
    copy)
        echo "--- [4/4] Copying APK to phone ---"
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$VPS_KEY" \
            "$VPS:/root/builds/muakbank_latest.apk" \
            "$PHONE_APK_DIR/muakbank_latest_$(date +%Y%m%d_%H%M%S).apk" 2>&1
        echo "✓ Copied to $PHONE_APK_DIR"
        ;;
    full)
        echo "--- [1/4] Pushing to GitHub ---"
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" push origin main 2>&1
        echo "✓ Pushed"

        echo ""
        echo "--- [2/4] Pulling on VPS ---"
        vps "cd $VPS_PROJECT && git pull origin main" 2>&1
        echo "✓ VPS pulled"

        echo ""
        echo "--- [3/4] Exporting Android APK on VPS ---"
        vps "cd $VPS_PROJECT && $VPS_GODOT --headless --export-release 'Muakbank Zombie' --export-path /root/builds/muakbank_latest.apk" 2>&1
        echo "✓ Exported"

        echo ""
        echo "--- [4/4] Copying APK to phone ---"
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$VPS_KEY" \
            "$VPS:/root/builds/muakbank_latest.apk" \
            "$PHONE_APK_DIR/muakbank_latest_$(date +%Y%m%d_%H%M%S).apk" 2>&1
        echo "✓ Copied"
        ;;
    *)
        echo "Usage: bash tools/export_on_vps.sh [push|pull|export|copy|full]"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "  Done"
echo "========================================"
