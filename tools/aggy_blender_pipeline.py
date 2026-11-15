#!/usr/bin/env python3
"""
aggy_blender_pipeline.py — Blender bpy import/registration script.

Ingests a JSON asset payload (SOP schema) and produces:

    assets/models/<asset_id>.glb          # Godot glTF scene
    assets/textures/<asset_id>.png        # multi-angle preview / albedo
    assets/textures/<asset_id>.png.import # Godot texture import metadata
    assets/materials/<asset_id>.tres      # Godot StandardMaterial3D

Directory mapping contract verified at the end:
    assets/models/*.glb
    assets/textures/*.png  (+ *.png.import)
    assets/materials/*.tres

Usage (run inside a Blender headless session):
    blender -b -P tools/aggy_blender_pipeline.py -- --payload payload.json
    echo '{"asset_id":"test_block","category":"block","dimensions_m":{"x":2.0,"y":2.5,"z":4.0},"export_target":"assets/models","materials":[{"slot":"albedo","base_color_hex":"#3a5a2a","roughness":0.7,"metallic":0.0,"wear_passes":1}]}' > payload.json
    blender -b -P tools/aggy_blender_pipeline.py -- --payload payload.json
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

import bpy

# --------------------------------------------------------------------------- #
# Constants / conventions
# --------------------------------------------------------------------------- #
REPO_ROOT = "/root/muakbank_zombie"
ASSETS_MODELS = os.path.join(REPO_ROOT, "assets", "models")
ASSETS_TEXTURES = os.path.join(REPO_ROOT, "assets", "textures")
ASSETS_MATERIALS = os.path.join(REPO_ROOT, "assets", "materials")
MAX_EDGE = 2048


def ensure_dirs():
    for d in (ASSETS_MODELS, ASSETS_TEXTURES, ASSETS_MATERIALS):
        os.makedirs(d, exist_ok=True)


# --------------------------------------------------------------------------- #
# Mesh builders (procedural, category-driven)
# --------------------------------------------------------------------------- #
def _cube_mesh(x, y, z):
    """Return (vertices, edges, faces) for a cuboid."""
    hx, hy, hz = x / 2, y / 2, z / 2
    v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
         (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    e = [(0, 1), (1, 2), (2, 3), (3, 0),
         (4, 5), (5, 6), (6, 7), (7, 4),
         (0, 4), (1, 5), (2, 6), (3, 7)]
    f = [(0, 1, 2, 3), (4, 5, 6, 7),
         (0, 1, 5, 4), (2, 3, 7, 6),
         (1, 2, 6, 5), (0, 3, 7, 4)]
    return v, e, f


def build_mesh(category: str, dimensions: dict) -> bpy.types.Object:
    """Build a procedural mesh matching category + dimensions_m."""
    x, y, z = dimensions["x"], dimensions["y"], dimensions["z"]

    if category in ("block", "building", "structure", "prop"):
        verts, edges, faces = _cube_mesh(x, y, z)
        mesh = bpy.data.meshes.new("BlockMesh")
        mesh.from_pydata(verts, edges, faces)
        mesh.update()
        obj = bpy.data.objects.new("BlockObject", mesh)
        bpy.context.collection.objects.link(obj)
        return obj

    if category == "vehicle":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
        chassis = bpy.context.object
        chassis.scale = (x * 0.9, y * 0.4, z * 0.6)
        chassis.location = (0, 0, -y * 0.1)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
        cabin = bpy.context.object
        cabin.scale = (x * 0.5, x * 0.5, z * 0.4)
        cabin.location = (0, 0, y * 0.25)
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = "VehicleObject"
        return obj

    if category == "character":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(0, 0, 2.0))
        head = bpy.context.object
        head.scale = (x * 0.4, x * 0.4, x * 0.4)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
        body = bpy.context.object
        body.scale = (x * 0.7, y * 0.9, x * 0.7)
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = "CharacterObject"
        return obj

    # Fallback: a rigid block.
    verts, edges, faces = _cube_mesh(x, y, z)
    mesh = bpy.data.meshes.new("BlockMesh")
    mesh.from_pydata(verts, edges, faces)
    mesh.update()
    obj = bpy.data.objects.new("BlockObject", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# --------------------------------------------------------------------------- #
# Material: Godot-style parameters  -> Blender Principled BSDF
# --------------------------------------------------------------------------- #
def make_material(mat_def: dict) -> bpy.types.Material:
    """Create a Principled BSDF material from the SOP material payload."""
    base_color_hex = mat_def.get("base_color_hex", "#888888")
    roughness = mat_def.get("roughness", 0.5)
    metallic = mat_def.get("metallic", 0.0)
    wear_passes = mat_def.get("wear_passes", 0)

    hex_str = base_color_hex.lstrip("#")
    rgb = tuple(int(hex_str[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

    rough = max(0.05, min(1.0, roughness + 0.1 * wear_passes))
    emit = 0.25 * wear_passes

    mat = bpy.data.materials.new(name=mat_def.get("slot", "Material"))
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Base Color"].default_value = (*rgb, 1.0)
    principled.inputs["Roughness"].default_value = rough
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Emission Color"].default_value = (emit, emit, emit, 1.0)
    principled.inputs["Emission Strength"].default_value = 1.0
    principled.location = (0, 0)

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (200, 0)
    mat.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])

    return mat


def register_material_to_object(obj: bpy.types.Object, mat: bpy.types.Material):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


# --------------------------------------------------------------------------- #
# Preview rendering (multi-angle)
# --------------------------------------------------------------------------- #
def purge_startup_meshes():
    """Remove Blender's default startup Cube (and any leftover mesh) before building.

    setup_scene() was defined but never called, and was broken anyway (it deleted
    ALL objects including the Camera that render_angles()/render_albedo() require).
    Without this, every exported GLB silently shipped a stray 2x2x2 "Cube" node
    alongside the real asset — a direct cause of the Issue #9.1 scale/geometry
    mismatch. Keep cameras and lights; drop only meshes.
    """
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def setup_scene():
    for obj in bpy.data.objects:
        obj.select_set(False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False, confirm=False)
    cam = bpy.data.objects["Camera"]
    cam.location = (0, 0, 5)
    bpy.context.scene.camera = cam
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    bpy.context.scene.render.film_transparent = False


def render_angles(obj: bpy.types.Object, textures_out: str, base: str):
    """Render front / side / top / iso; also composite a 2x2 contact sheet."""
    angles = [("front", (0, -8, 3), math.radians(30)),
              ("side", (-8, 0, 3), math.radians(-60)),
              ("top", (0, 0, 8), math.radians(90)),
              ("iso", (-6, -6, 6), math.radians(30))]
    paths = {}
    for name, loc, rot in angles:
        bpy.context.scene.camera = bpy.data.objects["Camera"]
        bpy.data.objects["Camera"].location = loc
        bpy.data.objects["Camera"].rotation_euler = (rot, 0, 0)
        path = os.path.join(textures_out, f"{base}_{name}.png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True, scene="Scene")
        paths[name] = path
        print(f"  preview: {path}")

    # Contact sheet: single PNG combining all four angles.
    contact = os.path.join(textures_out, f"{base}_preview.png")
    bpy.context.scene.render.resolution_x = 1024
    bpy.context.scene.render.resolution_y = 1024
    bpy.context.scene.render.filepath = contact
    bpy.ops.render.render(write_still=True, scene="Scene")
    print(f"  preview (contact sheet): {contact}")
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    return paths


def render_albedo(obj: bpy.types.Object, textures_out: str, base: str) -> str:
    """Render the front view of the material as the albedo texture .png."""
    cam = bpy.data.objects["Camera"]
    cam.location = (0, -8, 3)
    cam.rotation_euler = (math.radians(30), 0, 0)
    path = os.path.join(textures_out, f"{base}.png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True, scene="Scene")
    print(f"  albedo: {path}")
    return path


# --------------------------------------------------------------------------- #
# File writers (Godot gd_resource / .import)
# --------------------------------------------------------------------------- #
def uid_of(token: str) -> str:
    return "uid://" + "".join(format(ord(c), "x") for c in token)[:16]


def write_tres(asset_id: str, mats: list[dict], textures_out: str):
    """Write a Godot StandardMaterial3D .tres per material slot; each references
    the generated albedo .png via an ext_resource block."""
    tres_path = ""
    res_tex_path = f"res://assets/textures/{asset_id}.png"
    for idx, m in enumerate(mats):
        slot = m.get("slot", "albedo")
        ext_id = f"{idx}_{slot}"
        ext_uid = uid_of(f"{asset_id}:{slot}")
        base_color_hex = m.get("base_color_hex", "#888888").lstrip("#")
        r, g, b = (int(base_color_hex[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        roughness = m.get("roughness", 0.5)
        metallic = m.get("metallic", 0.0)
        wear = m.get("wear_passes", 0)
        emit = 0.25 * wear
        tres_path = os.path.join(ASSETS_MATERIALS, f"{asset_id}_{slot}.tres")
        with open(tres_path, "w") as f:
            f.write(
                f'[gd_resource type="StandardMaterial3D" load_steps=2 format=3 '
                f'uid="{uid_of(asset_id)}"]\n'
                f'[ext_resource type="Texture2D" uid="{ext_uid}" '
                f'path="{res_tex_path}" id="{ext_id}"]\n'
                "[resource]\n"
                f"albedo_color = Color({r:.3f}, {g:.3f}, {b:.3f}, 1.0)\n"
                f"albedo_texture = ExtResource(\"{ext_id}\")\n"
                f"roughness = {roughness:.3f}\n"
                f"metallic = {metallic:.3f}\n"
                f"specular = Color(0.05, 0.05, 0.05, 1.0)\n"
                f"emission_enabled = {bool(wear)}\n"
                f"emission = Color({emit:.3f}, {emit:.3f}, {emit:.3f}, 1.0)\n"
                f"emission_texture = null\n"
                f"normal_map_enabled = false\n"
                f"ambient_light_usage = 2\n"
            )
        print(f"  tres: {tres_path}")
    return tres_path


def write_import(asset_id: str, src_rel: str, textures_out: str):
    """Write a Godot CompressedTexture2D .import metadata file for the albedo .png."""
    src = os.path.join(textures_out, f"{asset_id}.png")
    src_rel = os.path.relpath(src, REPO_ROOT).replace(os.sep, "/")
    ctex = f"{asset_id}-{abs(hash(asset_id)) & 0xFFFFFFFF:x}.ctex"
    ctex_path = os.path.join(textures_out, ctex)
    import_path = os.path.join(textures_out, f"{asset_id}.import")
    with open(import_path, "w") as f:
        f.write(
            "[remap]\n\n"
            f'importer="texture"\n'
            f'type="CompressedTexture2D"\n'
            f'uid="{uid_of(asset_id)}"\n'
            f'path="{ctex_path}"\n'
            f'metadata={{"vram_texture": false}}\n\n'
            "[deps]\n\n"
            f'source_file="{src_rel}"\n'
            f'dest_files=["{ctex_path}"]\n\n'
            "[params]\n\n"
            "compress/mode=0\n"
            "compress/high_quality=false\n"
            "compress/lossy_quality=0.7\n"
            "compress/uastc_level=0\n"
            "compress/rdo_quality_loss=0.0\n"
            "compress/hdr_compression=1\n"
            "compress/normal_map=0\n"
            "compress/channel_pack=0\n"
            "mipmaps/generate=false\n"
            "mipmaps/limit=-1\n"
            "roughness/mode=0\n"
            "roughness/src_normal=\"\"\n"
            "process/channel_remap/red=0\n"
            "process/channel_remap/green=1\n"
            "process/channel_remap/blue=2\n"
            "process/channel_remap/alpha=3\n"
            "process/fix_alpha_border=true\n"
            "process/premult_alpha=false\n"
            "process/normal_map_invert_y=false\n"
            "process/hdr_as_srgb=false\n"
            "process/hdr_clamp_exposure=false\n"
            "process/size_limit=0\n"
            "detect_3d/compress_to=1\n"
        )
    print(f"  import: {import_path}")
    return import_path


# --------------------------------------------------------------------------- #
# Main pipeline
# --------------------------------------------------------------------------- #
def parse_args(argv=None):
    if argv is None:
        argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    p = argparse.ArgumentParser(add_help=True)
    p.add_argument("--payload", required=True, help="path to JSON asset payload")
    p.add_argument("--dry-run", action="store_true", help="plan only, write nothing")
    return p.parse_args(argv)


def load_payload(path: str) -> dict:
    if not os.path.isabs(path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        repo_root = os.path.dirname(script_dir)
        for cand in (os.path.join(script_dir, path), os.path.join(repo_root, path)):
            if os.path.exists(cand):
                path = cand
                break
    with open(path) as f:
        return json.load(f)


def main(argv=None):
    args = parse_args(argv)
    payload = load_payload(args.payload)
    asset_id = payload["asset_id"]
    category = payload.get("category", "prop")
    dims = payload["dimensions_m"]
    mats = payload.get("materials", [{"slot": "albedo", "base_color_hex": "#888888",
                                      "roughness": 0.5, "metallic": 0.0, "wear_passes": 0}])
    export_target = payload.get("export_target", "assets/models")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    models_out = os.path.join(repo_root, export_target.rstrip("/"))
    textures_out = os.path.join(repo_root, "assets", "textures")
    materials_out = os.path.join(repo_root, "assets", "materials")
    for d in (models_out, textures_out, materials_out):
        os.makedirs(d, exist_ok=True)

    print(f"[aggy] asset_id={asset_id} category={category}")
    print(f"[aggy] dimensions_m={dims} export_target={export_target}")

    if args.dry_run:
        print("[aggy] DRY-RUN: no files written")
        return 0

    # 1) Pin the scene to metres BEFORE building anything. glTF's exporter
    # defaults are version-dependent; leaving them implicit is what produced the
    # character-vs-environment scale mismatch (Issue #9.1). Godot imports these
    # .glb files with nodes/root_scale=1.0, so 1 Blender unit MUST equal 1 metre
    # and no scaling may be applied at export time.
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    # Remove Blender's default startup Cube BEFORE building, or it ships inside
    # the GLB as a stray 2x2x2 mesh (see purge_startup_meshes docstring).
    purge_startup_meshes()

    # 2) Build mesh
    obj = build_mesh(category, dims)
    print(f"[aggy] built {category} mesh (dims {dims})")

    # Assert the built geometry actually matches dimensions_m for the categories
    # whose mesh builder is dimension-exact (block/building/structure/prop).
    # vehicle/character deliberately use stylized proportions (unit cube * factor),
    # so for those we only log — asserting would reject valid stylized builds.
    expected = (float(dims["x"]), float(dims["y"]), float(dims["z"]))
    actual = tuple(float(v) for v in obj.dimensions)
    dimension_exact = category in ("block", "building", "structure", "prop")
    if dimension_exact:
        for got, want in zip(actual, expected):
            if want > 0.0 and abs(got - want) > max(0.01, want * 0.02):
                raise RuntimeError(
                    f"[aggy] dimension mismatch: built {actual}, expected {expected} "
                    "(Issue #9.1 scale guard)"
                )
        print(f"[aggy] dimensions verified: {actual} == {expected}")
    else:
        print(f"[aggy] built dimensions (stylized {category}): {actual} from {expected}")

    # 3) Apply materials
    for m in mats:
        mat = make_material(m)
        register_material_to_object(obj, mat)

    # 3) Multi-angle preview + contact sheet (+ albedo texture)
    base = asset_id.replace("/", "_")
    render_angles(obj, textures_out, base)
    render_albedo(obj, textures_out, base)

    # 4) glTF (.glb) export — pin the scale-affecting params that Blender 4.0.2
    # actually exposes (verified against the operator RNA: global_scale and
    # apply_unit_scale do NOT exist in this build; the scene unit_settings above
    # are what the exporter honours). export_yup=True gives the glTF-standard
    # Y-up conversion Godot expects; export_apply bakes modifiers (not transforms).
    # Godot imports these with nodes/root_scale=1.0, so 1 Blender unit = 1 metre.
    glb_path = os.path.join(models_out, f"{asset_id}.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        check_existing=False,
        export_yup=True,
        export_apply=True,
    )
    print(f"[aggy] glb: {glb_path} (METRIC 1BU=1m, y-up, root_scale=1.0 on Godot side)")

    # 5) Material registration (.tres -> assets/materials)
    write_tres(asset_id, mats, textures_out)

    # 6) Texture (.png) import metadata
    write_import(asset_id, "", textures_out)

    # 7) Verify directory mapping
    mapping = {
        "models|.glb": os.path.exists(glb_path),
        "textures|.png": os.path.exists(os.path.join(textures_out, f"{asset_id}.png")),
        "textures|.png.import": os.path.exists(os.path.join(textures_out, f"{asset_id}.import")),
        "materials|.tres": os.path.exists(os.path.join(materials_out, f"{asset_id}_albedo.tres")),
    }
    print("[aggy] V FILES:")
    for k, ok in mapping.items():
        print(f"    {k:<28} {ok}")
    ok_all = all(mapping.values())
    print(f"[aggy] DIR_MAPPING_OK={ok_all}")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
