#!/usr/bin/env python3
"""export_godot_asset.py - headless Blender export for Muakbank Zombie assets.

Run inside Blender:
    blender --background --python tools/export_godot_asset.py -- \
        --blend /root/vending_machine_props.blend \
        --out  assets/models/vending_machine.glb \
        --name vending_machine

Why this exists: the SOP's stage 4 is "export .glb + .png and transport to the repo".
Doing it by hand through the GUI drops presentation-only objects (annotation arrows,
leader lines, the floor, camera, lights), leaves object-level scale unapplied, and
puts the origin wherever the mesh was built. This script does the whole stage
deterministically and prints a manifest.

What it does:
  1. keeps only the machine parts (drops annotation arrows/leaders, floor, camera, lights)
  2. applies rotation + scale so the exported geometry is real-sized
  3. puts the origin at the bottom centre and the asset on z=0
  4. exports glTF with +Y up, materials and textures, no cameras/lights/animations
  5. writes a <out>.manifest.json with the part list and bounding box

Usage from the repo:
    bash tools/export_on_vps.sh vending_machine
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import bpy
from mathutils import Vector

# Prefixes that belong to the asset. Everything else in the blend is presentation.
KEEP_PREFIX = (
    "Shell_", "Bezel_", "Glass_Panel", "Control_Panel", "Coin_", "Button_",
    "Drip_Tray", "Sign_", "Vent_", "Foot_", "Shelf_", "Can_", "Back_Panel",
)


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--blend", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--name", default="asset")
    return p.parse_args(argv)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.open_mainfile(filepath=args.blend)

    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(KEEP_PREFIX)]
    if not meshes:
        raise SystemExit("no asset meshes matched KEEP_PREFIX")

    # drop presentation-only objects so they cannot leak into the export
    for o in [o for o in bpy.data.objects if o.type == 'MESH' and o not in meshes]:
        bpy.data.objects.remove(o, do_unlink=True)

    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    mins = Vector((1e9,) * 3)
    maxs = Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mins = Vector((min(mins[i], w[i]) for i in range(3)))
            maxs = Vector((max(maxs[i], w[i]) for i in range(3)))
    for o in meshes:
        o.location.x -= (mins.x + maxs.x) / 2
        o.location.y -= (mins.y + maxs.y) / 2
        o.location.z -= mins.z
    bpy.context.view_layer.update()

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )

    mins = Vector((1e9,) * 3)
    maxs = Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mins = Vector((min(mins[i], w[i]) for i in range(3)))
            maxs = Vector((max(maxs[i], w[i]) for i in range(3)))
    manifest = {
        "asset": args.name,
        "model": os.path.relpath(args.out, "/root/muakbank_zombie"),
        "parts": len(meshes),
        "dimensions_m": [round(v, 4) for v in (maxs - mins)],
        "origin": "bottom-centre, sitting on z=0",
        "up": "+Y in glTF, converted to Godot +Z",
    }
    man = os.path.splitext(args.out)[0] + ".manifest.json"
    with open(man, "w") as fh:
        json.dump(manifest, fh, indent=2)
    print("MANIFEST", json.dumps(manifest))


if __name__ == "__main__":
    main()
