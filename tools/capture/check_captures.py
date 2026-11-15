#!/usr/bin/env python3
"""Issue #23 — validate captured PNGs (deterministic, no device sign-off).
Checks: exists, non-trivial size, exact 1600x900, luminance variance > floor
(rejects blank/magenta frames). Writes capture_report.json.
Usage: python3 tools/capture/check_captures.py <out_dir> [manifest]
"""
import json, os, sys
from PIL import Image, ImageStat

MIN_BYTES = 8000
# A dark night/fog game legitimately has LOW luminance variance (measured 4.1-6.0
# on real 1600x900 renders). A flat stddev floor of 8 rejected valid scenes.
# Distinct quantized colours is the robust "real render vs blank/magenta frame"
# signal: a solid-colour frame has 1, our darkest real scene has 24.
MIN_LUMA_STDDEV = 1.0      # rejects a genuinely flat/uniform frame only
MIN_DISTINCT_COLORS = 16
EXPECTED = (1600, 900)

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    manifest = sys.argv[2] if len(sys.argv) > 2 else None
    names = []
    if manifest and os.path.isfile(manifest):
        for line in open(manifest, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) >= 2:
                names.append(parts[1].strip())
    if not names:
        names = [f[:-4] for f in os.listdir(out) if f.endswith(".png")]
    results = []
    for name in names:
        p = os.path.join(out, name + ".png")
        rec = {"name": name, "path": p}
        if not os.path.isfile(p):
            rec["pass"] = False; rec["reason"] = "missing"
            results.append(rec); continue
        size = os.path.getsize(p)
        try:
            im_rgb = Image.open(p).convert("RGB")
            im = im_rgb.convert("L")
            stat = ImageStat.Stat(im)
            variance = stat.stddev[0]
            dims = im.size
            q = im_rgb.quantize(colors=64)
            distinct = len(set(q.get_flattened_data())) if hasattr(q, "get_flattened_data") else len(set(q.getdata()))
        except Exception as e:
            rec["pass"] = False; rec["reason"] = str(e)[:100]
            results.append(rec); continue
        rec.update({"bytes": size, "dims": list(dims),
                    "luma_stddev": round(variance, 2),
                    "distinct_colors": distinct})
        ok = (size >= MIN_BYTES and variance >= MIN_LUMA_STDDEV
              and distinct >= MIN_DISTINCT_COLORS and dims == EXPECTED)
        rec["pass"] = bool(ok)
        if not ok:
            rec["reason"] = "blank, flat, wrong-size, or undersized"
        results.append(rec)
    passed = sum(1 for r in results if r.get("pass"))
    report = {
        "renderer": "gl_compatibility/llvmpipe",
        "mobile_renderer_unverified": True,
        "expected_dims": list(EXPECTED),
        "total": len(results), "passed": passed,
        "failed": len(results) - passed, "results": results,
    }
    rp = os.path.join(out, "capture_report.json")
    with open(rp, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    for r in results:
        print("CAPTURE %s pass=%s %s" % (r["name"], r.get("pass"), r.get("reason", "")))
    print("CAPTURE_SUMMARY passed=%d/%d" % (passed, len(results)))
    # Advisory-only when no manifest was supplied (single-scene smoke test).
    return 0 if (passed == len(results) or not manifest) else 1

if __name__ == "__main__":
    sys.exit(main())
