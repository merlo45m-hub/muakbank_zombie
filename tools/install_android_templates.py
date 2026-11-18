#!/usr/bin/env python3
"""Install Godot 4.7 Android export templates WITHOUT downloading the whole .tpz.

The official Godot_v4.7-stable_export_templates.tpz is ~1.28 GB, but an Android
headless export needs only three entries (~232 MB):
    templates/android_debug.apk
    templates/android_release.apk
    templates/version.txt

This reads the ZIP central directory via HTTP Range requests and fetches only
those entries (stdlib only: urllib, struct, zlib). Works on GitHub-hosted
ubuntu-latest runners AND Termux/VPS. Env-overridable for offline testing.

Install target: $GODOT_TEMPLATES_DIR (default ~/.local/share/godot/export_templates/<ver>)

Env:
  GODOT_TEMPLATES_URL     .tpz URL (default 4.7-stable godotengine release)
  GODOT_TEMPLATES_VERSION version dir name (default 4.7.stable)
  GODOT_TEMPLATES_DIR     destination dir override
  GODOT_TEMPLATES_LOCAL   path to a local .tpz (offline test; skips HTTP)
  GODOT_TEMPLATES_FORCE   "1" re-install even if files exist with correct size
"""
import os
import sys
import struct
import zlib
import urllib.request

DEFAULT_URL = ("https://github.com/godotengine/godot/releases/download/"
               "4.7-stable/Godot_v4.7-stable_export_templates.tpz")
URL = os.environ.get("GODOT_TEMPLATES_URL", DEFAULT_URL)
VERSION = os.environ.get("GODOT_TEMPLATES_VERSION", "4.7.stable")
DEST = os.environ.get(
    "GODOT_TEMPLATES_DIR",
    os.path.expanduser("~/.local/share/godot/export_templates/" + VERSION))
LOCAL = os.environ.get("GODOT_TEMPLATES_LOCAL", "")
FORCE = os.environ.get("GODOT_TEMPLATES_FORCE", "0") == "1"
TARGETS = ("templates/android_debug.apk", "templates/android_release.apk",
           "templates/version.txt")
TAIL = 65536


def log(msg):
    print("[templates] " + msg, flush=True)


class Source:
    """Byte-range reader over either a local file or an HTTP resource."""

    def __init__(self):
        self.local = None
        self.size = None
        if LOCAL:
            self.local = open(LOCAL, "rb")
            self.size = os.path.getsize(LOCAL)
            log("source: local %s (%d bytes)" % (LOCAL, self.size))
        else:
            # bytes=0-0 -> Content-Range: bytes 0-0/TOTAL gives the total size.
            data, _, headers = self._http(0, 0)
            cr = headers.get("Content-Range", "")
            if "/" not in cr:
                raise RuntimeError("server did not return Content-Range (range unsupported?): " + cr)
            self.size = int(cr.rsplit("/", 1)[1])
            log("source: %s (%d bytes)" % (URL, self.size))

    def _http(self, start, end):
        req = urllib.request.Request(
            URL, headers={"Range": "bytes=%d-%d" % (start, end),
                          "User-Agent": "muakbank-template-installer/1.0"})
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.read(), r.status, r.headers

    def read(self, start, end):  # inclusive
        if self.local:
            self.local.seek(start)
            return self.local.read(end - start + 1)
        data, status, _ = self._http(start, end)
        if status not in (200, 206):
            raise RuntimeError("range %d-%d returned HTTP %d" % (start, end, status))
        return data


def parse_central_directory(src):
    """Return {name: (method, crc, csize, usize, local_header_offset)}."""
    tail_start = max(0, src.size - TAIL)
    tail = src.read(tail_start, src.size - 1)
    eocd = tail.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError("EOCD not found in tail")
    cd_size = struct.unpack_from("<I", tail, eocd + 12)[0]
    cd_off = struct.unpack_from("<I", tail, eocd + 16)[0]
    log("central directory: offset=%d size=%d" % (cd_off, cd_size))
    if cd_off + cd_size > src.size:
        raise RuntimeError("central directory beyond file size")
    if cd_off >= tail_start:
        cd = tail[cd_off - tail_start: cd_off - tail_start + cd_size]
    else:
        cd = src.read(cd_off, cd_off + cd_size - 1)
    entries = {}
    pos = 0
    while pos + 46 <= len(cd) and cd[pos:pos + 4] == b"PK\x01\x02":
        method = struct.unpack_from("<H", cd, pos + 10)[0]
        crc = struct.unpack_from("<I", cd, pos + 16)[0]
        csize = struct.unpack_from("<I", cd, pos + 20)[0]
        usize = struct.unpack_from("<I", cd, pos + 24)[0]
        fnlen = struct.unpack_from("<H", cd, pos + 28)[0]
        exlen = struct.unpack_from("<H", cd, pos + 30)[0]
        cmlen = struct.unpack_from("<H", cd, pos + 32)[0]
        lho = struct.unpack_from("<I", cd, pos + 42)[0]
        name = cd[pos + 46: pos + 46 + fnlen].decode("utf-8", "replace")
        entries[name] = (method, crc, csize, usize, lho)
        pos += 46 + fnlen + exlen + cmlen
    log("parsed %d central-directory entries" % len(entries))
    return entries


def extract_entry(src, name, meta, out_path):
    method, crc, csize, usize, lho = meta
    hdr = src.read(lho, lho + 29)
    if hdr[:4] != b"PK\x03\x04":
        raise RuntimeError("bad local header for " + name)
    fnlen = struct.unpack_from("<H", hdr, 26)[0]
    exlen = struct.unpack_from("<H", hdr, 28)[0]
    data_start = lho + 30 + fnlen + exlen
    data = src.read(data_start, data_start + csize - 1)
    if len(data) != csize:
        raise RuntimeError("short read for %s (%d/%d)" % (name, len(data), csize))
    if method == 0:
        plain = data
    elif method == 8:
        plain = zlib.decompress(data, -15)
    else:
        raise RuntimeError("unsupported zip compression method %d" % method)
    if len(plain) != usize:
        raise RuntimeError("size mismatch for %s (%d/%d)" % (name, len(plain), usize))
    if zlib.crc32(plain) & 0xFFFFFFFF != crc:
        raise RuntimeError("CRC mismatch for " + name)
    tmp = out_path + ".part"
    with open(tmp, "wb") as f:
        f.write(plain)
    os.replace(tmp, out_path)
    log("installed %s (%d bytes, crc OK)" % (os.path.basename(name), usize))


def main():
    os.makedirs(DEST, exist_ok=True)
    src = Source()
    entries = parse_central_directory(src)
    missing = [t for t in TARGETS if t not in entries]
    if missing:
        raise RuntimeError("missing entries in .tpz: " + ", ".join(missing))
    total = 0
    for name in TARGETS:
        meta = entries[name]
        out = os.path.join(DEST, os.path.basename(name))
        need = FORCE or not os.path.isfile(out) or os.path.getsize(out) != meta[3]
        if need:
            extract_entry(src, name, meta, out)
            total += meta[2]
        else:
            log("already present: %s" % os.path.basename(name))
    # Godot checks version.txt matches the engine's version string.
    ver = open(os.path.join(DEST, "version.txt"), "r", encoding="utf-8").read().strip()
    log("version.txt = %r" % ver)
    for name in TARGETS:
        p = os.path.join(DEST, os.path.basename(name))
        if not os.path.isfile(p):
            raise RuntimeError("post-check missing " + p)
    log("bytes fetched this run: %d" % total)
    log("OK templates ready in " + DEST)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log("ERROR " + str(e))
        sys.exit(1)
