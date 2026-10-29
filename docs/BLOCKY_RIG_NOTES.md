# Blocky Rig Notes — Kenney "Blocky Characters" in Godot 4.7

**Purpose:** the critical-path technical answer for rebuilding the five survivors
(`gamer`, `doctor`, `nurse`, `streamer`, `hunter`) on the blocky rig so each **idles** on the
character-select screen and **moves/attacks** in gameplay.

**Scope of this document:** read-only investigation. No `.tscn`, `.gd` or asset was modified.
All findings below are from real tool output, not memory.

| Item | Value |
|---|---|
| Godot version (measured) | `4.7.stable.official.5b4e0cb0f` (VPS `/root/Godot_v4.7-stable_linux.x86_64 --version`) |
| Engine JSON | `{"major":4,"minor":7,"patch":0,"hex":263936,"status":"stable","build":"official","hash":"5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"}` |
| Rigs | `/storage/emulated/0/Games/Muakbank_zombie/assets/models/cc0/blocks/character-a.glb` … `character-r.glb` (18 files) |
| Textures | `…/blocks/Textures/texture-a.png` … `texture-r.png` (18 files) |
| GLB generator | `UnityGLTF` (per `asset.generator`) |
| Analysis method | stdlib-only Python GLB reader (struct + json over the JSON/BIN chunks) + headless Godot 4.7 scene probes on the VPS |

The Python reader used for §1 and §5 is in the **Appendix**; it has no third-party dependencies.

---

## Q1 — ANIMATION MECHANISM: rigid-body node transforms, not skeletal

**Answer: confirmed — these are rigid-body node transforms.** There is no skeleton anywhere in the
file. `skins: 0`, no `Skeleton3D`, no `joints`, no `inverseBindMatrices`, no `skin` key on any node.

Node graph in the GLB (8 nodes, 6 meshes):

```
character-a            (scene root, Node3D, no mesh)
└── root               (Node3D, no mesh — the body pivot / translation driver)
    ├── leg-left       (MeshInstance3D, mesh 0)
    ├── leg-right      (MeshInstance3D, mesh 1)
    └── torso          (MeshInstance3D, mesh 2)
        ├── arm-left   (MeshInstance3D, mesh 3)
        ├── arm-right  (MeshInstance3D, mesh 4)
        └── head       (MeshInstance3D, mesh 5)
```

Rest-pose local transforms (from the GLB `nodes` array):

| node | translation | scale |
|---|---|---|
| `root` | (0, 0, 0) | — |
| `leg-left` | (0.2, 1.0, ~0) | — |
| `leg-right` | (−0.2, 1.0, ~0) | — |
| `torso` | (0.0, 0.7, 0.0) | — |
| `arm-left` | (0.4, 1.1, −0.1) | — |
| `arm-right` | (−0.4, 1.1, −0.1) | — |
| `head` | (0.0, 1.2, 0.0) | **(0.1, 0.1, 0.1)** |

The `head` scale of 0.1 is why its mesh accessor bounds are `−4…4 / 0…8 / −4…4` (a literal 8-unit
cube) yet it renders at 0.8×0.8×0.8 — see §5.

### `idle` — the exact channels it drives

`idle` = **4 channels, 4 samplers, 40 keys each, all `rotation`, all `LINEAR`, t = 0.000…1.333 s**:

| GLB node | node path | property | interp | keys | duration |
|---|---|---|---|---|---|
| 4 | `character-a/root/torso` | `rotation` | LINEAR | 40 | 1.333 s |
| 5 | `character-a/root/torso/arm-left` | `rotation` | LINEAR | 40 | 1.333 s |
| 6 | `character-a/root/torso/arm-right` | `rotation` | LINEAR | 40 | 1.333 s |
| 7 | `character-a/root/torso/head` | `rotation` | LINEAR | 40 | 1.333 s |

Real keyframe values (quaternions, xyzw — the four node channels):

```
torso     t=0.000 (-0.0000, 0.0000, 0.0000, -1.0000)
          t=0.333 ( 0.0436, 0.0000, 0.0000, -0.9990)   <- +5.0 deg pitch
          t=1.000 (-0.0436, 0.0000, 0.0000, -0.9990)   <- -5.0 deg pitch
arm-left  t=0.000 (-0.0000, 0.0000, 0.0000, -1.0000)
          t=0.333 ( 0.1305, 0.0000, 0.0000, -0.9914)   <- +15.0 deg
          t=1.000 (-0.1305, 0.0000, 0.0000, -0.9914)   <- -15.0 deg
arm-right identical to arm-left
head      t=0.000 (-0.0000,  0.0000, 0.0000, -1.0000)
          t=0.333 (-0.0000, -0.1305, 0.0000, -0.9914)  <- -15.0 deg yaw
          t=1.000 (-0.0000,  0.1305, 0.0000, -0.9914)  <- +15.0 deg yaw
```

Angle from quaternion: `θ = 2·asin(x)` (or `2·acos(w)`). `x=0.1305 → θ/2 = 7.5° → θ = 15°`;
`x=0.0436 → θ/2 = 2.5° → θ = 5°`.

**`idle` does not move any position** — no `translation`, no `scale`. It is a pure breathing sway:
torso pitch ±5°, both arms ±15°, head yaw ±15°, over 1.333 s. First key == last key on every
channel, so it is authored to loop seamlessly.

### What the other clips drive (all node transforms, no bones)

| animation | channels | nodes / properties driven |
|---|---|---|
| `static` | 21 | `translation` + `rotation` + `scale` on **all 7** nodes — this is the **rest-pose reference clip** (e.g. `leg-left` translation `(0.2, 1.0, 0)`, `head` scale `0.1`), 2 keys, 0.1 s |
| `idle` | 4 | `rotation` on torso, arm-left, arm-right, head |
| `walk` | 6 | `translation` on `root` (vertical bob 0 → 0.0896) + `rotation` on leg-left, leg-right, arm-left, arm-right, head (legs ±55.7°, arms ±60°) |
| `sprint` | 7 | `translation` on `root` (bob to 0.2) + `rotation` on leg-left, leg-right, **torso**, arm-left, arm-right, head |
| `die` | 8 | `translation` + `rotation` on `root` (root pitches to quat x = 0.7071 = **90° fall-over**, y rises to 0.2444 then settles at 0.05) + `rotation` on all 5 parts |
| `attack-melee-right` | 7 | `translation` on `root` (z lunges −0.0498 then +0.0661) + `rotation` on leg-left, leg-right, torso, arm-left, **arm-right** (swings to quat x = 0.9906 ≈ **164°**) , head |
| `attack-melee-left` | 7 | mirrored (arm-left swings) |
| `attack-kick-right/left` | 7 each | legs + torso + arms + head |
| `holding-right` / `holding-left` | 1 each | `rotation` on arm-right / arm-left only |
| `holding-both` | 2 | both arms |
| `holding-*-shoot` | 3–4 | arm(s) + torso + head |
| `interact-left/right` | 4 | torso + arms + head |
| `sit`, `drive`, `pick-up`, `emote-yes/no` | 3–5 | legs / arms / torso / head |
| `wheelchair-*` | 4–6 | legs, torso, arms, head |

All 27 clips are **node-path keyframe tracks**. Nothing references a bone, a `Skeleton3D`, or a
skinning matrix. **Confirms: rigid-body node transforms.**

---

## Q2 — DRIVABILITY IN GODOT 4.7: yes, and it works out of the box

**Answer: Godot 4.7 imports each blocky GLB as a usable `AnimationPlayer` that drives the part
nodes directly. `AnimationPlayer.play("idle")` really animates them.**

Measured on Godot `4.7.stable.official.5b4e0cb0f`, headless, loading
`res://assets/models/cc0/blocks/character-a.glb`:

**Root node type:** `Node3D`. Note the per-instantiation naming: the PackedScene root is **authored**
as `character-a2` (a suffix the importer bakes in), and its child is a `Node3D` named `character-a`
(the original GLB scene root). Verified via `PackedScene.get_state()`:

```
[0] name=character-a2 type=Node3D           path=.
[1] name=character-a  type=Node3D           path=./character-a
[2] name=root         type=Node3D           path=./character-a/root
[3] name=leg-left     type=MeshInstance3D   path=./character-a/root/leg-left
[4] name=leg-right    type=MeshInstance3D   path=./character-a/root/leg-right
[5] name=torso        type=MeshInstance3D   path=./character-a/root/torso
[6] name=arm-left     type=MeshInstance3D   path=./character-a/root/torso/arm-left
[7] name=arm-right    type=MeshInstance3D   path=./character-a/root/torso/arm-right
[8] name=head         type=MeshInstance3D   path=./character-a/root/torso/head
[9] name=AnimationPlayer type=AnimationPlayer path=./AnimationPlayer
```

**Real observed node tree after `instantiate()` + `add_child()`:**

```
character-a2 (Node3D)
└── character-a (Node3D)
    └── root (Node3D)
        ├── leg-left (MeshInstance3D)
        ├── leg-right (MeshInstance3D)
        └── torso (MeshInstance3D)
            ├── arm-left (MeshInstance3D)
            ├── arm-right (MeshInstance3D)
            └── head (MeshInstance3D)
AnimationPlayer (AnimationPlayer)          <- SIBLING of `character-a`, child of the scene root
```

**Is an `AnimationPlayer` created?** Yes — exactly one, named `AnimationPlayer`, placed at
`./AnimationPlayer` relative to the glb scene root, as a **sibling** of the `character-a` node.
Its `root_node` is `..` (i.e. the glb scene root), and that resolves correctly:
`ap.get_node(ap.root_node).name == "character-a2"`.

**Animation names available — all 27, in one library `""`:**

```
attack-kick-left, attack-kick-right, attack-melee-left, attack-melee-right, die, drive,
emote-no, emote-yes, holding-both, holding-both-shoot, holding-left, holding-left-shoot,
holding-right, holding-right-shoot, idle, interact-left, interact-right, pick-up, sit,
sprint, static, walk, wheelchair-move-back, wheelchair-move-forward, wheelchair-move-left,
wheelchair-move-right, wheelchair-sit
```

**Track structure as Godot imports it** (the GLB channels above, plus Godot's own rest-pose
padding):

```
--- ANIM 'idle': tracks=8 length=1.333 ---
  track[0] type=2 path=character-a/root/torso            keys=39
  track[1] type=2 path=character-a/root/torso/arm-left   keys=39
  track[2] type=2 path=character-a/root/torso/arm-right  keys=39
  track[3] type=2 path=character-a/root/torso/head       keys=39
  track[4] type=1 path=character-a/root                  keys=1
  track[5] type=2 path=character-a/root                  keys=1
  track[6] type=2 path=character-a/root/leg-left         keys=1
  track[7] type=2 path=character-a/root/leg-right        keys=1
```

Track types are docs-verified (`Animation.TrackType`, Godot 4.7 docs):
`TYPE_VALUE = 0`, `TYPE_POSITION_3D = 1`, `TYPE_ROTATION_3D = 2`, `TYPE_SCALE_3D = 3`.
So `type=1` = position, `type=2` = rotation. Tracks with `keys=1` are the importer's rest-pose
holds (Godot adds a single-key track so unanimated parts do not inherit the previous clip's pose).

Interpolation of `idle` track[0] = `1` = `INTERPOLATION_LINEAR`.

**Does `play("idle")` actually animate the part nodes? Yes — measured live.**

```
BEFORE play: head.rot=(0,0,0) arm-right.rot=(0,0,0) leg-left.rot=(0,0,0)
is_playing=true current=idle
IDLE SAMPLE 0.20s arm-right.rot.x=-0.1696
IDLE SAMPLE 0.42s arm-right.rot.x=-0.2290
IDLE SAMPLE 0.64s arm-right.rot.x=-0.0194
IDLE SAMPLE 0.87s arm-right.rot.x=+0.1944
IDLE SAMPLE 1.09s arm-right.rot.x=+0.2154
IDLE SAMPLE 1.31s arm-right.rot.x=+0.0093
```

and for `walk` (root bob + legs):

```
WALK SAMPLE t=0.118 root.pos.y=0.0782 leg-left.rot.x=-0.8193 leg-right.rot.x=+0.8193
WALK SAMPLE t=0.243 root.pos.y=0.0562 leg-left.rot.x=-0.7034 leg-right.rot.x=+0.7034
WALK SAMPLE t=0.368 root.pos.y=0.0114 leg-left.rot.x=+0.2545 leg-right.rot.x=-0.2545
WALK SAMPLE t=0.493 root.pos.y=0.0896 leg-left.rot.x=+1.0307 leg-right.rot.x=-1.0307
```

**Animation survives reparenting.** After moving the glb root under a wrapper (`body/Mesh/<glb>`),
`play("idle")` still drove 8 distinct `arm-right.rot.x` values over 1.4 s. Because `root_node` is a
*relative* path (`..`), Godot re-resolves it after reparenting. No rebasing is needed.

**`play(anim, blend_time)` and `speed_scale` both work** (what `ZombieBase._drive_anim()` needs):

```
set_speed_scale(1.35) -> 1.35
play('walk', 0.15) -> current=walk
play('attack-melee-right') -> current=attack-melee-right len=0.417
```

### ⚠ Gotcha: imported clips are `LOOP_NONE` — they stop at the end

Measured clip metadata (all five sampled clips identical):

```
idle                 len=1.3333 loop_mode=0 step=0.0333 tracks=8
walk                 len=0.6667 loop_mode=0 step=0.0333 tracks=8
sprint               len=0.5000 loop_mode=0 step=0.0333 tracks=8
die                  len=0.3333 loop_mode=0 step=0.0333 tracks=8
attack-melee-right   len=0.4167 loop_mode=0 step=0.0333 tracks=8
```

Godot 4.7 docs, `Animation.LoopMode`: `LOOP_NONE = 0` — *"At both ends of the animation, the
animation will stop playing."* So **`idle`/`walk`/`sprint` play once and freeze** unless the code
sets `loop_mode`. Any replacement must do:

```gdscript
var a := ap.get_animation("idle")
a.loop_mode = Animation.LOOP_LINEAR   # LOOP_LINEAR = 1
```

Do this on a `duplicate()`d animation, not the shared imported resource (see §4 caveat).
`step = 0.0333` = the project's `animation/fps=30` import setting; snap-free, so it is fine.

---

## Q3 — COMPATIBILITY WITH THE EXISTING SYSTEM: it cannot drive a `skins: 0` rig

**Answer: `CharacterAnim.setup_rigged()` cannot drive a blocky rig. It returns `null` before it ever
looks at an animation, because every one of its model-resolution gates is a `Skeleton3D` test.**

`scripts/core/CharacterAnim.gd`, `setup_rigged()` (L48–90). The three fatal gates:

```gdscript
49	var model: Node3D = null
50	var direct := visuals.get_node_or_null("Model") as Node3D
51	if direct != null and _has_skeleton(direct):        # <-- GATE 1
52		model = direct
53	else:
54		for c in visuals.get_children():
55			if c is Node3D and _has_skeleton(c):        # <-- GATE 2
56				model = c
57				break
58	if model == null:
59		return null                                     # <-- BAILS HERE
60
61	var skels := model.find_children("*", "Skeleton3D", true, false)
62	if skels.is_empty():
63		return null                                     # <-- GATE 3
```

with the gate itself at L89–90:

```gdscript
89	static func _has_skeleton(n: Node) -> bool:
90		return not n.find_children("*", "Skeleton3D", true, false).is_empty()
```

**Measured proof:** in the exact `PlayerVisuals/Model/<glb>` layout the game builds,

```
Skeleton3D found under glb instance: 0
CharacterAnim.setup_rigged(wrapper) returned: NULL
```

and `Model.find_children("*","Skeleton3D",true,false).size() == 0`.

Three further independent reasons it cannot work even if the gates passed:

1. **`_retarget()` (L122–132) is bone-keyed.** It rewrites each track path to
   `"<skeleton_path>:<bone>"` only when `skeleton.find_bone(last) >= 0`. There is no skeleton and
   the last path segment of a blocky track is a *node name* (`torso`, `head`), not a bone. Every
   track would be left untouched and every path would then point at a nonexistent `:<bone>`
   property — the animation would silently no-op or error.
2. **`_load_clip()` (L95–117) reads the wrong files.** It hardcodes
   `ANIM_DIR + nm + ".glb"` for `["idle","run","jump"]` in `assets/models/cc0/kenney_anim/`. The
   blocky clips live *inside* `blocks/character-*.glb`, and the rig ships `walk`/`sprint` — there is
   **no `run` and no `jump` clip at all** in the blocky set.
3. **`apply_skin_raw()` is never reached**, because the function returns at L59/L63.

**Consequence today, traced through the callers:**

* `scripts/ui/CharacterSelect.gd:192-194` — `var sap := CharacterAnim.setup(vis, cid)` → `null`,
  so `if sap != null: sap.play("idle")` never runs. **No idle on the select screen.**
* `scripts/core/Player.gd:965-968` — `_skeletal = CharacterAnim.setup(vis, id)` → `null`, so
  `_skeletal.play("idle")` is skipped and `_update_skeletal_anim()` early-returns forever.
* `scripts/characters/ZombieBase.gd:396-399` — `_drive_anim()` does
  `var ap := mesh.get_node_or_null("AnimationPlayer")`; with the glb root nested one level below
  `Mesh`, this is **`null`** (measured: `Model.get_node_or_null("AnimationPlayer") = <Object#null>`),
  so it returns immediately.

### What a working replacement must do

A blocky-rig driver needs **no skeleton and no retargeting** — the imported tracks already target
the model's own nodes. Concretely:

1. **Find the `AnimationPlayer` recursively, not by direct path.**
   `model.find_child("AnimationPlayer", true, false)` (verified to return
   `.../Model/character-a2/AnimationPlayer`), *not* `get_node_or_null("AnimationPlayer")`.
2. **Do not require a `Skeleton3D`.** Branch on its absence: if no `Skeleton3D`, keep the glb's own
   `AnimationPlayer` and play its clips directly.
3. **Use the blocky clip names.** `idle`, `walk`, `sprint`, `die`, `attack-melee-right/left`,
   `attack-kick-*`, `holding-*`, `interact-*`, `pick-up`, `sit`, `drive`, `emote-*`. There is no
   `run` and no `jump` — map the game's "run" to `sprint` (or `walk`) and either drop jump or reuse
   `emote-yes`/`pick-up`. `_load_clip()`'s `kenney_anim/` paths and the `"Targeting"`-clip skip must
   both go.
4. **Set `loop_mode = LOOP_LINEAR`** on `idle`/`walk`/`sprint` (see §2 gotcha) on a duplicated
   `Animation` resource.
5. **Apply the skin by writing the GLB's single shared material**, not by blanket-overriding
   (see §4). `apply_skin_raw()`'s current per-`MeshInstance3D` `material_override` approach still
   "works" visually but throws away the unlit flag and creates six duplicate materials.
6. **Keep the `Model` child name** if you want `setup_rigged()`'s first branch to keep matching, but
   since the branch is skeleton-gated that is not sufficient on its own.

`docs/CHARSELECT_AUDIT.md:424-428` reaches the same conclusion ("Extend `CharacterAnim` with a
node-animated branch: if no `Skeleton3D` is found, keep the GLB's own `AnimationPlayer` … and play
`"idle"` directly. No retargeting needed"). §2 above is the empirical confirmation of that plan,
including the `loop_mode` and `find_child` details it omits.

---

## Q4 — TEXTURE APPLICATION: external URI, but Godot resolves it automatically

**Answer: the `.glb` references the texture by an EXTERNAL, relative URI — it is not embedded — and
Godot resolves it to the sibling PNG with no runtime code.**

GLB `images` / `textures` / `materials` (character-a):

```json
"images":   [{"uri": "Textures/texture-a.png", "name": "texture-a"}],
"textures": [{"sampler": 0, "source": 0, "name": "texture-a"}],
"samplers": [{"minFilter": 9729}],
"materials": [{
  "pbrMetallicRoughness": {
    "baseColorTexture": {"index": 0, "extensions": {"KHR_texture_transform": {"texCoord": 0}}}
  },
  "name": "texture-a",
  "extensions": {"KHR_materials_unlit": {}}
}]
"extensionsUsed": ["KHR_materials_unlit", "KHR_texture_transform"]
```

So: **one image, one texture, one material, external URI `Textures/texture-a.png`**, referenced by
`materials[0].pbrMetallicRoughness.baseColorTexture`. There is **no `bufferView`/`mimeType`** on the
image — nothing is embedded.

**Measured result in Godot 4.7** (the URI resolves against the GLB's own directory, giving the
sibling `Textures/` folder):

```
ResourceLoader.exists(res://assets/models/cc0/blocks/character-a.glb) = true
leg-left  surf[0] StandardMaterial3D albedo_texture.resource_path=res://assets/models/cc0/blocks/Textures/texture-a.png shading_mode=0 albedo_color=(1,1,1,1)
leg-right surf[0] ... same ...
torso     surf[0] ... same ...
arm-left  surf[0] ... same ...
arm-right surf[0] ... same ...
head      surf[0] ... same ...
```

`shading_mode=0` is `BaseMaterial3D.SHADING_MODE_UNSHADED`, produced by `KHR_materials_unlit`.
`albedo_color` is pure white `(1,1,1,1)`, so the PNG supplies all colour.

### Material structure — one material shared by all six parts

Measured with `get_instance_id()` per surface:

```
leg-left   material_instance_id=-9223372009994451503
leg-right  material_instance_id=-9223372009994451503
torso      material_instance_id=-9223372009994451503
arm-left   material_instance_id=-9223372009994451503
arm-right  material_instance_id=-9223372009994451503
head       material_instance_id=-9223372009994451503
DISTINCT material resources = 1  (parts per material: { "-9223372009994451503": 6 })
```

Then writing **only the head's** material:

```
loaded texture-b: res://assets/models/cc0/blocks/Textures/texture-b.png
leg-left  -> albedo_texture=.../texture-b.png albedo_color=(0.86, 0.92, 1.0, 1.0)
leg-right -> albedo_texture=.../texture-b.png albedo_color=(0.86, 0.92, 1.0, 1.0)
torso     -> albedo_texture=.../texture-b.png albedo_color=(0.86, 0.92, 1.0, 1.0)
arm-left  -> albedo_texture=.../texture-b.png albedo_color=(0.86, 0.92, 1.0, 1.0)
arm-right -> albedo_texture=.../texture-b.png albedo_color=(0.86, 0.92, 1.0, 1.0)
head      -> albedo_texture=.../texture-b.png albedo_color=(0.86, 0.92, 1.0, 1.0)
parts sharing the written material object = 6 / 6
```

**⇒ One write skins the entire body.**

### The exact property to set

There is **one** `StandardMaterial3D` on surface 0 of all six `MeshInstance3D`s. To swap skins:

```gdscript
var mat := (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
mat.albedo_texture = load("res://assets/models/cc0/blocks/Textures/texture-b.png")
mat.albedo_color   = Color(1, 1, 1)          # tint, if you want per-survivor distinction
mat.shading_mode   = BaseMaterial3D.SHADING_MODE_PER_PIXEL   # optional: unlit -> lit
mi.mesh.surface_set_material(0, mat)
```

* `albedo_texture` is the property that carries the skin (`texture-a.png` … `texture-r.png`).
* `albedo_color` is the per-survivor tint hook (mirrors `CharacterAnim.SKINS`' `tint` values).
* Set `shading_mode` to `SHADING_MODE_PER_PIXEL` (1) if you want the survivors to receive scene
  lighting; as imported they are **unlit and will look flat** in the menu and in gameplay.

**No runtime texture application is strictly required for `texture-a`** — it arrives wired up. It
*is* required for any other character, because `character-b.glb` hard-references `texture-b.png`,
etc., so simply loading `character-b.glb` already gives you texture-b. In practice you only need
runtime assignment if you want one GLB to wear a different character's skin.

⚠ **Unverified:** whether the single material resource is shared *across separate instances* of the
same PackedScene (I verified only that it is shared *within* one instance). The safe pattern is
`duplicate()` per instance, as above, which also avoids mutating the imported resource globally.
Also unverified: whether `duplicate()` on a material whose `albedo_texture` is an external
`CompressedTexture2D` carries the texture reference — set `albedo_texture` explicitly after
duplicating, as shown.

---

## Q5 — SCALE: native bbox is 1.6 × **2.7** × 0.8; scale factor = **0.6667** (2/3)

Composing every node transform (translation, quaternion rotation, scale) down the hierarchy and
transforming each mesh's accessor min/max gives the rest-pose bounding box in model units:

| part | min | max | size |
|---|---|---|---|
| `leg-left` | (0.000, 0.000, −0.200) | (0.400, 1.000, 0.200) | 0.4 × 1.0 × 0.4 |
| `leg-right` | (−0.400, 0.000, −0.200) | (0.000, 1.000, 0.200) | 0.4 × 1.0 × 0.4 |
| `torso` | (−0.400, 1.000, −0.300) | (0.400, 1.900, 0.300) | 0.8 × 0.9 × 0.6 |
| `arm-left` | (0.400, 0.800, −0.300) | (0.800, 1.900, 0.100) | 0.4 × 1.1 × 0.4 |
| `arm-right` | (−0.800, 0.800, −0.300) | (−0.400, 1.900, 0.100) | 0.4 × 1.1 × 0.4 |
| `head` | (−0.400, 1.900, −0.400) | (0.400, 2.700, 0.400) | 0.8 × 0.8 × 0.8 |
| **ASSEMBLED** | **(−0.800, 0.000, −0.400)** | **(0.800, 2.700, 0.400)** | **1.600 × 2.700 × 0.800** |

**Independently confirmed inside Godot 4.7** by merging the transformed per-mesh AABBs:

```
--- ASSEMBLED AABB (model units, relative to glb root) ---
  position=(-0.8, 0.0, -0.4) size=(1.6, 2.7, 0.8) end=(0.8, 2.7, 0.4)
```

Identical across all 18 files (checked `character-a` … `character-r`: every one is
`(1.600, 2.700, 0.800)`, height 2.700).

### The arithmetic

```
native height H = 2.700 model units
target height    = 1.800 m  (the game's Player.CHARACTER_HEIGHT)
scale s = 1.800 / 2.700 = 0.666666... = 2/3

check: 2.700 * 0.6667 = 1.8001 m   ✓
```

**Scale factor = 0.6667 (exactly 2/3).**

Feet sit at **y = 0** in model units (`assembled min.y == 0.000`), and the origin is horizontally
centred (`min.x == −max.x`, `min.z == −max.z`). So after scaling, feet are still at local y = 0 —
**no vertical offset is needed**, though re-grounding by AABB (as `Player.gd:962-964` already does)
is the robust habit.

**The game already computes this correctly at runtime.** `scripts/core/Player.gd`:

```gdscript
933	const CHARACTER_HEIGHT := 1.8
1010	var h := aabb.size.y
1012		var s := CHARACTER_HEIGHT / h
1013		mdl.scale = Vector3(s, s, s)
1014		mdl.position.y = -aabb.position.y * s
```

With `h = 2.7` that yields `s = 0.6667` — exactly the value derived above. Any hand-authored scale
must match it.

### ⚠ Correction to `assets/models/MODEL_SCALE_TABLE.md`

* `MODEL_SCALE_TABLE.md:55` lists `cc0/blocks/character-*.glb` as `[8.0, 9.0, 8.0]` and
  `:38` prescribes **scale 0.2**. Both are wrong. The `8 × 9 × 8` figure is the **raw, untransformed
  accessor bounds** — `8` comes from the head cube's `−4…4 / 0…8 / −4…4` accessor **before** the
  node's `0.1` scale is applied, and it ignores that `leg-left`'s accessor sits at `y −1.0…0.0`
  under a `translation.y = 1.0`. Applying `0.2` would make the survivors **0.54 m tall**.
* `docs/CHARSELECT_AUDIT.md:179-188` correctly rejects the `0.2`, but derives **2.0 units** tall and
  therefore `1.8 / 2.0 = 0.9`. That table (its rows for `leg-left`, `torso`, `arm-left`, `head`)
  **omits `torso`'s `translation.y = 0.7`** when composing the head. Correct chain:

  ```
  root(0) -> torso(+0.7) -> head(+1.2) = 1.9   head mesh y 0…8, scale 0.1 -> 0…0.8
  => head spans 1.9 … 2.7   (not 0.8 … 2.0)
  ```

  With `torso` included, height = **2.7**, so the correct factor is **0.6667**, not `0.9`. `0.9`
  would make the survivors **2.43 m** tall.

---

## Q6 — NAMED-PART CONTRACT: the exact addressable node names

**Real names, read from the GLB node list and confirmed post-import in Godot 4.7:**

| GLB node index | node name | Godot type | parent |
|---|---|---|---|
| 0 | `character-a` | `Node3D` | (glb scene root) |
| 1 | `root` | `Node3D` | `character-a` |
| 2 | `leg-left` | `MeshInstance3D` | `root` |
| 3 | `leg-right` | `MeshInstance3D` | `root` |
| 4 | `torso` | `MeshInstance3D` | `root` |
| 5 | `arm-left` | `MeshInstance3D` | `torso` |
| 6 | `arm-right` | `MeshInstance3D` | `torso` |
| 7 | `head` | `MeshInstance3D` | `torso` |

**Stable addressable part names (identical in all 18 files):**
`root`, `leg-left`, `leg-right`, `torso`, `arm-left`, `arm-right`, `head`.

Only the two *root* names vary per file — the scene root is `character-a` … `character-r` — and the
importer additionally renames the instantiated PackedScene root with a numeric suffix
(measured: authored `character-a2`; a second `instantiate()` also produced `character-a2`, i.e. the
suffix is **baked into the .scn by the importer**, not generated per instantiation).

⚠ **Do not rely on the two root names.** Address parts by the six stable names via a recursive
search. Measured from a `PlayerVisuals` wrapper:

```
visuals.find_child("leg-left")  -> .../Model/character-a2/character-a/root/leg-left
visuals.find_child("leg-right") -> .../Model/character-a2/character-a/root/leg-right
visuals.find_child("torso")     -> .../Model/character-a2/character-a/root/torso
visuals.find_child("arm-left")  -> .../Model/character-a2/character-a/root/torso/arm-left
visuals.find_child("arm-right") -> .../Model/character-a2/character-a/root/torso/arm-right
visuals.find_child("head")      -> .../Model/character-a2/character-a/root/torso/head
```

### Attaching a prop to the right hand

**There is no `hand` node.** The nearest anchor is `arm-right`, whose mesh AABB is
`pos=(-0.4, -1.0, -0.2) size=(0.4, 1.1, 0.4)` in its own local space — the arm hangs *downward* from
its pivot, so **the hand end is at local y ≈ −1.0**. `arm-right` has **zero children**
(`arm-right children=0`), so a prop must be added by the caller:

```gdscript
var hand := visuals.find_child("arm-right", true, false) as Node3D
# hand-local: y = -1.0 is the wrist/hand end, x = 0, z = 0
prop.position = Vector3(0.0, -1.0, 0.0)   # in MODEL units -> multiply by 0.6667 for world m
hand.add_child(prop)
```

Because the prop inherits the arm's animated rotation, it will swing with `attack-melee-right`
(which drives `arm-right` to ≈164°). Note the existing per-character `Prop` nodes in
`scenes/characters/character_*.tscn` (e.g. gamer's controller at `(0.28, 0.62, 0.24)`) were authored
against the **0.00425-scale `kenney_anim/model.glb`** and are wrong for this rig in both offset and
scale — they must be re-authored.

---

## Bonus findings that affect the rebuild

These are not among the six questions but are load-bearing for "idle on select, move in gameplay".

### Facing: the character faces **+Z**, but the game's yaw idiom assumes **−Z**

Determined by decoding the head cube's UVs against real atlas pixels:

* The head cube's UV layout is a standard 4-column × 3-row unwrap; column 4 / row 2 belongs to the
  face whose normal is `(0, 0, −1)`, and column 2 / row 2 to the face whose normal is `(0, 0, +1)`.
* Cropping each cell out of `texture-a.png` and inspecting: the cell for **normal `(0,0,+1)` contains
  the face** (eyes, brows, nose, beard, ear) and the cell for **normal `(0,0,−1)` is plain dark grey**
  (hair/back of head). The two side cells are ears.
* **⇒ the face is on +Z. The model faces +Z.**

**Independently confirmed by handedness, with no image inspection.** In Godot's basis,
`forward × up = right`, and the engine's own convention is `forward = −Z`, `right = +X`:
`(0,0,−1) × (0,1,0) = (+1,0,0)` ✓. This rig puts **`arm-right` at x = −0.4** and `arm-left` at
x = +0.4. A model whose own right arm lies at `−X` must have `right = −X`, and therefore
`forward = +Z` (since `(0,0,+1) × (0,1,0) = (−1,0,0) = −X` ✓). Two independent lines of evidence —
texture and handedness — agree on **+Z**.

The project assumes the opposite everywhere:

* `scripts/characters/ZombieBase.gd:313` (and every `Zombie*.gd`), and
  `scripts/core/Player.gd:353`:
  `var rot = atan2(dir.x, dir.z)` then `mesh.rotation.y = lerp_angle(...)` — this orients a
  **−Z-facing** model toward `dir`. For a +Z-facing model the survivor/zombie will **run backwards**.
* `docs/LEVEL1_DESIGN.md:21` — *"Rotation is yaw in radians (0 = facing −Z, the Godot forward)"*.
* `scripts/core/Player.gd:934` — `const MODEL_YAW_OFFSET := 0.0   # flip to PI if the model faces
  backwards`. **This is exactly that case.**

**Fix:** set `MODEL_YAW_OFFSET := PI` (Player.gd:934) and add `+ PI` (or `− PI`) to the
`atan2(dir.x, dir.z)` yaw in `ZombieBase.gd` / each `Zombie*.gd` / `Player.gd:353`, **or** bake the
180° into a wrapper node once. Baked-into-the-wrapper is preferable: one change instead of ~12.

### V coordinate convention — no flip

Godot imports the head's `TEXCOORD_0` **verbatim** (no V flip): matching raw-glTF vertices to
Godot's `surface_get_arrays()` shows identical positions with identical UVs
(raw glTF `(-4,0,-4) uv (0.0179, 1.2436)` ⇒ Godot `pos=(-4.000,0.000,-4.000) uv=(0.0179,1.2436)`).
GLTF UVs wrap, so `1.2436` samples PNG row `0.2436 × 1024 = 249`. Empirically confirmed by the
face-location crop in this section: the un-flipped crop is the coherent cube unwrap; the flipped
crop is garbage. So any custom atlas work must use the raw glTF V, unflipped.

### Atlas shape

`texture-*.png` are **1024×1024, 8-bit, palette (colortype 3)**, 256 distinct colours. The content
is a single unwrap block spanning roughly `x 0…736, y 534…1023` plus a smaller region at
`x 766…1023`; the remainder is a two-tone dark background `(30,30,35)` / `(42,42,49)`. The atlas is
**not** a clean grid of per-part squares — do not assume one; measure the UV footprint per part.

### Unlit shading

`KHR_materials_unlit` ⇒ `shading_mode = SHADING_MODE_UNSHADED` on the imported material. The
blocky characters will render **flat and unlit** — no shading response to scene lights. Set
`shading_mode = SHADING_MODE_PER_PIXEL` if you want them lit like the rest of the game.

### Where the rigs are (and are not) wired up today

* The five survivor scenes (`scenes/characters/character_{gamer,doctor,nurse,streamer,hunter}.tscn`)
  instance `res://assets/models/cc0/kenney_anim/model.glb` at `scale = 0.00425` — **not** the
  blocky rigs. The rebuild must change both the `ext_resource` and the `Transform3D` scale.
* The 18 blocky GLBs are currently referenced by **no** scene or script (only by
  `tools/charcast_probe.gd`, `docs/*`, `CREDITS.md`, `assets/models/*`).
* All 18 rigs are byte-structurally identical apart from their texture URI: `skins=0`, `nodes=8`,
  the same 7 part names, the same 27 animation names, the same 1.6 × 2.7 × 0.8 bbox, and the same
  `.import` settings (`animation/import=true`, `animation/fps=30`, `nodes/root_type=""`,
  `nodes/apply_root_scale=true`, `gltf/texture_map_mode=1`). Verified across all 18.
* `docs/CHARSELECT_AUDIT.md:604` asks *"Which of the 18 blocky models maps to which survivor?"* —
  still open. The only hard constraint is that `character-<x>.glb` hard-references
  `Textures/texture-<x>.png`, so picking `character-x` *is* picking skin `x`.

---

## Appendix — stdlib-only GLB reader

No third-party dependencies (`struct` + `json` only). Parses the 12-byte GLB header, walks the
chunks, and reads accessors out of the BIN chunk.

```python
#!/usr/bin/env python3
"""Stdlib-only GLB reader: JSON chunk + accessor decoding. No dependencies."""
import struct, json

def load_glb(path):
    with open(path, 'rb') as f:
        data = f.read()
    magic, version, length = struct.unpack_from('<III', data, 0)
    assert magic == 0x46546C67, "not a GLB (bad magic)"
    off, js, bin_chunk = 12, None, None
    while off < length:
        clen, ctype = struct.unpack_from('<II', data, off)
        off += 8
        chunk = data[off:off + clen]
        if ctype == 0x4E4F534A:      # 'JSON'
            js = json.loads(chunk.decode('utf-8'))
        elif ctype == 0x004E4942:    # 'BIN'
            bin_chunk = chunk
        off += clen
    return js, bin_chunk, version, length

COMP  = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

def read_accessor(js, bin_chunk, idx):
    acc = js['accessors'][idx]
    fmt, ncomp = COMP[acc['componentType']], NCOMP[acc['type']]
    bv = js['bufferViews'][acc['bufferView']]
    base = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    stride = bv.get('byteStride') or (struct.calcsize('<' + fmt) * ncomp)
    return [struct.unpack_from('<' + fmt * ncomp, bin_chunk, base + i * stride)
            for i in range(acc['count'])]

def node_path(js, idx):
    parent = {c: i for i, n in enumerate(js['nodes']) for c in (n.get('children') or [])}
    parts, cur = [], idx
    while cur is not None:
        parts.append(js['nodes'][cur].get('name', '?'))
        cur = parent.get(cur)
    return '/'.join(reversed(parts))

# --- report ---
if __name__ == '__main__':
    import sys
    js, bin_chunk, ver, length = load_glb(sys.argv[1])
    print("GLB v%d  bytes=%d  generator=%s" % (ver, length, js['asset'].get('generator')))
    print("skins=%d  nodes=%d  meshes=%d  materials=%d  images=%s"
          % (len(js.get('skins', [])), len(js['nodes']), len(js['meshes']),
             len(js.get('materials', [])), js.get('images')))
    for i, n in enumerate(js['nodes']):
        print("  node[%d] %-12s children=%s mesh=%s"
              % (i, n.get('name'), n.get('children'), n.get('mesh')))
    for a in js['animations']:
        print("  anim %-24s channels=%d" % (a['name'], len(a['channels'])))
        for ch in a['channels']:
            s = a['samplers'][ch['sampler']]
            t = [x[0] for x in read_accessor(js, bin_chunk, s['input'])]
            print("     %-40s prop=%-11s interp=%-6s keys=%d dur=%.3fs"
                  % (node_path(js, ch['target']['node']), ch['target']['path'],
                     s.get('interpolation', 'LINEAR'), len(t), max(t) - min(t)))
```

---

## Verified / unverified summary

**Verified by real tool output:**
rigid-body node animation with the exact `idle` channels and keyframe values · 27 animations in one
`""` library · Godot 4.7 imports a working `AnimationPlayer` (`root_node = ".."`, sibling of
`character-a`) · `play("idle")` and `play("walk")` drive the part nodes · animation survives
reparenting · `play(name, blend)` + `speed_scale` work · imported clips are `LOOP_NONE` ·
`CharacterAnim.setup_rigged()` returns `null` on this rig (measured) · `Model.get_node_or_null("AnimationPlayer")`
is `null` (measured) · texture is an external URI and Godot resolves it to the sibling PNG ·
one shared material across all six parts · bbox 1.6 × 2.7 × 0.8 with feet at y=0, so scale 0.6667 ·
the six part names and their parent chain · the face is on +Z · no V flip · all 18 rigs structurally
identical · Godot version `4.7.stable.official.5b4e0cb0f` · API enums (`TrackType`,
`LoopMode`, `track_get_type`, `root_node`) confirmed against the Godot 4.7 docs.

**Could NOT verify (flagged, not guessed):**
1. Whether the single imported material resource is shared *across separate instances* of the same
   PackedScene (verified only *within* one instance). Recommend `duplicate()` per instance.
2. Whether `StandardMaterial3D.duplicate()` carries the external `albedo_texture` reference —
   set `albedo_texture` explicitly after duplicating.
3. Which of `character-a` … `character-r` should map to which survivor — a content/design decision,
   not a technical one. The only hard coupling is `character-x.glb` ↔ `Textures/texture-x.png`.
4. No on-device (Android/Termux) rendering check was possible — Termux cannot run Godot. All Godot
   evidence is from headless 4.7 on the VPS. Headless proves the animation *drives* the nodes; it
   does not prove the visual result on a phone GPU.
