#!/usr/bin/env python3
"""validate_project.py — static validator for the Muakbank Zombie Godot project.

Catches the failure classes that subagent-generated scenes and folder
reorganisations introduce (Godot can't be run headless on Android — no glibc).

Usage:  python3 validate_project.py [project_dir]
Exit 0 = clean, 1 = issues found.
"""
import os, re, sys

PROJ = sys.argv[1] if len(sys.argv) > 1 else "/storage/emulated/0/Games/Muakbank_zombie"
SKIP_DIRS = {'.godot', '.git', 'addons'}
issues = []


def walk_suffix(suffix):
    out = []
    for root, dirs, files in os.walk(PROJ):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(suffix):
                out.append(os.path.join(root, f))
    return out


def rel(p):
    return p.replace(PROJ + "/", "")


# ── Scenes ────────────────────────────────────────────────────
tscn_files = walk_suffix('.tscn')
for path in sorted(tscn_files):
    with open(path, errors='replace') as fh:
        content = fh.read()
    r = rel(path)
    lines = content.split("\n")

    if not lines[0].startswith("[gd_scene"):
        issues.append(f"NO HEADER: {r} (first line: {lines[0][:60]!r})")
        continue
    if content.count("[") != content.count("]"):
        issues.append(f"UNBALANCED BRACKETS: {r} ([={content.count('[')} ]={content.count(']')})")
    if "[<node" in content:
        issues.append(f"BROKEN TAG [<node: {r}")
    # Subagents mangle the closing bracket: [node ...> instead of [node ...]
    for i, line in enumerate(lines, 1):
        if line.startswith("[node") and line.rstrip().endswith(">"):
            issues.append(f"NODE HEADER CLOSES WITH '>' not ']': {r}:{i}")
            break
    for bad in ("PointLight3D", "KinematicBody", 'type="Spatial"'):
        if bad in content:
            issues.append(f"GODOT3 TYPE ({bad}): {r}")
    # Godot 3 scene instancing: `scene = ExtResource(...)` / `type=""` on a node.
    # Godot 4 uses `instance=ExtResource("id")` inside the [node ...] header.
    if "scene = ExtResource" in content:
        issues.append(f"GODOT3 INSTANCING (scene = ExtResource): {r}")
    if re.search(r'^\[node [^\]]*type=""', content, re.M):
        issues.append(f'GODOT3 INSTANCING (type="" on node): {r}')
    for m in re.finditer(r'path="(res://[^"]+)"', content):
        p = m.group(1)
        if not os.path.exists(os.path.join(PROJ, p[6:])):
            issues.append(f"BROKEN REF: {r} -> {p}")
    nodes = [l for l in lines if l.startswith("[node")]
    if nodes and "parent=" in nodes[0]:
        issues.append(f"NO ROOT NODE (first node has parent=): {r}")

# ── Scripts ───────────────────────────────────────────────────
gd_files = walk_suffix('.gd')
sm = os.path.join(PROJ, "SceneManager.gd")
if os.path.exists(sm):
    gd_files.append(sm)

for path in sorted(gd_files):
    with open(path, errors='replace') as fh:
        content = fh.read()
    r = rel(path)
    for o, c, n in (("(", ")", "parens"), ("{", "}", "braces"), ("[", "]", "brackets")):
        s = re.sub(r'"[^"\n]*"', '""', content)
        s = re.sub(r'#[^\n]*', '', s)
        if s.count(o) != s.count(c):
            issues.append(f"UNBALANCED {n}: {r}")
    for bad in ("get_tree().change_scene(", "yield(", "DynamicFont",
                "add_color_override", "add_font_override", "rect_min_size",
                "KinematicBody", "type=\"Spatial\""):
        if bad in content:
            issues.append(f"GODOT3 API ({bad}): {r}")

# ── Report ────────────────────────────────────────────────────
print(f"Checked {len(tscn_files)} scenes, {len(gd_files)} scripts")
print(f"ISSUES: {len(issues)}")
for i in issues:
    print(" -", i)
if not issues:
    print("PROJECT IS STRUCTURALLY VALID")
sys.exit(1 if issues else 0)
