#!/usr/bin/env python3
"""Asset integrity gate for Muakbank Zombie shipments (stdlib only).

Verifies every shipped .glb:
  * has its .glb.import sidecar,
  * every GLB images[].uri texture resolves (relative to the glb file),
  * every resolved shipped texture is power-of-two and <= 2048 px,
  * contract bounds from tools/glb_asset_contract.json still match
    (delegated to tools/verify_glb_assets.py via subprocess; its parser is
    NOT duplicated here).

Usage:
  python3 tools/verify_asset_integrity.py --project-dir <dir>
  python3 tools/verify_asset_integrity.py --self-test   # negative control in /tmp

Exit: 0 PASS, 1 FAIL.
Emits:  ASSET_INTEGRITY: PASS (n glb)
        ASSET_INTEGRITY: FAIL file:line reason
"""
import glob
import json
import os
import struct
import shutil
import subprocess
import sys
import tempfile

CHECK_LIMIT = 2048


def _fail(fpath, line, reason):
    return "ASSET_INTEGRITY: FAIL %s:%d %s" % (fpath, line, reason)


def _glb_json(path):
    """Return the GLB's JSON chunk dict, or (None, error_string)."""
    try:
        with open(path, "rb") as fh:
            header = fh.read(12)
            if len(header) < 12 or header[:4] != b"glTF":
                return None, "not a glTF container"
            ln, ctype = struct.unpack("<I4s", fh.read(8))
            if ctype != b"JSON":
                return None, "first chunk is not JSON"
            return json.loads(fh.read(ln).decode("utf-8")), None
    except Exception as exc:  # noqa: BLE001
        return None, "unreadable: %s" % exc


def _png_dims(path):
    """Return (w, h) from a PNG header, or None if not decodable."""
    try:
        with open(path, "rb") as fh:
            sig = fh.read(8)
            if sig != b"\x89PNG\r\n\x1a\n":
                return None
            fh.read(4)  # IHDR length
            if fh.read(4) != b"IHDR":
                return None
            w, h = struct.unpack(">II", fh.read(8))
            return w, h
    except OSError:
        return None


def _is_pot(v):
    return v > 0 and (v & (v - 1)) == 0


def _scan_glbs(project_dir):
    """Sorted list of shipped .glb paths (excludes .godot import cache)."""
    out = []
    for root, dirs, files in os.walk(project_dir):
        dirs[:] = [d for d in dirs if d != ".godot"]
        for name in files:
            if name.endswith(".glb"):
                out.append(os.path.join(root, name))
    return sorted(out)


def check_glb(glb_path, project_dir):
    """Return list of (line, reason) problems for a single glb."""
    problems = []
    sidecar = glb_path + ".import"
    if not os.path.isfile(sidecar):
        problems.append((0, "missing .glb.import sidecar"))
        return problems  # cannot trust the asset further

    js, err = _glb_json(glb_path)
    if err:
        problems.append((0, "glb parse error: %s" % err))
        return problems

    glb_dir = os.path.dirname(glb_path)
    for image in js.get("images", []) or []:
        uri = image.get("uri")
        if not uri or uri.startswith("data:"):
            continue
        tex_path = os.path.join(glb_dir, uri)
        if not os.path.isfile(tex_path):
            problems.append((0, "images[].uri %s unresolved" % uri))
            continue
        dims = _png_dims(tex_path)
        if dims is None:
            # non-PNG texture: presence verified, dimensions not checked
            continue
        w, h = dims
        if not _is_pot(w) or not _is_pot(h):
            problems.append((0, "images[].uri %s not power-of-two (%dx%d)" % (uri, w, h)))
        if w > CHECK_LIMIT or h > CHECK_LIMIT:
            problems.append((0, "images[].uri %s exceeds %d px (%dx%d)" % (uri, CHECK_LIMIT, w, h)))
    return problems


def check_contract(project_dir):
    """Return list of (line, reason) problems from the contract gate."""
    problems = []
    verifier = os.path.join(project_dir, "tools", "verify_glb_assets.py")
    if not os.path.isfile(verifier):
        return [(0, "contract verifier missing: tools/verify_glb_assets.py")]
    try:
        proc = subprocess.run(
            [sys.executable, verifier, project_dir],
            capture_output=True, text=True,
        )
    except Exception as exc:  # noqa: BLE001
        return [(0, "contract verifier failed to run: %s" % exc)]
    if proc.returncode == 0:
        return []
    for line in (proc.stdout + proc.stderr).splitlines():
        line = line.strip()
        if line.startswith("VIOLATION"):
            problems.append((0, line[len("VIOLATION"):].strip()))
        elif line.startswith("GLB_CONTRACT: FAIL"):
            problems.append((0, line))
    if not problems and proc.returncode != 0:
        problems.append((0, "contract verifier exited rc=%d" % proc.returncode))
    return problems


def run_self_test():
    """Negative control: build fixtures in /tmp outside the scan tree.

    Builds one project tree with every failure mode plus a clean fixture and a
    .godot-cached glb that must be excluded. Runs the gate once and asserts
    each expected failure is detected while the clean and excluded fixtures are
    not flagged.
    """
    tmp = tempfile.mkdtemp(prefix="asset_integrity_selftest_")
    results = []
    try:
        assets = os.path.join(tmp, "assets")
        os.makedirs(os.path.join(assets, "Textures"))
        os.makedirs(os.path.join(tmp, ".godot", "imported"), exist_ok=True)
        os.makedirs(os.path.join(tmp, "tools"), exist_ok=True)
        # Shim the contract verifier with an empty manifest so the contract
        # sub-check passes on the self-test tree.
        shutil.copy(
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "verify_glb_assets.py"),
            os.path.join(tmp, "tools", "verify_glb_assets.py"),
        )
        with open(os.path.join(tmp, "tools", "glb_asset_contract.json"), "w") as fh:
            fh.write("[]\n")

        def write_glb(name, images, under_godot=False):
            import zlib
            base = os.path.join(tmp, ".godot", "imported") if under_godot else assets
            gtf = {"images": images, "materials": []}
            payload = json.dumps(gtf).encode("utf-8")
            chunk = struct.pack("<I", len(payload)) + b"JSON" + payload
            chunk += b" " * ((-len(chunk)) % 4)
            with open(os.path.join(base, name), "wb") as fh:
                fh.write(b"glTF" + struct.pack("<II", 2, 0) + chunk)

        def write_png(path, w, h):
            import zlib
            raw = b""
            for _ in range(h):
                raw += b"\x00" + b"\x00\x00\x00" * w
            compressed = zlib.compress(raw)
            ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
            ihdr_chunk = struct.pack(">I", len(ihdr)) + b"IHDR" + ihdr
            ihdr_crc = struct.pack(">I", zlib.crc32(b"IHDR" + ihdr) & 0xFFFFFFFF)
            idat_chunk = struct.pack(">I", len(compressed)) + b"IDAT" + compressed
            idat_crc = struct.pack(">I", zlib.crc32(b"IDAT" + compressed) & 0xFFFFFFFF)
            iend_chunk = struct.pack(">I", 0) + b"IEND"
            iend_crc = struct.pack(">I", zlib.crc32(b"IEND") & 0xFFFFFFFF)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as fh:
                fh.write(b"\x89PNG\r\n\x1a\n" + ihdr_chunk + ihdr_crc + idat_chunk + idat_crc + iend_chunk + iend_crc)

        def sidecar(glb_name, under_godot=False):
            base = os.path.join(tmp, ".godot", "imported") if under_godot else assets
            open(os.path.join(base, glb_name + ".import"), "w").close()

        write_glb("clean.glb", [{"uri": "Textures/a.png"}])
        write_png(os.path.join(assets, "Textures", "a.png"), 128, 128)
        sidecar("clean.glb")

        write_glb("no_sidecar.glb", [])  # intentionally no sidecar

        write_glb("unresolved.glb", [{"uri": "Textures/ghost.png"}])  # sidecar, no texture
        sidecar("unresolved.glb")

        write_glb("notpot.glb", [{"uri": "Textures/b.png"}])
        write_png(os.path.join(assets, "Textures", "b.png"), 100, 128)
        sidecar("notpot.glb")

        write_glb("big.glb", [{"uri": "Textures/c.png"}])
        write_png(os.path.join(assets, "Textures", "c.png"), 4096, 128)
        sidecar("big.glb")

        write_glb("excluded.glb", [], under_godot=True)  # in .godot cache -> not scanned

        problems, rc = _run_once(tmp, collect=True)
        reported = chr(10).join(problems)

        def flagged(name):
            return any(name in p for p in problems)

        checks = [
            ("clean fixture not flagged", not flagged("clean.glb")),
            (".godot excluded not scanned", not flagged("excluded.glb")),
            ("no_sidecar flagged", flagged("no_sidecar.glb") and "missing .glb.import sidecar" in reported),
            ("unresolved uri flagged", flagged("unresolved.glb") and "unresolved" in reported),
            ("non-pot flagged", flagged("notpot.glb") and "not power-of-two" in reported),
            ("over-2048 flagged", flagged("big.glb") and "exceeds 2048" in reported),
        ]
        for label, ok in checks:
            results.append((label, ok))
            print("SELF-TEST %s: %s" % (label, "PASS" if ok else "FAIL"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    all_pass = all(ok for _, ok in results)
    print("ASSET_INTEGRITY_SELF_TEST: %s" % ("PASS" if all_pass else "FAIL"))
    return 0 if all_pass else 1


def _run_once(project_dir, collect=False):
    problems = []
    glbs = _scan_glbs(project_dir)
    for glb in glbs:
        rel = os.path.relpath(glb, project_dir)
        for line, reason in check_glb(glb, project_dir):
            problems.append(_fail(rel, line, reason))
    for line, reason in check_contract(project_dir):
        problems.append(_fail("tools/glb_asset_contract.json", line, reason))
    if collect:
        return problems, (1 if problems else 0)
    for p in problems:
        print(p)
    if problems:
        print("ASSET_INTEGRITY: FAIL (%d problems, %d glb)" % (len(problems), len(glbs)))
        return 1
    print("ASSET_INTEGRITY: PASS (%d glb)" % len(glbs))
    return 0


def main(argv):
    project_dir = "."
    self_test = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--project-dir" and i + 1 < len(argv):
            project_dir = argv[i + 1]
            i += 2
        elif a == "--self-test":
            self_test = True
            i += 1
        else:
            print("ASSET_INTEGRITY: FAIL 0 unknown argument: %s" % a)
            return 1
    if self_test:
        return run_self_test()
    if not os.path.isdir(project_dir):
        print("ASSET_INTEGRITY: FAIL 0 project-dir not found: %s" % project_dir)
        return 1
    return _run_once(project_dir)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
