#!/bin/bash
# Visual bisect of the black gameplay frame. Read-only: loads scenes, hides nodes at
# runtime, screenshots. Never modifies project files.
cd /game || exit 1
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
G=/godot/Godot_v4.7.2-stable_linux.arm64

pkill Xvfb 2>/dev/null
sleep 1
Xvfb :99 -screen 0 720x1600x24 >/tmp/xvfb.log 2>&1 &
sleep 3
export DISPLAY=:99

run() {
  timeout 420 "$G" --rendering-method gl_compatibility --rendering-driver opengl3 \
    --resolution 720x1600 res://tools/diag.tscn 2>&1 | grep -E "^DIAG:|SCRIPT ERROR" | head -14
  echo "---"
}

echo "### 1. BASELINE (portrait, unmodified)"
DIAG_SCENE=res://scenes/main/game.tscn DIAG_FRAMES=60 DIAG_OUT=/game/diag_1_base.png run

echo "### 2. FOG/MIST HIDDEN"
DIAG_SCENE=res://scenes/main/game.tscn DIAG_HIDE="FogVolume,Mist" DIAG_FRAMES=60 DIAG_OUT=/game/diag_2_nofog.png run

echo "### 3. DEBUG TOP-DOWN CAMERA"
DIAG_SCENE=res://scenes/main/game.tscn DIAG_CAM="0,25,25;0,0,0" DIAG_FRAMES=60 DIAG_OUT=/game/diag_3_top.png run

echo "### 4. NO FOG + BOOSTED AMBIENT"
DIAG_SCENE=res://scenes/main/game.tscn DIAG_NOFOG=1 DIAG_AMBIENT=0.8 DIAG_FRAMES=60 DIAG_OUT=/game/diag_4_bright.png run

ls -l /game/diag_*.png
pkill Xvfb 2>/dev/null
