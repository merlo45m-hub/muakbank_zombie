#!/usr/bin/env python3
"""GLB asset contract gate (stdlib only; runs anywhere CI or dev host runs).

Prevents the failure classes seen in #14 voxel-antagonist work:
  1. axis mismatch  - Y-up vs Z-up builder bugs export sideways models.
  2. bounds drift   - assets silently shrink/grow past the locked dims.
  3. rig contract   - required VXZ part nodes / emissive materials missing.

Contract lives in tools/glb_asset_contract.json (one entry per .glb):
  {"file": ..., "dims_tolerance": 0.25, "expect": {"length_max_extent_axis": "X",
   "height_axis": "Y", "min_height_frac": 0.3, "required_nodes": [...],
   "required_emissive_materials": [...]}}

Validation parsing is intentionally FLEXIBLE: extents are compared with
tolerances and fraction checks (no strict string equality, no exact tuple
matches), and every violation names the file + the measured numbers.

Exit codes: 0 = PASS, 2 = FAIL, 3 = contract/asset missing (fail closed).
"""
import json
import os
import struct
import sys

AXIS = {"X": 0, "Y": 1, "Z": 2}


def glb_json_chunk(path):
    with open(path, "rb") as fh:
        header = fh.read(12)
        if len(header) < 12 or header[:4] != b"glTF":
            return None, "not a glTF container"
        ln, ctype = struct.unpack("<I4s", fh.read(8))
        if ctype != b"JSON":
            return None, "first chunk is not JSON"
        return json.loads(fh.read(ln).decode("utf-8")), None


def node_trs(node):
    """Return (translation, scale) honoring matrix nodes loosely."""
    if "matrix" in node:
        m = node["matrix"]
        scale = (
            (m[0] ** 2 + m[1] ** 2 + m[2] ** 2) ** 0.5,
            (m[4] ** 2 + m[5] ** 2 + m[6] ** 2) ** 0.5,
            (m[8] ** 2 + m[9] ** 2 + m[10] ** 2) ** 0.5,
        )
        trans = (m[12], m[13], m[14])
        return trans, scale
    t = node.get("translation", (0.0, 0.0, 0.0))
    s = node.get("scale", (1.0, 1.0, 1.0))
    return t, s


def world_extents(js):
    """Union of mesh bounds with node TRS applied, walking scene graph."""
    accessors = js.get("accessors", [])
    meshes = js.get("meshes", [])
    nodes = js.get("nodes", [])

    def mesh_bounds(mesh):
        mn = [1e18] * 3
        mx = [-1e18] * 3
        for prim in mesh.get("primitives", []):
            acc = accessors[prim["attributes"]["POSITION"]]
            if "min" not in acc or "max" not in acc:
                continue
            for i in range(3):
                mn[i] = min(mn[i], acc["min"][i])
                mx[i] = max(mx[i], acc["max"][i])
        return mn, mx

    def walk(idx, parent_scale, parent_trans):
        node = nodes[idx]
        trans, scale = node_trs(node)
        eff_trans = tuple(parent_trans[a] + parent_scale[a] * trans[a] for a in range(3))
        eff_scale = tuple(parent_scale[a] * scale[a] for a in range(3))
        out = []
        if "mesh" in node:
            mn, mx = mesh_bounds(meshes[node["mesh"]])
            out.append(
                (
                    [eff_trans[a] + eff_scale[a] * mn[a] for a in range(3)],
                    [eff_trans[a] + eff_scale[a] * mx[a] for a in range(3)],
                )
            )
        for child in node.get("children", []):
            out.extend(walk(child, eff_scale, eff_trans))
        return out

    roots = []
    scenes = js.get("scenes") or []
    if scenes:
        roots = scenes[0].get("nodes", [])
    else:
        parented = {c for n in nodes for c in n.get("children", [])}
        roots = [i for i in range(len(nodes)) if i not in parented]
    boxes = []
    for r in roots:
        boxes.extend(walk(r, (1.0, 1.0, 1.0), (0.0, 0.0, 0.0)))
    if not boxes:
        return None
    mn = [min(b[0][a] for b in boxes) for a in range(3)]
    mx = [max(b[1][a] for b in boxes) for a in range(3)]
    return mn, mx


def check_asset(root_dir, entry, problems):
    path = os.path.join(root_dir, entry["file"])
    if not os.path.isfile(path):
        problems.append("%s: MISSING asset file" % entry["file"])
        return
    js, err = glb_json_chunk(path)
    if err:
        problems.append("%s: %s" % (entry["file"], err))
        return
    ext = world_extents(js)
    if not ext:
        problems.append("%s: no POSITION bounds found" % entry["file"])
        return
    mn, mx = ext
    dims = [mx[a] - mn[a] for a in range(3)]

    exp = entry.get("expect", {})
    tol = float(entry.get("dims_tolerance", 0.25))
    height_axis = exp.get("height_axis", "Y")
    h = dims[AXIS[height_axis]]
    # 1. orientation: height must not be the smallest extent, and must be a
    #    reasonable fraction of the largest (a sideways model has height ~ length)
    largest = max(dims)
    if largest > 0 and h < largest * float(exp.get("min_height_frac", 0.3)):
        problems.append(
            "%s: orientation? height(%s)=%.2f is %.0f%% of largest extent=%.2f"
            % (entry["file"], height_axis, h, 100 * h / max(largest, 1e-6), largest)
        )
    # 2. bounds drift vs locked dims (flexible: tolerance fraction per axis)
    locked = exp.get("dims")
    if locked:
        for a, axis in enumerate("XYZ"):
            want = float(locked[axis])
            if want <= 0:
                continue
            dev = abs(dims[a] - want) / want
            if dev > tol:
                problems.append(
                    "%s: %s extent %.2f vs locked %.2f (dev %.0f%% > tol %.0f%%)"
                    % (entry["file"], axis, dims[a], want, 100 * dev, 100 * tol)
                )
    # 3. rig contract
    names = {n.get("name", "") for n in js.get("nodes", [])}
    for req in exp.get("required_nodes", []):
        if req not in names:
            problems.append("%s: missing required node %s" % (entry["file"], req))
    emissive = {
        m.get("name", "")
        for m in js.get("materials", [])
        if m.get("emissiveFactor") and any(m["emissiveFactor"])
    }
    for req in exp.get("required_emissive_materials", []):
        if req not in emissive:
            problems.append("%s: missing emissive material %s" % (entry["file"], req))
    print(
        "OK   %s dims=(%.2f,%.2f,%.2f) nodes=%d materials=%d emissive=%d"
        % (entry["file"], dims[0], dims[1], dims[2], len(js.get("nodes", [])), len(js.get("materials", [])), len(emissive))
    )


def main():
    root_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    contract_path = os.path.join(root_dir, "tools", "glb_asset_contract.json")
    if not os.path.isfile(contract_path):
        print("CONTRACT MISSING: %s (fail closed)" % contract_path)
        sys.exit(3)
    with open(contract_path) as f:
        entries = json.load(f)
    problems = []
    for entry in entries:
        check_asset(root_dir, entry, problems)
    if problems:
        for p in problems:
            print("VIOLATION", p)
        print("GLB_CONTRACT: FAIL (%d violations, %d assets)" % (len(problems), len(entries)))
        sys.exit(2)
    print("GLB_CONTRACT: PASS (%d assets)" % len(entries))
    sys.exit(0)


if __name__ == "__main__":
    main()
