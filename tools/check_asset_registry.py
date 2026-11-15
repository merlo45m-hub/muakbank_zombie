"""Pre-build asset registry check (Muakbank Zombie).

Parses the project directory and verifies EVERY referenced 3D model path. Three
reference classes:
  * static  -> exact file must exist (fatal if missing).
  * dynamic -> contains a placeholder (%s, ${...}, <...>); expanded to a glob,
               must match >=1 on-disk file. Verified expansion count reported.
  * exception -> documented dev-probe subjects (tools/asset_registry_exceptions.json)
               with an explicit reason; counted, never silently ignored.

Also flags orphan .import sidecars whose source is missing. Writes
assets/data/asset_registry.json. Stdlib only. Exit 0 = intact, 1 = broken.

On failure emits a standardized telemetry webhook (type/severity/name/value/ts)
via tools/asset_registry_notify.py.
Usage: python3 tools/check_asset_registry.py [--no-notify]
"""
from __future__ import annotations
import glob, hashlib, json, os, re, subprocess, sys
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "assets", "data", "asset_registry.json")
NOTIFY = os.path.join(REPO, "tools", "asset_registry_notify.py")
EXC = os.path.join(REPO, "tools", "asset_registry_exceptions.json")
SKIP_DIRS = {".git", ".godot", "build", "node_modules", "__pycache__", "addons"}
TEXT_EXT = (".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".md", ".py", ".sh")
REF = re.compile(r'res://[^\s"\'\)\],;]+?\.(?:glb|gltf|obj|fbx|dae|blend)\b', re.IGNORECASE)
PLACEHOLDER = re.compile(r'%s|\$\{[^}]*\}|<[^>]*>')


def utcnow():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def scan_refs():
    refs = []
    derived = {os.path.abspath(OUT)}
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fn in files:
            if not fn.endswith(TEXT_EXT):
                continue
            p = os.path.join(root, fn)
            if os.path.abspath(p) in derived:
                continue
            # Skip the generated registry itself: it embeds res:// model paths as
            # DATA, and re-scanning it would make the checker self-poisoning.
            try:
                text = open(p, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for m in REF.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                refs.append({"source": os.path.relpath(p, REPO), "line": line,
                             "ref": m.group(0)})
    return refs


def load_exceptions():
    if not os.path.exists(EXC):
        return {}
    try:
        d = json.load(open(EXC, encoding="utf-8"))
        return {e["ref"]: e["reason"] for e in d.get("exceptions", [])}
    except (json.JSONDecodeError, KeyError, OSError):
        return {}


def resolve_static(rel):
    if ".." in rel.split("/"):
        return False, "path traversal (..)"
    if "\\" in rel:
        return False, "backslash separator"
    if rel.startswith("/"):
        return False, "absolute-looking res path"
    cur = REPO
    for part in rel.split("/"):
        if not os.path.isdir(cur):
            return False, "directory missing mid-path"
        try:
            entries = os.listdir(cur)
        except OSError:
            return False, "unreadable dir"
        if part not in entries:
            low = {e.lower(): e for e in entries}
            if part.lower() in low:
                return False, "case mismatch: %s vs %s" % (part, low[part.lower()])
            return False, "missing component: %s" % part
        cur = os.path.join(cur, part)
    if not os.path.isfile(cur):
        return False, "not a file"
    return True, "ok"


def expand_dynamic(raw):
    rel = raw[len("res://"):]
    pat = PLACEHOLDER.sub("*", rel)
    matches = sorted(glob.glob(os.path.join(REPO, pat)))
    return [os.path.relpath(m, REPO) for m in matches], pat


def main() -> int:
    no_notify = "--no-notify" in sys.argv
    refs = scan_refs()
    exceptions = load_exceptions()
    seen = {}
    for r in refs:
        seen.setdefault(r["ref"], []).append(r)

    static_ok, dynamic_ok, broken, excepted = [], [], [], []
    for raw, occ in sorted(seen.items()):
        srcs = ["%s:%d" % (o["source"], o["line"]) for o in occ[:6]]
        base = {"ref": raw, "count": len(occ), "sources": srcs}
        if raw in exceptions:
            excepted.append({**base, "reason": exceptions[raw]})
            continue
        if PLACEHOLDER.search(raw):
            matches, pat = expand_dynamic(raw)
            rec = {**base, "kind": "dynamic", "pattern": pat, "matches": len(matches),
                   "sample": matches[:4]}
            if matches:
                dynamic_ok.append(rec)
            else:
                broken.append({**rec, "reason": "template matched 0 files"})
            continue
        ok, reason = resolve_static(raw[len("res://"):])
        rec = {**base, "kind": "static", "reason": reason}
        (static_ok if ok else broken).append(rec)

    orphans = []
    for root, dirs, files in os.walk(os.path.join(REPO, "assets")):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fn in files:
            if fn.endswith(".import"):
                src = os.path.join(root, fn[:-7])
                if not os.path.exists(src):
                    orphans.append(os.path.relpath(src, REPO))
    sidecar_missing = []
    on_disk = []
    for root, dirs, files in os.walk(os.path.join(REPO, "assets")):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fn in files:
            if fn.lower().endswith(".glb"):
                ap = os.path.join(root, fn)
                on_disk.append(os.path.relpath(ap, REPO))
                if not os.path.exists(ap + ".import"):
                    sidecar_missing.append(os.path.relpath(ap, REPO))

    # orphans are stale .import metadata (source asset never committed) — a
    # WARNING, not a broken model reference. They are reported explicitly so
    # nothing is hidden, but they do not fail the pre-build gate. Fatal classes:
    # broken refs, and on-disk .glb without its .import sidecar.
    ok = not broken and not sidecar_missing
    registry = {
        "generated_at": utcnow(), "generator": "tools/check_asset_registry.py",
        "unique_refs": len(seen), "total_ref_occurrences": len(refs),
        "static_ok": len(static_ok), "dynamic_ok": len(dynamic_ok),
        "excepted": len(excepted), "broken": broken,
        "exceptions": excepted, "dynamic": dynamic_ok,
        "on_disk_glb": len(on_disk), "missing_import_sidecars": sidecar_missing,
        "orphan_imports": orphans,
        "sha256": hashlib.sha256(json.dumps(sorted(seen.keys())).encode()).hexdigest()[:16],
        "ok": ok,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False, sort_keys=False)
    print("ASSET_REGISTRY_REFS", len(seen), "occurrences", len(refs))
    print("ASSET_REGISTRY_STATIC_OK", len(static_ok), "DYNAMIC_OK", len(dynamic_ok),
          "EXCEPTED", len(excepted))
    print("ASSET_REGISTRY_ON_DISK_GLB", len(on_disk))
    print("ASSET_REGISTRY_BROKEN", len(broken), broken[:3])
    print("ASSET_REGISTRY_SIDECARS_MISSING", len(sidecar_missing))
    print("ASSET_REGISTRY_ORPHAN_IMPORTS", len(orphans), orphans[:3])
    print("ASSET_REGISTRY_OK", ok)
    if not no_notify:
        sev = "info" if ok else "critical"
        val = {"refs": len(seen), "static_ok": len(static_ok), "broken": len(broken),
               "orphans": len(orphans), "details": broken[:5]}
        try:
            subprocess.run([sys.executable, NOTIFY, "--severity", sev,
                            "--name", "asset_registry_check",
                            "--value", json.dumps(val)], timeout=20, capture_output=True)
        except Exception as e:
            print("ASSET_REGISTRY_NOTIFY_SKIPPED", type(e).__name__, str(e)[:80])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
