# Character Select — Cinematic Match to Reference

Date: 2026-10-11
Branch: feat/charselect-cinematic
Status: approved for build

## Intent and the why

The player gave a reference image (the "blueprint") and wants the character-select
scene to match it as closely as possible. The reference is a spooky-graveyard
character select: five blocky characters standing in a row on glowing circular
pedestals, dramatic under-lighting, a big moon, ground fog, and a dark,
high-contrast mood. The current scene is functional but reads too flat and too
warmly lit. The goal is to move it toward the reference without rebuilding the
characters or breaking gameplay.

The user's words: "shading and lighting and a bit better pixel characters while
keeping the same theme." The characters themselves stay blocky/Kenney. The big
win is lighting and mood.

## The reference (confirmed by vision, multiple passes)

Coarse structure is reliable; exact text/small props are not and were not used.

- Five blocky characters in a horizontal row.
- Each stands on a glowing circular pedestal. The pedestal glow IS the
  selection indicator — no name labels above the characters.
- **Lighting comes from BELOW, off the pedestals** — dramatic under-light /
  rim-light on the characters against a dark scene. This is the signature move.
- Background: dark spooky graveyard, big full moon, bare trees, tombstones,
  ground fog/mist, cracked dark stone ground.
- Mood: mostly dark with bright neon accents (chiaroscuro). High contrast.
- Palette: cool/desaturated background (blues, greys, deep purples) + saturated
  neon foreground.

### Pedestal glow colors, left → right (from the reference)

| # | Character | Pedestal glow |
|---|-----------|---------------|
| 1 | Gamer    | pink / magenta |
| 2 | Doctor   | cyan / blue |
| 3 | Nurse    | cyan / turquoise |
| 4 | Streamer | purple / magenta |
| 5 | Hunter   | yellow / warm white |

### Per-character detail (from the reference, for props if added)

- Gamer: purple hoodie, gaming headphones, glowing controller (red-pink).
- Doctor: white lab coat over blue scrubs, stethoscope.
- Nurse: teal scrubs, surgical cap, face mask, glowing syringe (pink-magenta).
- Streamer: black hoodie up, beard, ring light (bright pink) + phone.
- Hunter: brown/tan jacket, baseball bat, gloves, beard.

## Current state (verified by reading the code)

- `scenes/ui/character_select.tscn` — CharacterSelect.gd + title_background.tscn.
- Pedestals built in `CharacterSelect.gd::_build_pedestals`: stone plinth +
  emissive disc + an OmniLight at **light_energy 0.12** (far too dim to be the
  hero light the reference needs) + a contact shadow.
- Background env in `title_background.tscn`:
  - ambient_light_energy 0.95, ambient bluish — too bright/flat.
  - Moon DirectionalLight energy 2.4 (keep, maybe tune).
  - **Warm fill lights**: MenuFill 1.8, LeftFill 2.7, RightFill 2.0 (warm
    orange-white). These fight the neon-underlight look and must be cut way
    down or removed.
  - fog_density 0.03, fog bluish (keep, maybe thicken near ground).
  - glow (bloom) enabled, tonemap 3 (keep).
- Characters are already on the Kenney blocky rig (scale 0.6667), skins applied
  via BlockyAnim. Do NOT touch the rigs or skins in this pass.

## Goals

1. Make the pedestal glow the primary light source — bright, wide colored
   under-light that rims each character.
2. Darken the overall scene (cut ambient and the warm fills) for high-contrast
   chiaroscuro matching the reference.
3. Match the five pedestal glow colors to the table above.
4. Keep ground fog and the moon; ensure fog reads near the ground.
5. Selection state stays obvious: selected pedestal's glow is clearly brighter
   than the rest (the reference uses glow as the indicator).

## Non-goals

- Do NOT change the character models, rigs, scale, or skins.
- Do NOT change gameplay, Player.gd, or anything outside the char-select screen
  and its background.
- Do NOT add per-character props in this pass unless a prop is trivially missing
  and clearly called for; lighting is the priority.
- Do NOT rebuild the background scene from scratch — tune what exists.

## Anti-goals (what would make this a failure even if it "works")

- A scene so dark the characters' faces are unreadable on a phone screen. Keep a
  touch of fill so faces read; the reference is dark but the characters are
  still clearly visible.
- Losing the selection indicator — the player must be able to tell which
  character is selected.
- Emissive discs with no actual light pooling on the ground/characters (emission
  without a real light = flat, not cinematic).

## The build (how it gets made)

Primary files to edit:
- `scripts/ui/CharacterSelect.gd` — `_build_pedestals` (raise the pedestal
  OmniLight energy, widen range, tune color/position so light pools upward);
  `_select_character` already scales `_lights[i].light_energy` 0.12↔1.1 and
  `_disc_mats[i].emission_energy_multiplier` 0.9↔2.0 — raise these baselines.
- `scenes/world/title_background.tscn` — cut ambient_light_energy and the warm
  MenuFill/LeftFill/RightFill; keep moon + fog; ensure fog near ground.

Constraints the implementer MUST honour:
- Absolute paths only. No `~`.
- .tscn rules: no `#` comment lines, no blank line inside a property block,
  keep `[gd_scene load_steps=N]` accurate (recompute = ext_resource +
  sub_resource + 1).
- Do NOT touch: scripts/core/Player.gd, scripts/core/BlockyAnim.gd, the
  character_*.tscn rigs, or any gameplay code.
- Emission only shows with bloom/glow enabled — it already is; don't remove it.
- Verify by rendering, not by reading the file: capture the char-select frame
  on the VPS (Xvfb + gl_compatibility, NOT --headless) and compare to the
  reference.

## Assets / downloads

If any free asset is pulled (unlikely for a lighting pass, but allowed for
e.g. a better moon skybox or fog texture), organize under:
`assets/downloaded/<source>/<pack>/` with a License file, and add a row to
`assets/ASSETS_INVENTORY.md` and `CREDITS.md`. CC0 only. Never leave a stray
file at the repo root.

## Left to the builder

- Exact energy/range/position numbers (iterate against a render).
- Exact color values for each pedestal (start from the table, tune on render).
- How much fill to keep so faces stay readable on phone.
- Whether to thicken ground fog.

## Verification (must pass before done)

1. Render the char-select frame on the VPS under Xvfb + gl_compatibility.
2. Visually compare to the reference: five characters, glowing pedestals as the
   main light, dark moody background, moon, ground fog.
3. Confirm selection indicator still works (selected pedestal brighter).
4. Confirm no Godot script errors in the render log.
5. Commit on feat/charselect-cinematic; do not merge to main.
