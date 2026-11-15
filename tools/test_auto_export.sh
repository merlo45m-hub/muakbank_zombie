#!/bin/bash
# Test harness for vps_auto_export.py — no real APK build, throwaway state/clone.
# Portable: override SC to any writable scratch dir. Never touches live state.
set -u
SC="${MKB_TEST_SCRATCH:-$PWD/.mkb_test_scratch}"
STATE=$SC/mkb_test_state
CLONE=$SC/mkb_test_clone
APK=$SC/mkb_test.apk
POLLER="${MKB_POLLER:-/root/bin/vps_auto_export.py}"
mkdir -p "$SC"
rm -f "$STATE" "$APK"
rm -rf "$CLONE"
export MKB_STATE="$STATE" MKB_EXPORT_DIR="$CLONE" MKB_APK_OUT="$APK" MKB_BRANCH=main
export MKB_DEV_REPO="${MKB_DEV_REPO:-/root/muakbank_zombie}"
export MKB_PHONE_COPY=0
# Stub export: create a valid APK-shaped zip (the artifact the poller validates).
export MKB_EXPORT_CMD="python3 -c \"import zipfile; z=zipfile.ZipFile('__APK__','w'); z.writestr('AndroidManifest.xml',b'x'); z.writestr('classes.dex',b'x'); z.writestr('resources.arsc',b'x'); z.writestr('assets/payload.bin',b'0'*1200000); z.close()\" && test -f $CLONE/project.godot"
export MKB_IMPORT_CMD="true"
echo "=== T1: first run (should detect + export) ==="
python3 "$POLLER"; echo "rc=$? state=$(cat "$STATE" 2>/dev/null)"
echo "=== T2: immediate second run (should be SILENT, no output) ==="
out=$(python3 "$POLLER"); echo "rc=$? output='$out'"
echo "=== T3: forced change (wipe state, should re-export) ==="
rm -f "$STATE"
python3 "$POLLER"; echo "rc=$? state=$(cat "$STATE" 2>/dev/null)"
echo "=== T4: DRY_RUN (detect+record, no export) ==="
rm -f "$STATE" "$APK"
MKB_DRY_RUN=1 python3 "$POLLER"; echo "rc=$? apk_exists=$(test -f "$APK" && echo yes || echo no) state=$(cat "$STATE" 2>/dev/null)"
echo "=== T5: failing export command (should FAIL and NOT record state) ==="
rm -f "$STATE"
export MKB_EXPORT_CMD="exit 7"
python3 "$POLLER"; echo "rc=$? state_exists=$(test -f "$STATE" && echo yes || echo no)"
rm -f "$STATE" "$APK"; rm -rf "$CLONE"
echo "=== CLEANUP DONE ==="
