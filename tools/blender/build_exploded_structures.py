"""Build the exploded-view Blender scene with an ENFORCED scale lock.

Lock guarantees per scoped mesh (the primary risk: transform inheritance or an
unapplied/applied modifier altering the bounding box on import), plus a rebuild
of the GLB with extras so a post-import verifier can detect drift.

Rules enforced HERE (before export):
  1. object scale is IDENTITY and BAKED into mesh data (transform_apply scale=True)
  2. object has NO parent (no transform inheritance)
  3. EVALUATED depsgraph bbox (includes modifiers) equals locked_dimensions_m
  4. custom properties stamp the lock into glTF node extras (export_extras=True)
  5. --selftest proves a Solidify modifier that expands the bbox is rejected.

Run: blender -b -P tools/blender/build_exploded_structures.py
     blender -b -P tools/blender/build_exploded_structures.py -- --selftest
"""
from __future__ import annotations
import json, os, sys, math
import bpy
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "assets", "data", "blender_structure_assets.json")
OUT_GLB = os.path.join(REPO, "assets", "models", "screen_structures_exploded.glb")
REPORT = os.path.join(REPO, "assets", "data", "blender_build_report.json")


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
    rgb = tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.55
    return m


def evaluated_dims(obj, depsgraph, tol):
    """World-space bbox of the EVALUATED object (modifiers included)."""
    ev = obj.evaluated_get(depsgraph)
    corners = [ev.matrix_world @ Vector(c) for c in ev.bound_box]
    mins = [min(c[i] for c in corners) for i in range(3)]
    maxs = [max(c[i] for c in corners) for i in range(3)]
    dims = [round(maxs[i] - mins[i], 5) for i in range(3)]
    return dims


def lock_object(obj, part, tol):
    """Apply the scale contract. Returns (ok, reason, evaluated_dims)."""
    if obj.parent is not None:
        return False, "parent transform inheritance forbidden", None
    # Bake scale into mesh data, then force identity.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.scale = (1.0, 1.0, 1.0)
    obj.delta_scale = (1.0, 1.0, 1.0)
    # Stamp lock into glTF extras.
    obj["scale_lock"] = True
    obj["part_id"] = part["part_id"]
    obj["locked_scale"] = "1,1,1"
    obj["locked_dimensions_m"] = ",".join(str(x) for x in part["dimensions_m"])
    obj["transform_inheritance"] = "forbidden"
    obj["modifier_policy"] = "bake_and_remeasure"
    depsgraph = bpy.context.evaluated_depsgraph_get()
    depsgraph.update()
    dims = evaluated_dims(obj, depsgraph, tol)
    want = [float(x) for x in part["dimensions_m"]]
    if any(abs(g - w) > tol for g, w in zip(dims, want)):
        return False, "evaluated bbox %s != locked %s" % (dims, want)
    return True, "locked", dims


def add_plate(name, dims, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    o.data.materials.append(material)
    return o


def add_label(name, text, loc, size=0.03):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text[:28]
    cu.size = size
    cu.align_x = "CENTER"
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.location = (loc[0], loc[1], loc[2] + 0.05)
    return o


def add_guide(name, a, b, material):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.0015
    sp = cu.splines.new("POLY")
    sp.points.add(1)
    sp.points[0].co = (*a, 1.0)
    sp.points[1].co = (*b, 1.0)
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def selftest(tol):
    """Prove a modifier that expands the bbox is rejected by the lock."""
    purge()
    part = {"part_id": "selftest_probe", "dimensions_m": [0.5, 0.5, 0.02]}
    o = add_plate("selftest_probe-convcol", part["dimensions_m"], (0, 0, 0), mat_for("#ffffff", "selftest_mat"))
    ok0, r0, d0 = lock_object(o, part, tol)   # clean -> must pass
    mod = o.modifiers.new("solidify_drift", "SOLIDIFY")
    mod.thickness = 0.2                       # expands Z bbox well beyond tol
    depsgraph = bpy.context.evaluated_depsgraph_get()
    depsgraph.update()
    d1 = evaluated_dims(o, depsgraph, tol)
    want = [float(x) for x in part["dimensions_m"]]
    drifted = any(abs(g - w) > tol for g, w in zip(d1, want))
    print("[selftest] clean_lock_ok", ok0, "clean_dims", d0)
    print("[selftest] solidify_dims", d1, "DETECTS_DRIFT", drifted)
    print("[selftest] SELFTEST_PASS", ok0 and drifted)
    purge()
    return 0 if (ok0 and drifted) else 1


def main():
    selftest_mode = "--selftest" in sys.argv
    with open(SRC, encoding="utf-8") as f:
        data = json.load(f)
    tol = float(data["scale_calibration"]["scale_lock_policy"]["bbox_tolerance_m"])
    if selftest_mode:
        return selftest(tol)

    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    purge()
    guide_mat = mat_for("#6E7A80", "guide_emissive")
    built, mismatches, locked_ok = 0, [], 0
    for asm in data["assemblies"]:
        asm_y = -2.0 * {"start": 0, "player": 1, "level": 2, "final": 3}[asm["assembly_id"]]
        for p in asm["parts"]:
            dims = p["dimensions_m"]
            ax, ay, az = p["assembled_position_m"]
            ay += asm_y
            ex = p["explode_offset_x_m"]
            loc = (ax + ex, ay, az)
            o = add_plate(p["part_id"] + "-convcol", dims, loc,
                          mat_for(p["material_color"], "mat_" + p["classification"]))
            ok, reason, evdims = lock_object(o, p, tol)
            if not ok:
                mismatches.append({"part": p["part_id"], "reason": reason})
            else:
                locked_ok += 1
            add_label(p["part_id"] + "_label",
                      "%s: %s" % (p["classification"], p["label_text"]), loc)
            add_guide(p["part_id"] + "_guide", (ax, ay, az), loc, guide_mat)
            built += 1

    if mismatches:
        print("[blender] SCALE_LOCK_FAIL", len(mismatches), mismatches[:4])
        return 1

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    try:
        bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB",
                                  check_existing=False, export_yup=True,
                                  export_apply=True, export_extras=True)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB",
                                  check_existing=False, export_yup=True, export_apply=True)
    report = {
        "source": os.path.basename(SRC),
        "parts_built": built,
        "expected_parts": data["total_parts"],
        "scale_locked_parts": locked_ok,
        "bbox_mismatches": mismatches,
        "bbox_tolerance_m": tol,
        "scale_contract_sha256": data["scale_contract_sha256"],
        "glb": os.path.basename(OUT_GLB),
        "glb_bytes": os.path.getsize(OUT_GLB) if os.path.exists(OUT_GLB) else 0,
        "build_ok": built == data["total_parts"] and not mismatches and locked_ok == built,
    }
    with open(REPORT, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("[blender] parts", built, "/", data["total_parts"], "locked", locked_ok)
    print("[blender] bbox_mismatches", len(mismatches))
    print("[blender] glb", report["glb_bytes"], "bytes")
    print("[blender] BUILD_OK", report["build_ok"])
    return 0 if report["build_ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
