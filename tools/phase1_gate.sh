#!/bin/bash
# Phase 1 gate: with zombie bodies on their own layer, the player must stay
# grounded when zombies touch him, AND the player camera must see the world.
cd /game || exit 1
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
G=/godot/Godot_v4.7.2-stable_linux.arm64

pkill Xvfb 2>/dev/null; sleep 1
Xvfb :99 -screen 0 720x1600x24 >/tmp/xvfb.log 2>&1 &
sleep 3
export DISPLAY=:99

DIAG_SCENE=res://scenes/main/game.tscn \
DIAG_PHYS=1 DIAG_PHYS_FRAMES=420 DIAG_FRAMES=5 \
DIAG_OUT=/game/phase1_gate.png \
timeout 900 "$G" --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 720x1600 res://tools/diag.tscn > /tmp/p1.log 2>&1
echo "EXIT: $?"

python3 - <<'PY'
import re
rows = []
for line in open('/tmp/p1.log'):
    m = re.match(r'DIAG-PHYS: f=(\d+) pos=\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\) vy=([-0-9.]+)', line)
    if m:
        rows.append((int(m.group(1)), float(m.group(3)), float(m.group(5))))
if not rows:
    print("NO PHYS ROWS")
else:
    ys = [r[1] for r in rows]; vys = [r[2] for r in rows]
    print(f"FRAMES: {len(rows)}")
    print(f"MAX Y:  {max(ys):.2f}   MIN Y: {min(ys):.2f}   (spawn/ground ~0.65)")
    print(f"MAX vy: {max(vys):.2f}   MIN vy: {min(vys):.2f}  (launch bug was +84)")
    launches = [r for r in rows if r[1] > 5.0]
    print(f"FRAMES ABOVE y=5: {len(launches)}")
    print("--- every 30th frame:")
    for r in rows[::30]:
        print(f"   f={r[0]:4d}  y={r[1]:7.2f}  vy={r[2]:7.2f}")
PY
grep -E "DIAG: saved|DIAG: camera" /tmp/p1.log | head -3
pkill Xvfb 2>/dev/null
