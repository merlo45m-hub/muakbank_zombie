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

---

## 6. Performance budget (Android)

Targets are set so a regression is *detectable*, not so a number looks good. The
game is a 6-level 3D survival brawler with procedural (non-skeletal) animation and
no baked lightmaps — the expensive things are real-time lights, shadows, and the
number of live `CharacterBody3D` zombies.

| Metric | Target | Hard ceiling | Why this number |
|---|---|---|---|
| Frame rate (S26 Ultra) | 60 FPS | 30 FPS | Flagship device; the loop is the product |
| Frame rate (mid-range Android) | 30 FPS | 24 FPS | Must stay playable on the `min_sdk` floor |
| Dropped frames (`Skipped N frames`) | < 1% of a 60 s sample | 5% | Android logs these; that is the cheap proxy for jank |
| RSS (steady state, in-level) | < 350 MB | 500 MB | A 62 MB APK with 43 MB of textures has no business above this |
| Concurrent zombies (`max_zombies`) | 12 | 16 | `ZombieSpawner3D.max_zombies` default; each is a physics body + per-frame AI |
| Real-time lights on screen | 3 | 4 | 1 directional + the player's 2 omnis. Street lamps must not all be live at once |
| Shadow-casting lights | 1 | 1 | Only the `DirectionalLight3D`. Per-light shadows are the first thing to cut |
| Draw calls | < 120 | 180 | Props are un-instanced; this is the real mobile bottleneck |
| Scene boot to playable | < 3 s | 6 s | Measured on device, cold start |

### How to measure (do not guess)

```bash
# Live sample — requires the game FOREGROUND and the phone awake.
# Reports frame drops, memory warnings, and CPU spikes from logcat.
~/bin/perf_monitor.sh com.merlo45.muakbankzombie 60

# Steady-state memory + per-process frame stats (no app change needed):
rish -c "dumpsys meminfo com.merlo45.muakbankzombie | head -20"
rish -c "dumpsys gfxinfo com.merlo45.muakbankzombie | head -20"
```

`perf_monitor.sh` prints **NO DATA** and exits 2 when Shizuku is down or logcat is
empty — that is a *missing measurement*, never a pass. Never pop the game on a phone
that is in active use; report the absence of a sample instead.

### Rules

- A new feature that pushes any metric past its **hard ceiling** is not shippable
  without cutting something else. State the trade in the commit message.
- Re-measure after anything that adds per-frame work: a new spawner, a new light, a
  new per-frame `_process` on many nodes.
- The debug overlay (`scripts/dev/DebugOverlay.gd`) reports FPS and memory live and is
  the fastest in-game check. It is dev-gated; see §7.

---

## 7. Dev tooling and the shipped build

**`OS.is_debug_build()` is NOT a safe gate for this project.** The Android APK is
exported with `--export-debug` (`~/bin/deploy_pipeline.sh`), so that call returns
`true` in the *shipped* build — gating dev tooling on it ships that tooling to every
player.

The gate is `scripts/core/DevMode.gd` → `DevMode.is_active()`: true inside the editor
(where dev tooling is the point), and in an exported build true only when the marker
file `user://dev_mode` contains the expected version string (`MARKER_VERSION = "1"`).
The marker is versioned so bumping `MARKER_VERSION` invalidates all existing markers —
a stale marker from an old build cannot silently enable dev mode after an update.
The title-screen footer long-press (≥1.0 s) toggles the marker; the DEV ROOM button is
hidden when dev mode is off.

Dev surfaces, all under `scenes/dev/` and `scripts/dev/`:

| File | Purpose |
|---|---|
| `scenes/dev/dev_room.tscn` | Sandbox. Keys **1-5** spawn ZombieDog / ZombieBoss / FoodBurger / WeaponPickup_bat / PowerUp 8 m ahead; **R** clears |
| `scenes/dev/test_player.tscn` | Player movement + camera in isolation |
| `scenes/dev/test_zombie.tscn` | ZombieDog AI, attack, death |
| `scenes/dev/test_food.tscn` | Food pickup / health restore |
| `scenes/dev/test_weapons.tscn` | Weapon pickup + swing |
| `scripts/dev/DebugOverlay.gd` | FPS / memory / player position / enemy count |

These are editor-driven (F6). In a shipped build they are reachable only with dev mode
on. **Nothing in the shipped game references them** — verify that claim before
shipping by grepping outside `scenes/dev` and `scripts/dev`.

