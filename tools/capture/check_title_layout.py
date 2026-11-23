#!/usr/bin/env python3
"""Issue #63 I2 — fail-closed title layout geometry gate.

Reads the JSON emitted by tools/capture/title_layout_probe.gd and asserts:
  1. viewport is exactly 1600x900,
  2. every named Control is inside the 48px safe area,
  3. TitleLabel / ButtonsBox / FooterBrand have zero positive-area overlap,
  4. the button stack fits its container and every button is >= 400x86.

Writes <input dir>/layout_report.json with explicit violation lists.
"""
from __future__ import annotations

import json
import os
import sys

REQUIRED = ("TitleLabel", "ButtonsBox", "FooterBrand")
EXPECTED_DIMS = (1600, 900)
EXPECTED_BUTTONS = 5
MIN_BUTTON_W = 400
MIN_BUTTON_H = 86
TOLERANCE = 1.0


def rect_of(raw: object) -> tuple[float, float, float, float]:
    if not isinstance(raw, dict):
        raise ValueError("rect is not an object")
    return (
        float(raw["x"]),
        float(raw["y"]),
        float(raw["w"]),
        float(raw["h"]),
    )


def overlaps(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ix = min(ax + aw, bx + bw) - max(ax, bx)
    iy = min(ay + ah, by + bh) - max(ay, by)
    return ix > TOLERANCE and iy > TOLERANCE


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else ""
    if not path or not os.path.isfile(path):
        print("LAYOUT_FAIL missing input: %s" % path)
        return 2
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        print("LAYOUT_FAIL invalid JSON: %s" % str(exc)[:100])
        return 2

    failures: list[str] = []
    dims = (int(data.get("width", -1)), int(data.get("height", -1)))
    if dims != EXPECTED_DIMS:
        failures.append("dims_%dx%d" % dims)

    margin = int(data.get("safe_margin", 48))
    rects_raw = data.get("rects", {})
    if not isinstance(rects_raw, dict):
        print("LAYOUT_FAIL rects is not an object")
        return 2

    rects: dict[str, tuple[float, float, float, float]] = {}
    safe_violations: list[str] = []
    for name in REQUIRED:
        if name not in rects_raw:
            failures.append("missing_%s" % name)
            continue
        try:
            rect = rect_of(rects_raw[name])
        except (KeyError, TypeError, ValueError):
            failures.append("bad_rect_%s" % name)
            continue
        rects[name] = rect
        x, y, w, h = rect
        width, height = dims
        if x < margin or y < margin or x + w > width - margin or y + h > height - margin:
            safe_violations.append(
                "%s[%.0f,%.0f,%.0f,%.0f]" % (name, x, y, w, h)
            )

    overlap_list: list[str] = []
    names = [n for n in REQUIRED if n in rects]
    for i, left in enumerate(names):
        for right in names[i + 1:]:
            if overlaps(rects[left], rects[right]):
                overlap_list.append("%s<->%s" % (left, right))

    content_violations: list[str] = []
    buttons = data.get("buttons", [])
    if not isinstance(buttons, list) or len(buttons) != EXPECTED_BUTTONS:
        content_violations.append("button_count_%d" % (len(buttons) if isinstance(buttons, list) else -1))
        buttons = []
    parsed_buttons: list[tuple[float, float, float, float]] = []
    for index, raw in enumerate(buttons):
        try:
            rect = rect_of(raw)
        except (KeyError, TypeError, ValueError):
            content_violations.append("bad_button_%d" % index)
            continue
        parsed_buttons.append(rect)
        _x, _y, w, h = rect
        if w < MIN_BUTTON_W or h < MIN_BUTTON_H:
            content_violations.append(
                "button_%d_size_%.0fx%.0f" % (index, w, h)
            )

    if "ButtonsBox" in rects:
        container_h = rects["ButtonsBox"][3]
        separation = int(data.get("button_separation", -1))
        if separation < 0:
            content_violations.append("bad_separation")
        elif parsed_buttons:
            content_h = sum(r[3] for r in parsed_buttons) + separation * (len(parsed_buttons) - 1)
            if content_h > container_h + TOLERANCE:
                content_violations.append(
                    "stack_overflow_content_%.0f_container_%.0f" % (content_h, container_h)
                )

    if safe_violations:
        failures.append("safe_area")
    if overlap_list:
        failures.append("overlap")
    if content_violations:
        failures.append("button_stack")

    report = {
        "source": os.path.abspath(path),
        "dims": list(dims),
        "safe_margin": margin,
        "required": list(REQUIRED),
        "rects": {name: list(rects[name]) for name in rects},
        "safe_violations": safe_violations,
        "overlap_list": overlap_list,
        "content_violations": content_violations,
        "passed": not failures,
        "failures": failures,
    }
    out_path = os.path.join(os.path.dirname(os.path.abspath(path)), "layout_report.json")
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)

    for name in REQUIRED:
        print("LAYOUT %s in_safe=%s" % (name, name not in safe_violations))
    print("LAYOUT overlap_list=%s" % overlap_list)
    print("LAYOUT content_violations=%s" % content_violations)
    print("LAYOUT_SUMMARY passed=%s report=%s" % (report["passed"], out_path))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
