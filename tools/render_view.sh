#!/bin/bash
# Phase 1 visual capture: phone-resolution frame of the ACTUAL gameplay view.
# time_scale advances the sim so the capture lands mid-game (zombies spawned,
# chasing/attacking) instead of frame #1, without rendering minutes of frames.
cd /game || exit 1
G=/godot/Godot_v4.7.2-stable_linux.arm64
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

OUT="${1:-/game/render_gameplay.png}"
SCENE="${2:-res://scenes/main/game.tscn}"
FRAMES="${3:-240}"
TIMESCALE="${4:-4}"
GOD="${5:-1}"

pkill -x Xvfb 2>/dev/null; sleep 1
Xvfb :99 -screen 0 720x1600x24 >/tmp/xvfb.log 2>&1 &
sleep 3
export DISPLAY=:99

DIAG_SCENE="$SCENE" DIAG_TIMESCALE="$TIMESCALE" DIAG_FRAMES="$FRAMES" DIAG_OUT="$OUT" DIAG_GOD="$GOD" \
timeout 1700 "$G" --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 720x1600 res://tools/diag.tscn > /tmp/render_view.log 2>&1
# NOTE: never pipe this through `head -N` — when the pipe closes, Godot dies of
# SIGPIPE mid-run and the PNG is never written (looks like a silent failure).
grep -E "DIAG: saved|DIAG: camera|DIAG: env|^SCRIPT ERROR" /tmp/render_view.log | head -6
echo "--- error count: $(grep -c 'ERROR' /tmp/render_view.log)"
ls -l "$OUT" 2>/dev/null || echo "MISSING: $OUT"
pkill -x Xvfb 2>/dev/null
