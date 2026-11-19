#!/usr/bin/env python3
"""Static + engine companion for verify_scene_resolves.gd:
scan every .tscn/.tres for ExtResource/SubResource ids referenced but never
declared in the same file (the class that parses to null at load and silently
removes a whole scene from the game). Exit 2 with named offenders."""
import re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
bad = []
for f in ROOT.rglob("*.tscn"):
    if "/.godot/" in str(f) or "/.git/" in str(f):
        continue
    s = f.read_text(encoding="utf-8", errors="replace")
    ext_ids = set(re.findall(r'\[ext_resource[^\n]*id="([^"]+)"', s))
    sub_ids = set(re.findall(r'\[sub_resource[^\n]*id="([^"]+)"', s))
    erefs = set(re.findall(r'ExtResource\("([^"]+)"\)', s))
    srefs = set(re.findall(r'SubResource\("([^"]+)"\)', s))
    d = (erefs - ext_ids) | (srefs - sub_ids)
    if d:
        bad.append((str(f.relative_to(ROOT)), sorted(d)))
for f in ROOT.rglob("*.tres"):
    if "/.godot/" in str(f):
        continue
    s = f.read_text(encoding="utf-8", errors="replace")
    ext_ids = set(re.findall(r'\[ext_resource[^\n]*id="([^"]+)"', s))
    erefs = set(re.findall(r'ExtResource\("([^"]+)"\)', s))
    d = erefs - ext_ids
    if d:
        bad.append((str(f.relative_to(ROOT)), sorted(d)))
# self-exclusion: report file is data, not source (pre-build-gates rule)
if bad:
    for path, ids in bad[:20]:
        print("  DANGLING %s: %s" % (path, ",".join(ids)))
    print("REF_SCAN: FAIL (%d files)" % len(bad))
    sys.exit(2)
print("REF_SCAN: PASS")
