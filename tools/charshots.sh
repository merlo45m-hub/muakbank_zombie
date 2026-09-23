#!/bin/bash
# Render asset-viewer shots for every character model + one animal as control.
# Plain lit backdrop, 512x512, ~30s each -> unambiguous silhouettes. Never judge a
# model from a gameplay frame: at 2 m behind at chest height a humanoid's torso and
# arms merge into a uniform column.
cd /game || exit 1
G=/godot/Godot_v4.7.2-stable_linux.arm64
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

pkill -x Xvfb 2>/dev/null
sleep 1
Xvfb :99 -screen 0 512x512x24 >/tmp/xvfb.log 2>&1 &
sleep 3
export DISPLAY=:99

shoot() {
	local mdl="$1" yaw="$2" name="$3"
	SHOT_MODEL="res://assets/models/${mdl}.glb" \
	SHOT_OUT="/game/charshot_${name}.png" \
	SHOT_YAW="$yaw" \
	timeout 240 "$G" --rendering-method gl_compatibility --rendering-driver opengl3 \
		--resolution 512x512 res://tools/charshot.tscn > "/tmp/cs_${name}.log" 2>&1
	echo "--- ${name}:"
	grep -hE "SHOT: (model|saved)|Parse Error|Failed to load script" "/tmp/cs_${name}.log" | head -3
}

shoot character_doctor 0 doc_front
shoot character_doctor 40 doc_threequarter
shoot character_streamer 0 streamer_front
shoot character_gamer 0 gamer_front
shoot zombie_dog 0 dog_control

ls -l /game/charshot_*.png 2>/dev/null || echo "NO SHOTS PRODUCED"
pkill -x Xvfb 2>/dev/null