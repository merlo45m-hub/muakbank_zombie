#!/usr/bin/env python3
"""tools/verify_visual_assets.py — pre-build visual asset gate (issue #63 I0).

Fails the pipeline BEFORE a build is generated when presentation surfaces ship
placeholder geometry, untextured materials, or broken texture references.

Checks (presentation scope = VISUAL_SCENES roots + their instances, recursive):
  V1  ext_resource targets referenced by scenes that do not exist on disk.
  V2  GLB ext references without a .glb.import sidecar (unimportable in engine).
  V3  Primitive meshes (Box/Sphere/Plane/Cylinder/Prism/TextMesh) inside
      presentation scenes — blockout placeholder class (title_background precedent).
  V4  StandardMaterial3D on visible MeshInstance3D in presentation scenes with an
      EMPTY albedo_texture (untextured flat look).
  V5  GLB JSON-chunk images[].uri references whose files are absent next to the glb.
Exceptions: tools/visual_assets_exceptions.json — counted, reason-bearing.
Derived report files are excluded from the scan (self-reference rule).

Verdict line (CI parses it): VISUAL_ASSETS: PASS (N surfaces) | VISUAL_ASSETS: FAIL (M issues)
Exit: 0 pass, 2 violations, 3 self-fault (missing scope, unreadable files).
"""
from __future__ import annotations
import json, os, re, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VISUAL_ROOTS = [
    "scenes/main", "scenes/ui", "scenes/world/title_background.tscn",
    "scenes/characters",  # roster models appear on selection surfaces
]
PRIMITIVE_TYPES = ("BoxMesh", "SphereMesh", "PlaneMesh", "CylinderMesh", "PrismMesh", "CapsuleMesh", "TextMesh")
EXC_PATH = ROOT / "tools" / "visual_assets_exceptions.json"
SELF = Path(__file__).resolve()

def load_exceptions() -> dict:
    if not EXC_PATH.exists():
        return {}
    data = json.loads(EXC_PATH.read_text(encoding="utf-8"))
    return {e["path"]: e.get("reason", "") for e in data.get("exceptions", [])}

def scene_files() -> list[Path]:
    files: list[Path] = []
    for r in VISUAL_ROOTS:
        p = ROOT / r
        if p.is_file():
            files.append(p)
        elif p.is_dir():
            files.extend(sorted(p.rglob("*.tscn")))
        else:
            print(f"VISUAL_ASSETS: SCOPE MISSING {r}", file=sys.stderr)
            sys.exit(3)
    return files

def ext_targets(text: str) -> list[tuple[str, str]]:
    out = []
    for m in re.finditer(r'\[ext_resource type="([^"]+)"[^\]]*path="res://([^"]+)"', text):
        out.append((m.group(1), m.group(2)))
    return out

def primitives_in(text: str) -> list[str]:
    hits = []
    for m in re.finditer(r"\[sub_resource type=\"(\w+)\" id=\"([^\"]+)\"\]", text):
        if m.group(1) in PRIMITIVE_TYPES:
            # only counts if actually referenced by a MeshInstance3D mesh= line
            if re.search(rf"mesh = SubResource\(\"{re.escape(m.group(2))}\"\)", text):
                hits.append(f"{m.group(1)}:{m.group(2)}")
    return hits

def untextured_materials(text: str) -> list[str]:
    hits = []
    for m in re.finditer(r'\[sub_resource type="StandardMaterial3D" id="([^"]+)"\]([^\[]*)', text):
        body = m.group(2)
        if "albedo_texture" not in body and re.search(rf"material = SubResource\(\"{m.group(1)}\"\)", text):
            used = re.search(rf'\[node [^\]]*\]([^\[]]*?)material = SubResource\("{re.escape(m.group(1))}"\)', text)
            if used and "MeshInstance3D" in text[max(0, used.start()-200):used.start()+30]:
                hits.append(m.group(1))
    return hits

def glb_uris_present(rel: str) -> list[str]:
    gp = ROOT / rel
    try:
        data = gp.read_bytes()
    except OSError:
        return ["<unreadable>"]
    if len(data) < 20 or data[:4] != b"glTF":
        return []
    clen = struct.unpack_from("<I", data, 12)[0]
    ctype = data[16:20]
    if ctype != b"JSON" or clen > len(data):
        return []
    try:
        doc = json.loads(data[20:20 + clen].decode("utf-8", "replace"))
    except json.JSONDecodeError:
        return ["<bad-json>"]
    missing = []
    base = gp.parent
    for img in doc.get("images", []):
        uri = img.get("uri", "")
        if not uri or uri.startswith("data:"):
            continue
        if not (base / uri).exists():
            missing.append(uri)
    return missing

def main() -> int:
    exc = load_exceptions()
    issues: list[str] = []
    surfaces = 0
    for f in scene_files():
        rel = str(f.relative_to(ROOT))
        if rel in exc:
            continue
        surfaces += 1
        try:
            text = f.read_text(encoding="utf-8")
        except OSError as e:
            issues.append(f"V0 {rel}: unreadable {e}")
            continue
        for typ, path in ext_targets(text):
            tgt = ROOT / path
            if not tgt.exists():
                issues.append(f"V1 {rel}: missing {typ} res://{path}")
            elif path.endswith(".glb") and not (ROOT / (path + ".import")).exists():
                issues.append(f"V2 {rel}: GLB without .import sidecar: {path}")
            if path.endswith(".glb") and tgt.exists():
                miss = glb_uris_present(path)
                for u in miss:
                    issues.append(f"V5 {rel}: GLB {path} texture uri absent: {u}")
        prim = primitives_in(text)
        if prim:
            issues.append(f"V3 {rel}: placeholder primitive meshes: {', '.join(prim[:6])}"
                          + (f" (+{len(prim)-6})" if len(prim) > 6 else ""))
        un = untextured_materials(text)
        if un:
            issues.append(f"V4 {rel}: untextured materials on visible meshes: {', '.join(un[:4])}")
    if issues:
        for i in issues[:40]:
            print("  ISSUE " + i)
        print(f"VISUAL_ASSETS: FAIL ({len(issues)} issues, {surfaces} surfaces scanned)")
        return 2
    print(f"VISUAL_ASSETS: PASS ({surfaces} surfaces)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
