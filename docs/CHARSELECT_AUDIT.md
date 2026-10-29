# Character Select — Audit (pre-rebuild)

**Scope:** `scripts/ui/CharacterSelect.gd` (381 lines), `scenes/ui/character_select.tscn` (87 lines),
plus the shared backdrop it instantiates (`scenes/world/title_background.tscn`, `scripts/ui/TitleBackground.gd`),
the persistence path (`scripts/core/SaveManager.gd`, `scripts/core/Player.gd`), the animation path
(`scripts/core/CharacterAnim.gd`), the candidate new rig (`assets/models/cc0/blocks/`), and the existing
probe (`tools/menu_render_probe.gd`).

**Bar:** `docs/anti-slop-principles.md`. Judged against it explicitly in §2.

Read-only audit. No file was modified except this document.

---

## 1. CURRENT STATE

### 1.1 What the .tscn ships (7 nodes) vs. what the script builds

`scenes/ui/character_select.tscn` is a skeleton. Everything the player actually sees or taps is
constructed in code.

| Node | Type | Authored in | Notes |
|---|---|---|---|
| `CharacterSelect` | `Control` | .tscn L12-19 | full-rect, script attached |
| `Background3D` | instance of `title_background.tscn` | .tscn L21-22 | `build_animals = false` |
| `UI` | `Control` | .tscn L24-31 | full-rect, `mouse_filter = 2` (IGNORE) |
| `UI/TitleLabel` | `Label` | .tscn L33-47 | Nosifer 52px, `CHOOSE YOUR SURVIVOR`, `DripMat` |
| `UI/SubtitleLabel` | `Label` | .tscn L49-65 | SpecialElite 22px, `Who will face the cemetery?` |
| `UI/StageZones` | `Control` | .tscn L67-74 | empty container, `mouse_filter = 2` |
| `UI/BottomBar` | `MarginContainer` | .tscn L76-87 | bottom-anchored, 144px logical tall |

Everything else — pedestals, discs, lights, contact shadows, the five survivors, the name buttons, the
action row, the name/desc/hint labels, the PLAY button, the step hint, and the five invisible tap zones —
is created at runtime in `_build_stage()` (L113-195) and `_build_ui()` (L200-311).

So the screen is a **code-authored screen with a scene-authored header**. The two headers are the only
part of the visual identity not reachable from the script (and, per §2.9, they carry a shader with
default parameters while the title screen's copy of the same shader is tuned).

### 1.2 Node-by-node behaviour

**Stage (3D), `_build_stage()` L113-195** — one loop over `PEDESTAL_X.size()`, five iterations, each
building four primitives + one character:

1. **Stone plinth** (L120-132): `CylinderMesh` top 0.64 / bottom 0.74 / height 0.5, 14 segments,
   at `(x, 0.45, -1.6)`, `StandardMaterial3D` albedo `(0.3, 0.29, 0.33)` roughness 0.9.
2. **Neon top disc** (L135-150): cylinder r 0.62 / h 0.06 at `(x, 0.73, -1.6)`, albedo
   `col.darkened(0.4)`, emission `col`, `emission_energy_multiplier = 0.9`. Material kept in
   `_disc_mats` for selection brightening.
3. **Glow light** (L153-159): `OmniLight3D` at `(x, 1.2, -1.3)`, `light_color = col`,
   `light_energy = 0.12`, `omni_range = 4.5`. No shadow. Kept in `_lights`.
4. **Contact shadow** (L162-174): cylinder r 0.78 / h 0.01 at `(x, 0.212, -1.6)`, transparent
   `(0.02, 0.02, 0.025, 0.65)`.
5. **Survivor** (L177-195): `load(CHARACTER_SCENES[i])`, take `PlayerVisuals`, discard the scene root,
   position at `(x, 0.76, -1.6)`, `_dim_model_materials(vis)`, then `CharacterAnim.setup(vis, cid)` and
   `sap.play("idle")`. Kept in `_models`.

**Idle bob, `_process()` L100-108** — `m.position.y = 0.76 + sin(_t * 1.2 + i * 1.3) * 0.03`, and the
PLAY button pulses `modulate.a` between 0.84 and 1.0 at `sin(_t * 3.4)`.

**UI, `_build_ui()` L200-311** — a `VBoxContainer` inside `BottomBar` containing three rows:
name buttons (L207-220, five buttons, `custom_minimum_size = (0, 54)`, `SIZE_EXPAND_FILL`,
wood style); an action row (L223-275) of `BACK (150, 58)` | centre label stack | `PLAY (300, 92)` with an
inline red `StyleBoxFlat`; and a step-hint label (L279-288). Then the five invisible tap zones (L293-311).

**Selection, `_select_character()` L344-362** — sets `selected_character`, then per index: light energy
`1.1` selected / `0.12` otherwise, disc emission `2.0` / `0.9`, name-button `modulate` white / `(0.66…)`.
Updates `_name_label` (tinted `CHARACTER_COLORS[index]`), `_desc_label`, `_hint_label`, then calls
`_confirm_selection()`.

**Routing** — `PLAY` → `level_select.tscn` (L376); `BACK` → `title_screen.tscn` (L381). Both play a click.

### 1.3 What the shared backdrop contributes

`character_select.tscn` L21 instantiates `title_background.tscn`, so the screen inherits: the
`WorldEnvironment` (L62-80), the `Camera3D` (L174-179), the floor, nine tombstones, three trees, the moon
mesh + glow quad + `DirectionalLight3D` (L300-307), `Ambient` omni (L309-313), `RimLight` (L333-336),
`VignetteLayer`, and three fill omnis `MenuFill` / `LeftFill` / `RightFill` (L352-370).

`TitleBackground._ready()` (L39-47) then runs `_setup_camera()`, `_hide_procedural()`, `_dress_floor()`,
`_build_graveyard()`, `_build_props()`, `_build_mist()` — i.e. the character select also renders the
authored KayKit/Kenney graveyard, the cobblestone floor, the mist blobs, and (because `build_animals`
is false) *not* the four flanking animals. This is the "graveyard backdrop" the task describes; it is
not authored in `character_select.tscn` at all.

**The camera is set in code, not in the scene.** `title_background.tscn` L175 carries
`transform = … (0, 0.3, 5) … fov = 90`, but `TitleBackground.gd` L50-61 overwrites it:

```gdscript
const TITLE_CAM_FOV = 62.0
const TITLE_CAM_POSITION = Vector3(-0.3, 1.5, 2.6)
const TITLE_CAM_TARGET = Vector3(-0.7, 0.95, -5.3)
```

`.bak`-visible evidence of the overwrite is in `.audit/boot_title.log` L9-11
(`before: (0.0, 0.3, 5.0) fov=90.0` → `after: (-0.3, 1.5, 2.6) fov=62.0`).

### 1.4 Persistence path today

`CharacterSelect._confirm_selection()` L365-371 → `Save.set_selected_character(CHARACTER_NAMES[index].to_lower())`
→ `SaveManager.set_selected_character()` L204-207 writes the member var, the dict, and calls `save_game()`.
`Player._selected_character_id()` L1001-1005 reads `save.get("selected_character")`. The API usage is
correct end-to-end. The *values* are wrong (§2.7).

---

## 2. DEFECTS FOUND

### 2.1 `_dim_model_materials()` is a **no-op** — it is overwritten two lines later (highest-value finding)

L188-194:

```gdscript
		vis.position = Vector3(x, MODEL_ORIGIN_Y, PEDESTAL_Z)
		bg.add_child(vis)
		_dim_model_materials(vis)          # sets material_override on every mesh
		var cid := …
		var sap := CharacterAnim.setup(vis, cid)
```

`CharacterAnim.setup()` → `setup_rigged()` → `apply_skin_raw()` (`CharacterAnim.gd` L143-153) ends with:

```gdscript
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
```

That replaces every `material_override` the dimming just installed. The dim workaround therefore does
nothing for all five characters on the current rig. The comment at L59-62 ("Dim a per-instance material
copy; the source scenes keep their own values") describes an effect that never reaches the screen.

It is *order-dependent dead code*: it only survives if `setup()` returns `null` — which is exactly what
happens with the blocky rig (§2.2). So the band-aid silently starts working the day the rig is swapped,
which is the opposite of predictable.

### 2.2 The blocky rig breaks the animation, tinting and scale assumptions

The candidate rig `assets/models/cc0/blocks/character-*.glb` was inspected directly (GLB JSON chunk):

```
character-a.glb  meshes: 6  nodes: 8  skins: 0  animations: 27  materials: 1  images: 1
materials[0].extensions = {"KHR_materials_unlit": {}}, baseColorTexture -> Textures/texture-a.png
animations: static, idle, walk, sprint, sit, drive, die, pick-up, emote-yes, … (27 clips)
animation "idle" channels target nodes 4,5,6,7 path=rotation   # node-animated, not bones
```

versus the current rig:

```
kenney_anim/model.glb  meshes: 1  nodes: 61  skins: 1  animations: 0  images: 0
```

Concrete consequences:

1. **`CharacterAnim.setup()` returns `null`.** `setup_rigged()` L48-59 bails before doing anything:
   ```gdscript
   	if model == null:
   		return null
   	var skels := model.find_children("*", "Skeleton3D", true, false)
   	if skels.is_empty():
   		return null
   ```
   `skins: 0` in the blocky GLB ⇒ no `Skeleton3D` ⇒ `_has_skeleton()` false ⇒ `null`.
   `CharacterSelect.gd` L193-194 guards with `if sap != null`, so `play("idle")` is simply skipped —
   **no animation at all**, only the bob.
2. **Per-character skin tinting is lost.** `CharacterAnim.SKINS` (L18-24) maps each survivor to a
   *Kenney animated-character* PNG (`skaterMaleA.png`, `survivorMaleB.png`, …) — rig-specific art. It is
   never even attempted for the blocky rig because `setup_rigged()` returns before `apply_skin_raw()`.
   The blocky GLB ships one shared material + `texture-a.png`, so all five survivors would render
   identically unless the rebuild adds its own tinting.
3. **The animation clips are not loadable by the current loader.** `_load_clip()` (L95-117) hardcodes
   `ANIM_DIR + nm + ".glb"` for `["idle","run","jump"]` in `kenney_anim/`. The blocky clips live inside
   `blocks/character-*.glb` and are node tracks, not bone tracks; `_retarget()` (L122-132) resolves bone
   names against a skeleton that does not exist.
4. **Scale is derived from a table entry that is wrong.** `assets/models/MODEL_SCALE_TABLE.md` L38 says
   `block-character … 9.0 units … recommended scale 0.2`, based on raw accessor bounds
   (`[8.0, 9.0, 8.0]`, L55). Composing the node transforms of `character-a.glb` gives a different answer:

   | node | translation | mesh accessor Y | composed Y |
   |---|---|---|---|
   | `leg-left` | `(0.2, 1.0, 0)` | `-1.0 … 0.0` | `0.0 … 1.0` |
   | `torso` | `(0, 0.7, 0)` | `0.3 … 1.2` | `1.0 … 1.9` |
   | `arm-left` | `(0.4, 1.1, -0.1)` | `-1.0 … 0.1` | `0.1 … 1.2` |
   | `head` | `(0, 1.2, 0)`, scale `0.1` | `-4 … 8` | `0.8 … 2.0` |

   ⇒ the model is **2.0 units tall with feet at local y = 0**, so the correct human-height scale is
   `1.8 / 2.0 = 0.9`, not `0.2`. The `9.0` in the table is the un-transformed head accessor (`8.0 × 0.1`
   is not applied). Applying 0.2 would make the survivors 0.4 m tall.

   The feet-at-0 result is good news: `MODEL_ORIGIN_Y` (L37) happens to be correct for this rig too —
   but it is correct by luck, and there is no derivation to prove it.

### 2.3 Hardcoded rig assumptions that will not survive the swap

| Assumption | Where | Why it breaks |
|---|---|---|
| `scale = 0.00425` | `character_{gamer,doctor,nurse,streamer,hunter}.tscn` L60/L96/L108/L111/L108 (Model node) | derived from `kenney_anim/model.glb` (`MODEL_SCALE_TABLE.md` L37). The blocky rig needs ≈0.9, i.e. **212× larger**. Nothing normalises it: unlike `Player.gd`, the menu never measures an AABB. |
| `PlayerVisuals` subtree with a child literally named `Model` | `CharacterSelect.gd` L182; `CharacterAnim.gd` L50 | `setup_rigged()` prefers `get_node_or_null("Model")`; the fallback "any child with a skeleton" loop (L53-57) exists but is skeleton-gated, so a node-animated rig must keep the name `Model` or the loader must be rewritten. |
| Feet at local y = 0 | `CharacterSelect.gd` L37 comment `# rigged models carry feet at local 0` | true for the blocky rig (verified above) but unverified and unenforced. `Player.gd` L962-964 re-grounds by AABB (`vis.position.y = -aabb.position.y`) precisely because it cannot trust this; the menu does not. |
| `CharacterAnim.SKINS` texture names | `CharacterAnim.gd` L18-24 | Kenney animated-character skins; meaningless for a voxel rig. |
| Prop offsets | e.g. doctor `Prop` at `(0.0, 1.02, 0.14)` (`character_doctor.tscn` L99), gamer controller at `(0.28, 0.62, 0.24)` (L63) | authored against a 0.00425 rig; blocky proportions (2.0 units, arms at y 0.1-1.2, half-width 0.4) are a different skeleton entirely. |

There is also an unexplained discrepancy: `Player.gd` L958-961 asserts

```gdscript
			# The menu-built scenes sink the model so its feet rest on a
			# pedestal (-0.8035 baked in).
```

but every `character_*.tscn` Model node carries translation `(0, 0, 0)` with scale `0.00425` only
(e.g. `character_doctor.tscn` L95-96). Either the comment is stale or a bake is missing. Listed in §6.

### 2.4 The stage tap zones **do not line up with the characters**, and mis-select on the right half

The zones are placed with a linear, aspect-blind formula (L40-42, L294-300):

```gdscript
# is 10.92 world units wide at the pedestal depth, so frac = 0.5 + x / 10.92.
const STAGE_WORLD_WIDTH := 10.92
	…
		var frac := 0.5 + PEDESTAL_X[i] / STAGE_WORLD_WIDTH
		z.anchor_left = frac - 0.075
		z.anchor_right = frac + 0.075
		z.anchor_top = 0.10
		z.anchor_bottom = 0.76
```

That models an orthographic camera centred on the stage. The real camera is perspective
(`Camera3D.fov = 62`, default `keep_aspect = KEEP_HEIGHT`, so 62° is the **vertical** FOV) and is both
offset and yawed (`TITLE_CAM_POSITION (-0.3, 1.5, 2.6)` looking at `(-0.7, 0.95, -5.3)`). Projecting the
five feet positions `(PEDESTAL_X[i], 0.76, -1.6)` through that camera at 1600×900 gives:

| x | character drawn at (screen frac) | zone centre (code) | zone span | character inside its own zone? |
|---|---|---|---|---|
| −3.4 | 0.193 | 0.189 | 0.114–0.264 | ✅ |
| −1.7 | 0.371 | 0.344 | 0.269–0.419 | ✅ |
| 0.0 | 0.557 | 0.500 | 0.425–0.575 | ✅ |
| 1.7 | **0.750** | 0.656 | 0.581–0.731 | ❌ **outside** |
| 3.4 | **0.952** | 0.811 | 0.736–0.886 | ❌ **outside** |

Two live bugs follow:

* **Mis-selection.** The streamer is drawn at 0.750, which falls inside the *hunter's* zone
  (0.736–0.886). Tapping the streamer's body selects HUNTER.
* **Dead tap.** The hunter is drawn at 0.952; no zone covers it. Tapping the hunter's body does nothing —
  the exact class of bug the code comments (L290-292) claim to have fixed.

The error grows to the right (0 → 6 → 43 → 91 → 151 → 225 logical px at 1600 wide) because the camera
yaw and perspective compress the left of the frame and stretch the right.

**And it is aspect-dependent**, because the formula has no aspect term. Recomputed per viewport width
(height fixed at 900 logical):

| logical viewport | horizontal FOV | left→right error (px) |
|---|---|---|
| 1600×900 (editor, `project.godot` L31-32) | 93.8° | +6 … +225 |
| 2000×900 (20:9 phone landscape) | 106.3° | +131 … +100 (sign flips) |
| 2400×900 | 116.1° | +256 … −25 |
| 900×900 (square) | 62.0° | −211 … +443 |

The constant `10.92` is the stage's world width at a *different* aspect: the actual width at the pedestal
depth is **9.01** world units at 16:9 and **11.26** at 20:9. The value 10.92 matches neither, which is
consistent with it having been tuned by eye on a device wider than the editor default.

**Why the probe never caught it:** `tools/menu_render_probe.gd` L80-86 asserts only that the *zone's own*
height is ≥ 44 px, and L118-125 taps `zones[2]` at `control.get_global_rect().get_center()` — the centre
of the zone, not the position of the drawn character. A self-consistent-but-wrong zone layout passes.

### 2.5 `BottomBar` is 144 px tall but its content needs ~186 px

`character_select.tscn` L76-87 gives `BottomBar` `offset_top = -158`, `offset_bottom = -14` → 144 logical
px (of a 900-tall viewport). `_build_ui()` fills it with a `VBoxContainer` (L202-204, `separation = 8`)
holding three rows whose minimum heights are:

* name-button row: `custom_minimum_size = Vector2(0, 54)` (L213) → 54
* action row: `max(BACK 58, PLAY 92, centre label stack 26+15+17)` (L228, L255, L240-249) → 92
* step hint: 18px font (L282) → ≈24
* two separations → 16

≈ **186 px into 144 px**. `MarginContainer` does not clip (`clip_contents` is false by default), so the
content overflows upward past the bar's top edge and silently overlaps the stage. The PLAY button alone
(92 px) is two-thirds of the bar's height.

### 2.6 Dead code, unused vars, duplicated source of truth

* **`CharacterAnim._apply_skin()` (L136-138) is never called.** A grep for `_apply_skin(` across the
  project returns only its own definition; all real callers go through `apply_skin_raw()` or `setup()`.
  It also duplicates `setup()`'s logic (L40-41).
* **`CharacterSelect._zone_buttons` is write-only.** Appended at L311, read only by a debug `print` at
  L96. Zones are never highlighted, so there is no visual affordance that the characters are tappable.
* **`selected_character` (L44) shadows `Save.selected_character`** — two sources of truth for the same
  fact. `tools/menu_render_probe.gd` L121/L137 reads the member var, so the probe tests the shadow, not
  the persisted value.
* **`print()` in production** at L96 and L368. `docs/anti-slop-principles.md` L14: *"No `console.log` in
  production — use proper logging or remove"*.
* **Descriptions are a third source of truth and contradict the stats files.**
  `CharacterSelect.CHARACTER_DESCS` (L25-31) vs `assets/materials/stats_*.tres`:

  | id | screen desc (L25-31) | `stats_*.tres` description | conflict |
  |---|---|---|---|
  | gamer | "Speed and snacks on demand" | "Balanced fighter with quick reflexes" (`stats_gamer.tres` L9) | different, and `move_speed = 5.0` is *not* the fastest |
  | doctor | "Tanky frame, medkits go further" | "Support medic with healing aura" (L9) | `max_health = 110`; hunter has 120 — "tanky" is wrong |
  | nurse | "Fast healer, fragile" | "Fast healer, weaker attack" (L9) | duplicate with drift |
  | streamer | "Trades health for damage" | "High crit showman, fragile" (L9) | different |
  | hunter | "Ranged specialist, steady aim" | "Tanky ranged specialist" (L9) | different |

  `CharacterStats` also carries `display_name` and `character_color`, and **none of the five `.tres` files
  is loaded by any code in the project** (grep for `stats_` / `CharacterStats` finds only the class, the
  `Player.character_stats` export that is never assigned, and the docs).
  `docs/BRANCH_WORKFLOW.md` L11 records `fix/character-stats` as still pending.

* **`CHARACTER_COLORS` (L18-24) also duplicates `character_color`** in each `.tres` and the two disagree:
  gamer is neon pink `(1.0, 0.32, 0.72)` on screen but `(0.3, 0.5, 0.9)` (blue) in `stats_gamer.tres` L29;
  hunter is neon yellow on screen but `(0.4, 0.32, 0.2)` (brown) in `stats_hunter.tres` L29.
* **Five parallel arrays indexed by `i`** — `CHARACTER_SCENES`, `CHARACTER_NAMES`, `CHARACTER_COLORS`,
  `CHARACTER_DESCS`, `PEDESTAL_X` (L10-34). Any insertion or reorder silently mis-pairs them. Only `cid`
  is derived (L191).

### 2.7 Selected-character persistence: writes correctly, **reads never**

`_ready()` L95 calls `_select_character(1, false)`, and `_confirm_selection()` persists on every call
(L371) including that initial one. So **entering the screen always writes `"doctor"` to disk**, discarding
whatever the player previously chose. The screen never reads `Save.selected_character` to preselect.

This is a known, still-open bug: `docs/BRANCH_WORKFLOW.md` L12 —
`- fix/char-select-overwrite — stop CharacterSelect forcing doctor on entry (pending)`.

Secondary effects: `Save.save_game()` (which serialises the whole dict) runs on every tap of every
character button and on every screen entry.

The default index `1` (L44, comment "doctor default, matches the old screen") happens to match
`SaveManager._default_save_data()["selected_character"] = "doctor"` (L137), so the bug is invisible on a
fresh save and only shows after the player picks someone else.

### 2.8 Anti-slop violations, itemised

| Principle (`anti-slop-principles.md`) | Violation |
|---|---|
| No god functions (L11) | `_build_ui()` L200-311 is 112 lines doing five unrelated jobs (name buttons, action row, labels, PLAY styling, step hint, tap zones). `_build_stage()` L113-195 is 83 lines doing six. |
| No magic numbers (L15) | `0.00425` (5 × .tscn); `10.92` (L42); `0.075` (L297-298); `0.10` / `0.76` anchors (L299-300); `1.3` bob phase (L105); `0.12` / `1.1` light energy (L156, L349); `0.9` / `2.0` emission (L147, L351); `0.78` / `0.84` dim channels (L70); `0.55` / `0.12` / `1.0` glow (L82-84); `3.4` play pulse (L108); `0.84` / `0.16` (L108); `1.3` / `0.06` / `0.64` / `0.74` / `0.62` / `0.78` / `0.212` pedestal geometry (L120-169). |
| No emoji as icons (L21) | `play.text = "PLAY  \u25b6"` (L254) — a Unicode glyph standing in for an icon. The comment at L254 ("right-pointing triangle: obvious way forward") is the tell: it is a stand-in, not an icon. |
| No decorative gradients by default (L26) | `steps` label (L279-288) adds an outline purely for legibility — acceptable — but the `SubtitleLabel` / `TitleLabel` header styling lives in the .tscn while every other control is code-styled; the screen has no single place that defines its visual language. |
| No copy-paste with slight variations (L12) | `character_{doctor,nurse,streamer,hunter}.tscn` are 187–202-line near-duplicates and `character_gamer.tscn` is a 143-line variant of the same template (identical `PlayerCollision`, `Camera`/`SpringArm3D`, `MobileControls`/`JoystickArea`, `HitFeedback` blocks) differing only in four material colours, one mesh, and the prop. `_style_button()` (L314-324) already abstracts the button styling, so the pattern is known — it just was not applied here. |
| No unused imports or properties (L13) | `CharacterAnim._apply_skin()`; `CharacterSelect._zone_buttons`; `TitleScreen`'s `@onready` refs are redundant with the .tscn `[connection]`s (see §2.9). |
| No uniform padding (L25) | `_wood_style()` L335-338 applies uniform content margins `16 / 16 / 8 / 8` to every wood button regardless of context. |
| Thumb zone, bottom 2/3 (L31) | The stage zones run `anchor_top = 0.10` → `0.76` (L299-300), i.e. they cover the **top** 76% of the screen, and the character bodies sit at screen y 0.38–0.59 — the middle of the screen, well above the thumb zone. The primary action (PLAY) is correctly bottom-anchored. |
| No hover states (L24, L32) | `_style_button()` defines `hover` and `focus` styleboxes (L316, L318) and `_wood_style` is applied to them; on touch these never fire. The PLAY button also defines `hover` (L265) and `pressed` (L266) using the *same* stylebox. Harmless but dead. |

**Touch targets themselves pass.** Verified against the 44×44 minimum: name buttons 54 px tall (L213),
BACK 150×58 (L228), PLAY 300×92 (L255), zones `0.15 × viewport width` wide × `0.66 × viewport height` tall
(L297-300) — 135×594 even at a 900-px-wide logical viewport. The *sizes* are fine; the *positions* are
wrong (§2.4).

### 2.9 Consistency with the adjacent screens (flow and pattern)

* **Routing is consistent and correct** for the intended flow: title `PLAY` → `character_select`
  (`TitleScreen.gd` L52), character select `PLAY` → `level_select` (L376), `BACK` → title (L381).
* **But `LevelSelect._on_back()` (L171-173) also goes to `title_screen`**, skipping character select.
  So the flow is title → char-select → level-select → title, and the only way back to character select is
  through the title. Worth deciding deliberately rather than by omission.
* **Wiring pattern is inconsistent.** `TitleScreen` wires its five buttons in the `.tscn`
  (`title_screen.tscn` L244-248 `[connection]` blocks) *and* defensively in code with `is_connected`
  guards (`TitleScreen.gd` L23-32). `CharacterSelect` wires everything in code. `LevelSelect` wires in
  code too. Two of three screens agree; the third carries redundant wiring.
* **Font loading is duplicated three ways.** `CharacterSelect` L90-92 loads
  `SpecialElite-Regular.ttf` behind a `ResourceLoader.exists()` check and stores it in `_btn_font`;
  `LevelSelect` L8-9 `preload`s the same font plus Creepster; `TitleScreen` uses .tscn `ext_resource`s.
  `character_select.tscn` already has the font as `ExtResource("5_se")` (L7) *and* loads it again in code.
* **`TitleLabel`'s blood-drip shader is untuned here.** `character_select.tscn` L9-10 creates
  `ShaderMaterial` `DripMat` with only `shader = ExtResource("3_drip")` — no parameters. `title_screen.tscn`
  L21-28 sets six (`drip_speed 0.8`, `drip_intensity 0.55`, `drip_length 0.18`, `blood_color`, `blood_dark`,
  `text_color`). So the same shader runs on two screens with different (default vs. authored) looks.

---

## 3. WHAT TO KEEP

These are genuinely good and should survive the rebuild unchanged:

1. **The single continuous 3D stage concept.** Five survivors on pedestals inside the graveyard, no card
   grid, no `SubViewport` per card. The header comment (L1-5) records why: cards "swallowed taps and hid
   the cemetery behind five boxes". That reasoning is sound and matches the reference art. Keep the
   architecture; replace the rig.
2. **The `PlayerVisuals` extraction pattern.** `full.get_node_or_null("PlayerVisuals")` →
   `remove_child` → `full.free()` (L182-187). This is *the same pattern* `Player.gd` L951-954 uses for
   gameplay, so the menu and the game show the identical visuals from one source. Keeping it means a rig
   swap in `character_*.tscn` propagates to gameplay for free. Keep verbatim.
3. **Named, commented layout constants.** `PEDESTAL_X`, `PEDESTAL_Z`, `PEDESTAL_TOP`, `MODEL_ORIGIN_Y`,
   `BOB_AMPLITUDE`, `BOB_SPEED` (L34-39) each carry a comment explaining *why* (`# rigged models carry
   feet at local 0 -> disc top (0.76)`). The failure is that some of these are wrong, not that they are
   magic. The fix is to *derive* them, not to delete them.
4. **The invisible-tap-zone approach.** A `flat` `Button` with a `StyleBoxEmpty` for all four states
   (L301-307) layered over the character is the right primitive — it keeps hit-testing in the GUI system
   and avoids 3D picking on mobile. Keep the mechanism; replace the anchor math with
   `Camera3D.unproject_position()`.
5. **`Save.set_selected_character()` as the persistence API.** It writes the member var *and* the dict
   *and* calls `save_game()` (L204-207) — the correct shape. `_confirm_selection`'s comment (L369-370)
   explains the "persist immediately" decision well. Keep the call; stop making it on entry (§4.5).
6. **The existing probe.** `tools/menu_render_probe.gd` is unusually good: it boots with real autoloads,
   asserts 5 models + 5 zones (L69-79), does a *hard geometry* assertion that each survivor's lowest mesh
   vertex sits on the pedestal within `[0.60, 0.90]` (L88-106), simulates real taps on a zone and a name
   button and asserts the resulting index (L118-141), and walks the full PLAY → level → game routing
   (L143-202). Keep it and extend it (§4.6) — it is the safety net for this rebuild.
7. **`Audio.play_menu_music()` on entry (L97) and `play_click()` on every button** — consistent with the
   title screen and with `Audio.stop_music()` at `TitleScreen.gd` L51.

---

## 4. WHAT TO REBUILD

### 4.1 The rig loader — derive the transform, never hardcode it

Replace the baked `0.00425` with a measurement, using the pattern that already exists in this codebase:
`Player.gd._model_aabb()` (L1064-1074) + `_normalise_model_transform()` (L1007-1014) scale to
`CHARACTER_HEIGHT / aabb.size.y` and ground by `-aabb.position.y * s`. `TitleBackground._place()`
(L119-133) does the same thing for every prop in the graveyard.

For the blocky rig the numbers are known (verified in §2.2.4): composed height **2.0 units**, feet at
**y = 0** ⇒ scale **0.9** for a 1.8 m survivor. Do not use `MODEL_SCALE_TABLE.md`'s `0.2`.

### 4.2 The animation path

`CharacterAnim.setup()` cannot serve this rig. Two options, both cheap:

* **Extend `CharacterAnim`** with a node-animated branch: if no `Skeleton3D` is found, keep the GLB's own
  `AnimationPlayer` (the blocky GLB imports with 27 clips — `animation/import=true` in
  `character-a.glb.import` L33) and play `"idle"` directly. No retargeting needed; the tracks already
  target the model's own nodes.
* **Or drive the menu locally** from a small per-rig config, leaving gameplay's `CharacterAnim` alone.

Either way the menu's `sap.play("idle")` (L194) must be replaced by something that reports failure loudly.
A silent `if sap != null` guard is what let "no animation" ship.

The idle bob (L100-108) should stay but be re-specified: with a real `idle` clip, a 0.03 m vertical bob at
1.2 rad/s will fight the clip's own motion. Decide: bob *or* clip, or apply the bob to the pedestal/disc
rather than the character.

### 4.3 Per-character identity (the `SKINS` replacement)

`CharacterAnim.SKINS` (L18-24) must not be reused — it names Kenney animated-character PNGs. The blocky
rigs ship one shared material with `baseColorTexture = texture-a.png` and `KHR_materials_unlit`. The
replacement needs:

* a per-survivor map from `character_id` → (blocky model file, tint colour), keyed off the same ids the
  rest of the project uses (`"gamer"`, `"doctor"`, …), and
* a tinting step that sets `material_override` on the model's meshes *after* any animation setup, so the
  ordering bug in §2.1 cannot recur.

This is also where `stats_*.tres` should finally be used: `CharacterStats.character_color` and
`.display_name` and `.description` already exist and are the project's intended single source of truth.

### 4.4 Tap zones — derive from the camera, not from a width constant

Delete `STAGE_WORLD_WIDTH` (L42) and the `0.5 + x / 10.92` formula (L296). Instead, each frame (or on
`get_viewport().size_changed`), take the *world* position of each pedestal —
`(PEDESTAL_X[i], MODEL_ORIGIN_Y + half_char_height, PEDESTAL_Z)` — and project it with
`camera.unproject_position()`, then anchor the zone to the resulting screen fraction with a half-width
derived from the character's projected width. That is automatically correct for every aspect ratio and
automatically re-corrects if the camera or `PEDESTAL_X` changes.

Cheap interim alternative if a full unproject is unwanted: make the zone span the *pedestal* rather than a
fixed 0.15 — the pedestal edges project to 0.117/0.270, 0.293/0.451, 0.475/0.640, 0.665/0.837, 0.863/1.042
at 16:9 — but that still needs the camera, so just do the unproject.

### 4.5 Persistence — read on entry, do not write

In `_ready()`: look up `Save.selected_character`, map it to an index, and call
`_select_character(idx, false)`. Do not persist on entry — only on a real tap. That closes
`fix/char-select-overwrite` (`docs/BRANCH_WORKFLOW.md` L12) and removes the write-on-every-tap.

### 4.6 The probe needs one new assertion

Add an alignment check: for each pedestal, project the character's world position with the *scene's own*
camera and assert the resulting screen point is inside the corresponding zone's `get_global_rect()`. The
existing probe taps the zone centre (L120, L27) so it cannot detect §2.4. Without this assertion the same
bug can be reintroduced by the rebuild.

### 4.7 Structural clean-up (required by the anti-slop bar)

* Split `_build_ui()` (112 lines) into `_build_name_row()`, `_build_action_row()`, `_build_step_hint()`,
  `_build_stage_zones()`.
* Split `_build_stage()` (83 lines) into `_build_pedestal(i)`, `_build_disc(i)`, `_build_pedestal_light(i)`,
  `_build_contact_shadow(i)`, `_spawn_survivor(i)`.
* Replace the five parallel arrays with one `const CHARACTERS: Array[Dictionary]` (or load the five
  `stats_*.tres` and add a scene path), so index drift is impossible.
* Remove `_dim_model_materials()` (§2.1) and `CharacterAnim._apply_skin()`.
* Remove the two `print()`s or route them through `DevMode` (which already exists and is used by
  `TitleBackground.gd` L18, L131, L236).
* Replace `"PLAY  \u25b6"` with either plain text or a real icon resource.

---

## 5. LIGHTING / LAYOUT / ANIMATION SPECIFICS

All values below are the *current* ones, quoted for tuning rather than guessing.

### 5.1 Camera (inherited from `title_background.tscn`, set in code)

| Property | Value | Source |
|---|---|---|
| position | `(-0.3, 1.5, 2.6)` | `TitleBackground.gd` L23 |
| look-at target | `(-0.7, 0.95, -5.3)` | `TitleBackground.gd` L24 |
| fov | `62.0` (vertical) | `TitleBackground.gd` L20, L57 |
| near / far | `0.1` / `120.0` | `TitleBackground.gd` L21-22 |
| scene-authored (dead) | `transform … (0, 0.3, 5)`, `fov = 90`, `near 0.1`, `far 100` | `title_background.tscn` L174-179 |
| derived horizontal FOV @1600×900 | 93.8° (stage width 9.01 world units at the pedestal depth) | computed |
| derived horizontal FOV @2000×900 | 106.3° (stage width 11.26) | computed |

`STAGE_WORLD_WIDTH = 10.92` (`CharacterSelect.gd` L42) matches neither.

### 5.2 Pedestal geometry (all in `CharacterSelect.gd`)

| Element | Mesh | Position | Material |
|---|---|---|---|
| Plinth | `CylinderMesh` top `0.64`, bottom `0.74`, h `0.5`, 14 seg | `(x, 0.45, -1.6)` L127 | albedo `(0.3, 0.29, 0.33)`, roughness `0.9` L129-130 |
| Neon disc | `CylinderMesh` r `0.62`, h `0.06`, 14 seg | `(x, 0.73, -1.6)` L142 | albedo `col.darkened(0.4)`, emission `col`, energy `0.9` L144-147 |
| Contact shadow | `CylinderMesh` r `0.78`, h `0.01`, 18 seg | `(x, 0.212, -1.6)` L169 | transparent `(0.02, 0.02, 0.025, 0.65)` L171-172 |
| Pedestal light | `OmniLight3D`, range `4.5`, no shadow | `(x, 1.2, -1.3)` L154 | colour `col`, energy `0.12` L156 |

Plinth spans y `0.20 … 0.70`; disc spans y `0.70 … 0.76`; `MODEL_ORIGIN_Y = 0.76` (L37) therefore equals
the disc top exactly — that part is self-consistent.

Pedestal spacing is `1.7` (L34) while the plinth radius is `0.74` and the light range is `4.5`, so the
five omnis overlap heavily and their colours bleed into each other. With one at `1.1` energy (L349), the
neighbouring pedestals are tinted by it.

### 5.3 Selection states

| Element | Unselected | Selected | Line |
|---|---|---|---|
| Pedestal light energy | `0.12` | `1.1` | L156, L349 |
| Disc `emission_energy_multiplier` | `0.9` | `2.0` | L147, L351 |
| Name button `modulate` | `(0.66, 0.66, 0.66)` | `(1, 1, 1)` | L353 |
| Name label colour | — | `CHARACTER_COLORS[index]` | L356 |
| Hint label | — | `"<NAME> selected. Tap PLAY to continue"` | L361 |

### 5.4 Per-character neon colours (`CharacterSelect.gd` L18-24)

| id | RGB | Description |
|---|---|---|
| gamer | `(1.0, 0.32, 0.72)` | neon pink |
| doctor | `(0.25, 0.45, 1.0)` | neon blue |
| nurse | `(0.15, 0.95, 1.0)` | neon cyan |
| streamer | `(0.72, 0.38, 1.0)` | neon purple |
| hunter | `(0.95, 0.85, 0.25)` | neon yellow |

(These disagree with `character_color` in the five `stats_*.tres` — see §2.6.)

### 5.5 Bloom / environment workaround, exact before-and-after

`_soften_bloom()` L74-85 duplicates the instanced `Environment` and overrides three fields:

| Field | `title_background.tscn` L62-80 | `_soften_bloom()` L82-84 |
|---|---|---|
| `glow_intensity` | `1.0` | `0.55` |
| `glow_bloom` | `0.32` | `0.12` |
| `glow_hdr_threshold` | `0.8` | `1.0` |

Untouched here: `background_color (0.12, 0.13, 0.18)`, `ambient_light_color (0.5, 0.52, 0.6)`,
`ambient_light_energy 0.95`, `fog_light_color (0.28, 0.31, 0.40)`, `fog_density 0.03`,
`tonemap_mode 3`, `adjustment_brightness 1.02` / `contrast 1.07` / `saturation 1.15`.

`_dim_model_materials()` L58-71 multiplies each mesh's `albedo_color` by `(0.78, 0.78, 0.84)` —
deliberately non-uniform, blue least attenuated. **This never reaches the screen** (§2.1).

### 5.6 Backdrop lights the stage also receives

| Light | Type | Position / rotation | Colour | Energy | Range |
|---|---|---|---|---|---|
| `Moon` | `DirectionalLight3D` | `rot (-55, -35, 0)` | `(0.75, 0.8, 0.9)` | `2.4` | shadows on, fade 8.0 |
| `Ambient` | `OmniLight3D` | `(0, 4, 0)` | `(0.35, 0.3, 0.25)` | `0.9` | `50.0` |
| `RimLight` | `DirectionalLight3D` | rot from `(0.906,0,0.423,…)` | `(0.55, 0.62, 0.95)` | `0.4` | — |
| `MenuFill` | `OmniLight3D` | `(-0.3, 2.4, -1)` | `(0.95, 0.82, 0.68)` | `1.8` | `12.0` |
| `LeftFill` | `OmniLight3D` | `(-2.8, 1.8, -1.2)` | `(0.95, 0.85, 0.7)` | `2.7` | `9.0` |
| `RightFill` | `OmniLight3D` | `(2.8, 1.8, -1.2)` | `(0.95, 0.85, 0.7)` | `2.0` | `9.0` |
| lantern ×2 | `OmniLight3D` (built in code) | `(±1.7, 1.3, -4.9)` | `(1.0, 0.72, 0.38)` | `2.4` | `5.5` |

Plus the five per-pedestal omnis from §5.2. **Total omni lights in the character-select frame: 11**
(5 pedestal + Ambient + MenuFill + LeftFill + RightFill + 2 lanterns), on the `mobile` renderer
(`project.godot` L129). Worth profiling — this is the kind of thing that quietly costs frames on a phone.

Note the fills sit at `z = -1` to `-1.2` and the pedestals at `z = -1.6`, i.e. the fill lights are
*behind* the survivors relative to the camera, so they read as rim/back light rather than fill.

### 5.7 Animation

| Motion | Value | Source |
|---|---|---|
| Survivor bob | `y = 0.76 + sin(_t * 1.2 + i * 1.3) * 0.03` | L105, L38-39 |
| PLAY pulse | `modulate.a = 0.84 + 0.16 * (0.5 + 0.5 * sin(_t * 3.4))` | L108 |
| Per-character idle clip | `CharacterAnim.setup(vis, cid).play("idle")` | L192-194 |
| Rotating/floating props | none | — |

The bob is a pure sine applied to `position.y` *after* the character's transform, so it overrides any
vertical motion the `idle` clip produces on the root. `_t` accumulates `delta` unbounded (L101) — fine for
hours, but note it is never wrapped.

---

## 6. OPEN QUESTIONS

Things I could not determine from the code alone:

1. **Which of the 18 blocky models maps to which survivor?** `assets/models/cc0/blocks/character-a.glb`
   … `character-r.glb` exist; nothing in the repo records the mapping. `tools/charcast_probe.gd` renders
   all 18 into `tools/charcast_blocks.png` for a human to pick from, but no selection was ever written
   back. The five roles need `a`–`r` assignments before the rebuild can start.
2. **Is the intended rig the node-animated `.glb` (no skeleton), or is a rigged blocky variant coming?**
   The `.glb` files have `skins: 0` and 27 node-animated clips. If the intent is skeletal animation,
   the source assets are different from what is on disk.
3. **Should the blocky rig replace the gameplay model too?** `Player.gd` L946-976 prefers the
   `character_*.tscn` `PlayerVisuals`, so editing those five scenes propagates to gameplay automatically.
   That is almost certainly desirable, but it is a bigger change than "rebuild the menu" and should be
   confirmed.
4. **What is the target device aspect ratio?** It determines the horizontal FOV and therefore both the
   `10.92` constant and the zone layout. `project.godot` L31-32 declares 1600×900 with
   `stretch/mode = "canvas_items"` and `stretch/aspect = "expand"`, so real phones get a *wider* logical
   viewport than the editor. 20:9 and 24:9 both produce different errors (§2.4).
5. **Where does `-0.8035` come from?** `Player.gd` L958-961 says the menu-built scenes bake a `-0.8035`
   sink so the model's feet rest on the pedestal, but the `Model` nodes in all five `character_*.tscn`
   carry translation `(0, 0, 0)` with scale `0.00425`. Either the comment is stale, a bake was lost, or
   the sink lives inside the imported scene. The current survivor height and foot line should be measured
   in-engine before the rig is swapped, so the "before" number exists.
6. **Is the 11-omni-light count actually a problem on the target phone?** It needs a device profile, not
   a code read.
7. **Should `LevelSelect`'s BACK go to character select instead of the title?** Currently
   `LevelSelect.gd` L171-173 routes to `title_screen`, so the character select is only reachable via
   title → PLAY.
8. **What is the intended idle behaviour for the rebuild** — a real `idle` clip, the existing bob, or
   both? They conflict (§5.7).
9. **`SaveManager.gd` L17** claims `"gamer" is a 64-vert blockout` while `character_gamer.glb` measures
   `[1.300, 2.275, 0.775]` (`MODEL_SCALE_TABLE.md` L140) — history I could not reconstruct. It matters
   only because it explains why "doctor" became the default, which the rebuild may want to revisit.

---

## Appendix — verification method

* Script, scene and resource contents were read directly (line numbers cited throughout).
* The blocky rig's structure, materials and animation clips were read from the GLB JSON chunk
  (`struct` + `json`, no external tooling); node transforms were composed by hand to obtain the 2.0-unit
  height and feet-at-0 result.
* Screen fractions in §2.4 were computed by projecting world points through the camera described in
  `TitleBackground.gd` L20-24 using Godot's convention (`Camera3D.fov` is vertical; `keep_aspect`
  defaults to `KEEP_HEIGHT`), with the logical viewport from `project.godot` L31-32.
* No engine run was performed as part of this audit; `tools/menu_render_probe.gd` is the existing
  in-engine check and its assertions were read to establish what *is* covered and what is not.
