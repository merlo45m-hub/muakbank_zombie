#!/usr/bin/env python3
"""check_gdscript_typing.py — static guard for the GDScript type-mismatch
failures actually observed in this repo (2026-11-15).

Rules (each maps to a real parse/runtime error hit in this project):
  T1  `var x := <recv>.<method>()` where `recv` is a DYNAMIC receiver — a
      variable assigned from get_node_or_null / get_first_node_in_group / a
      Node-typed autoload lookup. GDScript cannot infer that return type.
      Fix: explicit annotation, e.g. `var d: Dictionary = wp.serialize()`.
      Statically-typed singletons (ResourceLoader, Engine, ...) are NOT flagged.
  T2  plain Array literal assigned to a TYPED array member
      (`@export var edges: Array[Dictionary] = []` then `c.edges = rows`).
      Fix: `var t: Array[Dictionary] = []; t.assign(rows); c.edges = t`.
  T3  `:=` on a bare-identifier string concatenation (Variant loop key).
      Fix: `var s: String = "_on_" + key`.

Usage: python3 tools/check_gdscript_typing.py [root]   (default .)
Exit 0 = clean, 1 = findings. Prints `file:line: RULE message` per finding.
"""
import os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
SKIP_DIRS = {".godot", ".git", "addons", "build", "node_modules", ".hermes", "tmp"}
DYNAMIC_RECV_SRC = re.compile(
    r"get_node_or_null|get_first_node_in_group|get_node\(|find_child\(|"
    r"instantiate\(\)|\.get\(")
STATIC_RECV = {"ResourceLoader", "Engine", "OS", "JSON", "Time", "FileAccess",
               "DirAccess", "ClassDB", "ProjectSettings", "Input", "AudioServer",
               "RenderingServer", "PhysicsServer3D", "get_tree", "get_root"}
TYPED_ARRAY_DECL = re.compile(r"(?:@export\s+)?var\s+(\w+)\s*:\s*Array\[[^\]]+\]")

def scan(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    typed_members, dynamic_recvs = set(), set()
    for ln in lines:
        m = TYPED_ARRAY_DECL.search(ln)
        if m:
            typed_members.add(m.group(1))
        m2 = re.search(r"\bvar\s+(\w+)\s*(?::=|=|:)\s*(.+)", ln)
        if m2 and DYNAMIC_RECV_SRC.search(m2.group(2)):
            dynamic_recvs.add(m2.group(1))
    out = []
    for i, ln in enumerate(lines, 1):
        code = ln.split("#", 1)[0]
        m = re.search(r"\bvar\s+\w+\s*:=\s*(.+)", code)
        if m:
            rhs = m.group(1).strip()
            has_cast = " as " in rhs
            recv = re.match(r"(\w+)\s*\.", rhs)
            if recv and not has_cast and recv.group(1) in dynamic_recvs and recv.group(1) not in STATIC_RECV:
                out.append((i, "T1", "explicit type needed on dynamic-receiver call"))
            elif "+" in rhs and not has_cast and not re.search(r"\d|\"|\'|:", rhs) and re.match(r"\w+\s*\+\s*\w+", rhs):
                out.append((i, "T3", "explicit : String on Variant concatenation"))
        m2 = re.match(r"\s*\w+\.(\w+)\s*=\s*(\w+)\s*$", code)
        if m2 and m2.group(1) in typed_members:
            rhs_name = m2.group(2)
            if any(re.search(r"\bvar\s+" + re.escape(rhs_name) + r"\s*(?:=|:)\s*\[", l)
                   and "Array[" not in l for l in lines):
                out.append((i, "T2", "use .assign() into a typed Array temp"))
    return out

def main():
    # --changed: scope the gate to .gd files touched vs HEAD (CI/pre-commit).
    # Legacy probe scripts keep their existing style; new work must be explicit.
    changed_only = "--changed" in sys.argv
    base = None
    for a in sys.argv[1:]:
        if a.startswith("--base="):
            base = a.split("=", 1)[1]
    args = [a for a in sys.argv[1:]
            if a != "--changed" and not a.startswith("--base=")]
    root = args[0] if args else "."
    targets = None
    if changed_only:
        import subprocess
        cmds = [["git", "diff", "--name-only", "--diff-filter=ACM", "HEAD"],
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM", "HEAD"]]
        if base:
            cmds.append(["git", "diff", "--name-only", "--diff-filter=ACM",
                         base + "...HEAD"])
        names = set()
        for c in cmds:
            r = subprocess.run(c, cwd=root, capture_output=True, text=True)
            names.update(l.strip() for l in r.stdout.splitlines()
                         if l.strip().endswith(".gd"))
        r2 = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"],
                            cwd=root, capture_output=True, text=True)
        names.update(l.strip() for l in r2.stdout.splitlines()
                     if l.strip().endswith(".gd"))
        targets = names
        print("TYPING_CHANGED_FILES=%d" % len(targets))
    findings = []
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in SKIP_DIRS and not d.startswith(".")]
        for f in fn:
            if not f.endswith(".gd"):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, root)
            if targets is not None and rel not in targets:
                continue
            for i, rule, msg in scan(p):
                findings.append("%s:%d: %s %s" % (p, i, rule, msg))
    for f in findings:
        print(f)
    print("TYPING_FINDINGS=%d" % len(findings))
    return 1 if findings else 0

if __name__ == "__main__":
    sys.exit(main())
