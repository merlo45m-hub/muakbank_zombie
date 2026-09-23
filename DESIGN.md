# DESIGN.md — Muakbank Zombie

Design contract for the game UI. Derived from the three art-director mockups
(title/menu, character select, splash). Implementation follows this file; this
file follows the mockups.

---

## 1. Direction

**Bold / expressive — spooky-neon arcade.**

Statement surfaces: oversized distressed display type, hard contrast, a
graveyard-night ground, and saturated neon used as *signal* (a character's
lane, a live stat, a threat). One element may break the grid on purpose — the
blood-drip wordmark and the glowing pedestals do that.

Deliberately **not** the model's default prior (cream ground, serif display,
terracotta accent, editorial margins). This is a dark arcade product surface;
the warm-editorial default would wash out the neon and fight the mood.

Borrowed element, with reason: from **Operational**, the HUD keeps stable bar
dimensions so a reading eye isn't re-learning the layout mid-fight.

### Anti-slop commitments
- Not one-note: the ground is layered (night → fog → stone), not one flood color plus grey.
- Not flat: hierarchy is carried by size and weight steps, not by everything at medium.
- No motion as decoration: glow pulses describe state (threat, selection), not mood.
- Every state drawn: buttons get hover/pressed/disabled; bars get empty/full/danger.

---

## 2. Palette (hex)

| Token | Hex | Use |
|---|---|---|
| `bg-deep` | `#0d0a1a` | Void ground, project clear color |
| `bg-mid` | `#1a1428` | Mid ground behind panels |
| `bg-surface` | `#241e38` | Panels, bar tracks |
| `wood-900` | `#3b2a1a` | Menu plank base |
| `wood-700` | `#5a4028` | Menu plank face |
| `blood` | `#c8102e` | Wordmark, danger |
| `accent-pink` | `#ff2d7b` | Primary accent, HYPE bar, Gamer lane |
| `accent-orange` | `#ff8c2b` | Secondary accent, bar gradient end |
| `accent-yellow` | `#ffd60a` | Timer, Hunter lane, highlights |
| `neon-cyan` | `#2de0ff` | Nurse lane |
| `neon-purple` | `#a05cff` | Streamer lane |
| `neon-green` | `#37e05a` | Zombie eyes, OVERWHELM bar |
| `moon` | `#e8ecf5` | Key light, primary text on dark |
| `text-primary` | `#ffffff` | Primary text |
| `text-muted` | `#a89cc4` | Secondary text, subtitles |

Accent budget: pink is the **only** primary accent. Orange appears only as a
gradient partner; yellow only for time-critical and selection signals. Neon
cyan/purple/green are reserved for character lanes and threat — never chrome.

---

## 3. Type & geometry

**Stack**
- Display (wordmark, screen titles): distressed slab, uppercase, tight tracking.
  Shipped substitute: NotoSans at heavy weight + outline, until a display face is chosen.
- Text/UI: `NotoSans` — fallback `NotoColorEmoji` for icon glyphs.

Both shipped at `assets/fonts/`, registered in `theme/main_theme.tres` as a
`FontVariation` (base = NotoSans, fallbacks = [NotoColorEmoji]) so emoji glyphs
render instead of a tofu box.

**Geometry**
- Radius: `12` (panels), `50` (pill buttons), `999` (pedestal discs)
- Border weight: `2` (idle), `3` (active/selected)
- Spacing base: `8` — all padding/gaps step in multiples (8/16/24/32)
- Bar height: `16` (stable — deliberately borrowed from the operational direction)
- Pedestal diameter: `120`

---

## 4. Signature elements

1. **Blood-drip wordmark** — `MUAKBANK ZOMBIE` in blood red, drip on the
   descenders, sitting on the moon.
2. **Glowing neon pedestal** — a character's lane is a disc of their own hue.
   Chosen lane raises + brightens; others dim.
3. **Wooden plank buttons** — the menu's primary affordance reads as cut timber,
   not as a rounded rectangle.

---

## 5. Implementation status

| Surface | Mockup | Built | Gap |
|---|---|---|---|
| Wordmark / splash | blood-drip display | flat red label | display face + drip |
| Menu buttons | wooden planks | ✅ WoodPlank StyleBox applied | — |
| Character select | neon pedestals | ✅ PedestalGamer/Doctor/Nurse/Streamer/Hunter sub-resources | — |
| HUD bars | HYPE (pink→orange), OVERWHELM (green→yellow) | ✅ Gradient-enabled GodotxHealthBarStyle | — |
| HUD labels | `🔥 HYPE` / `⚠ OVERWHELM` | matched | — |
| HUD food bar | 6 round food buttons | ✅ 6 TextureButton slots with generated icons | — |
| Center message banner | bordered banner | ✅ Panel + Label with fade tween | — |
| Fonts | n/a | NotoSans + NotoColorEmoji | — |

Owner for the remaining gaps: frontend/godot UI lane. Rendered verification
belongs to visual QA on device — **not claimed here**.
