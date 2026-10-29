#!/bin/bash
# One-command VPS export wrapper (Muakbank Zombie)
# Edit on phone -> push rescue/muakbank-work -> VPS pulls -> Godot exports Android APK -> APK copied to phone Download
# Usage: bash tools/export_on_vps.sh [push|pull|export|release|copy|full]
# Default: full (push + pull + export + copy)
#
# Canonical branch is rescue/muakbank-work while main stays clean (see docs/BRANCH_WORKFLOW.md).
# Routing uses the `vps` ssh alias (WireGuard 10.9.0.1) with a vpspub (public IP) fallback.

set -e

PROJECT="/storage/emulated/0/Games/Muakbank_zombie"
BRANCH="rescue/muakbank-work"

# ssh routing: prefer the `vps` alias (fast wireguard), fall back to public IP (vpspub)
if ssh -o ConnectTimeout=5 -o BatchMode=yes vps true 2>/dev/null; then
    VPS_HOST="vps"
elif ssh -o ConnectTimeout=5 -o BatchMode=yes root@162.35.174.155 true 2>/dev/null; then
    VPS_HOST="root@162.35.174.155"
else
    echo "ERROR: cannot reach VPS via 'ssh vps' or root@162.35.174.155" >&2
    exit 1
fi

VPS_GODOT="/root/Godot_v4.7-stable_linux.x86_64"
VPS_PROJECT="/root/muakbank_zombie"
PHONE_APK_DIR="/storage/emulated/0/Download"
ACTION="${1:-full}"

echo "=========================================="
echo "  VPS Export: $ACTION  (branch: $BRANCH)"
echo "=========================================="

# run command on VPS
vps() {
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VPS_HOST" "$1" 2>&1
}

case "$ACTION" in
    push)
        echo "--- [1/4] Pushing $BRANCH to GitHub ---"
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" push origin "$BRANCH" 2>&1
        echo "OK pushed"
        ;;
    pull)
        echo "--- [2/4] Pulling on VPS ---"
        vps "cd $VPS_PROJECT && git fetch origin && git checkout $BRANCH 2>&1 && git pull origin $BRANCH" 2>&1
        echo "OK vps pulled"
        ;;
    export)
        echo "--- [3/4] Exporting Android APK on VPS ---"
        vps "mkdir -p /root/builds && cd $VPS_PROJECT && $VPS_GODOT --headless --import --path $VPS_PROJECT 2>&1 | tail -3 && $VPS_GODOT --headless --export-debug 'Android' --export-path /root/builds/muakbank_latest.apk" 2>&1
        echo "OK exported"
        ;;
    release)
        # Store-release-signed export. Uses the recovered release keystore
        # (alias "muakbank"; password from the MKB_RELEASE_PASS env var, never
        # committed — matches export_presets.cfg's blank release_password design).
        # The keystore must exist at the res:// path the preset references:
        #   cp /root/.local/share/godot/keystores/release.keystore /root/muakbank_zombie/muakbank-release.keystore
        echo "--- [3/4] Exporting RELEASE-signed Android APK on VPS ---"
        if [ -z "$MKB_RELEASE_PASS" ]; then
            echo "ERROR: MKB_RELEASE_PASS not set (release keystore password)." >&2
            echo "  Run: MKB_RELEASE_PASS='<pass>' bash tools/export_on_vps.sh release" >&2
            exit 1
        fi
        vps "mkdir -p /root/builds && cd $VPS_PROJECT && $VPS_GODOT --headless --import --path $VPS_PROJECT 2>&1 | tail -3 && GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='$MKB_RELEASE_PASS' $VPS_GODOT --headless --export-release 'Android' --export-path /root/builds/muakbank_release_$(date +%Y%m%d).apk" 2>&1
        echo "OK release-exported (see /root/builds/muakbank_release_*.apk on VPS)"
        ;;
    copy)
        echo "--- [4/4] Copying APK to phone ---"
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VPS_HOST:/root/builds/muakbank_latest.apk" \
            "$PHONE_APK_DIR/muakbank_latest_$(date +%Y%m%d_%H%M%S).apk" 2>&1
        echo "OK copied to $PHONE_APK_DIR"
        ;;
    full)
        echo "--- [1/4] Pushing $BRANCH to GitHub ---"
        git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" push origin "$BRANCH" 2>&1
        echo "OK pushed"
        echo ""
        echo "--- [2/4] Pulling on VPS ---"
        vps "cd $VPS_PROJECT && git fetch origin && git checkout $BRANCH 2>&1 && git pull origin $BRANCH" 2>&1
        echo "OK vps pulled"
        echo ""
        echo "--- [3/4] Exporting Android APK on VPS ---"
        vps "mkdir -p /root/builds && cd $VPS_PROJECT && $VPS_GODOT --headless --import --path $VPS_PROJECT 2>&1 | tail -3 && $VPS_GODOT --headless --export-debug 'Android' --export-path /root/builds/muakbank_latest.apk" 2>&1
        echo "OK exported"
        echo ""
        echo "--- [4/4] Copying APK to phone ---"
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VPS_HOST:/root/builds/muakbank_latest.apk" \
            "$PHONE_APK_DIR/muakbank_latest_$(date +%Y%m%d_%H%M%S).apk" 2>&1
        echo "OK copied to $PHONE_APK_DIR"
        ;;
    *)
        echo "Usage: bash tools/export_on_vps.sh [push|pull|export|copy|full]"
        exit 1
        ;;
esac

echo "=========================================="
echo "  Done"
echo "=========================================="
