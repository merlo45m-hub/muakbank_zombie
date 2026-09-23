#!/bin/bash
# Phase 1 gate, v2:
#  STAGE A — physics probe HEADLESS (no renderer needed, full speed, 1200 frames)
#            -> proves zombie contact no longer launches the player.
#  STAGE B — short visual render at phone resolution -> the frame the user sees.
cd /game || exit 1
G=/godot/Godot_v4.7.2-stable_linux.arm64

echo "########## STAGE A: PHYSICS (headless) ##########"
DIAG_SCENE=res://scenes/main/game.tscn \
DIAG_PHYS=1 DIAG_PHYS_FRAMES=1200 DIAG_FRAMES=1 \
timeout 600 "$G" --headless res://tools/diag.tscn > /tmp/pA.log 2>&1
echo "STAGE A EXIT: $?"

python3 - <<'PY'
import re
rows, contacts = [], []
for line in open('/tmp/pA.log'):
    m = re.match(r'DIAG-PHYS: f=(\d+) pos=\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\) vy=([-0-9.]+)', line)
    if m:
        rows.append((int(m.group(1)), float(m.group(3)), float(m.group(5))))
    if 'DIAG-PHYS' in line and 'zombie' in line.lower():
        contacts.append(line.strip()[:160])
if not rows:
    print("NO PHYS ROWS — check /tmp/pA.log")
else:
    ys = [r[1] for r in rows]; vys = [r[2] for r in rows]
    print(f"FRAMES: {len(rows)}  (sim time {len(rows)/60:.1f}s)")
    print(f"MAX Y: {max(ys):.3f}   MIN Y: {min(ys):.3f}   (ground = 0.65)")
    print(f"MAX vy: {max(vys):.2f}  MIN vy: {min(vys):.2f}   (launch bug was +84)")
    hi = [r for r in rows if r[1] > 3.0]
    print(f"FRAMES ABOVE y=3: {len(hi)}   -> {'LAUNCHED' if hi else 'GROUNDED THE WHOLE TIME'}")
    print(f"ZOMBIE CONTACT FRAMES: {len(contacts)}")
    for c in contacts[:4]:
        print("   ", c)
    print("--- every 120th frame:")
    for r in rows[::120]:
        print(f"   f={r[0]:5d}  y={r[1]:8.3f}  vy={r[2]:8.2f}")
PY

echo ""
echo "########## STAGE B: VISUAL (720x1600) ##########"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
pkill Xvfb 2>/dev/null; sleep 1
Xvfb :99 -screen 0 720x1600x24 >/tmp/xvfb.log 2>&1 &
sleep 3
export DISPLAY=:99
DIAG_SCENE=res://scenes/main/game.tscn DIAG_FRAMES=120 DIAG_OUT=/game/phase1_view.png \
timeout 900 "$G" --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 720x1600 res://tools/diag.tscn 2>&1 | grep -E "DIAG: saved|DIAG: camera|ERROR" | head -5
ls -l /game/phase1_view.png 2>/dev/null
pkill Xvfb 2>/dev/null
echo "########## DONE ##########"
