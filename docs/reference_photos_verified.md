# Reference Photos — VERIFIED Visual Spec (issues #12, #13, #14)

Status: **verified transcript**. Unlike `aggy_vision_refs.md` / `aggy_exploding_diagrams.md`
(whose `[SPEC]` values were draft guesses because `vision_analyze` returned HTTP 429
at the time), every description below came from actually decoding the JPGs with
`vision_analyze` on 2026-11-15. This document supersedes those drafts for the
character species, colors, counts, and distinguishing features.

Source images (downloaded from the GitHub issue user-attachments):
- #12 character select — `ref_12.jpg`
- #13 start/title screen — `ref_13.jpg`
- #14 antagonists — `ref_14.jpg`

---

## REF #13 — START / TITLE SCREEN

- **Title text:** "MUAK BANK ZOMBIE" centered top, jagged horror serif, bright red
  with blood drips (notably on the K of BANK, E of ZOMBIE), dark drop shadow.
- **Menu:** 5 weathered wooden-plank buttons stacked vertically, centered:
  PLAY / LEVELS / SETTINGS / CREDITS / QUIT. White bold centered text; each plank
  has a red blood splatter on its right side.
- **Background:** dark misty night sky, large full moon behind the title, bare
  spooky tree silhouettes framing left/right, cracked grey graveyard stone slabs,
  crooked tombstones.
- **Four animal flankers (left→right):** tan dog w/ floppy ears + red collar +
  glowing red eyes; grey-white cat with bright green glowing eyes; brown bear
  holding a glowing orange fire sphere; white upright chicken with long brown
  rabbit ears. All have glowing eyes.
- **Bottom logo:** small square "MOKBANK" wordmark with a cartoon character and
  flame icon.
- **Implemented (Phase 2a, `c1b35b4`):** blood-red wordmark `#c8102e`, removed
  non-reference stat strip + tagline, MOKBANK footer.
- **Still missing:** 4 explicit animal flankers, plank nail heads / baked blood
  splatter / disabled button state, the square brand icon, volumetric fog.

## REF #12 — CHARACTER SELECT

- **5 lanes/pedestals** in a horizontal row, flat cylindrical platforms, each
  emitting a colored light onto the character's feet and the ground.
- Left→right:
  1. **Gamer** — purple hoodie, dark pants, RGB headphones, glowing red game
     controller. Pedestal magenta/purple.
  2. **Doctor** — white coat over blue scrubs, brown hair, stethoscope, smile.
     Pedestal bright blue/cyan.
  3. **Nurse** — teal/green scrubs, surgical cap, blue face mask, syringe.
     Pedestal cyan/teal.
  4. **Streamer** — all-black hoodie (hood up), brown beard, smartphone +
     large glowing pink ring light. Pedestal purple/pink.
  5. **Hunter** — brown leather jacket, dark cargo pants, boots, beard, wooden
     baseball bat over shoulder. Pedestal yellow/gold.
- **Background:** cracked stone, graveyard tombstones, dead trees, heavy fog,
  large full moon, dark blue misty sky. "GRAVE" faintly on the far-left tombstone.
- **Camera:** slightly low angle looking up, even 5-way spacing.
- **Canonical lane colors (DESIGN.md §2 / canonical roster, shipped `.tres`):**
  Gamer `#ff2d7b`, Doctor `#6fa8ff`, Nurse `#2de0ff`, Streamer `#a05cff`,
  Hunter `#ffd60a`. NOTE: the photo's Doctor/Nurse read as blue/cyan and the
  canonical palette deliberately differentiates them (clinical-blue vs neon-cyan).
  Issue #16 confirmed Nurse = neon-cyan, not Mint Green.
- **Implemented (Phase 2b `d8b7292` + `fa9414c`):** removed non-reference header
  chrome; aligned the live `PEDESTAL_COLORS` runtime dict to the canonical palette
  (all 5 verified byte-for-byte against the `.tres` files).
- **Still missing:** the 5-lane declarative rebuild (current scene is a single
  hero pedestal with a carousel), per-character 3D models with the props above,
  volumetric fog, moon lighting.

## REF #14 — ANTAGONISTS (bad guys)

Low-poly voxel style, foggy graveyard night, full moon, emissive eyes/wounds.

Left→right, 5 distinct characters:
1. **Skeleton Dog** — bone-white/cream with dark brown patches on ribcage/legs.
   Canine skull, exposed teeth, **glowing red eyes**, exposed ribcage + spine.
   Bipedal, hunched. Medium size (~waist-high to the bear).
2. **Black Cat** — dark grey/black fur, **glowing green eyes**, quadrupedal in a
   classic arched-back "scared cat" pose with tail raised. Smallest, low to ground.
3. **Zombie Bear (center, focal)** — dark brown fur, blocky face with small ears,
   **large jagged chest wound emitting bright orange/yellow glow** (heart/internal
   fire). Extremely bulky, muscular. **LARGEST**, towers over the others.
4. **Zombie Rabbit** — pale grey/white skin, dark grey patches on arms/legs,
   skeletal face with long ears, **glowing red eyes**, stitched/wounded torso.
   Upright bipedal. Medium.
5. **Zombie Chicken/Rooster** — yellow/tan feathers, red comb, beak, **glowing
   yellow eyes**, folded wings. Upright. Medium.

- **Logo:** "MUAKBANIK" + "ZOMBIE" in jagged red letters with black outline,
  bottom center.
- **Modeling notes:** cube/voxel geometry; matte rough fur/skin; lighter matte
  bone; emissive for red eyes (dog, rabbit), green eyes (cat), yellow eyes
  (chicken), orange chest wound (bear). Dog/Bear/Rabbit/Chicken bipedal, Cat
  quadrupedal.

### #14 current-state audit (verified 2026-11-15)
All five species ALREADY exist as scenes (`scenes/characters/zombie_{dog,cat,bear,
rabbit,chicken}.tscn`) and `.glb` models, plus `zombie_boss`, `zombie_butcher`,
`zombie_runner`, `zombie_spitter`. BUT parsing the GLB JSON shows **all five
`zombie_*.glb` have `materials: []` — zero materials, zero emissive factors**.
So the reference's defining emissive features (glowing eyes, bear chest wound)
are NOT present. That is the concrete remaining art task for #14.

The per-species emissive contract is recorded as a data resource in
`resources/characters/antagonist_emissive.gd` (see `AntagonistEmissive`), so the
modeling pass has exact colors without re-reading the photo.

---

## Honest status
#12/#13/#14 are **reference-driven ART tasks**. Code-level progress is committed
and verified (see above), but full visual fidelity — 5-lane character select,
4 animal flankers + title-screen plank detail, detailed antagonist models with
emissive accents, volumetric fog and painterly lighting — is NOT achieved and is
NOT claimed. Those need Blender modeling + a visual review pass against these
photos.
