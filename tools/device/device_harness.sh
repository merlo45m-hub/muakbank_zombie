#!/usr/bin/env bash
# Issue #21 / #23 follow-up — on-device shader/behaviour harness.
# Runs on the VPS, drives the phone over the self-healing mesh adb transport.
#
# Android 16 LogAccessDialog rule: reading logcat as an APP uid pops
# com.android.systemui/.logcat.LogAccessDialogActivity ("allow only one time").
# adb shell logcat executes as uid 2000(shell), which is ALLOWED and triggers
# nothing. NEVER invoke /system/bin/logcat directly from Termux/app code.
#
# Captures: gfxinfo framestats, thermal zones, a screencap of the shipped
# Vulkan/mobile renderer, and logcat filtered for shader/GPU errors.
set -uo pipefail
ADB_BIN="${CAP_ADB_BIN:-/root/bin/phone-adb}"
PKG="${CAP_PKG:-com.merlo45.muakbankzombie}"
OUT="${CAP_OUT:-/root/muakbank_zombie/build/device_capture}"
DURATION="${CAP_DURATION:-12}"
mkdir -p "$OUT"

"$ADB_BIN" shell whoami | grep -qx shell || { echo "DEVICE_FAIL not uid shell"; exit 1; }

# --- 1) Logcat dialog-bypass assertion -------------------------------------
# Read logcat THROUGH adb shell (uid 2000), then prove no dialog window exists.
"$ADB_BIN" shell logcat -d -t 50 > "$OUT/logcat_sample.txt" 2>&1
LOG_LINES=$(wc -l < "$OUT/logcat_sample.txt")
DIALOG=$("$ADB_BIN" shell dumpsys window windows 2>/dev/null | grep -ci 'LogAccessDialog' || true)
UID_TXT=$("$ADB_BIN" shell id 2>&1 | head -1)
echo "LOGCAT_ROUTE adb_shell lines=$LOG_LINES dialog_windows=$DIALOG"
echo "LOGCAT_UID $UID_TXT"

# --- 2) Launch the shipped app ---------------------------------------------
"$ADB_BIN" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > "$OUT/launch.log" 2>&1
sleep 3
FOCUS=$("$ADB_BIN" shell dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus' || true)
echo "FOREGROUND $FOCUS"

# --- 3) Frame metrics -------------------------------------------------------
"$ADB_BIN" shell dumpsys gfxinfo "$PKG" framestats > "$OUT/gfxinfo.txt" 2>&1
"$ADB_BIN" shell dumpsys gfxinfo "$PKG" > "$OUT/gfxinfo_summary.txt" 2>&1
echo "GFXINFO_BYTES $(wc -c < "$OUT/gfxinfo.txt")"

# --- 4) Thermal metrics -----------------------------------------------------
"$ADB_BIN" shell dumpsys thermalservice > "$OUT/thermal_service.txt" 2>&1 || true
"$ADB_BIN" shell 'for f in /sys/class/thermal/thermal_zone*/temp; do echo "$f $(cat $f)"; done' \
  > "$OUT/thermal_zones.txt" 2>&1 || true
echo "THERMAL_ZONES $(wc -l < "$OUT/thermal_zones.txt")"

# --- 5) Frame capture of the REAL renderer ---------------------------------
sleep "$DURATION"
"$ADB_BIN" shell screencap -p /sdcard/cap23_device.png > /dev/null 2>&1
"$ADB_BIN" pull /sdcard/cap23_device.png "$OUT/device_frame.png" > /dev/null 2>&1
"$ADB_BIN" shell rm -f /sdcard/cap23_device.png > /dev/null 2>&1
if [ -s "$OUT/device_frame.png" ]; then
  echo "DEVICE_FRAME_OK bytes=$(wc -c < "$OUT/device_frame.png")"
else
  echo "DEVICE_FRAME_MISSING"
fi

# --- 6) Shader / GPU error log ---------------------------------------------
"$ADB_BIN" shell logcat -d -v brief 2>&1 | \
  grep -iE 'shader|vulkan|adreno|glsl|egl|gpu|renderer|SCRIPT ERROR' > "$OUT/shader_log.txt" || true
echo "SHADER_LOG_LINES $(wc -l < "$OUT/shader_log.txt")"

# --- 7) Machine-readable verdict -------------------------------------------
PASS=1
[ "$LOG_LINES" -gt 0 ] || PASS=0
[ "$DIALOG" -eq 0 ] || PASS=0
echo "$UID_TXT" | grep -q 'uid=2000' || PASS=0
[ -s "$OUT/gfxinfo.txt" ] || PASS=0
[ -s "$OUT/device_frame.png" ] || PASS=0
echo "DEVICE_HARNESS_PASS=$PASS"
exit $((1 - PASS))
