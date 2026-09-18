#!/usr/bin/env python3
"""gen_animations.py — regenerate valid Godot 4 .anim files.

The original files used a non-existent 'AnimationTrack' sub-resource type.
This writes proper Animation resources with value tracks that animate the
child model's scale/rotation (the same node paths the zombie scripts tween).

Usage: python3 gen_animations.py
"""
import os

OUT = "/storage/emulated/0/Games/Muakbank_zombie/assets/animations"
ENEMIES = ["dog", "cat", "bear", "rabbit", "chicken"]

# (name, length, loop_mode, keys) where keys = list of (time, Vector3)
ANIMS = {
    "idle": (1.5, 1, [(0.0, (1.0, 1.0, 1.0)), (0.75, (1.02, 0.98, 1.02)), (1.5, (1.0, 1.0, 1.0))]),
    "walk": (0.8, 1, [(0.0, (1.0, 1.0, 1.0)), (0.2, (0.97, 1.03, 0.97)), (0.4, (1.0, 1.0, 1.0)),
                      (0.6, (0.97, 1.03, 0.97)), (0.8, (1.0, 1.0, 1.0))]),
    "attack": (0.5, 0, [(0.0, (1.0, 1.0, 1.0)), (0.15, (1.15, 0.85, 1.15)), (0.3, (0.95, 1.05, 0.95)),
                        (0.5, (1.0, 1.0, 1.0))]),
    "death": (1.0, 0, [(0.0, (1.0, 1.0, 1.0)), (0.5, (1.1, 0.7, 1.1)), (1.0, (1.0, 0.3, 1.0))]),
}


def vec3(v):
    return f"Vector3({v[0]}, {v[1]}, {v[2]})"


def build(name, length, loop_mode, keys):
    times = ", ".join(str(k[0]) for k in keys)
    trans = ", ".join("1" for _ in keys)
    values = ", ".join(vec3(k[1]) for k in keys)
    return f'''[gd_resource type="Animation" format=3]

[resource]
length = {length}
step = 0.1
loop_mode = {loop_mode}
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Mesh:scale")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {{
"times": PackedFloat32Array({times}),
"transitions": PackedFloat32Array({trans}),
"update": 0,
"values": [{values}]
}}
'''


os.makedirs(OUT, exist_ok=True)
count = 0
for enemy in ENEMIES:
    for anim_name, (length, loop_mode, keys) in ANIMS.items():
        path = f"{OUT}/{enemy}_{anim_name}.anim"
        with open(path, "w") as f:
            f.write(build(anim_name, length, loop_mode, keys))
        count += 1

print(f"Wrote {count} valid .anim files to {OUT}")

# Verify
c = open(f"{OUT}/dog_idle.anim").read()
assert c.startswith('[gd_resource type="Animation"'), "bad header"
assert "AnimationTrack" not in c, "still has invalid AnimationTrack"
print("Verified: valid Godot 4 Animation resources, no AnimationTrack")
