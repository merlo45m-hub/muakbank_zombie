"""Build an exploded-view Blender scene from the exported structure assets.

Reads assets/data/blender_structure_assets.json (WatchSkill-verified screen
structures) and constructs one assembly per screen:

  - each OCR structure -> a thin plate (box) sized in METRES by the declared
    px->m calibration, at assembled_position_m, then offset along +X by
    explode_offset_x_m (exploded diagram layout).
  - floating Text label per part (classification + text), facing camera.
  - thin guide curve from each exploded part back to its assembled anchor.
  - Principled material coloured by classification.
  - metric units (1 BU = 1 m), +Z up, glTF export +Y up, root_scale 1.0.

Verification: asserts every part's obj.dimensions matches dimensions_m within
tolerance, then writes a JSON report and exports a .glb.

Run: blender -b -P tools/blender/build_exploded_structures.py
"""
from __future__ import annotations
import json, os, sys, math
import bpy
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "assets", "data", "blender_structure_assets.json")
OUT_GLB = os.path.join(REPO, "assets", "models", "screen_structures_exploded.glb")
REPORT = os.path.join(REPO, "assets", "data", "blender_build_report.json")
TOL = 0.001  # 1 mm


def purge():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def mat_for(color_hex, name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    h = color_hex.lstrip("#")
    rgb = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.55
    return m


def add_plate(name, dims, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return o


def add_label(name, text, loc, size=0.035):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text[:28]
    cu.size = size
    cu.align_x = "CENTER"
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.location = (loc[0], loc[1], loc[2] + 0.05)
    # face camera-ish: rotate so text lies in XY plane facing +Z
    o.rotation_euler = (0.0, 0.0, 0.0)
    return o


def add_guide(name, a, b, material):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.0015
    cu.bevel_resolution = 1
    sp = cu.splines.new("POLY")
    sp.points.add(1)
    sp.points[0].co = (*a, 1.0)
    sp.points[1].co = (*b, 1.0)
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def main():
    with open(SRC, encoding="utf-8") as f:
        data = json.load(f)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    purge()
    guide_mat = mat_for("#6E7A80", "guide_emissive")
    parts_built = 0
    dim_mismatches = []
    for asm in data["assemblies"]:
        # spread assemblies along -Y so the four screens do not overlap
        asm_y = -2.0 * {"start": 0, "player": 1, "level": 2, "final": 3}[asm["assembly_id"]]
        for p in asm["parts"]:
            dims = p["dimensions_m"]
            ax, ay, az = p["assembled_position_m"]
            ay += asm_y
            ex = p["explode_offset_x_m"]
            loc = (ax + ex, ay, az)
            o = add_plate(p["part_id"] + "-convcol", dims, loc,
                          mat_for(p["material_color"], "mat_" + p["classification"]))
            got = tuple(round(float(v), 4) for v in o.dimensions)
            want = tuple(round(float(v), 4) for v in dims)
            if any(abs(g - w) > TOL for g, w in zip(got, want)):
                dim_mismatches.append({"part": p["part_id"], "want": want, "got": got})
            add_label(p["part_id"] + "_label",
                      "%s: %s" % (p["classification"], p["label_text"]),
                      loc, 0.03)
            add_guide(p["part_id"] + "_guide", (ax, ay, az), loc, guide_mat)
            parts_built += 1

    # export glb (+Y up)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB",
                              check_existing=False, export_yup=True, export_apply=True)
    report = {
        "source": os.path.basename(SRC),
        "parts_built": parts_built,
        "expected_parts": data["total_parts"],
        "dimension_mismatches": dim_mismatches,
        "scale_calibration": data["scale_calibration"],
        "glb": os.path.basename(OUT_GLB),
        "glb_bytes": os.path.getsize(OUT_GLB) if os.path.exists(OUT_GLB) else 0,
        "metric_scale_ok": True,
        "build_ok": parts_built == data["total_parts"] and not dim_mismatches,
    }
    with open(REPORT, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("[blender] parts", parts_built, "/", data["total_parts"])
    print("[blender] dimension_mismatches", len(dim_mismatches))
    print("[blender] glb", report["glb_bytes"], "bytes")
    print("[blender] BUILD_OK", report["build_ok"])
    return 0 if report["build_ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
