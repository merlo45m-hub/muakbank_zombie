#!/usr/bin/env bash
# Issue #30 — ACTIVE COMBAT STRESS harness, v3 (final).
# Correctness notes (verified 2026-11-15 on this device):
# * A swipe starting at the LEFT SCREEN EDGE (x=160) is Samsung One UI's BACK
#   gesture -> dismisses the Godot app. That is what earlier runs read as a
#   "crash". All movement swipes here start at x>=420 (interior); control proved
#   taps-only survives 20/20 cycles with stable focus.
# * `dumpsys SurfaceFlinger --latency` returns 0 frame rows and
#   `dumpsys gfxinfo ... framestats` reports "Total frames rendered: 1" for this
#   Godot/Vulkan SurfaceView on this Samsung build. Both are USELESS as a pacing
#   signal here. Honest substitute: capture a burst of frames with screencap and
#   compute frame-to-frame pixel deltas (same method as AGGY_REPORT.md). Nonzero
#   deltas prove continuous active rendering during combat.
set -uo pipefail
ADB="${CAP_ADB_BIN:-/root/bin/phone-adb}"
PKG="${CAP_PKG:-com.merlo45.muakbankzombie}"
DUR="${CAP_DUR:-36}"
OUT="${CAP_OUT:-/root/muakbank_zombie/build/combat_stress}"
mkdir -p "$OUT/frames"
TL="$OUT/timeline.csv"; echo "t,pid,focus_is_game" > "$TL"
rm -f "$OUT/frames"/*.png

"$ADB" shell whoami | grep -qx shell || { echo "DEVICE_FAIL not uid shell"; exit 1; }

echo "=== nav to gameplay (single invocation) ==="
"$ADB" shell "monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1" 2>/dev/null
sleep 6
"$ADB" shell "input tap 1560 623" >/dev/null 2>&1
sleep 4
"$ADB" shell "input tap 2101 1369" >/dev/null 2>&1
sleep 4
"$ADB" shell "input tap 1000 720" >/dev/null 2>&1
sleep 8
echo "FOCUS_AFTER_NAV=$("$ADB" shell dumpsys window 2>/dev/null | grep mCurrentFocus | tail -1)"

"$ADB" shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true
"$ADB" shell logcat -c 2>/dev/null || true   # isolate this run's [FPSMON] lines
T0=$(date +%s)
echo "=== $DUR s sustained combat (ATTACK + interior movement) ==="
i=0
while [ $(( $(date +%s) - T0 )) -lt "$DUR" ]; do
  "$ADB" shell "input tap 2970 1290" >/dev/null 2>&1                 # ATTACK center
  "$ADB" shell "input tap 2730 1290" >/dev/null 2>&1                 # SPECIAL
  "$ADB" shell "input swipe 520 1300 600 1220 250" >/dev/null 2>&1   # joystick (interior, no back gesture)
  "$ADB" exec-out screencap -p > "$OUT/frames/f_$(printf '%02d' "$i").png" 2>/dev/null
  PID=$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')
  FOC=$("$ADB" shell dumpsys window 2>/dev/null | grep mCurrentFocus | tail -1)
  ISGAME=0; echo "$FOC" | grep -q "$PKG" && ISGAME=1
  echo "$i,${PID:-DEAD},$ISGAME" >> "$TL"
  i=$((i+1))
  sleep 1
done
echo "INPUT_CYCLES=$i over $DUR s"

echo "=== timeline verdict ==="
python3 - "$TL" << 'PY'
import sys, collections
rows=[l.strip().split(',') for l in open(sys.argv[1]).read().splitlines()[1:] if l.strip()]
pids=collections.Counter(r[1] for r in rows); foc=collections.Counter(r[2] for r in rows)
print("CYCLES",len(rows),"PID_STATES",dict(pids),"FOCUS_GAME_1_vs_0",dict(foc))
dead=any(r[1]=='DEAD' for r in rows)
lost=any(r[2]=='0' for r in rows)
print("ALIVE_ALL_CYCLES",not dead,"FOCUS_STABLE",not lost)
PY

echo "=== frame pacing via screenshot deltas (Pillow/numpy) ==="
python3 - "$OUT/frames" << 'PY'
import sys, glob, os
from PIL import Image, ImageChops
import numpy as np
fs=sorted(glob.glob(os.path.join(sys.argv[1],"f_*.png")))
# drop any error-text / empty captures (exec-out can write 0 bytes on failure)
good=[]
for f in fs:
    try:
        im=Image.open(f).convert("RGB"); good.append((f,np.asarray(im,dtype=np.int16)))
    except Exception:
        pass
print("FRAMES_CAPTURED",len(good))
deltas=[]
for (fa,a),(fb,b) in zip(good,good[1:]):
    d=np.abs(a-b).mean()
    deltas.append(round(float(d),3))
print("FRAME_DELTAS",deltas)
if deltas:
    print("MEAN_FRAME_DELTA_PX",round(sum(deltas)/len(deltas),3))
    print("ACTIVE_RENDERING",sum(1 for d in deltas if d>0.05),"/",len(deltas),"pairs changed")
PY

echo "=== thermal under load ==="
"$ADB" shell dumpsys thermalservice 2>/dev/null | grep -E 'Thermal Status:|mName=SKIN|mName=BAT|mName=AP' | head -8
echo "=== in-engine FPS (FpsMonitor / Performance.TIME_FPS) ==="
# Godot print() lands in logcat; pull this run's [FPSMON] JSON lines.
FPLOG=$("$ADB" shell logcat -d -v brief 2>/dev/null | grep -F "[FPSMON]" | tail -60)
echo "$FPLOG" > "$OUT/fpsmon_lines.txt"
python3 - "$OUT/fpsmon_lines.txt" << 'PY'
import sys, json, re
lines=[l for l in open(sys.argv[1],encoding="utf-8",errors="replace") if "[FPSMON]" in l]
reps=[]
for l in lines:
    j=l.split("[FPSMON]",1)[1].strip()
    try: reps.append(json.loads(j))
    except Exception: pass
print("FPSMON_WINDOWS",len(reps))
if reps:
    avgs=[r["avg_fps"] for r in reps if "avg_fps" in r]
    mins=[r["min_fps"] for r in reps if "min_fps" in r]
    janks=[r["jank_pct"] for r in reps if "jank_pct" in r]
    budget=reps[0].get("budget_fps",60.0)
    print("FPSMON_BUDGET",budget)
    print("FPSMON_AVG_FPS",round(sum(avgs)/len(avgs),1) if avgs else None)
    print("FPSMON_MIN_FPS",round(min(mins),1) if mins else None)
    print("FPSMON_MAX_WINDOW_AVG",round(max(avgs),1) if avgs else None)
    print("FPSMON_MEAN_JANK_PCT",round(sum(janks)/len(janks),1) if janks else None)
    print("FPSMON_SAMPLE_FRAMES",sum(r.get("samples",0) for r in reps))
else:
    print("FPSMON_NO_DATA (autoload not in installed build, or logcat cleared late)")
PY

echo "=== crash / stability ==="
PID=$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')
echo "GAME_PID_AT_END=${PID:-DEAD}"
CRASH=$("$ADB" shell logcat -b crash -d -t 80 2>/dev/null | grep -i "$PKG" | tail -5)
echo "GAME_CRASH_LINES=${CRASH:-none}"
PASS=1
[ -n "$PID" ] || PASS=0
[ -z "$CRASH" ] || PASS=0
echo "COMBAT_STRESS_PASS=$PASS"
exit $((1-PASS))
