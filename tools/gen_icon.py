#!/usr/bin/env python3
"""Generate the Muakbank Zombie launcher icon set.

WHY THIS EXISTS
The old icon was one 512x512 square used as adaptive foreground AND background AND
monochrome at once. Android launchers MASK adaptive icons (circle / squircle) and only
the central ~66% of the 108dp canvas is guaranteed visible, so the title text that ran
to the canvas edges got sliced off. It also had missing-glyph "tofu" boxes in it.

ADAPTIVE GEOMETRY (Android, at 4x)
  432x432 px canvas == 108dp.
  - the CENTRED CIRCLE of diameter 264 px is the guaranteed-visible area
  - everything outside the 288x288 px centre square may be cropped by aggressive masks
So: all text/drips live inside radius 132 px of centre; the background is full-bleed
and contains nothing that must survive.

Outputs (theme/icons/):
  icon_fg.png       432x432 transparent foreground (text + drips)
  icon_bg.png       432x432 full-bleed background (gradient + blood glow)
  icon_mono.png     432x432 monochrome (themed-icon) silhouette
  icon_legacy.png   512x512 square composite (no mask applies; bigger text)
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "Nosifer-Regular.ttf"
OUT = ROOT / "theme" / "icons"
CANVAS = 432
SAFE_R = 132.0          # radius of the guaranteed-visible circle
CENTER = CANVAS / 2.0

# palette: sickly/dark horror - bone text, warning red, near-black with green undertone
BONE = (236, 228, 208, 255)
STROKE = (12, 8, 10, 255)
RED_HOT = (179, 22, 26, 255)
RED_DEEP = (104, 13, 17, 255)
BG_TOP = (20, 12, 14)
BG_BOT = (7, 10, 8)
GLOW = (150, 22, 28)


def fit_font(text: str, target_w: float, hi: int = 400) -> ImageFont.FreeTypeFont:
    """Largest font size at which `text` is no wider than target_w."""
    lo, best = 6, 6
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(str(FONT), mid)
        if f.getlength(text) <= target_w:
            best = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return ImageFont.truetype(str(FONT), best)


def radial_bg() -> Image.Image:
    """Full-bleed background: vertical gradient + smoky blood glow behind the text."""
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    for y in range(CANVAS):
        t = y / (CANVAS - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3))
        d.line([(0, y), (CANVAS, y)], fill=c + (255,))

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([CENTER - 150, CENTER - 130, CENTER + 150, CENTER + 130], fill=GLOW + (120,))
    glow = glow.filter(ImageFilter.GaussianBlur(46))
    img = Image.alpha_composite(img, glow)

    # vignette so the mask edge is never a hard bright line
    vig = Image.new("L", (CANVAS, CANVAS), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-70, -70, CANVAS + 70, CANVAS + 70], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(60))
    dark = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
    img = Image.composite(img, dark, vig)
    return img


def draw_drips(d: ImageDraw.ImageDraw, xs, y0: float, rng: random.Random, max_len: float) -> float:
    """Blood drips hanging from y0. Returns the lowest y touched."""
    low = y0
    for x in xs:
        ln = rng.uniform(max_len * 0.35, max_len)
        w = rng.choice([3, 3, 4, 4, 5])
        d.line([(x, y0), (x, y0 + ln)], fill=RED_DEEP, width=w)
        r = w * 0.95
        d.ellipse([x - r, y0 + ln - r * 0.6, x + r, y0 + ln + r * 1.4], fill=RED_HOT)
        low = max(low, y0 + ln + r * 1.4)
    return low


def compose(canvas: int, text_target: float, mono: bool = False):
    """Draw the MARK on transparency. Returns (image, content_bbox).

    text_target: max width for the widest line - keeps the mark inside the safe circle
    at adaptive sizes; the legacy icon can use a bigger one (no mask applies to it).
    """
    cc = canvas / 2.0
    f_big = fit_font("MUAK BANK", text_target)
    f_small = fit_font("ZOMBIE", text_target * 0.86)
    scale = canvas / float(CANVAS)

    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    l1_h = f_big.getbbox("MUAK BANK")[3] - f_big.getbbox("MUAK BANK")[1]
    l2_h = f_small.getbbox("ZOMBIE")[3] - f_small.getbbox("ZOMBIE")[1]
    gap = 10 * scale
    block_h = l1_h + gap + l2_h
    top = cc - block_h / 2.0 - 20 * scale          # sit slightly high, drips hang below

    if mono:
        fill, stroke, sw = (255, 255, 255, 255), (255, 255, 255, 255), 0
    else:
        fill, stroke, sw = BONE, STROKE, max(2, int(3 * scale))

    if not mono:
        # blood glow behind the letters
        glow = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.text((cc, top), "MUAK BANK", font=f_big, fill=RED_HOT, anchor="ma")
        gd.text((cc, top + l1_h + gap), "ZOMBIE", font=f_small, fill=RED_HOT, anchor="ma")
        img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(14 * scale)))
        d = ImageDraw.Draw(img)

    d.text((cc, top), "MUAK BANK", font=f_big, fill=fill, anchor="ma",
           stroke_width=sw, stroke_fill=stroke)
    y2 = top + l1_h + gap
    d.text((cc, y2), "ZOMBIE", font=f_small, fill=fill, anchor="ma",
           stroke_width=sw, stroke_fill=stroke)

    # drips under the title, kept inside the safe circle
    bottom_text = y2 + l2_h
    rng = random.Random(1337)
    half = min(text_target / 2.0, 118 * scale)
    xs = [cc + half * (-0.86 + 1.72 * i / 8.0) for i in range(9)]
    low = draw_drips(d, xs, bottom_text - 2 * scale, rng, 30 * scale)

    # Content extent = SOLID alpha only. The blood glow is a soft blur and would
    # otherwise inflate the bbox to the canvas corners; letting a faint glow run under
    # the mask is correct icon practice, letting the text do it is not.
    return img, content_bbox(img)


def content_bbox(img: Image.Image, thresh: int = 40):
    """bbox of pixels at least `thresh` opaque - ignores soft glow falloff."""
    alpha = img.getchannel("A").point(lambda a: 255 if a >= thresh else 0)
    return alpha.getbbox()


def check(name: str, bbox, canvas: int, mode: str = "circle", margin: int = 40) -> bool:
    """circle: adaptive layer - content must stay inside the guaranteed-visible circle.
    square: legacy icon - no mask applies, just needs sane margins."""
    if bbox is None:
        print(f"  {name}: EMPTY CONTENT - FAIL")
        return False
    cc = canvas / 2.0
    if mode == "circle":
        safe = SAFE_R * (canvas / float(CANVAS))
        worst = 0.0
        for x in (bbox[0], bbox[2]):
            for y in (bbox[1], bbox[3]):
                worst = max(worst, math.hypot(x - cc, y - cc))
        ok = worst <= safe
        print(f"  {name}: bbox={bbox} worst_corner_radius={worst:.1f} safe={safe:.1f} "
              f"{'PASS' if ok else 'FAIL - circular mask would clip it'}")
        return ok
    ok = bbox[0] >= margin and bbox[1] >= margin and bbox[2] <= canvas - margin and bbox[3] <= canvas - margin
    print(f"  {name}: bbox={bbox} margins=({bbox[0]},{bbox[1]},{canvas - bbox[2]},{canvas - bbox[3]}) need>={margin} "
          f"{'PASS' if ok else 'FAIL - too close to the edge'}")
    return ok


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    ok = True

    fg, bbox = compose(CANVAS, 222)
    fg.save(OUT / "icon_fg.png")
    ok &= check("icon_fg", bbox, CANVAS, "circle")

    bg = radial_bg()
    bg.save(OUT / "icon_bg.png")
    print("  icon_bg: full-bleed gradient, no critical content")

    mono, mbbox = compose(CANVAS, 222, mono=True)
    mono.save(OUT / "icon_mono.png")
    ok &= check("icon_mono", mbbox, CANVAS, "circle")

    mark512, lbbox = compose(512, 380)
    legacy = Image.alpha_composite(radial_bg().resize((512, 512), Image.Resampling.LANCZOS), mark512)
    legacy.save(OUT / "icon_legacy.png")
    ok &= check("icon_legacy", lbbox, 512, "square", margin=36)

    for f in sorted(OUT.glob("*.png")):
        print(f"  wrote {f.relative_to(ROOT)} ({f.stat().st_size} bytes)")
    print("RESULT:", "ALL SAFE" if ok else "SOME CONTENT WOULD BE CLIPPED")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
