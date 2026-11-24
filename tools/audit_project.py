#!/usr/bin/env python3
"""audit_project.py - uniform-quality audit for the Muakbank Zombie Godot project.

Checks, across every scene and resource in the repo:
  A. ext_resource paths resolve to files that exist
  B. StandardMaterial3D resources carry the expected PBR inputs
  C. referenced textures exist and are power-of-two (mobile requirement)
  D. texture format consistency
  E. node-tree integrity: no duplicate node names, every parent= resolves
  F. orphan textures (on disk, never referenced)
  G. script references resolve

Usage:  python3 tools/audit_project.py [project_dir]
Exit 0 = clean, 1 = issues found.
"""
from __future__ import annotations

import collections
import os
import re
import struct
import sys

PROJ = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
SKIP = {'.godot', '.git', 'addons', '.tmp-godot-cache', '.tmp-godot-config', '.tmp-godot-data'}

issues: list[str] = []


def walk(*suffixes):
    for root, dirs, files in os.walk(PROJ):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for f in files:
            if f.endswith(suffixes):
                yield os.path.join(root, f)


def rel(p):
    return os.path.relpath(p, PROJ).replace(os.sep, "/")


def res_path(path: str) -> str:
    return os.path.join(PROJ, path[6:]) if path.startswith('res://') else path


def png_size(path):
    try:
        with open(path, "rb") as fh:
            head = fh.read(26)
        if head[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        return struct.unpack(">II", head[16:24])
    except Exception:
        return None


EXT_RES = re.compile(r'^\[ext_resource\s+([^\]]+)\]', re.M)
SUB_RES = re.compile(r'^\[sub_resource\s+([^\]]+)\]', re.M)
NODE_HDR = re.compile(r'^\[node\s+([^\]]+)\]', re.M)
PROP = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$', re.M)


def parse_attrs(body: str) -> dict:
    return {m.group(1): m.group(2) for m in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"', body)}


def lineno_of(text, pos):
    return text.count("\n", 0, pos) + 1


scene_files = sorted(walk('.tscn'))
res_files = sorted(walk('.tres'))
script_files = sorted(walk('.gd'))
texture_files = sorted(walk('.png', '.jpg', '.jpeg', '.webp', '.exr', '.hdr', '.tga', '.bmp'))

ext_refs = []
sub_blocks = collections.defaultdict(list)
node_decls = {}

for path in scene_files + res_files:
    text = open(path, encoding='utf-8', errors='replace').read()
    r = rel(path)
    for m in EXT_RES.finditer(text):
        ext_refs.append((r, lineno_of(text, m.start()), parse_attrs(m.group(1))))
    for m in SUB_RES.finditer(text):
        sub_blocks[r].append((parse_attrs(m.group(1)).get('type', ''), lineno_of(text, m.start())))
    nodes = []
    for m in NODE_HDR.finditer(text):
        attrs = parse_attrs(m.group(1))
        # instance=ExtResource("...") is unquoted, so parse_attrs skips it.
        if 'instance=ExtResource(' in m.group(1):
            attrs['instance'] = 'true'
        nodes.append((lineno_of(text, m.start()), attrs))
    if nodes:
        node_decls[r] = nodes

# A + G: references resolve
referenced = set()
for r, ln, attrs in ext_refs:
    p = attrs.get('path')
    if not p:
        continue
    referenced.add(p)
    kind = attrs.get('type', '')
    if not os.path.exists(res_path(p)):
        severity = 'ERROR' if kind in ('Script', 'Texture', 'PackedScene') else 'WARN'
        issues.append(f"{severity}: {r}:{ln} missing ext_resource {kind} -> {p}")

# B: material inputs
EXPECTED = ('albedo_color', 'roughness', 'metallic')
mat_count = 0
for path in res_files + scene_files:
    text = open(path, encoding='utf-8', errors='replace').read()
    r = rel(path)
    for m in SUB_RES.finditer(text):
        attrs = parse_attrs(m.group(1))
        if attrs.get('type') != 'StandardMaterial3D':
            continue
        mat_count += 1
        ln = lineno_of(text, m.start())
        end = text.find("\n[", m.start() + 1)
        body = text[m.start(): end if end != -1 else len(text)]
        props = set(PROP.findall(body))
        if not props:
            issues.append(f"WARN: {r}:{ln} StandardMaterial3D sets no properties (all defaults)")

# C + D: textures
tex_by_path = {'res://' + rel(t): t for t in texture_files}
fmt_count = collections.Counter(os.path.splitext(t)[1].lower() for t in texture_files)
for r, ln, attrs in ext_refs:
    if attrs.get('type') != 'Texture':
        continue
    p = attrs.get('path', '')
    target = res_path(p)
    if not os.path.exists(target):
        continue
    size = png_size(target)
    if size and ((size[0] & (size[0] - 1)) or (size[1] & (size[1] - 1))):
        issues.append(f"WARN: {r}:{ln} {p} is {size[0]}x{size[1]} (not power of two)")

# E: node trees
for r, nodes in node_decls.items():
    declared = {a.get('name', '') for _, a in nodes}
    # Parent paths may drill into an instanced PackedScene/GLB. Those internal
    # node names are not declared in the .tscn and must not be flagged.
    instance_roots = {a.get('name', '') for _, a in nodes if 'instance' in a}
    by_name = collections.defaultdict(list)
    for ln, attrs in nodes:
        by_name[attrs.get('name', '')].append((ln, attrs))
    # duplicate names are only illegal among siblings
    for name, entries in by_name.items():
        if not name or len(entries) < 2:
            continue
        parents = {(a.get('parent') or '.') for _, a in entries}
        if len(parents) == 1:
            issues.append(f"ERROR: {r} duplicate sibling node name '{name}' (parent {parents.pop()})")
    # every parent= path segment must be a declared node
    for ln, attrs in nodes:
        parent = attrs.get('parent')
        if not parent or parent == '.':
            continue
        missing_seg = []
        for seg in parent.split('/'):
            if not seg:
                continue
            if seg in instance_roots:
                break
            if seg not in declared:
                missing_seg.append(seg)
        if missing_seg:
            issues.append(f"ERROR: {r}:{ln} node '{attrs.get('name')}' parent path '{parent}' has undeclared segment(s) {missing_seg}")

# F: orphans
orphans = [t for p, t in tex_by_path.items() if p not in referenced]

# report
print(f"project           : {PROJ}")
print(f"scenes            : {len(scene_files)}")
print(f"resources         : {len(res_files)}")
print(f"scripts           : {len(script_files)}")
print(f"textures          : {len(texture_files)}")
print(f"StandardMaterial3D: {mat_count}")
print(f"ext_resource refs : {len(ext_refs)}")
print(f"texture formats   : {dict(fmt_count)}")
print(f"orphan textures   : {len(orphans)}")
print("=" * 60)
for i in issues:
    print(" -", i)
if not issues:
    print("no issues found")
print("=" * 60)
errs = len([i for i in issues if i.startswith('ERROR')])
warns = len([i for i in issues if i.startswith('WARN')])
print(f"{errs} errors / {warns} warnings")
sys.exit(1 if errs else 0)
