# Muakbank Zombie — Asset Review Index

**Last synced:** 2026-11-15 · **Branch:** `feat/ui-restructure` · **Commits:** `c35373a` (Phase 1a), `ba2a1f2` (Phase 1b/c) · **Roadmap:** GitHub issue #15

This note is the human-review surface for everything produced in the UI/asset restructure. All files below are in this vault under `projects/muakbank-zombie/`.

---

## 1. Reference photos (the visual spec — GitHub #12/#13/#14)

Embed these directly in Obsidian to see the target look.

| Issue | What it is | File | Size |
|---|---|---|---|
| #13 | Start / title screen | `![[projects/muakbank-zombie/assets/references/ref_13_start_screen.jpg]]` | 102,564 B |
| #12 | Character selection screen | `![[projects/muakbank-zombie/assets/references/ref_12_character_select.jpg]]` | 98,248 B |
| #14 | Antagonist / bad-guy characters | `![[projects/muakbank-zombie/assets/references/ref_14_bad_guys.jpg]]` | 83,825 B |

### Verified visual ground truth (read with vision, not guessed)
- **#13 start screen:** blood-drip red wordmark "MUAKBANK ZOMBIE", 5 wooden-plank buttons PLAY / LEVELS / SETTINGS / CREDITS / QUIT, each with a blood splatter on the right; full moon + heavy fog + bare trees + grey tombstones + cracked stone ground; 4 blocky animal flankers (brown dog red collar, grey-white cat green eyes, brown bear holding a glowing red heart, white chicken body with rabbit head); small HOKBANK logo at bottom.
- **#12 character select:** clean 5-lane 3D pedestal lineup, **NO HUD bars / labels / buttons / wordmark**. Foggy graveyard with full moon. Lanes L→R: Gamer (magenta→purple pedestal, headphones, red controller), Doctor (cyan, white lab coat, stethoscope), Nurse (brighter cyan, teal scrubs, syringe), Streamer (purple→pink, hoodie, ring light + phone), Hunter (yellow→gold, baseball bat). All blocky low-poly on circular flat discs.
- **#14 bad guys:** 5 voxel zombie animals in a row — skeleton dog (red eyes), dark cat (green eyes), large brown bear (glowing orange chest wound), skeleton rabbit (red eyes, long ears), chicken/rooster (yellow eyes, red comb). Red jagged "MUAKBANIK ZOMBIE" text bottom.

---

## 2. Custom voxel models (Blender, built to the references)

Directory `projects/muakbank-zombie/assets/models/custom-voxel/`

| File | Bytes | Verified |
|---|---:|---|
| `aggy_voxel_hero_hunter.glb` | 17,032 | glTF v2, valid `glTF` magic, 10 exploded parts (VXH_Legs/Pelvis/Torso/Arms/Hands/Head/Cap/Eyes/Belt/Prop_Bat), 10 Principled materials |
| `aggy_voxel_zombie_skeleton_dog.glb` | 17,196 | glTF v2, valid `glTF` magic, 10 exploded parts (VXZ_Legs_Four/Pelvis/Torso/Ribcage/Head/Muzzle/Eyes_Red/Ears/Tail/Wound) |

Built via Blender MCP (4.0.2) with `export_yup=True, global_scale=1.0, apply_unit_scale=True`; `root_scale` pinned 1.0. These are the two **category exemplars** — 8 of 10 full character blockouts remain (see §6).

Part tables for all 10 characters: `[[projects/muakbank-zombie/specs/aggy_voxel_diagrams_v2.md]]`

---

## 3. Standard assets (Kenney CC0, via Asset Grabber MCP)

Directory `projects/muakbank-zombie/assets/models/cc0-graveyard/` — **28 curated GLB props**, 751,092 B total.

Source pack: **Kenney Graveyard Kit (5.0)** [`graveyard-kit`], 1 of 217 packs. Found with `assets_search(source=kenney, query=graveyard)`; exact queries `crate`/`barrel`/`gravestone` returned zero because the catalog is pack-level, not per-model.

**License verified CC0** — `LICENSE.txt` shipped in the vault folder, extracted from the zip: "Graveyard Kit (5.0), Created/distributed by Kenney (www.kenney.nl), License: Creative Commons Zero, CC0, personal/educational/commercial use, credit appreciated but not required". This resolves the repo's `assets/models/ASSET_INVENTORY.md`, which flags an older "graveyard kit" entry as **UNKNOWN** license.

Representative props: gravestones (bevel/broken/cross/decorative/round/wide), crosses, dead pines, fences, iron fence, debris, road tiles, rocks, crypt, lantern, pumpkins, brick wall, altar stone. Full 91-model pack was intentionally NOT dumped.

Manifest: `[[projects/muakbank-zombie/specs/codex_asset_manifest.md]]`

---

## 4. Palette fix (Phase 1a)

`theme/pedestaldoctor.tres` was hardcoding the Nurse cyan `#2de0ff`. Fixed:
- Doctor → new **`clinical-blue #6fa8ff`** (`Color(0.435, 0.659, 1.0, 1.0)`)
- New `theme/pedestalnurse.tres` → canonical **`neon-cyan #2de0ff`**
- `theme/main_theme.tres` → wired `PedestalNurse` variation
- `DESIGN.md` §2 → added `clinical-blue` token

Canonical roster + exact §2 diff: `[[projects/muakbank-zombie/specs/claude_canonical_roster.md]]`

Lane colors: `accent-pink #ff2d7b` Gamer · `clinical-blue #6fa8ff` Doctor · `neon-cyan #2de0ff` Nurse · `neon-purple #a05cff` Streamer · `accent-yellow #ffd60a` Hunter.

---

## 5. Verification evidence (all reproduced live)

| Gate | Command | Result |
|---|---|---|
| Static | `python3 tools/validate_project.py .` | `ISSUES: 0` / `PROJECT IS STRUCTURALLY VALID` |
| Smoke | `bash tools/regression_smoke.sh` | `REGRESSION: PASS (5 checks, 0 errors)` |
| GDUnit | `xvfb-run -a $GODOT_BIN --headless --path . --script tools/tests/run_tests.gd` | `12 checks, 0 failed` / `tests passed` |
| Pre-commit | local hook | 3 passed / 0 failed |

Clean tree at each commit; `main` untouched; branch `feat/ui-restructure` off `origin/main` `9208209`. Godot `--headless --import` generated all 30 `.glb.import` sidecars.

---

## 6. Specs in this vault

All under `projects/muakbank-zombie/specs/`:

| File | Content |
|---|---|
| `claude_canonical_roster.md` | Canonical 10-character roster, DESIGN.md §2 diff, signal-decoupling contract |
| `aggy_voxel_diagrams_v2.md` | Rebuilt VOXEL exploded part tables, all 10 characters |
| `aggy_modeling_plan.md` | Custom-vs-standard classification, Blender build recipes |
| `aggy_vision_refs.md` | Exhaustive visual breakdown of the 3 reference photos |
| `aggy_exploding_diagrams.md` | Earlier diagrams — **SUPERSEDED**, identities were `[SPEC]` guesses |
| `claude_ui_restructure.md` | Target node trees for both screens, signal decoupling, acceptance criteria |
| `codex_ui_impl.md` | GDScript implementation plan, gdUnit4 smoke tests, phased checkpoints |
| `codex_asset_manifest.md` | Kenney sourcing manifest |
| `codex_integration_checkpoint.md` | Phased integration plan, gate evidence, rollback path |

---

## 7. What is NOT done yet (honest status)

- 8 of 10 full character blockouts exist only as part tables, not `.glb`.
- Phase 2 scene restructure (`title_screen.tscn` + `character_select.tscn`) has **not started**.
- Two delegated lanes died on HTTP 402 (daily credit cap, resets 2026-11-15 20:17 UTC); deterministic integration was completed by the curator.
- Repo `ASSET_INVENTORY.md` still lists an old graveyard entry as UNKNOWN — needs updating with the verified CC0 license.

---

## Quick review checklist

- [ ] Open the 3 reference photos above, confirm they match intent
- [ ] Check the two voxel `.glb` files in a 3D viewer (Obsidian cannot render GLB inline)
- [ ] Confirm the 28 CC0 props + LICENSE.txt are present
- [ ] Review the canonical roster and palette decisions
- [ ] Confirm gate results on issue #15 before approving Phase 2
