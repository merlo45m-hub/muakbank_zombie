#!/usr/bin/env python3
"""
measure_models.py — Extract union bounding boxes from GLB files.

Reads the GLB binary header + JSON chunk, finds all VEC3 accessors that
carry min/max, and computes the union bounding box across all of them.

Usage:
    python3 tools/measure_models.py [project_root]

Output: JSON to stdout with per-file bbox data.
"""

import json
import os
import struct
import sys


def parse_glb_bbox(filepath):
    """Parse a GLB file and return (min_xyz, max_xyz, error_message)."""
    try:
        with open(filepath, "rb") as f:
            data = f.read()
    except Exception as e:
        return None, None, f"read error: {e}"

    if len(data) < 20:
        return None, None, "file too small for GLB header"

    # GLB header: magic(4) + version(4) + length(4)
    magic = data[0:4]
    if magic != b"glTF":
        return None, None, f"not a GLB file (magic: {magic!r})"

    # First chunk: JSON
    chunk_len = struct.unpack_from("<I", data, 12)[0]
    chunk_type = data[16:20]
    if chunk_type != b"JSON":
        return None, None, f"first chunk is not JSON (type: {chunk_type!r})"

    json_start = 20
    json_end = json_start + chunk_len
    if json_end > len(data):
        return None, None, "JSON chunk extends past end of file"

    try:
        gltf = json.loads(data[json_start:json_end])
    except json.JSONDecodeError as e:
        return None, None, f"JSON parse error: {e}"

    # Find all VEC3 accessors with min/max
    accessors = gltf.get("accessors", [])
    if not accessors:
        return None, None, "no accessors in GLB"

    union_min = [float("inf"), float("inf"), float("inf")]
    union_max = [float("-inf"), float("-inf"), float("-inf")]
    found_vec3 = False

    for acc in accessors:
        if acc.get("type") != "VEC3":
            continue
        if "min" not in acc or "max" not in acc:
            continue
        found_vec3 = True
        mn = acc["min"]
        mx = acc["max"]
        for i in range(3):
            union_min[i] = min(union_min[i], mn[i])
            union_max[i] = max(union_max[i], mx[i])

    if not found_vec3:
        return None, None, "no VEC3 accessors with min/max found"

    return union_min, union_max, None


def classify_model(relpath):
    """Classify a model into a category based on its path."""
    p = relpath.lower()
    if "/commercial/" in p or "building-" in p or "low-detail-building" in p:
        if "skyscraper" in p:
            return "commercial-skyscraper"
        return "commercial-building"
    if "/suburban/" in p:
        if "building-type" in p:
            return "suburban-building"
        if "fence" in p:
            return "fence"
        if "tree" in p:
            return "tree"
        if "driveway" in p or "path" in p or "planter" in p:
            return "suburban-prop"
        return "suburban-prop"
    if "/roads/" in p:
        if "road-" in p or "tile-" in p:
            return "road-piece"
        if "sign" in p or "traffic-light" in p or "light-" in p:
            return "road-furniture"
        if "electricity" in p or "bridge" in p or "construction" in p or "dumpster" in p:
            return "road-prop"
        return "road-piece"
    if "/cars/" in p:
        if "wheel" in p or "debris" in p or "cone" in p or "box" in p:
            return "car-part"
        return "car"
    if "/animals/" in p:
        return "animal"
    if "/blocks/" in p:
        return "block-character"
    if "/minis/" in p:
        if "character" in p:
            return "mini-character"
        return "mini-prop"
    if "/kenney_anim/" in p:
        return "character-rig"
    if "/kenney/" in p:
        return "gravestone"
    if "character_" in p or "zombie_" in p:
        return "character"
    if "weapon_" in p:
        return "weapon"
    return "misc"


def main():
    project_root = sys.argv[1] if len(sys.argv) > 1 else "/storage/emulated/0/Games/Muakbank_zombie"
    models_dir = os.path.join(project_root, "assets", "models")

    if not os.path.isdir(models_dir):
        print(f"ERROR: models dir not found: {models_dir}", file=sys.stderr)
        sys.exit(1)

    results = []
    errors = []

    for dirpath, dirnames, filenames in os.walk(models_dir):
        for fname in sorted(filenames):
            if not fname.lower().endswith(".glb"):
                continue
            fpath = os.path.join(dirpath, fname)
            relpath = os.path.relpath(fpath, models_dir)

            mn, mx, err = parse_glb_bbox(fpath)
            if err:
                errors.append({"path": relpath, "error": err})
                continue

            size = [mx[i] - mn[i] for i in range(3)]
            category = classify_model(relpath)

            results.append({
                "path": relpath,
                "category": category,
                "min": mn,
                "max": mx,
                "size": size,
            })

    output = {
        "total": len(results) + len(errors),
        "measured": len(results),
        "errors": len(errors),
        "results": results,
        "error_list": errors,
    }

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
