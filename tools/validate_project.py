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
    # Malformed vector constructors (e.g. PlaneMesh size = Vector3(a, b) needs Vector2)
    for ln, line in enumerate(content.split("\n"), 1):
        for ctor, want in (("Vector3", 3), ("Vector2", 2)):
            for m in re.finditer(rf'{ctor}\(([^)]*)\)', line):
                args = [a for a in m.group(1).split(",") if a.strip()]
                if args and len(args) != want and not any(
                        x in args[0] for x in ("UP", "ZERO", "ONE", "INF", "DOWN", "LEFT", "RIGHT",
                                               "FORWARD", "BACK", "AXIS")):
                    issues.append(f"MALFORMED {ctor} ({len(args)} args) at {r}:{ln}")
    for m in re.finditer(r'path="(res://[^"]+)"', content):
        p = m.group(1)
        if not os.path.exists(os.path.join(PROJ, p[6:])):
            issues.append(f"BROKEN REF: {r} -> {p}")
    nodes = [l for l in lines if l.startswith("[node")]
    if nodes and "parent=" in nodes[0]:
        issues.append(f"NO ROOT NODE (first node has parent=): {r}")
    # Declarations must precede the first [node], and ext_resource before sub_resource
    first_node = content.find("\n[node")
    if first_node != -1:
        tail = content[first_node:]
        if "\n[ext_resource" in tail or "\n[sub_resource" in tail:
            issues.append(f"DECLARATION AFTER FIRST NODE: {r}")
    tags = [l.strip() for l in content.split("\n") if l.startswith("[")]
    first_sub = next((i for i, t in enumerate(tags) if t.startswith("[sub_resource")), None)
    if first_sub is not None:
        late_ext = [t for i, t in enumerate(tags)
                    if t.startswith("[ext_resource") and i > first_sub]
        if late_ext:
            issues.append(f"ext_resource AFTER sub_resource: {r}")

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
    # Block openers must have an indented body
    glines = content.split("\n")
    for i, line in enumerate(glines):
        st = line.strip()
        if not st or st.startswith("#"):
            continue
        if st.endswith(":"):
            indent = len(line) - len(line.lstrip("\t"))
            j = i + 1
            while j < len(glines) and (not glines[j].strip() or glines[j].strip().startswith("#")):
                j += 1
            if j < len(glines):
                nxt = glines[j]
                if len(nxt) - len(nxt.lstrip("\t")) <= indent:
                    issues.append(f"EMPTY BLOCK at {r}:{i+1} ({st[:40]})")

# ── Resources (.tres) ─────────────────────────────────────────
tres_files = walk_suffix('.tres')
for path in sorted(tres_files):
    with open(path, errors='replace') as fh:
        content = fh.read()
    r = rel(path)
    if not content.startswith("[gd_resource"):
        issues.append(f"TRES NO HEADER: {r}")
        continue
    # Every ExtResource("N") must have a matching [ext_resource ... id="N"]
    declared = set(re.findall(r'^\[ext_resource[^\]]*id="([^"]+)"', content, re.M))
    used = set(re.findall(r'ExtResource\("([^"]+)"\)', content))
    missing = used - declared
    if missing:
        issues.append(f"TRES UNDECLARED ext_resource {sorted(missing)}: {r}")
    # No stray bracket-only lines other than known tags
    for ln, line in enumerate(content.split("\n"), 1):
        s = line.strip()
        if s.startswith("[") and not re.match(
                r'^\[(gd_resource|resource|ext_resource|sub_resource)', s):
            issues.append(f"TRES JUNK TAG at {r}:{ln}: {s[:40]}")

# ── Report ────────────────────────────────────────────────────
print(f"Checked {len(tscn_files)} scenes, {len(gd_files)} scripts, {len(tres_files)} resources")
print(f"ISSUES: {len(issues)}")
for i in issues:
    print(" -", i)
if not issues:
    print("PROJECT IS STRUCTURALLY VALID")
sys.exit(1 if issues else 0)
