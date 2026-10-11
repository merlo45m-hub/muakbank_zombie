# Character Wiring Audit — survivor rigs, props, zombies, save chain

**Scope:** how the five survivor characters (`character_{gamer,doctor,nurse,streamer,hunter}.tscn`) and their
per-character props are wired into the running game, every place the current Kenney *Animated Characters
Survivors* rig (`assets/models/cc0/kenney_anim/model.glb`, scale `0.00425`) is hardcoded, and what must change
to move the survivors onto a different rig (candidate: `assets/models/cc0/blocks/character-*.glb`, Kenney Blocky
Characters, 18 chars).

**Method:** static read of the repo only. No files modified. Every claim cites `file:line`. Where a claim could
not be settled from source alone it is marked **undetermined** rather than guessed.

**Repo root:** `/storage/emulated/0/Games/Muakbank_zombie`

---

## 0. Executive summary

| # | Finding | Severity for a rig swap |
|---|---------|------------------------|
| 1 | The character scene is instantiated **whole** and only its `PlayerVisuals` subtree survives; the scene root (script, camera, collision, weapon system) is freed. Both the menu and gameplay do this. | Low — one extraction point per site |
| 2 | The rigged model + `0.00425` scale are hardcoded in **9 `.tscn` files** (5 survivors + 4 rigged zombies). | High |
| 3 | `CharacterAnim.gd` is a **skeleton-only** pipeline: it refuses any model without a `Skeleton3D` and retargets clips by bone name. The Kenney *Blocky* set has **0 skins / 0 joints** (verified in the GLB JSON) → the entire skeletal path returns `null`. | **Critical** |
| 4 | Props are **not bone-attached**. They are `MeshInstance3D` children of `PlayerVisuals` with hand-tuned local transforms in feet-origin space, and **no `.gd` file reads them**. | High (silent visual break, no crash) |
| 5 | `Player.character_stats` is **never assigned anywhere in the codebase**. All five `stats_*.tres` files are dead assets. Every character plays identically today. | Independent of the rig swap, but must be fixed to make per-character rigs meaningful |
| 6 | The 4 rigged zombies share the rig **through `CharacterAnim`, not through the survivor scenes** — so editing only `character_*.tscn` leaves zombies intact, but any change to `CharacterAnim.gd` / `ANIM_DIR` / the shared `model.glb` hits them. | High (coupling is indirect and easy to miss) |

---

## 1. Character loading chain

### 1.1 Step by step

| Step | Site | Code |
|---|---|---|
| 1. Menu → character select | `scripts/ui/TitleScreen.gd:52` | `get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")` |
| 2. Select screen knows the five scenes | `scripts/ui/CharacterSelect.gd:10-16` | `const CHARACTER_SCENES: Array[String] = ["res://scenes/characters/character_gamer.tscn", ...]` |
| 3. Select screen displays each survivor | `scripts/ui/CharacterSelect.gd:177-195` | `var scene: PackedScene = load(CHARACTER_SCENES[i])` → `var full := scene.instantiate()` → `var vis: Node3D = full.get_node_or_null("PlayerVisuals")` (`:182`) → `full.remove_child(vis)` / `full.free()` (`:186-187`) |
| 4. User picks a survivor | `scripts/ui/CharacterSelect.gd:344-345` | `func _select_character(index: int, ...) -> void:` / `selected_character = index` |
| 5. **Selection is persisted here** | `scripts/ui/CharacterSelect.gd:365-371` | `func _confirm_selection(...)` → `Save.set_selected_character(CHARACTER_NAMES[index].to_lower())` |
| 6. Writer of the save key | `scripts/core/SaveManager.gd:204-207` | `func set_selected_character(character_name: String) -> void:` / `selected_character = character_name` / `save_data["selected_character"] = character_name` / `save_game()` |
| 7. Select → level select | `scripts/ui/CharacterSelect.gd:374-376` | `get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")` |
| 8. Level select → gameplay | `scripts/ui/LevelSelect.gd:164-168` | `Save.set_current_level(level)` / `get_tree().change_scene_to_file("res://scenes/main/game.tscn")` |
| 9. **The gameplay player is NOT a character scene** | `scenes/main/game.tscn:145-147` | `[node name="Player" type="CharacterBody3D" parent="."]` + `script = ExtResource("2")` (ExtResource `"2"` = `res://scripts/core/Player.gd`, declared at `scenes/main/game.tscn:5`) |
| 10. Player boots and pulls the model | `scripts/core/Player.gd:99-107` | `func _ready()` → `_apply_character_model()` (`:107`) |
| 11. **The reader of the save key** | `scripts/core/Player.gd:1001-1005` | `func _selected_character_id() -> String:` / `var save := get_node_or_null("/root/Save")` / `if save and save.get("selected_character") != null:` / `return String(save.get("selected_character"))` / `return "gamer"` |
| 12. Loads the character **scene** | `scripts/core/Player.gd:931-932` | `const CHARACTER_MODEL_DIR := "res://assets/models/character_%s.glb"` / `const CHARACTER_SCENE_DIR := "res://scenes/characters/character_%s.tscn"` |
| 13. Extracts the subtree | `scripts/core/Player.gd:946-976` | `var scene_path := CHARACTER_SCENE_DIR % id` → `packed_scene.instantiate()` → `var vis := full.get_node_or_null("PlayerVisuals") as Node3D` (`:951`) → `full.remove_child(vis)` / `full.free()` (`:953-954`) → `vis.name = "CharacterVisuals"` (`:955`) → `visuals.add_child(vis)` (`:957`) |
| 14. Re-ground by AABB | `scripts/core/Player.gd:962-964` | `var aabb := _model_aabb(vis)` / `if aabb.size.y > 0.01:` / `vis.position.y = -aabb.position.y` |
| 15. Attach animation | `scripts/core/Player.gd:965-968` | `_skeletal = CharacterAnim.setup(vis, id)` / `_skeletal.play("idle")` / `_anim_state = "idle"` |

**Answer to "whole scene or subtree?":** the scene is instantiated **whole**, then a **subtree is extracted**
(`PlayerVisuals`) and the remainder is freed. Both consumers do exactly this:

- Menu: `scripts/ui/CharacterSelect.gd:181-187`
- Gameplay: `scripts/core/Player.gd:950-954`

The discarded root carries `Player.gd`, `WeaponSystem`, `HitFeedback`, the camera, collision shapes and
`MobileControls` (see any `scenes/characters/character_*.tscn` — e.g. `character_doctor.tscn:86-187`). None of
that reaches gameplay; gameplay uses the copies authored in `scenes/main/game.tscn`.

### 1.2 Defaults and fallbacks (three of them, and they disagree)

| Site | Value |
|---|---|
| `scripts/core/SaveManager.gd:17` | `var selected_character: String = "doctor"   # real geometry (1146 verts); "gamer" is a 64-vert blockout` |
| `scripts/core/SaveManager.gd:137` | `"selected_character": "doctor",  # drives which GLB Player._apply_character_model loads` |
| `scripts/core/Player.gd:1005` | `return "gamer"` |
| `scripts/ui/CharacterSelect.gd:44` | `var selected_character: int = 1  # doctor default, matches the old screen` |
| `scripts/ui/CharacterSelect.gd:95` | `_select_character(1, false)` — index 1 = `character_doctor.tscn` |

`SaveManager._load_game()` reconciles the member var with the on-disk value at
`scripts/core/SaveManager.gd:61`: `selected_character = String(save_data.get("selected_character", selected_character))`.
`Player.gd:1005`'s `"gamer"` fallback therefore only fires when the `/root/Save` autoload is absent.

### 1.3 The GLB fallback path is live but degraded

`scripts/core/Player.gd:978-999` falls back to `res://assets/models/character_%s.glb` when the character
**scene** is missing. Those five GLBs exist (`assets/models/character_gamer.glb` … `character_hunter.glb`) but
are single-mesh, **0-skin, 0-animation blockouts** — verified from the GLB JSON: root node `geometry_0`,
`meshes=1 skins=0 nodes=1 anims=0`. This matches the `SaveManager.gd:17` comment ("gamer is a 64-vert
blockout") and `Player.gd:1060-1061` (`push_warning(... "it is a blockout placeholder")`). The fallback path
also paints every mesh with a flat dark-red override at `scripts/core/Player.gd:1031-1041`.

### 1.4 Autoloads (`project.godot:18-27`)

```
SceneManager="*SceneManager.gd"
SaveSystem="*uid://dfu2pldj84cy1"
Save="*scripts/core/SaveManager.gd"
Audio="*scripts/core/GameAudioManager.gd"
Level="*scripts/core/LevelManager.gd"
SoundManager="*uid://6q1wagejt60k"
MinosDamageNumbers2D="*uid://cmstxlu50gkl7"
MinosDamageNumbers3D="*uid://bqk86tyyf62lx"
```

`CharacterAnim` is **not** an autoload — it is a `RefCounted` with `class_name CharacterAnim`
(`scripts/core/CharacterAnim.gd:11-12`) used statically. Main scene: `res://scenes/main/title_screen.tscn`
(`project.godot:14`).

---

## 2. Rig coupling — every hardcoded assumption about the current rig

### 2.1 Shared model path `assets/models/cc0/kenney_anim/model.glb`

| file:line | Assumption | What breaks if the rig changes |
|---|---|---|
| `scenes/characters/character_gamer.tscn:5` | `[ext_resource type="PackedScene" path="res://assets/models/cc0/kenney_anim/model.glb" id="model"]` | Model instance is wrong/absent |
| `scenes/characters/character_gamer.tscn:59-60` | `[node name="Model" parent="PlayerVisuals" instance=ExtResource("model")]` + `transform = Transform3D(0.00425, ...)` | Scale + node name wrong |
| `scenes/characters/character_doctor.tscn:14, :95, :96` | same pattern | same |
| `scenes/characters/character_nurse.tscn:14, :107, :108` | same pattern | same |
| `scenes/characters/character_streamer.tscn:14, :110, :111` | same pattern | same |
| `scenes/characters/character_hunter.tscn:14, :107, :108` | same pattern | same |
| `scenes/characters/zombie_runner.tscn:4, :24, :25` | same rig, under `Mesh/Model` | zombie rig changes too |
| `scenes/characters/zombie_butcher.tscn:4, :24, :25` | same rig | same |
| `scenes/characters/zombie_spitter.tscn:4, :24, :25` | same rig | same |
| `scenes/characters/zombie_boss.tscn:4, :19, :20` | same rig | same |
| `scripts/core/CharacterAnim.gd:14` | `const ANIM_DIR := "res://assets/models/cc0/kenney_anim/"` | Clip loading path |
| `scripts/core/CharacterAnim.gd:96` | `var path := ANIM_DIR + nm + ".glb"` (loads `idle.glb`, `run.glb`, `jump.glb`) | No clips → `setup_rigged` returns `null` |
| `scripts/core/Player.gd:931` | `const CHARACTER_MODEL_DIR := "res://assets/models/character_%s.glb"` | Fallback path only |

The GLB is **skinned**: verified from the file itself — `meshes=1`, `skins=1`, **45 joints**, 61 nodes,
1 material, `images: []` (texture comes from the separate PNG atlases). Root `RootNode` → `Root` → …
→ `Hips` → `Spine/Chest/UpperChest/Neck/Head` and `Left/RightShoulder|Arm|ForeArm|Hand|HandIndex1-3|HandThumb1-2`,
`Left/RightUpLeg|Leg|Foot|Toes`. The mesh hangs off a sibling node `characterMedium` under `RootNode`.

### 2.2 The `0.00425` scale

Nine `.tscn` files, one identical line each:

| file:line | Line |
|---|---|
| `scenes/characters/character_gamer.tscn:60` | `transform = Transform3D(0.00425, 0, 0, 0, 0.00425, 0, 0, 0, 0.00425, 0, 0, 0)` |
| `scenes/characters/character_doctor.tscn:96` | same |
| `scenes/characters/character_nurse.tscn:108` | same |
| `scenes/characters/character_streamer.tscn:111` | same |
| `scenes/characters/character_hunter.tscn:108` | same |
| `scenes/characters/zombie_runner.tscn:25` | same |
| `scenes/characters/zombie_butcher.tscn:25` | same |
| `scenes/characters/zombie_spitter.tscn:25` | same |
| `scenes/characters/zombie_boss.tscn:20` | same |

Documented rationale at `assets/models/MODEL_SCALE_TABLE.md:37`:
> `| character-rig | 4 | 2.0–100.8 | 1.8m human | **0.00425** | Base rig \`model.glb\` ≈2 units. Animation clips are ~100 units (world-space keyframes). |`

**Note:** the scale exists to make the ~100-unit *animation* keyframes land on a 1.8 m human, not because the
base mesh is 2 m. The mesh's own POSITION accessor spans only `y ∈ [-0.5142, 0.5339]` (raw), i.e. **1.048 units
tall** — see §2.7 for why this matters to `_model_aabb`.

For the Blocky set the table already prescribes a different scale —
`assets/models/MODEL_SCALE_TABLE.md:38`: `| block-character | 18 | 9.0 | 1.8m human | **0.2** | Voxel/blocky style, 9×9×9. Scale 0.2 → 1.8m. |`

**What breaks:** any rig swap that keeps `0.00425` renders the new model at the wrong size (Blocky at `0.00425`
→ ~3.8 cm tall). Nothing in `.gd` reads or corrects this number — it is authored per-scene only.

### 2.3 The `PlayerVisuals` node name and its children (`Model`, `Prop`)

| file:line | Assumption | What breaks |
|---|---|---|
| `scripts/core/Player.gd:54` | `@onready var mesh: Node3D = $PlayerVisuals/Body if has_node("PlayerVisuals/Body") else null` | Hardcoded `PlayerVisuals` + child `Body` (the game.tscn placeholder capsule) |
| `scripts/core/Player.gd:937` | `var visuals := get_node_or_null("PlayerVisuals")` — early-returns if missing | No visuals at all if the node is renamed |
| `scripts/core/Player.gd:951` | `var vis := full.get_node_or_null("PlayerVisuals") as Node3D` | Extraction fails → falls through to the blockout GLB |
| `scripts/core/Player.gd:955` | `vis.name = "CharacterVisuals"` | Renames the extracted root (see `tools/gameplay_boot_probe.gd:77,91` which assert this name) |
| `scripts/core/Player.gd:121` | `var holder := anim_target.get_parent()  # $PlayerVisuals` | Assumes the visual root's parent is `PlayerVisuals`; reparenting puts `ProceduralAnimator` between them |
| `scripts/core/Player.gd:532-536` | `var _pv := get_node_or_null("PlayerVisuals")` → `_pv.get_node_or_null("ProceduralAnimator")` | Attack feedback path |
| `scripts/ui/CharacterSelect.gd:182` | `var vis: Node3D = full.get_node_or_null("PlayerVisuals") as Node3D` | Menu extraction |
| `scripts/core/CharacterAnim.gd:50` | `var direct := visuals.get_node_or_null("Model") as Node3D` | Preferred model lookup by node name |
| `scenes/main/game.tscn:163-172` | `[node name="PlayerVisuals" type="Node3D" parent="Player"]` with placeholder `Body` (`:165`) and `Head` (`:169`) | These are the fallback meshes hidden by `Player.gd:1025-1029` |

`CharacterAnim.setup_rigged` is **tolerant of the `Model` name** — if `get_node_or_null("Model")` yields nothing
or has no skeleton, it scans direct children for any `Node3D` containing a `Skeleton3D`
(`scripts/core/CharacterAnim.gd:49-57`). It is **not** tolerant of the absence of a skeleton (see §2.5).

Tooling that also hardcodes these names (not shipped, but they will silently lie after a swap):
`tools/diag_rig.gd:9,16`; `tools/diag_rig2.gd:9,16`; `tools/motion_probe.gd:22`;
`tools/gameplay_boot_probe.gd:63,77,91`.

### 2.4 Texture atlas names in `CharacterAnim.SKINS`

`scripts/core/CharacterAnim.gd:18-24`:

```gdscript
const SKINS := {
	"gamer": {"tex": "skaterMaleA.png", "tint": Color(0.86, 0.92, 1.0)},
	"doctor": {"tex": "survivorMaleB.png", "tint": Color(1.0, 1.0, 1.0)},
	"nurse": {"tex": "skaterFemaleA.png", "tint": Color(1.0, 0.94, 0.96)},
	"streamer": {"tex": "cyborgFemaleA.png", "tint": Color(0.94, 0.86, 1.0)},
	"hunter": {"tex": "criminalMaleA.png", "tint": Color(0.84, 1.0, 0.82)},
}
```

Loaded from `ANIM_DIR` at `scripts/core/CharacterAnim.gd:143-146`:
```gdscript
static func apply_skin_raw(model: Node3D, tex_name: String, tint: Color) -> void:
	var tex: Texture2D = null
	if tex_name != "" and ResourceLoader.exists(ANIM_DIR + tex_name):
		tex = load(ANIM_DIR + tex_name) as Texture2D
```

Applied as a blanket `material_override` on **every** `MeshInstance3D` in the subtree
(`scripts/core/CharacterAnim.gd:147-153`).

Verified present in `assets/models/cc0/kenney_anim/`: `skaterMaleA.png`, `survivorMaleB.png`,
`skaterFemaleA.png`, `cyborgFemaleA.png`, `criminalMaleA.png`, plus **unused** `survivorFemaleA.png`,
`zombieA.png`, `zombieC.png`.

**What breaks:** the atlas names are Kenney-Survivors-specific UV layouts. A Blocky rig ships its own atlas set
(`assets/models/cc0/blocks/Textures/texture-a.png` … `texture-r.png`, one per character). Because
`SKINS.get(char_id, {})` returns an empty dict on a miss (`scripts/core/CharacterAnim.gd:40-41`) and
`apply_skin_raw` tolerates `tex_name == ""`, a stale/unknown id produces a **silent white, untextured model**
with no warning. Also note `material_override` replaces the Blocky GLB's own material rather than tinting it.

### 2.5 Anything that assumes a SKELETON (`skins:1`) rather than rigid parts — **the critical coupling**

| file:line | Assumption | What breaks with a rigid-parts rig |
|---|---|---|
| `scripts/core/CharacterAnim.gd:51` | `if direct != null and _has_skeleton(direct):` | Fails → falls through |
| `scripts/core/CharacterAnim.gd:55` | `if c is Node3D and _has_skeleton(c):` | Fails for every child |
| `scripts/core/CharacterAnim.gd:58-59` | `if model == null: return null` | **`setup_rigged` returns `null`** → no `AnimationPlayer` at all |
| `scripts/core/CharacterAnim.gd:61-63` | `var skels := model.find_children("*", "Skeleton3D", true, false)` / `if skels.is_empty(): return null` | Second hard gate |
| `scripts/core/CharacterAnim.gd:64-65` | `var sk: Skeleton3D = skels[0]` / `var sk_path := String(model.get_path_to(sk))` | Requires a real skeleton |
| `scripts/core/CharacterAnim.gd:74-79` | `for nm in ["idle", "run", "jump"]:` … `_retarget(clip, sk, sk_path)` | Clip names + retarget both assume bones |
| `scripts/core/CharacterAnim.gd:89-90` | `static func _has_skeleton(n: Node) -> bool:` / `return not n.find_children("*", "Skeleton3D", true, false).is_empty()` | The gate itself |
| `scripts/core/CharacterAnim.gd:122-132` | `_retarget(...)`: `if skeleton.find_bone(last) >= 0:` / `anim.track_set_path(i, NodePath(sk_path + ":" + last))` | Bone-name-keyed retarget; a rigid rig has no bones to match |
| `scripts/core/CharacterAnim.gd:143-153` | `apply_skin_raw` overrides every `MeshInstance3D`'s material | Flattens a multi-part textured model |
| `scripts/core/Player.gd:965-968` | `_skeletal = CharacterAnim.setup(vis, id)` / `if _skeletal != null:` / `_skeletal.play("idle")` | `_skeletal` stays `null` |
| `scripts/core/Player.gd:366-370` | `_play_jump_anim()`: `if _skeletal != null and ... _skeletal.has_animation("jump")` | Jump anim silently skipped |
| `scripts/core/Player.gd:374-388` | `_update_skeletal_anim(delta)`: `if _skeletal == null ... return`, then `_skeletal.play(want)` with `want = "idle" if spd < 0.35 else "run"` and `_skeletal.speed_scale = clampf(spd / 2.3, 0.75, 1.7)` | No animation at all |
| `scripts/core/Player.gd:129-130` | `if _skeletal != null: _anim.set_process(false)` | **Inverse coupling:** with a rigid rig `_skeletal == null`, so the `ProceduralAnimator` stays enabled — which is arguably the *desired* fallback, but it means the swap silently changes which animation system drives the character |
| `scripts/characters/ZombieBase.gd:133` | `CharacterAnim.setup_rigged(mesh, skin.tex, skin.tint)` (return value ignored) | Zombies silently lose their animation if the shared rig loses its skeleton |
| `scripts/characters/ZombieBase.gd:396-409` | `_drive_anim()`: `var ap := mesh.get_node_or_null("AnimationPlayer")` … `ap.play("run", 0.15)` / `ap.play("idle", 0.2)` | `null` → early return, zombies T-pose/statue |

**Verified against the actual candidate rig** (GLB JSON, `assets/models/cc0/blocks/character-a.glb`):
`meshes=6 skins=0 nodes=8 anims=27`, root `character-a`, nodes
`['character-a', 'root', 'leg-left', 'leg-right', 'torso', 'arm-left', 'arm-right', 'head']`.
**Zero skeletons, zero joints.** Therefore every gate above fails and `CharacterAnim.setup*` returns `null` for
a Blocky rig as shipped.

### 2.6 Animation clip names (`idle` / `run` / `jump`)

`scripts/core/CharacterAnim.gd:74` — `for nm in ["idle", "run", "jump"]:`
`scripts/core/Player.gd:367` — `_skeletal.has_animation("jump")`
`scripts/core/Player.gd:381` — `var want := "idle" if spd < 0.35 else "run"`
`scripts/characters/ZombieBase.gd:402,407` — `ap.play("run", 0.15)` / `ap.play("idle", 0.2)`
`scripts/characters/ZombieRunner.gd:42-49` — `ap.play("idle", 0.2)` / `ap.play("run", 0.15)`

The clip files are `assets/models/cc0/kenney_anim/{idle,run,jump}.glb`, and `_load_clip` explicitly **skips the
`"0_Targeting Pose"` setup clip** by name (`scripts/core/CharacterAnim.gd:109-112`):
```gdscript
for c in src.get_animation_list():
	if not String(c).contains("Targeting"):
		clip = src.get_animation(c)
		break
```

### 2.7 Measurement note — the `_model_aabb` re-grounding is not rig-neutral

`scripts/core/Player.gd:962-964` re-grounds the extracted visuals using a bounding box:
```gdscript
var aabb := _model_aabb(vis)
if aabb.size.y > 0.01:
	vis.position.y = -aabb.position.y
```
and `_model_aabb` (`scripts/core/Player.gd:1064-1074`) sums `mesh_i.get_aabb()` per `MeshInstance3D` — i.e. the
**mesh-local** AABB, which for a skinned mesh is the bind-pose extent of the raw vertex data, not the
skeleton-posed extent.

Measured from `assets/models/cc0/kenney_anim/model.glb` directly:
- raw `POSITION` accessor: 1029 verts, `min = [-1.8091, -0.5142, ~0]`, `max = [1.8095, 0.5339, 3.7654]`
  → raw mesh height ≈ **1.048 units**
- the skinned mesh node is `characterMedium` under `RootNode`, carrying a 100× matrix
  (`matrix = [100,0,0,0, 0,-1.6e-5,-100,0, 0,100,-1.6e-5,0, 0,0,0,1]`), and the skeleton is a **sibling**
  (`RootNode` children = `[Root, characterMedium]`) — so the skinned bind-pose extent lives in a different scale
  space than the raw mesh AABB
- applying `jointGlobal × inverseBindMatrix` to every vertex (linear-blend skinning, computed offline) gives a
  bind-pose extent of **1028.33 rig units**, i.e. **≈ 4.37 m** once the `0.00425` node scale is applied, with the
  lowest vertex at `-106.65` units (`≈ -0.453` after scaling)

The exact in-engine resting height and foot-line of the current survivor is **undetermined** from source alone —
it depends on `get_aabb()`'s skinned-mesh behaviour at runtime, which needs an engine run to confirm. What *is*
determinable: `vis.position.y = -aabb.position.y` is driven by the raw mesh AABB, so it is a rig-shape-dependent
fudge factor. A new rig with a different mesh-vs-skeleton relationship will need this re-derived (or replaced
with an explicit authored offset), and it will fail **silently** (wrong height, no error).

The menu uses a *different*, hardcoded grounding instead — `scripts/ui/CharacterSelect.gd:37`:
`const MODEL_ORIGIN_Y := PEDESTAL_TOP + 0.06  # rigged models carry feet at local 0 -> disc top (0.76)`
applied at `scripts/ui/CharacterSelect.gd:188` (`vis.position = Vector3(x, MODEL_ORIGIN_Y, PEDESTAL_Z)`). So
menu and gameplay ground the same subtree by two unrelated mechanisms — both must be revisited.

---

## 3. Zombie coupling

### 3.1 Which zombies share the survivor rig

| Zombie | Model source | Skinned? | Shares survivor rig? |
|---|---|---|---|
| `zombie_runner.tscn:4` | `res://assets/models/cc0/kenney_anim/model.glb` | yes (45 joints) | **YES** |
| `zombie_butcher.tscn:4` | `res://assets/models/cc0/kenney_anim/model.glb` | yes | **YES** |
| `zombie_spitter.tscn:4` | `res://assets/models/cc0/kenney_anim/model.glb` | yes | **YES** |
| `zombie_boss.tscn:4` | `res://assets/models/cc0/kenney_anim/model.glb` | yes | **YES** |
| `zombie_dog.tscn:4` | `res://assets/models/zombie_dog.glb` | no — `meshes=1 skins=0 nodes=1 anims=0`, root `geometry_0` | no |
| `zombie_cat.tscn:4` | `res://assets/models/zombie_cat.glb` | no (same shape) | no |
| `zombie_bear.tscn:4` | `res://assets/models/zombie_bear.glb` | no | no |
| `zombie_rabbit.tscn:4` | `res://assets/models/zombie_rabbit.glb` | no | no |
| `zombie_chicken.tscn:4` | `res://assets/models/zombie_chicken.glb` | no | no |

The five animal types are also listed in `ZombieSpawner3D` preloads (`scripts/characters/ZombieSpawner3D.gd:14-20`)
and pooled at `scripts/characters/ZombieSpawner3D.gd:91-99`.

### 3.2 The coupling is **indirect — through `CharacterAnim`, not through the survivor scenes**

The zombies never load a `character_*.tscn`. They call the shared helper directly:

`scripts/characters/ZombieBase.gd:129-133`:
```gdscript
# Attach the rigged animation pipeline (idle/run/jump + skin) to the mesh.
if mesh:
	var skin_key := _get_zombie_skin_key()
	var skin: Dictionary = CharacterAnim.ZOMBIE_SKINS.get(skin_key, CharacterAnim.ZOMBIE_SKINS["zombie"])
	CharacterAnim.setup_rigged(mesh, skin.tex, skin.tint)
```
and again on pool checkout, `scripts/characters/ZombieBase.gd:556-560`:
```gdscript
var ap := mesh.get_node_or_null("AnimationPlayer") as AnimationPlayer
if ap == null:
	var skin_key := _get_zombie_skin_key()
	var skin: Dictionary = CharacterAnim.ZOMBIE_SKINS.get(skin_key, CharacterAnim.ZOMBIE_SKINS["zombie"])
	CharacterAnim.setup_rigged(mesh, skin.tex, skin.tint)
```

`ZOMBIE_SKINS` — `scripts/core/CharacterAnim.gd:27-33`:
```gdscript
const ZOMBIE_SKINS := {
	"runner": {"tex": "zombieA.png", "tint": Color(0.72, 1.0, 0.72)},
	"butcher": {"tex": "zombieC.png", "tint": Color(1.0, 0.72, 0.72)},
	"spitter": {"tex": "zombieA.png", "tint": Color(0.72, 1.0, 0.82)},
	"boss": {"tex": "zombieC.png", "tint": Color(0.86, 0.86, 0.92)},
	"zombie": {"tex": "zombieA.png", "tint": Color(0.80, 1.0, 0.78)},
}
```
Key resolution: `scripts/characters/ZombieBase.gd:150-165` (`_get_zombie_skin_key()` — `zombie_type` first, then
script basename `ZombieRunner`/`ZombieButcher`/`ZombieSpitter`/`ZombieBoss`, else `"zombie"`).

### 3.3 Do the zombies break if the survivors get a new rig?

**Depends entirely on *how* the swap is done:**

| Swap approach | Zombie impact |
|---|---|
| Edit only the 5 `scenes/characters/character_*.tscn` files (new model instance + new scale) | **Zombies unaffected.** They never read those files. |
| Change `CharacterAnim.gd` (e.g. drop the skeleton requirement, change `ANIM_DIR`, change `SKINS`/`ZOMBIE_SKINS`, change `apply_skin_raw`) | **Zombies break** — 4 of 7 types lose idle/run and freeze (`ZombieBase.gd:133` return value is discarded; `ZombieBase.gd:397-399` then early-returns) |
| Replace/delete `assets/models/cc0/kenney_anim/model.glb` or `idle/run/jump.glb` | **Zombies break** — 4 zombie scenes reference the same GLB (`zombie_runner.tscn:4` etc.) and `_load_clip` reads `ANIM_DIR + nm + ".glb"` (`CharacterAnim.gd:96`) |
| Change `Player.gd`'s extraction/grounding logic only | **Zombies unaffected** — no shared code path |

**Files that would need to change for a survivor-only swap:** the 5 `character_*.tscn`; `Player.gd`
(`_apply_character_model` / `_model_aabb` grounding, `CHARACTER_HEIGHT`, `_normalise_model_transform`);
`CharacterSelect.gd` (pedestal grounding + `_dim_model_materials`).
**Files that would NOT need to change:** `ZombieBase.gd`, all 9 `zombie_*.tscn`, `ZombieSpawner3D.gd`,
`SaveManager.gd`, `LevelManager.gd`, `game.tscn`, `character_select.tscn`.

**Files that would need to change if the *shared* `CharacterAnim.gd` is repurposed for a rigid rig:**
`CharacterAnim.gd` (obviously), `ZombieBase.gd:129-133` and `:556-560`, `ZombieRunner.gd:37,42-49,59-66`
(it does `get_node_or_null("Mesh/AnimationPlayer")` and plays `"idle"`/`"run"`), `Player.gd:965-968`,
`Player.gd:366-388`, `Player.gd:129-130`.

### 3.4 Two pre-existing zombie observations relevant to any swap

1. **`ZombieBase` disables the `ProceduralAnimator` for *every* zombie**, including the five non-rigged animal
   types — `scripts/characters/ZombieBase.gd:126-128`:
   ```gdscript
   var pa := get_node_or_null("ProceduralAnimator")
   if pa:
       pa.set_process(false)
   ```
   Only the four rigged human types get a replacement `AnimationPlayer` (`ZombieBase.gd:133`). The animal GLBs
   have `skins=0`, so `CharacterAnim.setup_rigged` returns `null` for them, and `_drive_anim` early-returns on
   `ap == null` (`ZombieBase.gd:397-399`). Whether the animals therefore have *no* walk animation today is
   **undetermined** without an engine run, but the code path says so.
2. **The `AnimationPlayer` node declared in the zombie scenes is unrelated to the one used at runtime.**
   `zombie_runner.tscn:26` etc. declare `[node name="AnimationPlayer" type="AnimationPlayer" parent="Mesh"]`, but
   `CharacterAnim.setup_rigged` creates its own `AnimationPlayer.new()` named `"CharacterAnim"` and parents it to
   the **model** node (`scripts/core/CharacterAnim.gd:67-70`). Both `ZombieBase.gd:397` and
   `ZombieRunner.gd:37` query `mesh.get_node_or_null("AnimationPlayer")` — i.e. the *scene-declared* node, not
   `CharacterAnim`. Same pattern on the player side: `Player.gd` keeps the returned reference in `_skeletal`
   (`Player.gd:965`) rather than re-querying by name.

---

## 4. Prop attachment

### 4.1 Mechanism: siblings of the model, not bone children

Every survivor scene declares exactly **one** prop node named `Prop`, a `MeshInstance3D` and a **direct child of
`PlayerVisuals`** — a sibling of `Model`, not a child of it and not attached to any bone. Nothing in the
codebase reads it: `grep -rn '"Prop"' --include=*.gd scripts/` returns **no matches** (only `PropScatter` and
`property` substrings).

### 4.2 Every prop node and its transform

| Character | file:line | Mesh | Local transform (from the `.tscn`) | Translation |
|---|---|---|---|---|
| gamer | `character_gamer.tscn:62-65` | `ControllerMesh` (`:45-52`, `BoxMesh` 0.15×0.05×0.08, emissive red) | `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.28, 0.62, 0.24)` | `(0.28, 0.62, 0.24)` |
| doctor | `character_doctor.tscn:98-101` | `StethoscopeMesh` (`:61-69`, `BoxMesh` 0.3×0.02×0.3, dark metal) | `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, 1.02, 0.14)` | `(0.0, 1.02, 0.14)` |
| nurse | `character_nurse.tscn:110-113` | `SyringeMesh` (`:85-94`, `CylinderMesh` r=0.03 h=0.2, red) | `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.28, 0.62, 0.24)` | `(0.28, 0.62, 0.24)` |
| streamer | `character_streamer.tscn:113-116` | `PhoneMesh` (`:75-83`, `BoxMesh` 0.1×0.18×0.02, dark) | `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.26, 0.62, 0.26)` | `(0.26, 0.62, 0.26)` |
| hunter | `character_hunter.tscn:110-113` | `BatMesh` (`:73-81`, `BoxMesh` 0.06×0.5×0.06, wood) | `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.32, 0.55, 0.28)` | `(0.32, 0.55, 0.28)` |

All five are **identity rotation, uniform scale 1** — translation only. The doctor's stethoscope is the only one
at chest height (`y = 1.02`); the other four sit at roughly hand/hip height (`y ≈ 0.55–0.62`), offset to the
character's right (`x ≈ +0.26…+0.32`) and forward (`z ≈ +0.14…+0.28`).

### 4.3 The prompt's prop list vs. what the scenes actually declare

The brief mentioned headset, stethoscope, syringe, ring light, bat. Only **one prop node is instantiated per
scene**; the other prop meshes are declared as `sub_resource`s that **no node references** (verified: grepping
for `SubResource("Headset`, `"RingLight`, `"Lens`, `"Cap`, `"Mask`, `"Vest`, `"Ammo`, `"Stick`, `"Hoodie`,
`"Scrubs`, `"Jacket` across `scenes/characters/character_*.tscn` returns **zero** node usages). Dead
sub-resources, per file:

- `character_gamer.tscn` — unused: `PlayerMesh` (`:11`), `PlayerMaterial` (`:15`), `HeadMesh` (`:20`), `HeadMaterial` (`:23`), `HoodieMesh` (`:28`), `HoodieMaterial` (`:31`), **`HeadsetMesh` (`:36`)**, **`HeadsetMaterial` (`:40`)**. Only `ControllerMesh`/`ControllerMaterial` are used, by `Prop`.
- `character_doctor.tscn` — unused: `PlayerMesh` (`:24`), `PlayerMaterial` (`:30`), `HeadMesh` (`:37`), `HeadMaterial` (`:42`), `CoatMesh` (`:49`), `CoatMaterial` (`:54`), `LensMesh` (`:73`), `LensMaterial` (`:78`). Only `StethoscopeMesh`/`StethoscopeMaterial` used.
- `character_nurse.tscn` — unused: `PlayerMesh` (`:24`), `PlayerMaterial` (`:30`), `HeadMesh` (`:37`), `HeadMaterial` (`:42`), `ScrubsMesh` (`:49`), `ScrubsMaterial` (`:54`), `CapMesh` (`:61`), `CapMaterial` (`:66`), `MaskMesh` (`:73`), `MaskMaterial` (`:78`). Only `SyringeMesh`/`SyringeMaterial` used.
- `character_streamer.tscn` — unused: `PlayerMesh` (`:24`), `PlayerMaterial` (`:30`), `HeadMesh` (`:37`), `HeadMaterial` (`:42`), `HoodieMesh` (`:49`), `HoodieMaterial` (`:54`), **`RingLightMesh` (`:61`)**, **`RingLightMaterial` (`:67`)**, `StickMesh` (`:87`), `StickMaterial` (`:94`). Only `PhoneMesh`/`PhoneMaterial` used.
- `character_hunter.tscn` — unused: `PlayerMesh` (`:24`), `PlayerMaterial` (`:30`), `HeadMesh` (`:37`), `HeadMaterial` (`:42`), `JacketMesh` (`:49`), `JacketMaterial` (`:54`), `VestMesh` (`:61`), `VestMaterial` (`:66`), `AmmoMesh` (`:85`), `AmmoMaterial` (`:91`). Only `BatMesh`/`BatMaterial` used.

**Implication for the swap:** the new rig must supply the body/clothing that the current placeholder meshes
(`PlayerMesh`, `HeadMesh`, `HoodieMesh`, `CoatMesh`, `ScrubsMesh`, `JacketMesh`, `VestMesh`) were stubbing — they
are dead already, so there is no visual regression to worry about from them.

### 4.4 Which space the transforms are in, and what they must become

- The transforms are **local to `PlayerVisuals`** (the node's `parent="PlayerVisuals"`), not to a bone and not
  to `Model`. They are in the **character's feet-origin space** — the same space the extracted subtree occupies
  once re-grounded, where `y = 0` is the capsule bottom and the model is scaled `0.00425` with feet at
  `y ≈ 0` (per the menu's own comment, `scripts/ui/CharacterSelect.gd:37`).
- Because `Prop` is a **sibling** of `Model`, the whole-subtree moves applied by both consumers move the prop
  too: `Player.gd:964` (`vis.position.y = -aabb.position.y`) and `CharacterSelect.gd:188`
  (`vis.position = Vector3(x, MODEL_ORIGIN_Y, PEDESTAL_Z)`). The prop's own local offsets are untouched by
  either.
- **Therefore the prop offsets are hand-tuned to the Kenney Survivors rig's proportions**: `y ≈ 0.62` assumes
  that rig's hand/hip height for a ~1.8 m body, and `x ≈ +0.28` assumes its arm's lateral offset. Nothing
  reads a bone to derive them.

**What they must become for a different rig:**
1. **Re-tuned per rig** if kept as `PlayerVisuals` children — the new model's hand/hip height and shoulder width
   must be measured and the `Transform3D` translations re-authored. Silent failure mode: props float in mid-air
   or sit inside the body; no error is raised.
2. **Or converted to bone attachments** — which the current codebase has no support for. There is no
   `BoneAttachment3D` anywhere, no `Skeleton3D` lookup in the prop path, and no `.gd` that touches `Prop`. Doing
   this properly requires new code (find the hand bone, reparent, or add a `BoneAttachment3D` with
   `bone_name = "RightHand"` for the Kenney Survivors rig — note the rig *does* have a usable bone set:
   `RightHand` is node index 42 with `translation y = 0.5272` in rig units, from the GLB JSON).
3. **The props also need a home in the new rig's texture story** — they are `material_override` `StandardMaterial3D`
   solids (`character_gamer.tscn:65`, etc.), so they will clash visually with a new art style but will not
   error.

---

## 5. The stats gap

### 5.1 The declaration

`scripts/core/Player.gd:31-32`:
```gdscript
# === CHARACTER STATS ===
var character_stats: CharacterStats = null
```

### 5.2 Every read of it (from `Player.gd` only)

| file:line | Use |
|---|---|
| `scripts/core/Player.gd:101-102` | `if character_stats:` / `_apply_character_stats()` |
| `scripts/core/Player.gd:160-168` | `_apply_character_stats()` reads `max_health`, `max_stamina`, `move_speed`, `sprint_speed`, `attack_damage`, `stamina_regen` |
| `scripts/core/Player.gd:560` | `var speed_mult: float = character_stats.attack_speed if character_stats else 1.0` |
| `scripts/core/Player.gd:569` | `var hit_range: float = weapon_range * (character_stats.attack_range / 2.0 if character_stats else 1.0)` |
| `scripts/core/Player.gd:573-574` | `if character_stats:` / `damage = int(damage * character_stats.weapon_damage_multiplier)` |
| `scripts/core/Player.gd:578-579` | `if character_stats and randf() < character_stats.critical_chance:` / `damage = int(damage * character_stats.critical_multiplier)` |
| `scripts/core/Player.gd:602` | `func use_special_ability()`: `if special_timer > 0 or not character_stats: return` |
| `scripts/core/Player.gd:605` | `var ability: String = character_stats.special_ability` |
| `scripts/core/Player.gd:610,614-615,620-621,626-627,631` | special-ability cooldown/duration reads |
| `scripts/core/Player.gd:647-648` | `if character_stats:` / `amount = int(amount * (1.0 - character_stats.damage_reduction))` |

### 5.3 The assignment — there is none

Exact grep evidence, run from the repo root:

```
$ grep -rn "character_stats\s*=" --include=*.gd --include=*.tscn .
(no output)
```

```
$ grep -rn "stats_(gamer|doctor|nurse|streamer|hunter)" --include=*.gd --include=*.tscn .
(no output in tracked files; 15 hits only in gitignored .godot/ editor caches)
```

```
$ grep -rn "CharacterStats\|stats_" --include=*.tscn .
(no output)
```

The only file that names `CharacterStats` at all is its own definition
(`scripts/characters/CharacterStats.gd:2` — `class_name CharacterStats`) plus the reads in `Player.gd` listed
above. The five `.tres` files are referenced from **nowhere**:

```
assets/materials/stats_gamer.tres     — character_id = "gamer",    special_ability = "rage"
assets/materials/stats_doctor.tres    — character_id = "doctor",   special_ability = "heal_aura"
assets/materials/stats_nurse.tres     — character_id = "nurse",    special_ability = "heal"
assets/materials/stats_streamer.tres  — character_id = "streamer", special_ability = "rush"
assets/materials/stats_hunter.tres    — character_id = "hunter",   special_ability = "iron_skin"
```
(each is `[gd_resource type="Resource" script_class="CharacterStats" ...]` with
`script = ExtResource("1")` → `res://scripts/characters/CharacterStats.gd`)

There is no `load("res://assets/materials/stats_*.tres")` anywhere, no `preload`, no `.tscn` `ExtResource`, and
no exported `character_stats` slot in any scene (a `.tscn` would need `character_stats = ExtResource(...)` to
set it — absent).

### 5.4 Conclusion — stated plainly

**`Player.character_stats` is never assigned anywhere in the codebase.** It is permanently `null`.

Consequences, all currently live:

1. `_apply_character_stats()` (`Player.gd:160-168`) **never runs** — the guard at `Player.gd:101` is false.
2. Every character therefore plays with the `Player.gd` export defaults, which are identical for all five:
   `max_health = 100` (`:17`), `max_stamina = 100` (`:18`), `move_speed = 4.5` (`:19`), `sprint_speed = 7.5`
   (`:20`), `attack_damage = 25` (`:26`), `attack_range = 2.5` (`:27`), `attack_cooldown = 0.4` (`:28`),
   `stamina_regen = 15.0` (`:23`).
3. **`use_special_ability()` returns immediately for every character** (`Player.gd:602`) — no special ability
   exists in the game today, despite `CharacterSelect.gd:25-31` advertising them ("Speed and snacks on demand",
   "Tanky frame, medkits go further", "Fast healer, fragile", "Trades health for damage", "Ranged specialist,
   steady aim") and the five `.tres` files defining `special_ability` values.
4. Damage-reduction, crit, attack-speed and weapon-multiplier branches all take their `else` path.
5. The only per-character *gameplay* difference that exists today is the model/appearance (via
   `CharacterAnim.SKINS`) and the menu's descriptive text. **Collision is identical too** — every character
   scene declares the same `CapsuleShape3D` `radius = 0.3, height = 1.6` (e.g. `character_gamer.tscn:7-9`), and
   gameplay uses `game.tscn`'s own copy anyway (`scenes/main/game.tscn:63-65`, `:174-176`).

**What would need wiring (not done here — read-only audit):**
1. A loader keyed off the same id `_selected_character_id()` returns (`Player.gd:1001-1005`), e.g.
   `character_stats = load("res://assets/materials/stats_%s.tres" % id) as CharacterStats`, called **before**
   the guard at `Player.gd:101` (i.e. in `_ready()` ahead of `_apply_character_stats()`).
2. A guard for the miss case — `SKINS`-style `load()` on a bad id returns `null` silently.
3. Note `stats_doctor.tres` has no `character_id`-vs-file mismatch, but `stats_gamer.tres:23` says
   `special_ability = "rage"` while `Player.gd:607-635` handles `"heal"`, `"rage"`, `"iron_skin"`, `"rush"`,
   `"heal_aura"` — all five values in the `.tres` files are covered by the `match`, so the mapping is sound.
4. `CharacterStats.dodge_chance`, `knockback_resistance`, `food_healing_multiplier`, `ammo_efficiency`,
   `character_color` (`scripts/characters/CharacterStats.gd:27,28,36,38,41`) are read by **nothing** even in
   `Player.gd` — wiring the resource alone will not activate those five fields.

---

## 6. Blockers for a rig swap — ranked, in dependency order

Ranked by "must happen before the next item can be validated", with the failure mode if skipped.

| Rank | Change | Why it is at this position | Failure mode if skipped |
|---|---|---|---|
| **1** | **Decide the animation strategy.** The Blocky GLBs have `skins=0` / `joints=0` but `anims=27` over a named rigid hierarchy (`root`, `leg-left`, `leg-right`, `torso`, `arm-left`, `arm-right`, `head`). Either (a) build a rigid-parts/`NodePath`-track animation path, or (b) accept `_skeletal == null` and fall back to `ProceduralAnimator`. | Everything else (2–7) depends on which path is taken. `CharacterAnim.setup*` returns `null` for a skeleton-less rig — verified gate at `CharacterAnim.gd:58-59,61-63,89-90`. | The survivors render as frozen statues; `Player.gd:374-388` silently no-ops. |
| **2** | **Replace the model instance + scale in all 5 `character_*.tscn`.** New `ext_resource` (e.g. `res://assets/models/cc0/blocks/character-<x>.glb`) and a new `Transform3D` scale — `MODEL_SCALE_TABLE.md:38` prescribes **0.2** for block-chars (9 units → 1.8 m), not `0.00425`. Lines to change: `character_gamer.tscn:5,59-60`; `character_doctor.tscn:14,95-96`; `character_nurse.tscn:107-108`; `character_streamer.tscn:110-111`; `character_hunter.tscn:107-108`. | Needs the decision from #1 only for the animation node layout. | Model renders at ~3.8 cm (keeping `0.00425`) or ~13 m (using 0.2 on the old rig). |
| **3** | **Re-derive the re-grounding offset.** `Player.gd:962-964` (`vis.position.y = -aabb.position.y` via `_model_aabb`, `:1064-1074`) measures the **raw mesh AABB**, which for the current rig disagrees with the skinned bind pose (§2.7). Replace with an explicit authored offset per rig, or verify `get_aabb()` empirically for the new mesh. | Cannot be tuned until the new model is in the scene (#2). | Character sunk into or floating above the floor — silently, in gameplay only. |
| **4** | **Re-ground the menu independently.** `CharacterSelect.gd:37` (`MODEL_ORIGIN_Y := PEDESTAL_TOP + 0.06`) and `:188` (`vis.position = Vector3(x, MODEL_ORIGIN_Y, PEDESTAL_Z)`) use a *different* hardcoded assumption from gameplay's AABB path. | Same reason as #3, separate code site. | Survivors float above or sink into the pedestals on the select screen. |
| **5** | **Re-author the 5 prop transforms** (§4.2) or convert to `BoneAttachment3D`. Nothing reads `Prop`, so this is purely visual — but it must be done per-rig, and the doctor's `y = 1.02` chest placement is the one most likely to be visibly wrong. | Needs the final rig geometry (#2–#4) to measure against. | Props float in air / intersect the body. No crash, no error. |
| **6** | **Rewrite or retire the skin path.** `CharacterAnim.SKINS` (`:18-24`) points at Kenney-Survivors UV atlases; the Blocky set ships `assets/models/cc0/blocks/Textures/texture-a.png`…`texture-r.png` (one per character). Also `apply_skin_raw` (`:143-153`) blanket-overrides every `MeshInstance3D` material, and `CharacterSelect._dim_model_materials` (`CharacterSelect.gd:58-71`) assumes a `StandardMaterial3D` at surface 0. | After the rig is chosen, because atlas↔character mapping is a content decision. | Silent white/untextured survivors (`SKINS.get()` miss → empty dict → `tex_name == ""` → `tex = null`). |
| **7** | **Only if `CharacterAnim.gd` is shared with zombies: preserve or fork the zombie path.** The 4 rigged zombies depend on `CharacterAnim.setup_rigged` + `ANIM_DIR` + `ZOMBIE_SKINS` (`ZombieBase.gd:129-133`, `:556-560`; `ZombieRunner.gd:37,42-49`). Forking into a survivor-only helper is the safest option. | Last, because it is the only cross-system risk, and it is avoidable. | 4 of 7 zombie types lose idle/run and freeze mid-field. |
| **8** | **(Independent of the rig) Wire `character_stats`.** Load `res://assets/materials/stats_<id>.tres` in `Player._ready()` before the guard at `Player.gd:101`. | Not required for the rig swap, but the swap is the natural moment: per-character rigs make no sense while all five characters still play identically. | Five visually distinct characters with identical stats and no special abilities (§5.4). |

### 6.1 What must NOT be touched

- `scripts/characters/ZombieBase.gd`, the 9 `scenes/characters/zombie_*.tscn`, `ZombieSpawner3D.gd` — a
  survivor-only swap needs none of these (see §3.3).
- `scripts/core/SaveManager.gd` — the save key, its lowercase values, and the "doctor" default are rig-agnostic;
  the rig swap must keep `set_selected_character(<lowercase name>)` (`CharacterSelect.gd:371`) working, which it
  does as long as the five ids (`gamer`, `doctor`, `nurse`, `streamer`, `hunter`) are unchanged.
- `scripts/core/LevelManager.gd` — level/enemy/difficulty tables, unrelated.
- `scenes/main/game.tscn`'s `Player` node tree — the character is attached into `PlayerVisuals` at runtime; the
  scene's placeholder `Body`/`Head` (`game.tscn:165-172`) stay as the documented fallback
  (`Player.gd:1025-1029` hides them).

### 6.2 Silent-break checklist (no error is raised for any of these)

1. Unknown `selected_character` id → `SKINS.get(id, {})` miss → untextured white model.
2. `CharacterAnim.setup*` returning `null` → no animation, no warning.
3. Wrong `Transform3D` scale → wrong size, no warning.
4. Wrong re-ground offset → sunk/floating character, no warning.
5. Props mis-placed → floating props, no warning.
6. `character_stats` staying `null` → identical characters, no warning.

---

## 7. Undetermined items

These could not be settled from source alone and were **not** guessed:

1. **The exact in-engine visual height / foot-line of the current survivor.** `_model_aabb` uses
   `MeshInstance3D.get_aabb()` on a skinned mesh; the raw mesh AABB (1.048 units) and the skinned bind-pose
   extent (1028.33 units) disagree by ~1000×, so the effective `vis.position.y` cannot be derived statically.
   Needs an engine run. (§2.7)
2. **Whether the five non-rigged animal zombies currently have any walk animation.** `ZombieBase.gd:126-128`
   disables the `ProceduralAnimator` for every zombie, and their GLBs have `skins=0` so `CharacterAnim` returns
   `null`; the code implies no walk animation, but this was not executed. (§3.4)
3. **The intended mapping of Blocky `character-a`…`character-r` and `texture-a`…`texture-r` onto the five
   survivor roles.** `tools/charcast_probe.gd` renders all 18 for manual selection
   (`tools/charcast_probe.gd:3,15-16`) but the repo contains no recorded choice.
4. **Whether `Prop` is meant to be one prop per character.** The brief listed five prop names; each scene
   instantiates exactly one `Prop` node and leaves the rest as unreferenced `sub_resource`s (§4.3).

---

## 8. Appendix — quick reference

**The five survivor ids (lowercase, as stored):** `gamer`, `doctor`, `nurse`, `streamer`, `hunter`
(`CharacterSelect.gd:10-16` → `:371`).

**Load chain, one line:** `title_screen` → `character_select.tscn` (`TitleScreen.gd:52`) →
`Save.set_selected_character()` (`CharacterSelect.gd:371`) → `level_select.tscn` (`CharacterSelect.gd:376`) →
`game.tscn` (`LevelSelect.gd:168`) → `Player._ready()` → `_apply_character_model()` (`Player.gd:107`) →
`_selected_character_id()` reads `/root/Save` (`Player.gd:1001-1005`) →
loads `scenes/characters/character_<id>.tscn` (`Player.gd:946`) → extracts `PlayerVisuals` (`Player.gd:951`) →
`CharacterAnim.setup(vis, id)` (`Player.gd:965`).

**Files referencing the current rig (complete list):**
`scenes/characters/character_{gamer,doctor,nurse,streamer,hunter}.tscn`,
`scenes/characters/zombie_{runner,butcher,spitter,boss}.tscn`,
`scripts/core/CharacterAnim.gd`, `scripts/core/Player.gd`, `scripts/ui/CharacterSelect.gd`,
`assets/models/MODEL_SCALE_TABLE.md`.
