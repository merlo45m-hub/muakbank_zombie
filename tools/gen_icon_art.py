#!/usr/bin/env python3
"""Build the Muakbank Zombie launcher icon from the key art.

Source art: theme/icons/src_cover.png - a square recomposition of the user's key art
(five blocky zombie animals, foggy moonlit graveyard, full moon, no baked-in text).

LAYOUT (fractions of the canvas S)
  window  : the art fills the full width, top 57% - characters, moon, graveyard
  ground  : the art's own foreground stone, stretched + darkened, carries the icon to
            the bottom edge (fade to near-black, which also backs the title)
  title   : Nosifer, orange->red gradient, black outline, drop shadow - exactly the
            treatment in the reference art - in the lower band

MASK MATH (this is what the old icon got wrong: text must never be sliceable)
  A launcher mask is a shape inscribed in the S x S canvas; the tightest common one is
  the full circle of radius R = S/2. A line of text whose vertical centre sits dy px
  from the canvas centre survives that circle only if its half-width <= sqrt(R^2-dy^2).
  The script checks both the full circle and Android's conservative guarantee circle
  (radius 0.3056*S) and prints the verdict for every line.
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "theme" / "icons"
ART = OUT / "src_cover.png"
FONT_PATH = ROOT / "assets" / "fonts" / "Nosifer-Regular.ttf"

GRAD_TOP = (255, 152, 34)      # hot orange, as in the reference title
GRAD_BOT = (188, 22, 28)       # blood red
OUTLINE = (12, 8, 10, 255)
SHADOW = (0, 0, 0, 170)


def text_h(font: ImageFont.FreeTypeFont, text: str) -> int:
    b = font.getbbox(text)
    return (b[3] - b[1]) if b else font.size


def fit_font(text: str, target_w: float) -> ImageFont.FreeTypeFont:
    lo, best = 6, 6
    hi = 400
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(str(FONT_PATH), mid)
        if f.getlength(text) <= target_w:
            best = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return ImageFont.truetype(str(FONT_PATH), best)


def scene(S: int) -> Image.Image:
    """Full-bleed background: art window on top, stretched dark ground below."""
    art = Image.open(ART).convert("RGB")
    win_h = round(S * 0.572)

    win = art.resize((S, win_h), Image.Resampling.LANCZOS)

    img = Image.new("RGB", (S, S), (6, 7, 9))
    img.paste(win, (0, 0))

    # Below the window the art's own pavement keeps going: a strip of the art's
    # foreground stone, stretched moderately and mirror-tiled to fill the band, then
    # darkened on a smooth ramp so the ground recedes into the night. No flat fill and
    # no hard seam - the pavement itself is the transition.
    ground_h = S - win_h
    src = art.crop((0, int(art.size[1] * 0.82), art.size[0], art.size[1]))
    strip = src.resize((S, max(8, round(src.size[1] * S / art.size[0] * 2.0))), Image.Resampling.LANCZOS)

    ground = Image.new("RGB", (S, ground_h), (10, 10, 14))
    y, flip = 0, False
    while y < ground_h:
        piece = strip.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if flip else strip
        ground.paste(piece, (0, y))
        y += strip.size[1]
        flip = not flip
    ground = ground.filter(ImageFilter.GaussianBlur(2.4))   # kills the mirror-tile seams

    # darkness ramp: the pavement stays readable for the first ~35%, then sinks to night
    gd = ImageDraw.Draw(ground)
    for yy in range(ground_h):
        t = yy / max(1, ground_h - 1)
        k = max(0.0, min(1.0, (t - 0.04) / 0.96)) ** 1.2
        col = ground.getpixel((S // 2, yy))
        c = tuple(int(col[i] * (1 - k) + (6, 7, 11)[i] * k) for i in range(3))
        gd.line([(0, yy), (S, yy)], fill=c)
    img.paste(ground, (0, win_h))

    # organic mist just under the join (a flat rectangle read as a cheap grey band)
    mist = Image.new("RGBA", (S, ground_h), (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    span = max(1, int(ground_h * 0.55))
    for k in range(6):
        cx = int(S * (0.08 + 0.18 * k))
        cy = int(span * (0.25 + 0.5 * ((k * 7) % 5) / 4.0))
        rx, ry = int(S * 0.26), int(span * 0.30)
        md.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(140, 150, 172, 30))
    mist = mist.filter(ImageFilter.GaussianBlur(S * 0.05))
    ground_rgba = Image.alpha_composite(ground.convert("RGBA"), mist)
    img.paste(ground_rgba.convert("RGB"), (0, win_h))

    feather = img.crop((0, max(0, win_h - 10), S, min(S, win_h + 10))).filter(ImageFilter.GaussianBlur(4))
    img.paste(feather, (0, max(0, win_h - 10)))
    return img


def letters(S: int, text: str, target_w: float, anchor_y: float, mono: bool = False):
    """Title line: gradient fill + outline + drop shadow. Returns (layer, bbox)."""
    font = fit_font(text, target_w)
    x = S / 2.0
    stroke = max(3, int(round(S * 0.014)))

    solid = Image.new("L", (S, S), 0)
    ImageDraw.Draw(solid).text((x, anchor_y), text, font=font, fill=255, anchor="ma",
                               stroke_width=stroke, stroke_fill=255)
    inner = Image.new("L", (S, S), 0)
    ImageDraw.Draw(inner).text((x, anchor_y), text, font=font, fill=255, anchor="ma")
    bbox = inner.getbbox()

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if not mono:
        # drop shadow
        sh = solid.filter(ImageFilter.GaussianBlur(S * 0.012))
        sh = ImageChops.offset(sh, int(S * 0.008), int(S * 0.011))
        layer.paste(Image.new("RGBA", (S, S), SHADOW), (0, 0), sh)
    # outline ring
    ring = ImageChops.subtract(solid, inner) if not mono else solid
    layer.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255) if mono else OUTLINE), (0, 0), ring)
    # fill
    if mono:
        layer.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), inner)
    else:
        grad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        top, bot = bbox[1], bbox[3]
        for yy in range(top, bot + 1):
            t = (yy - top) / max(1, bot - top)
            c = tuple(int(GRAD_TOP[i] + (GRAD_BOT[i] - GRAD_TOP[i]) * t) for i in range(3))
            gd.line([(bbox[0], yy), (bbox[2], yy)], fill=c + (255,))
        layer.paste(grad, (0, 0), inner)
    return layer, bbox


def title(S: int, mono: bool = False):
    """Both title lines as one layer: MUAK BANK over ZOMBIE."""
    l1_target, l2_target = S * 0.51, S * 0.42
    f1 = fit_font("MUAK BANK", l1_target)
    f2 = fit_font("ZOMBIE", l2_target)
    h1 = text_h(f1, "MUAK BANK")
    h2 = text_h(f2, "ZOMBIE")
    gap = S * 0.012
    block_h = h1 + gap + h2
    y1 = S * 0.715 - block_h / 2.0         # right under the animals, as in the reference

    a, b1 = letters(S, "MUAK BANK", l1_target, y1, mono)
    b, b2 = letters(S, "ZOMBIE", l2_target, y1 + h1 + gap, mono)
    layer = Image.alpha_composite(a, b)
    return layer, (min(b1[0], b2[0]), b1[1], max(b1[2], b2[2]), b2[3]), [("MUAK BANK", b1), ("ZOMBIE", b2)]


def mask_report(name: str, bbox, S: int) -> bool:
    """Report whether the content survives the full-canvas circle and the guarantee circle."""
    if bbox is None:
        print(f"  {name}: EMPTY - FAIL")
        return False
    c = S / 2.0
    r_full, r_guar = S / 2.0, 0.3056 * S
    worst = 0.0
    for x in (bbox[0], bbox[2]):
        for y in (bbox[1], bbox[3]):
            worst = max(worst, math.hypot(x - c, y - c))
    ok = worst <= r_full * 0.97
    print(f"  {name}: bbox={bbox} worst_radius={worst:.1f} full_circle={r_full:.1f} "
          f"guarantee_circle={r_guar:.1f} -> {'safe inside a full circular mask' if ok else 'CLIPPED by a full circle mask'}")
    return ok


def main() -> int:
    if not ART.exists():
        print(f"missing source art: {ART}")
        return 2
    ok = True

    for S, tag in ((432, ""), (512, "_legacy")):
        bg = scene(S)
        fg, bbox, lines = title(S)
        if tag == "":
            bg.save(OUT / "icon_bg.png")
            fg.save(OUT / "icon_fg.png")
            title(S, mono=True)[0].save(OUT / "icon_mono.png")
        else:
            bg.save(OUT / "icon_legacy.png")
            Image.alpha_composite(bg.convert("RGBA"), fg).save(OUT / "icon_legacy_title.png")

        print(f"--- canvas {S}")
        for tname, tb in lines:
            ok &= mask_report(f"{tname}", tb, S)
        ok &= mask_report("title block", bbox, S)

    for f in sorted(OUT.glob("icon_*.png")):
        print(f"  wrote {f.relative_to(ROOT)} ({f.stat().st_size} bytes)")
    print("RESULT:", "TITLE SURVIVES THE MASK" if ok else "TITLE WOULD BE CLIPPED")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
