# Character Select — Rebuild Design

**Status:** awaiting approval
**Branch:** `feat/charselect-blocky`
**Scope:** the character-select screen (2nd screen: title → character select → level select) and the five survivor characters it displays.
**Reference art:** the user's image `IMG_20261011_183806_060.jpg`, filed in the Obsidian vault at
`/storage/emulated/0/ObsidianVault/hermes_brain/second_brain/` and referenced from the note
`muakbank zombie character select scene.md`. Confirmed by the user as "exactly how I want it".
It is **not** in the git repo — copy it to `docs/reference/` on approval so the acceptance bar is
inspectable by whoever builds this.

**Project pattern reference:** `godot-game-dev` **skill** (not the repo) →
`references/character-scene-enhancement.md`, at
`/data/data/com.termux/files/home/.hermes/skills/godot-game-dev/references/`. There is no
`references/` directory in the repo.

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
- **It must serve both the menu and gameplay.** The menu wants `idle`; gameplay asks for `idle` / `run` / `jump` (`Player.gd:367,370,381`). See §7.3b for the full mapping and the two clips that do not exist.
- Force `loop_mode` on a **`duplicate()`d `Animation`**, not the shared imported resource.
- `CharacterAnim.gd` is **left alone** — zombies depend on it (§7, §9) and touching it is the one change that would break them.

### Traps the implementer must not miss
- The `AnimationPlayer` is a **sibling** of the glb root. Use `find_child(..., true)` or check the parent — a root-only `get_node_or_null("AnimationPlayer")` returns `null`. (The existing `ZombieBase._drive_anim()` already has this latent bug.)
- **Keep the node names `PlayerVisuals` and a child named `Model`.** `Player.gd:951` and `CharacterAnim.gd:50` look these up by name; rename either and it silently falls back to the blockout GLB.
- Imported clips are `loop_mode = LOOP_NONE` — they freeze after one cycle.

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

**Approach — technique now specified (the first draft left this undecided; a builder could not have produced the preview it promised).**

The blocky atlases are **1024×1024 8-bit palette PNGs** (`mode=P`, 256-entry `PLTE`) — verified by decoding them. The garment colour is a **palette index**, not a pixel region. Measured examples:

| Skin | Garment | Palette index | Colour |
|---|---|---|---|
| `texture-f` (gamer base) | green hood | 9 | `#58bd98` |
| `texture-i` (nurse base) | white coat | 8 | `#d0e8ff` |

Three candidate techniques, and only one is acceptable:

- ❌ **Runtime `albedo_color` tint** — multiplies the *whole* texture. Cannot turn a green hood purple without wrecking skin, beard and hair. This is the approach the *outgoing* system used (five tinted copies of four skins), and it is exactly the "five recolours" anti-goal in §2.
- ❌ **Repaint pixels in the UV region** — the per-part UV footprint is **not a clean grid** (`BLOCKY_RIG_NOTES`), so this needs per-part UV work for no benefit over the next option.
- ✅ **Edit the palette entry** — the colour is garment-only, so remapping one index recolours the garment and touches nothing else.

**Decision:** copy `texture-f.png` → `texture-gamer.png` and `texture-i.png` → `texture-nurse.png`, edit the **palette index** in the copy, and **leave the stock Kenney PNGs untouched**. The GLB's external `baseColorTexture` URI is then repointed at the new file — which means a small GLB edit, or (preferred) loading the new texture at runtime onto the rig's shared `StandardMaterial3D.albedo_texture`.

**Preferred implementation: runtime, not GLB surgery.** The rig has **one shared material** across all six parts (verified), so setting `albedo_texture` once reskins the whole character. A `duplicate()`d material + our own texture avoids editing any Kenney source file and keeps the CC0 assets pristine. The recoloured PNGs live in the project, not over the pack.

**The two edited skins will be rendered and shown to the user for approval before being wired in.**

**Props** are rebuilt as primitives under `PlayerVisuals` (the established pattern, `godot-game-dev` skill → `references/character-scene-enhancement.md`): gamer headset + controller, doctor stethoscope, nurse mask + syringe, streamer ring light + phone, hunter bat. Attachment points and the size rule are in §7.3b — **not** `arm-right` for everything, and the outgoing transforms are not reusable.

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

**Correction to an earlier draft of this design.** The draft said "`Player.gd:934` already has the hook — set `MODEL_YAW_OFFSET := PI`". **That is wrong and would have shipped dead code.** Verified: `MODEL_YAW_OFFSET` is read at exactly one site, `Player.gd:1015` (`mdl.rotate_y(MODEL_YAW_OFFSET)`), which lives in `_normalise_model_transform` — the **GLB blockout fallback path**. Gameplay and the menu use the *scene* path (`Player.gd:942-966`), which never reaches it.

**Real fix site:** the live facing is applied at `Player.gd:353-355`:
```gdscript
var target_rot: float = atan2(direction.x, direction.z)
vis.rotation.y = lerp_angle(vis.rotation.y, target_rot, rot_speed * delta)
```
Apply the 180° here — a yaw offset on `target_rot`, or a one-time `rotate_y(PI)` on the visual root at attach time. **Do NOT** add `+PI` inside `ZombieBase.gd`: the zombies keep the outgoing rig and would be flipped instead.

### 7.3b Gameplay animation is rewired too 🔴 (added after builder review)
The first draft of this design only gave the **menu** a `BlockyAnim` path and left `Player.gd:965` calling `CharacterAnim.setup(vis, id)`. For a `skins:0` rig that returns `null`, so in gameplay:
- `_skeletal` stays `null` (`Player.gd:90`),
- `_update_skeletal_anim()` early-returns (`Player.gd:374-376`),
- `ProceduralAnimator` stays **enabled** (`Player.gd:129-130` disables it only when `_skeletal != null`),
- the survivor procedurally sways with no walk cycle, and acceptance #7 fails in gameplay while passing in the menu.

**Fix:** replace the `Player.gd:965` call with `BlockyAnim`. The clip map in §5 is therefore **wrong as written** — it must cover the names `Player.gd` actually asks for:

| `Player.gd` asks for | Site | Blocky clip |
|---|---|---|
| `"idle"` | `:381` | `idle` |
| `"run"` | `:381` | `sprint` (the set has no `run`) |
| `"jump"` | `:367,370` | **none** — the set has no `jump`; the `has_animation("jump")` guard at `:367` already makes this a clean no-op, so jump plays the fallback and that is acceptable |
| attack | `WeaponSystem` path | `attack-melee-right` |
| death | death path | `die` |

Also: **drop the sine idle-bob** at `CharacterSelect.gd:105` — `idle` is now a real looping clip and the two fight each other.

**Prop attachment, made concrete.** Headset and mask → `head`; stethoscope → `torso`; controller / syringe / phone / bat → `arm-right` (no `hand` node exists; the mesh's hand end is at local `y ≈ −1.0`). **Size a prop in model units as `metres / 0.6667`** — a child of `arm-right` inherits the rig scale. The outgoing props' transforms were tuned for scale `0.00425` and are **not reusable**; recompute each from the recipe in `BLOCKY_RIG_NOTES`.

**Ring light is a live decision:** `Player.gd` extracts the same `PlayerVisuals` for gameplay, so anything parented under it follows the survivor into a level. A stage-only prop must not be parented there.

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

**These are the only ones that need your call** — everything else the doc now settles, or a builder decides.

1. **Gameplay gets the new rig too?** Gameplay extracts the same `PlayerVisuals`, so the survivors change in-game, not just in the menu. §7.3b now wires gameplay animation properly — but confirm you want the in-game character changed at all, versus a menu-only reskin. (My recommendation: yes, both — otherwise the menu lies about what you play.)

2. **Nurse and gamer bases — pick the body.** The recolour base *is* the model, since `character-<x>.glb` hard-references `texture-<x>.png`. Nurse: `character-i` or `character-p`? Gamer: confirm `character-f`? The body shape/hair you see is that letter's.

3. **Doctor: `texture-j` (older, grey beard) or `texture-i` (younger, purple hair)?** Your reference shows a younger brown-haired man; neither matches exactly, so pick the closer trade.

4. **The ring light — carry it or leave it on the pedestal?** `PlayerVisuals` goes into gameplay, so a ring light parented there follows the survivor into a level. Stage-prop-only is the other option.

5. **Approve the two recoloured skins before wiring.** I'll render purple-hoodie and teal-scrubs previews and show you before they go in.

**Settled by this design, listed so you can overrule:** scale 0.6667; animation via a new `BlockyAnim` helper with `CharacterAnim.gd` untouched; palette-index recolour into new project textures rather than editing Kenney sources or tinting at runtime; hunter=`texture-k`, streamer=`texture-r`; the four defect fixes in §7; the `run`→`sprint` / no-`jump` mapping.
