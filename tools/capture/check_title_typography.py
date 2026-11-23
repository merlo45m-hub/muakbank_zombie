#!/usr/bin/env python3
"""Issue #63 I3 — fail-closed title typography and touch-target gate.

Reads CAP_TYPO_OUT JSON and asserts:
  1. every glyph used by title-screen Buttons/Labels exists in its font,
  2. every Button is at least 48x48,
  3. PLAY keeps Bungee as the primary CTA at >=40px,
  4. secondary buttons and DEV ROOM use SpecialElite at >=28px,
  5. title and footer use Nosifer at the expected sizes.

Writes <input dir>/typography_report.json.
"""
from __future__ import annotations

import json
import os
import sys

FONT_SUBSTRINGS = {
    "Bungee": "bungee-regular.ttf",
    "SpecialElite": "specialelite-regular.ttf",
    "Nosifer": "nosifer-regular.ttf",
}
SECONDARY = {"LevelBtn", "SettingsBtn", "CreditsBtn", "QuitBtn"}


def font_kind(value: object) -> str:
    path = str(value).lower()
    for kind, needle in FONT_SUBSTRINGS.items():
        if needle in path:
            return kind
    return "unknown"


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else ""
    if not path or not os.path.isfile(path):
        print("TYPO_FAIL missing input: %s" % path)
        return 2
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        print("TYPO_FAIL invalid JSON: %s" % str(exc)[:100])
        return 2

    violations: list[str] = []
    missing = data.get("missing_glyphs", [])
    small = data.get("small_targets", [])
    if not isinstance(missing, list) or missing:
        violations.append("missing_glyphs:%s" % (missing if isinstance(missing, list) else "bad"))
    if not isinstance(small, list) or small:
        violations.append("small_targets:%s" % (small if isinstance(small, list) else "bad"))

    buttons = data.get("buttons", [])
    labels = data.get("labels", [])
    if not isinstance(buttons, list) or not isinstance(labels, list):
        print("TYPO_FAIL buttons/labels are not arrays")
        return 2

    by_name = {str(b.get("name", "")): b for b in buttons if isinstance(b, dict)}
    label_by_name = {str(l.get("name", "")): l for l in labels if isinstance(l, dict)}

    play = by_name.get("PlayBtn")
    if not play:
        violations.append("missing_PlayBtn")
    else:
        kind = font_kind(play.get("font"))
        size = int(play.get("font_size", -1))
        if kind != "Bungee" or size < 40:
            violations.append("PlayBtn_font_%s_%d" % (kind, size))

    dev = None
    for b in buttons:
        if isinstance(b, dict) and str(b.get("text", "")).strip().upper() == "DEV ROOM":
            dev = b
            break

    for name in sorted(SECONDARY):
        b = by_name.get(name)
        if not b:
            violations.append("missing_%s" % name)
            continue
        kind = font_kind(b.get("font"))
        size = int(b.get("font_size", -1))
        if kind != "SpecialElite" or size < 28:
            violations.append("%s_font_%s_%d" % (name, kind, size))

    if dev is None:
        violations.append("missing_DEV_ROOM")
    else:
        kind = font_kind(dev.get("font"))
        size = int(dev.get("font_size", -1))
        if kind != "SpecialElite" or size < 28:
            violations.append("DEV_ROOM_font_%s_%d" % (kind, size))

    title = label_by_name.get("TitleLabel")
    if not title:
        violations.append("missing_TitleLabel")
    else:
        kind = font_kind(title.get("font"))
        size = int(title.get("font_size", -1))
        if kind != "Nosifer" or size < 60:
            violations.append("TitleLabel_font_%s_%d" % (kind, size))

    brand = label_by_name.get("BrandLabel")
    if not brand:
        violations.append("missing_BrandLabel")
    else:
        kind = font_kind(brand.get("font"))
        size = int(brand.get("font_size", -1))
        if kind != "Nosifer" or size < 20:
            violations.append("BrandLabel_font_%s_%d" % (kind, size))

    report = {
        "source": os.path.abspath(path),
        "missing_glyphs": missing,
        "small_targets": small,
        "buttons": buttons,
        "labels": labels,
        "passed": not violations,
        "violations": violations,
    }
    out_path = os.path.join(os.path.dirname(os.path.abspath(path)), "typography_report.json")
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)

    print("TYPO missing_glyphs=%s" % missing)
    print("TYPO small_targets=%s" % small)
    print("TYPO violations=%s" % violations)
    print("TYPO_SUMMARY passed=%s report=%s" % (report["passed"], out_path))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
