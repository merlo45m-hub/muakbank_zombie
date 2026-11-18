#!/usr/bin/env python3
"""check_gdscript_strict.py — static analysis pass for GDScript strict typing.

Issue #32: maps and prioritizes the type fixes needed to enable strict typing
project-wide. Reports (per file) untyped declarations, inferred declarations
(:=), functions missing explicit return types, and untyped parameters.

Stdlib only. Usage:
  python3 tools/check_gdscript_strict.py .            # full report
  python3 tools/check_gdscript_strict.py --json .    # machine JSON
"""
from __future__ import annotations
import json, os, re, sys

SKIP = {".godot", ".git", "addons", "build", "__pycache__"}
# func declarations; capture name + full param list + optional return type
FUNC = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\(([^)]*)\)\s*(->\s*[\w\[\],\. ]+)?\s*:')
# var/const declarations at statement level
VAR = re.compile(r'^\s*(?:(?:@\w+(?:\([^)]*\))?)\s+)?(var|const)\s+(\w+)\s*(?::=?=|:(?:[A-Za-z_][\w\[\],\. ]*)?\s*=|=)')
INFER = re.compile(r'^\s*var\s+\w+\s*:=')
UNTYPED_VAR = re.compile(r'^\s*(?:var|const)\s+\w+\s*=')


def scan(root):
    rows = []
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in SKIP]
        for f in fn:
            if not f.endswith(".gd"):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, root)
            c = {"file": rel, "funcs": 0, "no_ret": [], "untyped_params": [],
                 "inferred": 0, "untyped_var": 0, "lines": 0}
            for i, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                c["lines"] += 1
                if INFER.match(line):
                    c["inferred"] += 1
                elif UNTYPED_VAR.match(line):
                    c["untyped_var"] += 1
                m = FUNC.match(line)
                if m:
                    c["funcs"] += 1
                    name, params, ret = m.group(1), m.group(2), m.group(3)
                    if not ret or not ret.strip().lstrip("->").strip():
                        c["no_ret"].append(i)
                    for prm in params.split(","):
                        prm = prm.strip()
                        if not prm:
                            continue
                        if ":" not in prm and "=" not in prm[:prm.find(" ") if " " in prm else len(prm)]:
                            c["untyped_params"].append(i)
            c["score"] = (len(c["no_ret"]) * 3 + len(c["untyped_params"]) * 2
                          + c["inferred"] + c["untyped_var"])
            rows.append(c)
    return rows


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else "."
    as_json = "--json" in sys.argv
    rows = scan(root)
    rows.sort(key=lambda r: (-r["score"], r["file"]))
    totals = {
        "files": len(rows),
        "funcs": sum(r["funcs"] for r in rows),
        "missing_return_types": sum(len(r["no_ret"]) for r in rows),
        "untyped_params": sum(len(r["untyped_params"]) for r in rows),
        "inferred_declarations": sum(r["inferred"] for r in rows),
        "untyped_declarations": sum(r["untyped_var"] for r in rows),
    }
    if as_json:
        print(json.dumps({"totals": totals, "files": rows}, indent=2))
        return 0
    if "--gate" in sys.argv:
        # Enforceable gate: explicit return types and typed params are mandatory
        # (both are currently 0). `:=` and untyped `var` are reported, not gated,
        # because they are statically-inferred and tracked as a refactor backlog.
        n_ret = totals["missing_return_types"]
        n_par = totals["untyped_params"]
        print("STRICT_GATE missing_return_types=%d untyped_params=%d" % (n_ret, n_par))
        if n_ret or n_par:
            for r in rows:
                if r["no_ret"] or r["untyped_params"]:
                    print("  FIX", r["file"], "no_ret_lines", r["no_ret"],
                          "untyped_param_lines", r["untyped_params"])
            return 1
        return 0
    print("STRICT_TOTALS", json.dumps(totals))
    print("TOP_FILES_BY_REFACTOR_SCORE")
    for r in rows[:20]:
        print("  %6d  %s  no_ret=%d params=%d :=%d untyped=%d" % (
            r["score"], r["file"], len(r["no_ret"]), len(r["untyped_params"]),
            r["inferred"], r["untyped_var"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
