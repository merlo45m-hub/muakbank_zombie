#!/bin/bash
# Rebuild + verify the Android APK (run INSIDE proot ubuntu with binds:
#   --bind /data/data/com.termux/files/home/godot:/godot
#   --bind /storage/emulated/0/Games/Muakbank_zombie:/game
# )
#
# SIGNING KEY IS LOAD-BEARING: the phone already has this app installed, signed with
# /root/.local/share/godot/keystores/debug.keystore (CN=Godot, SHA-1 004dee77...).
# Android refuses to update an installed package with a different signing key, so the
# rebuild must be signed by that same keystore. It is configured as Godot's default
# debug keystore in editor_settings-4.7.tres, so a normal debug export signs correctly.
set -e
cd /game || exit 1
G=/godot/Godot_v4.7.2-stable_linux.arm64
OUT=/game/build/muakbank_zombie.apk
APKSIGNER=/opt/android-sdk/build-tools/34.0.0/apksigner
KS=/root/.local/share/godot/keystores/debug.keystore

echo "=== 1/3 export ==="
"$G" --headless --export-debug "Android" "$OUT" 2>&1 | grep -viE "^$|Texture|libpng" | tail -6
ls -l "$OUT"

echo "=== 2/3 signature check ==="
if "$APKSIGNER" verify --print-certs "$OUT" > /tmp/apksig.txt 2>&1; then
	grep -E "DN|SHA-1 digest" /tmp/apksig.txt | head -4
else
	echo "!! export did not produce a v2/v3 signature - signing manually"
	"$APKSIGNER" sign --ks "$KS" --ks-pass pass:android --ks-key-alias androiddebugkey \
		--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true "$OUT"
	"$APKSIGNER" verify --print-certs "$OUT" 2>&1 | grep -E "DN|SHA-1 digest" | head -4
fi

echo "=== 3/3 artifacts ==="
ls -l "$OUT" /game/build/muakbank_zombie.apk.idsig 2>/dev/null || true
sha256sum "$OUT"
echo "READY - copy to /sdcard/Download on the host side"
