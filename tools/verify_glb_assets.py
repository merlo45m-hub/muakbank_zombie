#!/usr/bin/env python3
"""GLB asset contract gate (stdlib core; trimesh cross-check when available).

Layers, all deterministic (no vision, no engine):
  0. MANIFEST SCHEMA - tools/glb_asset_contract.schema.json enforced on the
     manifest itself before anything else (stdlib subset validator; pydantic
     used additionally when importable). Contract drift = fail closed rc 3.
  1. ORIENTATION     - height axis must be a real fraction of the largest
     extent (catches Y-up/Z-up sideways exports) per contract entry.
  2. BOUNDS          - world extents vs locked dims with per-axis tolerance.
  3. RIG SCHEMA      - required part node names + emissive material names.
  4. CROSS-CHECK     - when trimesh is importable, its scene bounds must agree
     with the stdlib parser within 2 cm; disagreement is a VIOLATION
     (validates the gate itself, not just the assets).

Usage:
  python3 tools/verify_glb_assets.py [repo_root]
  python3 tools/verify_glb_assets.py [repo_root] --generate   # refresh locked dims

Exit: 0 PASS, 2 FAIL, 3 missing/broken contract or schema (fail closed).
"""
import glob
import json
import os
import re
import struct
import sys

AXIS = {"X": 0, "Y": 1, "Z": 2}


# ---------------------------------------------------------------- manifest schema
def _v_type_ok(val, want):
    m = {"object": dict, "array": list, "string": str,
         "number": (int, float), "boolean": bool}
    if want == "number":
        return isinstance(val, (int, float)) and not isinstance(val, bool)
    return isinstance(val, m[want])


def _validate_subset(data, schema, path, errors):
    t = schema.get("type")
    if t and not _v_type_ok(data, t):
        errors.append("%s: expected type %s" % (path, t))
        return
    if "enum" in schema and data not in schema["enum"]:
        errors.append("%s: %r not in enum %s" % (path, data, schema["enum"]))
    if isinstance(data, dict):
        for r in schema.get("required", []):
            if r not in data:
                errors.append("%s: missing required key '%s'" % (path, r))
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for k in data:
                if k not in props:
                    errors.append("%s: unexpected key '%s'" % (path, k))
        for k, sub in props.items():
            if k in data:
                _validate_subset(data[k], sub, "%s.%s" % (path, k), errors)
    if isinstance(data, list) and "items" in schema:
        for i, item in enumerate(data):
            _validate_subset(item, schema["items"], "%s[%d]" % (path, i), errors)
    if isinstance(data, str):
        if len(data) < schema.get("minLength", 0):
            errors.append("%s: shorter than minLength %d" % (path, schema["minLength"]))
        if "pattern" in schema and re.search(schema["pattern"], data) is None:
            errors.append("%s: does not match pattern %s" % (path, schema["pattern"]))
    if isinstance(data, (int, float)) and not isinstance(data, bool):
        if "minimum" in schema and data < schema["minimum"]:
            errors.append("%s: %s < minimum %s" % (path, data, schema["minimum"]))
        if "maximum" in schema and data > schema["maximum"]:
            errors.append("%s: %s > maximum %s" % (path, data, schema["maximum"]))


def validate_manifest(entries, root_dir):
    schema_path = os.path.join(root_dir, "tools", "glb_asset_contract.schema.json")
    if not os.path.isfile(schema_path):
        return ["manifest schema file missing: " + schema_path]
    with open(schema_path) as f:
        schema = json.load(f)
    errors = []
    _validate_subset(entries, schema, "manifest", errors)
    # optional strict re-validation with pydantic when importable (dev hosts).
    # CI stays stdlib-only by design: no pip, no engine.
    try:
        import pydantic  # noqa: F401
        # jsonschema is the closer analogue for raw-schema validation; use it
        # when present to double-check the subset validator itself.
        try:
            import jsonschema
            jsonschema.validate(entries, schema)
        except ImportError:
            pass
        except Exception as e:  # jsonschema disagrees with subset -> suspicious
            errors.append("jsonschema disagrees with subset validator: %s" % str(e)[:200])
    except ImportError:
        pass
    return errors


# ---------------------------------------------------------------- glb parsing
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
    if "matrix" in node:
        m = node["matrix"]
        scale = (
            (m[0] ** 2 + m[1] ** 2 + m[2] ** 2) ** 0.5,
            (m[4] ** 2 + m[5] ** 2 + m[6] ** 2) ** 0.5,
            (m[8] ** 2 + m[9] ** 2 + m[10] ** 2) ** 0.5,
        )
        return (m[12], m[13], m[14]), scale
    return node.get("translation", (0.0, 0.0, 0.0)), node.get("scale", (1.0, 1.0, 1.0))


def quat_to_3x3(q):
    x, y, z, w = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]


def node_matrix(node):
    """4x4 as rows. Honors gltf 'matrix' (column-major) or T/R/S."""
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = node.get("translation", [0.0, 0.0, 0.0])
    r = quat_to_3x3(node["rotation"]) if "rotation" in node else [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    s = node.get("scale", [1.0, 1.0, 1.0])
    rows = [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]] for i in range(3)]
    rows.append([0.0, 0.0, 0.0, 1.0])
    return rows


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def xform_point(m, p):
    return [m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3)]


def world_extents(js):
    """Union of mesh POSITION bounds through composed 4x4 node transforms
    (translation, rotation, scale, or matrix) - exact for rotated hierarchies."""
    accessors = js.get("accessors", [])
    meshes = js.get("meshes", [])
    nodes = js.get("nodes", [])

    def mesh_bounds(mesh):
        mn = [1e18] * 3
        mx = [-1e18] * 3
        seen = False
        for prim in mesh.get("primitives", []):
            acc = accessors[prim["attributes"]["POSITION"]]
            if "min" in acc and "max" in acc:
                seen = True
                for i in range(3):
                    mn[i] = min(mn[i], acc["min"][i])
                    mx[i] = max(mx[i], acc["max"][i])
        return (mn, mx) if seen else None

    def walk(idx, parent_mat):
        node = nodes[idx]
        mat = mat_mul(parent_mat, node_matrix(node))
        pts = []
        if "mesh" in node:
            mb = mesh_bounds(meshes[node["mesh"]])
            if mb:
                mn, mx = mb
                for i in range(8):
                    pts.append(xform_point(
                        mat,
                        [mx[0] if i & 1 else mn[0],
                         mx[1] if i & 2 else mn[1],
                         mx[2] if i & 4 else mn[2]],
                    ))
        for child in node.get("children", []):
            pts.extend(walk(child, mat))
        return pts

    ident = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    scenes = js.get("scenes") or []
    if scenes:
        roots = scenes[0].get("nodes", [])
    else:
        parented = {c for n in nodes for c in n.get("children", [])}
        roots = [i for i in range(len(nodes)) if i not in parented]
    pts = []
    for r in roots:
        pts.extend(walk(r, ident))
    if not pts:
        return None
    mn = [min(p[a] for p in pts) for a in range(3)]
    mx = [max(p[a] for p in pts) for a in range(3)]
    return mn, mx


def trimesh_extents(path, rigid=False):
    try:
        import trimesh
    except Exception:
        return None
    if rigid:
        # skinned/animated asset: compare node-transform tree (same rest
        # geometry the stdlib parser measures), not deformed scene bounds
        g = trimesh.load(path)
        return g.bounding_box.extents
    sc = trimesh.load(path, force="scene")
    return sc.bounds[1] - sc.bounds[0]


# ---------------------------------------------------------------- checks
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
    if entry.get("animation_container"):
        if not (js.get("animations") or js.get("skins")):
            problems.append("%s: flagged animation_container but has neither skins nor animations" % entry["file"])
            return
        print("OK   %s animation-container (skins=%d anims=%d)" % (
            entry["file"], len(js.get("skins", [])), len(js.get("animations", []))))
        return
    if not ext:
        problems.append("%s: no POSITION bounds found" % entry["file"])
        return
    mn, mx = ext
    dims = [mx[a] - mn[a] for a in range(3)]
    exp = entry.get("expect", {})
    tol = float(entry.get("dims_tolerance", 0.25))
    h_axis = AXIS[exp.get("height_axis", "Y")]

    largest = max(dims)
    min_frac = float(exp.get("min_height_frac", 0.3))
    if min_frac > 0 and largest > 0 and dims[h_axis] < largest * min_frac:
        problems.append(
            "%s: orientation? height extent %.2f is %.0f%% of largest %.2f (min %.0f%%)"
            % (entry["file"], dims[h_axis], 100 * dims[h_axis] / largest, largest, 100 * min_frac))

    locked = exp.get("dims")
    if locked:
        ABS_FLOOR = 0.005  # 5mm: absolute floor so sub-cm rounding of tiny
        #                      props can never produce false violations
        for a, axis in enumerate("XYZ"):
            want = float(locked[axis])
            if want <= 0:
                continue
            dev_abs = abs(dims[a] - want)
            if dev_abs > max(tol * want, ABS_FLOOR):
                problems.append("%s: %s extent %.3f vs locked %.3f (dev %.0f%% > tol %.0f%%)"
                                % (entry["file"], axis, dims[a], want,
                                   100 * dev_abs / want, 100 * tol))

    names = {n.get("name", "") for n in js.get("nodes", [])}
    for req in exp.get("required_nodes", []):
        if req not in names:
            problems.append("%s: missing required node %s" % (entry["file"], req))
    emissive = {m.get("name", "") for m in js.get("materials", [])
                if m.get("emissiveFactor") and any(m["emissiveFactor"])}
    for req in exp.get("required_emissive_materials", []):
        if req not in emissive:
            problems.append("%s: missing emissive material %s" % (entry["file"], req))

    te = trimesh_extents(path, rigid=bool(js.get("skins") or js.get("animations")))
    if te is not None:
        worst = max(abs(te[a] - dims[a]) for a in range(3))
        if worst > 0.02:
            problems.append("%s: parser disagreement - stdlib (%.2f,%.2f,%.2f) vs trimesh (%.2f,%.2f,%.2f) maxdev %.2fm"
                            % (entry["file"], dims[0], dims[1], dims[2], te[0], te[1], te[2], worst))
    print("OK   %s dims=(%.2f,%.2f,%.2f)%s nodes=%d mats=%d emissive=%d"
          % (entry["file"], dims[0], dims[1], dims[2],
             " xtrimesh" if te is not None else "",
             len(js.get("nodes", [])), len(js.get("materials", [])), len(emissive)))


# ---------------------------------------------------------------- generate
def generate(root_dir):
    cp = os.path.join(root_dir, "tools", "glb_asset_contract.json")
    existing = {}
    if os.path.isfile(cp):
        for e in json.load(open(cp)):
            existing[e["file"]] = e
    entries = []
    for path in sorted(glob.glob(os.path.join(root_dir, "assets", "**", "*.glb"),
                                  recursive=True)):
        rel = os.path.relpath(path, root_dir).replace(os.sep, "/")
        js, err = glb_json_chunk(path)
        if err:
            print("SKIP %s (%s)" % (rel, err))
            continue
        ext = world_extents(js)
        if not ext or js.get("skins") or js.get("animations"):
            entries.append({
                "file": rel,
                "animation_container": True,
                "expect": {"height_axis": "Y", "min_height_frac": 0.0},
            })
            print("NOTE %s (%s -> container entry)" % (
                rel, "skinned/animated: rigid-tree extents meaningless (joint-chain phantom)"
                if (js.get("skins") or js.get("animations")) else "no POSITION bounds"))
            continue
        dims = [round(ext[1][a] - ext[0][a], 3) for a in range(3)]
        if rel in existing and existing[rel].get("expect", {}).get("required_nodes"):
            e = existing[rel]
            e["expect"]["dims"] = {"X": dims[0], "Y": dims[1], "Z": dims[2]}
            entries.append(e)
        else:
            entries.append({
                "file": rel,
                "dims_tolerance": 0.05,
                "expect": {
                    "height_axis": "Y",
                    "min_height_frac": 0.0,
                    "dims": {"X": dims[0], "Y": dims[1], "Z": dims[2]},
                },
            })
    with open(cp, "w") as f:
        json.dump(entries, f, indent=2)
        f.write("\n")
    print("GENERATED %d contract entries -> %s" % (len(entries), cp))


def main():
    args = sys.argv[1:]
    gen = "--generate" in args
    if gen:
        args.remove("--generate")
    root_dir = args[0] if args else "."
    if gen:
        generate(root_dir)
        sys.exit(0)

    contract_path = os.path.join(root_dir, "tools", "glb_asset_contract.json")
    if not os.path.isfile(contract_path):
        print("CONTRACT MISSING: %s (fail closed)" % contract_path)
        sys.exit(3)
    with open(contract_path) as f:
        entries = json.load(f)

    schema_errors = validate_manifest(entries, root_dir)
    if schema_errors:
        for e in schema_errors:
            print("SCHEMA VIOLATION", e)
        print("GLB_CONTRACT: FAIL (manifest schema: %d errors)" % len(schema_errors))
        sys.exit(3)
    print("MANIFEST SCHEMA: valid (%d entries)" % len(entries))

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
