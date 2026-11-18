"""Verify the scale lock survives glTF export -> Godot import.

Checks the GLB itself (what Godot imports), not the Blender source:
  - every -convcol node carries scale_lock extras.
  - node scale is identity (no transform inheritance baked into node TRS).
  - accessor POSITION min/max extent equals locked_dimensions_m within tolerance.
  - recompute scale_contract_sha256 from the exported asset JSON.
  - negative controls: --inject-scale (scale drift) and --inject-bbox (modifier drift).

Run: python3 tools/blender/verify_scale_contract.py [--inject-scale|--inject-bbox]
"""
from __future__ import annotations
import hashlib, json, os, struct, sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "assets", "data", "blender_structure_assets.json")
GLB = os.path.join(REPO, "assets", "models", "screen_structures_exploded.glb")


def read_glb(path):
    d = open(path, "rb").read()
    magic, ver, length = struct.unpack("<4sII", d[:12])
    assert magic == b"glTF", "not a GLB"
    off, chunks = 12, {}
    while off < length:
        clen, ctype = struct.unpack("<I4s", d[off:off + 8])
        chunks[ctype.strip(b"\x00").decode()] = d[off + 8:off + 8 + clen]
        off += 8 + clen
    j = json.loads(chunks["JSON"].decode("utf-8").rstrip(" \x00"))
    return j, chunks.get("BIN", b"")


def accessor_extent(j, bin_chunk, idx):
    acc = j["accessors"][idx]
    if "min" in acc and "max" in acc and acc.get("type") == "VEC3":
        return [round(float(acc["max"][i]) - float(acc["min"][i]), 5) for i in range(3)]
    return None


def node_dims(j, bin_chunk, node):
    """World extent of a mesh node from POSITION accessor * node scale."""
    if "mesh" not in node:
        return None, None
    prims = j["meshes"][node["mesh"]].get("primitives", [])
    ext = None
    for pr in prims:
        a = pr.get("attributes", {}).get("POSITION")
        if a is not None:
            e = accessor_extent(j, bin_chunk, a)
            if e:
                ext = e
                break
    scale = node.get("scale", [1.0, 1.0, 1.0])
    if ext is None:
        return None, scale
    # glTF is Y-up; Blender +Z up. Extent axes are permuted by export_yup; compare
    # as a sorted multiset so axis permutation does not read as drift.
    dims = sorted(round(ext[i] * float(scale[i]), 5) for i in range(3))
    return dims, scale


def main():
    inject = None
    if "--inject-scale" in sys.argv:
        inject = "scale"
    elif "--inject-bbox" in sys.argv:
        inject = "bbox"
    with open(SRC, encoding="utf-8") as f:
        data = json.load(f)
    cal = data["scale_calibration"]
    tol = float(cal["scale_lock_policy"]["bbox_tolerance_m"])
    locks = {p["scale_lock"]["part_id"]: p["scale_lock"] for a in data["assemblies"] for p in a["parts"]}
    # recompute contract hash
    contract = {"calibration": cal,
                "locks": [locks[k] for k in sorted(locks)]}
    payload = json.dumps(contract, sort_keys=True, separators=(",", ":")).encode("utf-8")
    recomputed = "sha256:" + hashlib.sha256(payload).hexdigest()
    hash_ok = recomputed == data["scale_contract_sha256"]
    j, bin_chunk = read_glb(GLB)

    if inject == "scale":
        # simulate transform inheritance: non-identity node scale
        for n in j["nodes"]:
            if n.get("name", "").endswith("-convcol"):
                n["scale"] = [1.5, 1.5, 1.5]
                break
    if inject == "bbox":
        # simulate a modifier expanding geometry
        for n in j["nodes"]:
            if n.get("name", "").endswith("-convcol"):
                pr = j["meshes"][n["mesh"]]["primitives"][0]
                a = pr["attributes"]["POSITION"]
                j["accessors"][a]["max"] = [x * 1.5 for x in j["accessors"][a]["max"]]
                break

    findings = []
    checked = 0
    for n in j["nodes"]:
        name = n.get("name", "")
        if not name.endswith("-convcol"):
            continue
        pid = name[:-len("-convcol")]
        lock = locks.get(pid)
        if lock is None:
            findings.append({"node": name, "issue": "no scale_lock contract"})
            continue
        extras = n.get("extras", {}) or {}
        if not extras.get("scale_lock"):
            findings.append({"node": name, "issue": "missing scale_lock extras in GLB"})
        dims, scale = node_dims(j, bin_chunk, n)
        if any(abs(float(s) - 1.0) > 1e-6 for s in scale):
            findings.append({"node": name, "issue": "non-identity node scale %s" % scale})
        want = sorted(float(x) for x in lock["locked_dimensions_m"])
        if dims is None:
            findings.append({"node": name, "issue": "no POSITION accessor extent"})
        elif any(abs(g - w) > tol for g, w in zip(dims, want)):
            findings.append({"node": name, "issue": "bbox %s != locked %s" % (dims, want)})
        checked += 1

    ok = hash_ok and checked == data["total_parts"] and not findings
    print("SCALE_CONTRACT_HASH_OK", hash_ok)
    print("NODES_CHECKED", checked, "/", data["total_parts"])
    print("FINDINGS", len(findings), findings[:3])
    print("VERIFY_OK", ok)
    if inject:
        # negative control: injection MUST make verification fail
        print("INJECTION", inject, "DETECTED", not ok)
        return 0 if (not ok) else 1
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
