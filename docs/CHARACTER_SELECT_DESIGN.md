# Character Select — Rebuild Design

**Status:** awaiting approval
**Branch:** `feat/charselect-blocky`
**Scope:** the character-select screen (2nd screen: title → character select → level select) and the five survivor characters it displays.
**Reference art:** `second_brain/muakbank zombie character select scene.md` → five blocky survivors on glowing pedestals in the graveyard. Confirmed by the user as "exactly how I want it".

---

## 1. Intent

The screen already has the right *idea* — one continuous stage, five survivors standing in the graveyard on neon pedestals, tap to select, PLAY forward. The user likes that. What is wrong is the characters themselves: they are built on the wrong rig, and four of the five share tinted duplicates of the same skin, so they read as generic.

This pass replaces the rig and the skins underneath, fixes four real defects found in audit, and leaves the stage concept intact.

**What the player should feel:** five *specific* people, not five colour swaps. Each recognisable by silhouette alone at a glance — the gamer's headset, the doctor's coat, the nurse's mask, the streamer's hood, the hunter's bat.

**Non-goal:** this is not a gameplay rebalance. The stats wiring (below) makes the five *exist* as different characters; it does not tune their numbers.

---

## 2. Goals / Non-Goals / Anti-Goals

### Goals
- Five survivors on Kenney **Blocky Characters** rigs, matching the reference silhouette (square head ≈30% of body height, blocky limbs, no neck).
- Each survivor visually distinct by skin **and** prop.
- Characters idle correctly on the select screen and move/attack correctly in gameplay.
- The four audited defects fixed: tap-zone misalignment, persistence overwrite, rig facing, dead stats.
- Correct the two wrong scale figures in project docs.

### Non-Goals
- No new level content, no zombie changes, no HUD/UI changes outside this screen.
- No new external asset downloads — the rig and skins are already on disk and verified CC0.
- No skeletal animation. The blocky rig is rigid-part animated by design (see §5).

### Anti-Goals (what makes this a failure even if it "works")
- **Five recolours again.** If two survivors differ only by tint, the pass failed.
- **A dead screen.** If any survivor is invisible, untextured, frozen, or facing the wrong way, the pass failed.
- **Silent regressions.** If zombies, saves, or gameplay break because a shared helper changed, the pass failed.
- **Slop.** Generic copy, emoji-as-icons, magic numbers, god functions — the project bar (`docs/anti-slop-principles.md`) applies.

---

## 3. Constraints

- **Termux cannot run Godot.** All engine verification happens on the VPS (`/root/Godot_v4.7-stable_linux.x86_64`). Local edits, then sync.
- **`.tscn` has three silent-failure rules:** no `#` comments, no blank lines inside a property block, `load_steps` must equal `ext_resource + sub_resource + 1`. A comment line drops the node *and its children* while the scene still loads.
- **Headless cannot render.** Frame capture needs Xvfb + `--rendering-method gl_compatibility --rendering-driver opengl3` (installed on the VPS; the project's `tools/render_view.sh` documents the pattern). `--headless` produces a null viewport texture.
- **`--script` gives false failures.** `extends SceneTree` runs before autoloads exist, so any autoload access reports `Identifier not found: Audio`. Test with a real scene.
- **Never commit secrets.** `apk_test/` and `*.conf` are gitignored after an earlier incident; stage by explicit path.

---

## 4. The Rig — measured facts

All figures below were measured on this project, not assumed. Two project docs disagree and are both wrong; this section supersedes them.

| Property | Value | How verified |
|---|---|---|
| Files | `assets/models/cc0/blocks/character-a.glb` … `character-r.glb` (18) | directory listing |
| Skins | `skins: 0` — **no skeleton** | GLB JSON parse |
| Animation | **27 clips**, rigid-part node transforms | GLB animation channels |
| Native height | **2.7 units** (bbox 1.6 × 2.7 × 0.8), feet at y=0 | composed node transforms |
| **Scale for 1.8 m** | **0.6667** (= 1.8 / 2.7) | arithmetic + in-engine AABB |
| Head | 0.8 cube, sits at y 1.9–2.7 = **30% of total height** | composed transforms |
| Node names | `root`, `leg-left`, `leg-right`, `torso`, `arm-left`, `arm-right`, `head` | GLB node list |
| Hands | **no `hand` node** — attach props to `arm-right` (mesh hangs down, hand end at local y ≈ −1.0) | GLB node list |
| Texture | external URI `Textures/texture-<x>.png`, resolved automatically by Godot | GLB JSON + import |
| Material | **one shared** `StandardMaterial3D` across all 6 parts; property is `albedo_texture` | instance-id test in engine |
| Shading | `KHR_materials_unlit` (unshaded) — same as the outgoing rig | GLB extensions |
| Facing | **+Z**, but the game assumes −Z | head UV decode + handedness |

### Two traps that will bite the implementer
1. **The `AnimationPlayer` is a sibling of the glb root, not a child.** A `get_node_or_null("AnimationPlayer")` from the root returns `null`. (The existing `ZombieBase._drive_anim()` already has this latent bug.)
2. **Imported clips are `loop_mode = LOOP_NONE`.** They play once and freeze. Idle/walk/sprint must be set to loop explicitly.

### Correcting the record
- `assets/models/MODEL_SCALE_TABLE.md` recommends **0.2** → survivors 0.54 m tall.
- `docs/CHARSELECT_AUDIT.md` §defects states **0.9** → 2.43 m tall. (It omits `torso`'s `translation.y = 1.0` when composing.)
- **Measured: 0.6667.** Both docs get corrected as part of this pass.

---

## 5. Animation strategy — the decision this design makes

The outgoing helper `CharacterAnim.setup_rigged()` **cannot drive this rig** and is *measured* to return `null` for it: it gates on `Skeleton3D` at three points, its `_retarget()` is bone-keyed, and its `_load_clip()` reads `kenney_anim/` for `["idle","run","jump"]` — the blocky set ships `walk`/`sprint` and has **no `run` or `jump` at all**.

**Decision (mine, stated so it can be rejected):** add a *new* helper rather than bend the old one.

- New file: `scripts/core/BlockyAnim.gd`
- Responsibilities: locate the sibling `AnimationPlayer`, map game states → blocky clip names, force `loop_mode = LOOP` on the looping set, expose `play_state(state: String)`.
- Clip mapping (the blocky set's real names):
  - `idle` → `idle`
  - `walk` → `walk`
  - `sprint` → `sprint`
  - `attack` → `attack-melee-right` (fallback `attack-kick-right`)
  - `death` → `die`
- `CharacterAnim.gd` is **left alone** — zombies depend on it (§7) and touching it is the one change that would break them.

---

## 6. Character mapping

Reference → blocky skin. Two of five are a direct match; three need work. This is the honest split, and the "no AI slop" judgement lives here.

| Survivor | Reference (from the user's image) | Blocky skin | Verdict |
|---|---|---|---|
| **Hunter** | brown jacket over green shirt, full beard, wooden bat | `texture-k` — bearded, brown leather jacket, red shirt | ✅ **direct match** |
| **Streamer** | black hoodie, hood up, beard, ring light + phone | `texture-r` — full black hood | ✅ **match** (add beard detail) |
| **Doctor** | white lab coat, blue scrubs under, stethoscope, brown hair | `texture-j` — white lab coat, blue shirt | 🟡 close — `-j` is older/grey-bearded; `-i` is younger but purple-haired |
| **Nurse** | teal scrubs, teal cap, blue surgical mask, syringe | none — `-i`/`-p` are white lab coats | 🔴 **needs skin edit** (recolour to teal) |
| **Gamer** | purple hoodie, rainbow-LED headset, controller | none — `-f` is a *green* hood | 🔴 **needs skin edit** (recolour to purple) |

**Approach:** take the closest skin, edit the PNG (recolour hood → purple, coat → teal), keep everything else Kenney-authored. Editing a texture is not "generating art" — it is recolouring existing art, which keeps the pack's hand-authored style. **The two edited skins will be shown to the user for approval before being wired in.**

**Props** are rebuilt as primitives under `PlayerVisuals` (the established pattern, `references/character-scene-enhancement.md`): gamer headset + controller, doctor stethoscope, nurse mask + syringe, streamer ring light + phone, hunter bat. Attached to `arm-right` for hand items (no `hand` node exists).

---

## 7. Defects to fix

Four confirmed bugs, each with evidence in the audit docs.

### 7.1 Tap zones do not align with the characters 🔴
`CharacterSelect.gd:42,296` computes zone position as `0.5 + x / 10.92` — that models an **orthographic** camera centred on the stage. The real camera is perspective, offset and yawed. Projecting the five feet gives an error growing 6 → 225 px left-to-right, so **tapping the streamer selects hunter and tapping the hunter does nothing**. Aspect-blind (up to 443 px at 1:1).

**Fix:** derive each zone from the actual camera projection (`Camera3D.unproject_position()` on each character's head/feet), recomputed on resize. Delete the `STAGE_WORLD_WIDTH` magic number.

### 7.2 Selection is overwritten on entry 🔴
`CharacterSelect.gd:95` calls `_select_character(1, false)` → `_confirm_selection()` → `Save.set_selected_character("doctor")`. Entering the screen always clobbers the saved choice.

**Fix:** read the saved character on `_ready()` and select *that*; only write on an explicit user tap.

### 7.3 The rig faces backwards 🔴
The blocky rig faces **+Z**; `Player.gd` and every `Zombie*.gd` compute yaw as `atan2(dir.x, dir.z)` assuming **−Z**. Uncorrected, characters run backwards.

**Fix:** `Player.gd:934` already has the hook — set `MODEL_YAW_OFFSET := PI`. Verify by rendering a character mid-run.

### 7.4 The stats are dead 🔴
`Player.gd:32` declares `var character_stats: CharacterStats = null` and **nothing ever assigns it** (`grep -rn "character_stats\s*="` returns nothing). The five `assets/materials/stats_*.tres` files are unreferenced. All five survivors currently play identically and no special ability fires.

**Fix:** `Player._apply_character_model()` loads `stats_<id>.tres` and assigns `character_stats` before `_apply_character_stats()` runs. This is what makes the five actually differ.

### 7.5 Quality items (lower severity, same pass)
- `_dim_model_materials()` is a **no-op today** — `apply_skin_raw()` overwrites it two lines later. Either make it the real fix or delete it.
- `_soften_bloom()` is a band-aid over `KHR_materials_unlit`; make the fix rig-independent.
- `_build_ui()` (112 lines, six jobs) and `_build_stage()` (83 lines, six jobs) get split.
- Five parallel index-keyed arrays → one typed array of a small `Survivor` struct.
- `print()` at `:96` and `:368` → proper logging or removed.
- Descriptions and colours duplicate `stats_*.tres` and **disagree with them** — single source of truth.
- `BottomBar` is 144 px tall holding ~186 px of content.

---

## 8. What is kept

Explicitly preserved, because it works:

- The single-stage concept (no card grid).
- The `PlayerVisuals` extraction pattern — the *same* pattern gameplay uses, which is what makes menu and gameplay agree.
- The invisible flat-`Button` zone mechanism (correct approach; only the *maths* is wrong).
- The `Save.set_selected_character()` API.
- The graveyard backdrop, pedestal geometry, and per-survivor accent colours.
- `tools/menu_render_probe.gd` — extended with an alignment assertion rather than replaced.
- Named constants over inline literals.

---

## 9. Out of scope

- Zombie rigs. 4 of 7 zombie types share the *outgoing* `model.glb` via `CharacterAnim` — they are coupled to the **helper**, not to the survivor scenes, so leaving `CharacterAnim.gd` untouched keeps them working. This design does not migrate zombies.
- Level content, HUD, combat balance, audio.
- The a–r → survivor mapping is a design decision recorded in §6, not a discovered fact.

---

## 10. Acceptance — how this is judged done

1. All five survivors visible, textured, correctly scaled (1.8 m), feet on the pedestal.
2. All five **visually distinct without reading the name** — checked by render.
3. Tapping each character selects *that* character; verified by projecting the zone and asserting the hit.
4. Saved character is restored on entry and not clobbered.
5. Characters face the direction they move, in gameplay.
6. Each survivor's `stats_*.tres` actually applies (verify one measurable stat differs, e.g. max_health).
7. `play("idle")` loops; no frozen characters.
8. Zombies, saves, and a full level still run clean (zero `vanished` warnings, zero script errors).
9. `.tscn` sweep clean: no `#` comments, correct `load_steps`.
10. Renders attached as evidence — not a claim that it works.

---

## 11. Open questions for the user

1. **Doctor identity** — `texture-j` (older, grey beard) or `texture-i` (younger, purple hair)? Reference shows a younger brown-haired man.
2. **The two edited skins** (purple hoodie, teal scrubs) — approve the recolour before wiring, or use the closest unedited skin and accept the mismatch?
3. **Gameplay too?** Gameplay extracts `PlayerVisuals` from the same scenes, so gameplay gets the new rig automatically. Confirm that is wanted (it changes the in-game character, not just the menu).
