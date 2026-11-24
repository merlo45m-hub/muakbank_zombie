#!/usr/bin/env python3
"""Static gate: no CSG nodes, mesh boolean ops, or real-time fracture in the dismantle path.

Allowed: the shipped pre-authored split-part swap (split_parts_scene) and short-lived debris.
Fails closed: bad project dir, missing anchor file, unreadable file, or zero files => FAIL.

Usage:
  check_no_realtime_fracture.py --project-dir /path/to/project
  check_no_realtime_fracture.py --self-test      (fixtures built in a temp dir, not the repo)
"""
import argparse
import os
import re
import sys
import tempfile

GLOBAL_SKIP = {".git", ".godot", ".import", "addons", "node_modules"}
TOP_LEVEL_SKIP = {"tools", "tests", "docs", "renders"}
SCAN_EXTS = {".gd", ".gdshader", ".tscn", ".tres"}
ANCHOR = "scripts/gameplay/DismantleComponent.gd"

CSG_RE = re.compile(r"(?<![A-Za-z0-9])csg", re.IGNORECASE)
BOOLEAN_RE = re.compile(
    r"(boolean[_ ]?(op|mesh|subtract|union|intersect)|mesh[_ ]?boolean|(subtract|intersect)_mesh)",
    re.IGNORECASE,
)
FRACTURE_RE = re.compile(r"(fractur|shatter|voronoi|mesh[_ ]?(slice|cut)|slice[_ ]?mesh)", re.IGNORECASE)
RUNTIME_MESH_RE = re.compile(r"\b(SurfaceTool|MeshDataTool|add_surface_from_arrays)\b")


def strip_comment(line, ext):
    if ext == ".gd":
        marker = "#"
    elif ext == ".gdshader":
        marker = "//"
    else:
        return "" if line.lstrip().startswith(";") else line
    quote = None
    idx = 0
    while idx < len(line):
        ch = line[idx]
        if quote:
            if ch == "\\":
                idx += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif line.startswith(marker, idx):
            return line[:idx]
        idx += 1
    return line


def check_line(text, ext, in_dismantle_path):
    if CSG_RE.search(text):
        return "CSG node/operation"
    if BOOLEAN_RE.search(text):
        return "mesh boolean operation"
    if in_dismantle_path and FRACTURE_RE.search(text):
        return "real-time fracture in dismantle path"
    if in_dismantle_path and ext == ".gd" and RUNTIME_MESH_RE.search(text):
        return "runtime mesh construction in dismantle path"
    return None


def scan(project_dir):
    """Return (files_scanned, [(relpath, lineno, reason), ...])."""
    violations = []
    files = 0
    if not os.path.isdir(project_dir):
        return 0, [("<project-dir>", 0, "not a directory: %s" % project_dir)]
    if not os.path.isfile(os.path.join(project_dir, "project.godot")):
        return 0, [("project.godot", 0, "missing: not a Godot project dir")]
    if not os.path.isfile(os.path.join(project_dir, *ANCHOR.split("/"))):
        violations.append((ANCHOR, 0, "dismantle anchor file missing"))
    for dirpath, dirnames, filenames in os.walk(project_dir):
        at_top = os.path.abspath(dirpath) == os.path.abspath(project_dir)
        dirnames[:] = sorted(
            d for d in dirnames if d not in GLOBAL_SKIP and not (at_top and d in TOP_LEVEL_SKIP)
        )
        for name in sorted(filenames):
            ext = os.path.splitext(name)[1].lower()
            if ext not in SCAN_EXTS:
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, project_dir).replace(os.sep, "/")
            in_dismantle_path = "dismantle" in rel.lower()
            files += 1
            try:
                with open(full, "r", encoding="utf-8", errors="replace") as handle:
                    lines = handle.read().splitlines()
            except OSError as exc:
                violations.append((rel, 0, "unreadable: %s" % exc))
                continue
            for lineno, raw in enumerate(lines, start=1):
                reason = check_line(strip_comment(raw, ext), ext, in_dismantle_path)
                if reason:
                    violations.append((rel, lineno, reason))
    if files == 0 and not violations:
        violations.append(("<project-dir>", 0, "no scannable files"))
    return files, violations


def render(files, violations):
    if violations:
        return ["NO_REALTIME_FRACTURE: FAIL %s:%d (%s)" % v for v in violations]
    return ["NO_REALTIME_FRACTURE: PASS (%d files)" % files]


CLEAN_DISMANTLE = (
    "## Swaps to PRE-AUTHORED split-part meshes (NOT real-time CSG / boolean / fracture).\n"
    "@export var split_parts_scene: PackedScene = null\n"
    "func _swap_to_split_meshes() -> void:\n"
    "\tvar debris_pool: Node = null  # short-lived debris, recycled\n"
)
CLEAN_PROP_TSCN = '[gd_scene format=3]\n[sub_resource type="ArrayMesh" id="1"]\n'


def build_fixture(root, extra):
    files = {
        "project.godot": "config_version=5\n",
        ANCHOR: CLEAN_DISMANTLE,
        "scenes/world/props/gravestone_dismantle.tscn": CLEAN_PROP_TSCN,
    }
    files.update(extra)
    for rel, content in files.items():
        if content is None:
            continue
        path = os.path.join(root, *rel.split("/"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)


def self_test():
    cases = [
        ("clean shipped-style swap", {}, None),
        ("CSG node in scene", {"scenes/x.tscn": '[gd_scene]\n\n[node name="W" type="CSGBox3D"]\n'}, "scenes/x.tscn:3"),
        ("CSG created in script", {"scripts/y.gd": "extends Node\nvar n = CSGCombiner3D.new()\n"}, "scripts/y.gd:2"),
        ("boolean op in script", {"scripts/z.gd": "func f():\n\tvar m = mesh_boolean_subtract(a, b)\n"}, "scripts/z.gd:2"),
        (
            "fracture in dismantle path",
            {"scripts/gameplay/DismantleComponent.gd": CLEAN_DISMANTLE + "func fracture_mesh():\n\tpass\n"},
            "DismantleComponent.gd:5",
        ),
        (
            "runtime mesh build in dismantle path",
            {"scripts/gameplay/DismantleComponent.gd": CLEAN_DISMANTLE + "var st = SurfaceTool.new()\n"},
            "DismantleComponent.gd:5",
        ),
        ("missing anchor", {ANCHOR: None}, "DismantleComponent.gd:0"),
    ]
    failures = 0
    for name, extra, expect_fail_at in cases:
        with tempfile.TemporaryDirectory() as tmp:
            build_fixture(tmp, extra)
            files, violations = scan(tmp)
            out = "\n".join(render(files, violations))
        ok = ("PASS" in out) if expect_fail_at is None else ("FAIL" in out and expect_fail_at in out)
        print("  [%s] %s" % ("ok" if ok else "BAD", name))
        failures += 0 if ok else 1
    with tempfile.TemporaryDirectory() as tmp:
        files, violations = scan(tmp)
        ok = bool(violations)
        print("  [%s] empty dir fails closed" % ("ok" if ok else "BAD"))
        failures += 0 if ok else 1
    total = len(cases) + 1
    if failures:
        print("SELF_TEST: FAIL (%d/%d bad)" % (failures, total))
        return 1
    print("SELF_TEST: PASS (%d cases)" % total)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project-dir", help="Godot project root to scan (required unless --self-test)")
    parser.add_argument("--self-test", action="store_true", help="run fixture-based negative controls")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not args.project_dir:
        parser.error("--project-dir is required")
    files, violations = scan(args.project_dir)
    print("\n".join(render(files, violations)))
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
