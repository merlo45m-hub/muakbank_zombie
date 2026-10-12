class_name BlockyAnim
extends RefCounted

## BlockyAnim — Animation and skin driver for Kenney Blocky Characters (skins: 0) rigs.
##
## Unlike skeletal rigs, blocky rigs animate rigid node transforms.
## The AnimationPlayer is a sibling of the GLB scene root.
## This helper locates the player, duplicates looping clips so imported resources
## are not mutated, maps gameplay animation states to blocky clip names,
## and applies survivor texture atlases at runtime.

const RIG_PART_NAMES: Array[String] = [
	"leg-left",
	"leg-right",
	"torso",
	"arm-left",
	"arm-right",
	"head",
]

const LOOPING_CLIPS: Array[String] = [
	"idle",
	"walk",
	"sprint",
	"holding-both",
	"holding-left",
	"holding-right",
	"interact-right",
]

const STATE_TO_CLIP: Dictionary = {
	"idle": "idle",
	"run": "sprint",
	"sprint": "sprint",
	"walk": "walk",
	"attack": "attack-melee-right",
	"death": "die",
	"die": "die",
}


## Which rig letter each survivor uses. Verified by rendering all 18 rigs:
## b=red hoodie (gamer), i=white coat+glasses (doctor), f=female teal (nurse),
## q=hooded dark (streamer), a=bearded jacket (hunter).
const RIG_LETTER_TO_SURVIVOR: Dictionary = {
	"b": "gamer",
	"i": "doctor",
	"f": "nurse",
	"q": "streamer",
	"a": "hunter",
}

## 15 distinct Kenney Blocky Character bodies assigned across survivors:
## gamer: b (default), e, h
## doctor: i (default), j, l
## nurse: f (default), c, k
## streamer: q (default), p, m
## hunter: a (default), d, n
## Unused left over: o, g, r
const SKIN_VARIANTS: Dictionary = {
	"gamer": [
		{"name": "Cyber Purple", "rig": "res://assets/models/cc0/blocks/character-b.glb", "atlas": "res://assets/textures/survivors/gamer.png", "blocky": "res://assets/textures/survivors/gamer.png"},
		{"name": "Arcade Gold", "rig": "res://assets/models/cc0/blocks/character-e.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-e.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-e.png"},
		{"name": "Street Cap", "rig": "res://assets/models/cc0/blocks/character-h.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-h.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-h.png"},
	],
	"doctor": [
		{"name": "Clinical White", "rig": "res://assets/models/cc0/blocks/character-i.glb", "atlas": "res://assets/textures/survivors/doctor.png", "blocky": "res://assets/textures/survivors/doctor.png"},
		{"name": "Field Officer", "rig": "res://assets/models/cc0/blocks/character-j.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-j.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-j.png"},
		{"name": "Head Surgeon", "rig": "res://assets/models/cc0/blocks/character-l.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-l.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-l.png"},
	],
	"nurse": [
		{"name": "Mint Teal", "rig": "res://assets/models/cc0/blocks/character-f.glb", "atlas": "res://assets/textures/survivors/nurse.png", "blocky": "res://assets/textures/survivors/nurse.png"},
		{"name": "Pastel Mint", "rig": "res://assets/models/cc0/blocks/character-c.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-c.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-c.png"},
		{"name": "Formal Blue", "rig": "res://assets/models/cc0/blocks/character-k.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-k.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-k.png"},
	],
	"streamer": [
		{"name": "Shadow Black", "rig": "res://assets/models/cc0/blocks/character-q.glb", "atlas": "res://assets/textures/survivors/streamer.png", "blocky": "res://assets/textures/survivors/streamer.png"},
		{"name": "Urban Neon", "rig": "res://assets/models/cc0/blocks/character-p.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-p.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-p.png"},
		{"name": "Tactical Camo", "rig": "res://assets/models/cc0/blocks/character-m.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-m.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-m.png"},
	],
	"hunter": [
		{"name": "Camo Olive", "rig": "res://assets/models/cc0/blocks/character-a.glb", "atlas": "res://assets/textures/survivors/hunter.png", "blocky": "res://assets/textures/survivors/hunter.png"},
		{"name": "Forest Ranger", "rig": "res://assets/models/cc0/blocks/character-d.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-d.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-d.png"},
		{"name": "Wild Scout", "rig": "res://assets/models/cc0/blocks/character-n.glb", "atlas": "res://assets/models/cc0/blocks/Textures/texture-n.png", "blocky": "res://assets/models/cc0/blocks/Textures/texture-n.png"},
	],
}

const SURVIVOR_TEXTURE_MAP: Dictionary = {
	"gamer": "res://assets/textures/survivors/gamer.png",
	"doctor": "res://assets/textures/survivors/doctor.png",
	"nurse": "res://assets/textures/survivors/nurse.png",
	"streamer": "res://assets/textures/survivors/streamer.png",
	"hunter": "res://assets/textures/survivors/hunter.png",
}


## Setup an AnimationPlayer for a blocky rig under `visuals`.
## Sets up looping on looping clips (on duplicated Animation resources),
## registers a "run" -> "sprint" alias so callers asking for "run" succeed,
## and applies the survivor skin texture if character_id is provided or detected.
static func setup(visuals: Node3D, character_id: String = "", variant_index: int = 0) -> AnimationPlayer:
	if visuals == null:
		return null

	var resolved_id := character_id
	if resolved_id.is_empty():
		resolved_id = _resolve_id_from_rig(visuals)

	if variant_index > 0 and not resolved_id.is_empty():
		return apply_body_variant(visuals, resolved_id, variant_index)

	var ap := find_animation_player(visuals)
	if ap == null:
		push_warning("[BlockyAnim] AnimationPlayer not found under %s" % visuals.name)
		return null

	_setup_looping_and_aliases(ap)

	if not resolved_id.is_empty():
		apply_skin_for_character(visuals, resolved_id, variant_index)

	return ap


## Recursively locate the AnimationPlayer.
## Note: In Kenney blocky GLBs, AnimationPlayer is a sibling of the GLB root,
## not a child of it, so a root-only lookup returns null.
static func find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		return ap
	var parent := node.get_parent()
	if parent != null:
		ap = parent.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null:
			return ap
	return null


## Map a rig's glb node name (character-<x>) to a survivor id via the
## character<->texture correspondence. Falls back to an empty string.
static func _resolve_id_from_rig(visuals: Node3D) -> String:
	var rig_root := _find_rig_root(visuals)
	if rig_root == null:
		return ""
	# glb roots are "character-a" .. "character-r"
	var rn: String = rig_root.name.to_lower()
	if not rn.begins_with("character-"):
		return ""
	var letter := rn.substr("character-".length(), 1)
	if letter.is_empty():
		return ""
	# the design maps a letter to a survivor; keep that table in one place
	return RIG_LETTER_TO_SURVIVOR.get(letter, "")


## The imported glb root is named character-<x>. It is NOT a direct child of
## the wrapper: the scene is PlayerVisuals > Model > character-<x>, because
## Model is the instance of the .glb. Search the whole subtree.
static func _find_rig_root(visuals: Node3D) -> Node3D:
	for n in visuals.find_children("character-*", "Node3D", true, false):
		var nd := n as Node3D
		if nd != null:
			return nd
	return null


## Setup looping on idle/walk/sprint and register "run" alias.
## Clones the Animation first to avoid mutating the shared imported resource.
static func _setup_looping_and_aliases(ap: AnimationPlayer) -> void:
	for clip_name in LOOPING_CLIPS:
		if not ap.has_animation(clip_name):
			continue
		var orig := ap.get_animation(clip_name)
		if orig == null:
			continue
		var dup := orig.duplicate() as Animation
		dup.loop_mode = Animation.LOOP_LINEAR
		_replace_animation(ap, clip_name, dup)

	# The blocky rig has "sprint" but no "run".
	# Register "run" as an alias to the looping sprint clip so standard anim loops work.
	if ap.has_animation("sprint") and not ap.has_animation("run"):
		var sprint_anim := ap.get_animation("sprint")
		_add_animation_alias(ap, "run", sprint_anim)


static func _replace_animation(ap: AnimationPlayer, clip_name: String, new_anim: Animation) -> void:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib != null and lib.has_animation(clip_name):
			lib.add_animation(clip_name, new_anim)
			return
	var default_lib := ap.get_animation_library("")
	if default_lib != null:
		default_lib.add_animation(clip_name, new_anim)


static func _add_animation_alias(ap: AnimationPlayer, alias_name: String, anim: Animation) -> void:
	var default_lib := ap.get_animation_library("")
	if default_lib != null:
		default_lib.add_animation(alias_name, anim)


## Map a high-level game state to a blocky clip name:
## idle -> idle, run -> sprint, attack -> attack-melee-right, death -> die.
static func map_state(state: String) -> String:
	return STATE_TO_CLIP.get(state, state)


## Play a game state on the given AnimationPlayer.
## Automatically maps state name to the corresponding blocky clip.
static func play_state(ap: AnimationPlayer, state: String, blend_time: float = -1.0) -> void:
	if ap == null or not is_instance_valid(ap):
		return
	var clip := map_state(state)
	if not ap.has_animation(clip):
		return
	if blend_time >= 0.0:
		ap.play(clip, blend_time)
	else:
		ap.play(clip)


## Return list of skin variants for character_id.
static func get_skin_variants(character_id: String) -> Array:
	return SKIN_VARIANTS.get(character_id, [])


## Return number of skin variants for character_id.
static func get_variant_count(character_id: String) -> int:
	var variants: Array = SKIN_VARIANTS.get(character_id, [])
	return variants.size()


## Return variant info dictionary for (character_id, variant_index).
static func get_variant_info(character_id: String, variant_index: int) -> Dictionary:
	var variants: Array = SKIN_VARIANTS.get(character_id, [])
	if variants.is_empty():
		return {}
	var idx := clampi(variant_index, 0, variants.size() - 1)
	return variants[idx]


## Swaps or sets the model body for (character_id, variant_index).
## Frees the current rig instance under visuals, instantiates the variant's character-<letter>.glb
## (or authored character scene for variant 0 if available), scales to 0.6667, positions at Vector3.ZERO
## so feet rest correctly on the ground/pedestal, duplicates material and sets albedo_texture to
## the variant atlas, configures animation looping, and plays idle.
static func apply_body_variant(visuals: Node3D, character_id: String, variant_index: int = 0) -> AnimationPlayer:
	if visuals == null:
		return null
	var resolved_id := character_id
	if resolved_id.is_empty():
		resolved_id = _resolve_id_from_rig(visuals)
	if resolved_id.is_empty():
		return null

	var var_info := get_variant_info(resolved_id, variant_index)
	if var_info.is_empty():
		return null

	var rig_path: String = var_info.get("rig", "")
	var atlas_path: String = var_info.get("atlas", var_info.get("blocky", ""))

	# 1. Locate and free existing rig instance(s) under visuals
	var to_free: Array[Node] = []
	for child in visuals.get_children():
		var cn: String = child.name.to_lower()
		if cn == "rig" or cn == "model" or cn.begins_with("character-") or (child is Node3D and child.find_child("AnimationPlayer", true, false) != null):
			to_free.append(child)
	for old_node in to_free:
		visuals.remove_child(old_node)
		old_node.free()

	# 2. Instantiate rig: for variant 0, prefer authored character scene if available; otherwise load variant GLB
	var new_rig: Node3D = null
	if variant_index == 0:
		var scene_path := "res://scenes/characters/character_%s.tscn" % resolved_id
		if ResourceLoader.exists(scene_path):
			var packed_sc := load(scene_path) as PackedScene
			if packed_sc != null:
				var full := packed_sc.instantiate()
				var pvis := full.get_node_or_null("PlayerVisuals") as Node3D
				if pvis != null:
					var m := pvis.get_node_or_null("Model") as Node3D
					if m != null:
						pvis.remove_child(m)
						new_rig = m
					else:
						full.remove_child(pvis)
						new_rig = pvis
				full.free()

	if new_rig == null:
		if rig_path.is_empty() or not ResourceLoader.exists(rig_path):
			push_warning("[BlockyAnim] Variant rig does not exist: %s" % rig_path)
			return null
		var rig_scene := load(rig_path) as PackedScene
		if rig_scene == null:
			push_warning("[BlockyAnim] Failed to load rig scene: %s" % rig_path)
			return null
		new_rig = rig_scene.instantiate() as Node3D
		if new_rig == null:
			push_warning("[BlockyAnim] Failed to instantiate rig: %s" % rig_path)
			return null

	new_rig.name = "Model"
	new_rig.scale = Vector3(0.6667, 0.6667, 0.6667)
	new_rig.position = Vector3.ZERO
	visuals.add_child(new_rig)

	# 3. Duplicate material and apply variant atlas
	if not atlas_path.is_empty():
		apply_skin(visuals, atlas_path)

	# 4. Doctor select-screen stage lighting tint if needed
	if resolved_id == "doctor" and variant_index == 0:
		for mi in visuals.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).get_surface_override_material(0)
			if m is StandardMaterial3D:
				m.albedo_color = Color(0.72, 0.72, 0.75)

	# 5. Locate AnimationPlayer, setup looping and aliases, play idle
	var ap := find_animation_player(visuals)
	if ap != null:
		_setup_looping_and_aliases(ap)
		if ap.has_animation("idle"):
			ap.play("idle")

	# 6. Attach archetype 3D accessory props
	attach_archetype_props(visuals, resolved_id)

	return ap


## Apply chosen skin variant to whatever model is present under `visuals`.
## Swaps body if necessary or reapplies skin texture.
static func apply_skin_variant(visuals: Node3D, character_id: String, variant_index: int = 0) -> void:
	apply_body_variant(visuals, character_id, variant_index)


## Apply survivor skin texture by character ID, supporting optional variant index.
static func apply_skin_for_character(visuals: Node3D, character_id: String, variant_index: int = 0) -> void:
	apply_body_variant(visuals, character_id, variant_index)


## Apply a skin texture at runtime: duplicate the rig's shared material,
## set albedo_texture to the survivor's PNG, and assign it to every rig MeshInstance3D.
static func apply_skin(visuals: Node3D, texture_path: String) -> void:
	if visuals == null or texture_path.is_empty():
		return
	if not ResourceLoader.exists(texture_path):
		push_warning("[BlockyAnim] Skin texture does not exist: %s" % texture_path)
		return
	var tex := load(texture_path) as Texture2D
	if tex == null:
		push_warning("[BlockyAnim] Failed to load skin texture: %s" % texture_path)
		return

	# Collect all rig MeshInstance3D parts
	var rig_parts: Array[MeshInstance3D] = []
	var base_mat: BaseMaterial3D = null
	for child in visuals.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		if mi.name in RIG_PART_NAMES:
			rig_parts.append(mi)
			if base_mat == null:
				var m := mi.get_active_material(0)
				if m is BaseMaterial3D:
					base_mat = m

	# Fallback to mesh surface material if active material wasn't resolved yet
	if base_mat == null and not rig_parts.is_empty() and rig_parts[0].mesh != null:
		var m := rig_parts[0].mesh.surface_get_material(0)
		if m is BaseMaterial3D:
			base_mat = m

	# Duplicate the rig's shared material to avoid mutating imported resource
	var new_mat: StandardMaterial3D = null
	if base_mat is StandardMaterial3D:
		new_mat = base_mat.duplicate() as StandardMaterial3D
	else:
		new_mat = StandardMaterial3D.new()

	new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# Crisp atlas texels without distant bleed (values per Godot 4 docs).
	new_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	# Toon-ish diffuse + specular for a stylized, less-plastic read.
	new_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	new_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	# Gentle rim so silhouettes separate from the dark graveyard background.
	new_mat.rim_enabled = true
	new_mat.rim = 0.5
	new_mat.rim_tint = 0.1
	new_mat.roughness = 0.55
	new_mat.metallic = 0.05
	new_mat.albedo_texture = tex
	new_mat.albedo_color = Color.WHITE

	# Assign to all rig parts using surface override so mesh resources are untouched
	for mi in rig_parts:
		mi.set_surface_override_material(0, new_mat)


## Attach archetype-specific 3D accessory props to the rig under visuals.
## Accounts for blocky rig hierarchy (head scale 0.1, arm-right hand position ~-1.0).
static func attach_archetype_props(visuals: Node3D, character_id: String) -> void:
	if visuals == null or character_id.is_empty():
		return

	# Remove any previously attached archetype props
	for child in visuals.find_children("ArchetypeProp_*", "Node3D", true, false):
		child.queue_free()

	# Remove legacy placeholder props if present from authored scenes
	for mi in visuals.find_children("*", "MeshInstance3D", true, false):
		if mi.name in ["Headset", "Mask", "Prop"]:
			mi.queue_free()

	match character_id:
		"gamer":
			# Headphones on head (head node scale is 0.1, so head local space is 10x)
			var head := visuals.find_child("head", true, false) as Node3D
			if head != null:
				var hp_root := Node3D.new()
				hp_root.name = "ArchetypeProp_Headphones"

				# Headband over top of head
				var arc := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 3.9
				tm.outer_radius = 4.5
				tm.rings = 24
				tm.ring_segments = 12
				arc.mesh = tm
				arc.rotation_degrees = Vector3(90, 0, 0)
				arc.position = Vector3(0.0, 7.8, 0.0)
				var arc_mat := StandardMaterial3D.new()
				arc_mat.albedo_color = Color(0.14, 0.14, 0.18)
				arc_mat.metallic = 0.8
				arc_mat.roughness = 0.3
				arc.material_override = arc_mat
				hp_root.add_child(arc)

				# Left earcup with cyan glow
				var cup_l := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 1.1
				cm.bottom_radius = 1.1
				cm.height = 0.8
				cm.radial_segments = 16
				cup_l.mesh = cm
				cup_l.rotation_degrees = Vector3(0, 0, 90)
				cup_l.position = Vector3(-4.2, 4.2, 0.0)
				var lmat := StandardMaterial3D.new()
				lmat.albedo_color = Color(0.1, 0.85, 1.0)
				lmat.emission_enabled = true
				lmat.emission = Color(0.1, 0.85, 1.0)
				lmat.emission_energy_multiplier = 3.0
				cup_l.material_override = lmat
				hp_root.add_child(cup_l)

				# Right earcup with magenta glow
				var cup_r := MeshInstance3D.new()
				cup_r.mesh = cm
				cup_r.rotation_degrees = Vector3(0, 0, 90)
				cup_r.position = Vector3(4.2, 4.2, 0.0)
				var rmat := StandardMaterial3D.new()
				rmat.albedo_color = Color(1.0, 0.15, 0.75)
				rmat.emission_enabled = true
				rmat.emission = Color(1.0, 0.15, 0.75)
				rmat.emission_energy_multiplier = 3.0
				cup_r.material_override = rmat
				hp_root.add_child(cup_r)

				head.add_child(hp_root)

			# Controller in right arm
			var arm_r := visuals.find_child("arm-right", true, false) as Node3D
			if arm_r != null:
				var ctrl := Node3D.new()
				ctrl.name = "ArchetypeProp_Controller"
				ctrl.position = Vector3(-0.20, -1.0, 0.15)
				ctrl.rotation_degrees = Vector3(32, -12, 0)

				var cbody := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.24, 0.07, 0.13)
				cbody.mesh = bm
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = Color(0.10, 0.10, 0.14)
				cmat.roughness = 0.4
				cbody.material_override = cmat
				ctrl.add_child(cbody)

				# Glowing LED strip
				var led := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.15, 0.015, 0.02)
				led.mesh = lm
				led.position = Vector3(0.0, 0.038, -0.055)
				var led_mat := StandardMaterial3D.new()
				led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				led_mat.albedo_color = Color(1.0, 0.1, 0.8) * 3.5
				led.material_override = led_mat
				ctrl.add_child(led)

				# Glowing sticks
				for sx in [-0.06, 0.06]:
					var stick := MeshInstance3D.new()
					var sm := CylinderMesh.new()
					sm.top_radius = 0.02
					sm.bottom_radius = 0.018
					sm.height = 0.02
					stick.mesh = sm
					stick.position = Vector3(sx, 0.04, 0.01)
					var smat := StandardMaterial3D.new()
					smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					smat.albedo_color = (Color(0.1, 0.85, 1.0) if sx < 0 else Color(1.0, 0.15, 0.8)) * 3.0
					stick.material_override = smat
					ctrl.add_child(stick)

				arm_r.add_child(ctrl)

		"doctor":
			# Stethoscope on torso
			var torso := visuals.find_child("torso", true, false) as Node3D
			if torso != null:
				var steth := Node3D.new()
				steth.name = "ArchetypeProp_Stethoscope"

				# Neck loop
				var tube := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.16
				tm.outer_radius = 0.20
				tm.rings = 24
				tm.ring_segments = 12
				tube.mesh = tm
				tube.position = Vector3(0.0, 0.84, 0.08)
				tube.rotation_degrees = Vector3(25, 0, 0)
				var tmat := StandardMaterial3D.new()
				tmat.albedo_color = Color(0.18, 0.22, 0.26)
				tmat.roughness = 0.5
				tube.material_override = tmat
				steth.add_child(tube)

				# Chrome chest disc
				var disc := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.055
				cm.bottom_radius = 0.055
				cm.height = 0.018
				cm.radial_segments = 20
				disc.mesh = cm
				disc.rotation_degrees = Vector3(85, 0, 0)
				disc.position = Vector3(0.04, 0.65, 0.28)
				var dmat := StandardMaterial3D.new()
				dmat.albedo_color = Color(0.92, 0.94, 0.98)
				dmat.metallic = 0.95
				dmat.roughness = 0.15
				disc.material_override = dmat
				steth.add_child(disc)

				torso.add_child(steth)

		"nurse":
			# Surgical mask on face (in head local units, front of face is Z=4.0)
			var head_n := visuals.find_child("head", true, false) as Node3D
			if head_n != null:
				var mask_root := Node3D.new()
				mask_root.name = "ArchetypeProp_NurseMask"

				var mask := MeshInstance3D.new()
				var mm := BoxMesh.new()
				mm.size = Vector3(5.2, 3.2, 0.6)
				mask.mesh = mm
				mask.position = Vector3(0.0, 3.6, 4.2)
				var mmat := StandardMaterial3D.new()
				mmat.albedo_color = Color(0.12, 0.72, 0.78)
				mmat.roughness = 0.65
				mask.material_override = mmat
				mask_root.add_child(mask)

				head_n.add_child(mask_root)

			# Glowing pink syringe in right arm
			var arm_nr := visuals.find_child("arm-right", true, false) as Node3D
			if arm_nr != null:
				var syr := Node3D.new()
				syr.name = "ArchetypeProp_Syringe"
				syr.position = Vector3(-0.20, -1.0, 0.18)
				syr.rotation_degrees = Vector3(20, 0, 0)

				# Translucent barrel
				var barrel := MeshInstance3D.new()
				var bc := CylinderMesh.new()
				bc.top_radius = 0.035
				bc.bottom_radius = 0.035
				bc.height = 0.24
				barrel.mesh = bc
				var bmat := StandardMaterial3D.new()
				bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bmat.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
				barrel.material_override = bmat
				syr.add_child(barrel)

				# Glowing pink medicine core
				var core := MeshInstance3D.new()
				var cc := CylinderMesh.new()
				cc.top_radius = 0.026
				cc.bottom_radius = 0.026
				cc.height = 0.16
				core.mesh = cc
				core.position = Vector3(0.0, -0.02, 0.0)
				var cmat := StandardMaterial3D.new()
				cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				cmat.albedo_color = Color(1.0, 0.15, 0.75) * 3.6
				core.material_override = cmat
				syr.add_child(core)

				# Chrome needle
				var needle := MeshInstance3D.new()
				var nc := CylinderMesh.new()
				nc.top_radius = 0.005
				nc.bottom_radius = 0.002
				nc.height = 0.12
				needle.mesh = nc
				needle.position = Vector3(0.0, -0.17, 0.0)
				var nmat := StandardMaterial3D.new()
				nmat.albedo_color = Color(0.95, 0.95, 0.98)
				nmat.metallic = 0.95
				needle.material_override = nmat
				syr.add_child(needle)

				arm_nr.add_child(syr)

		"streamer":
			# Handheld stick with glowing ring light & phone
			var arm_sr := visuals.find_child("arm-right", true, false) as Node3D
			if arm_sr != null:
				var vlogger := Node3D.new()
				vlogger.name = "ArchetypeProp_RingLight"
				vlogger.position = Vector3(-0.20, -0.95, 0.18)
				vlogger.rotation_degrees = Vector3(25, -20, 15)

				# Handle stick
				var stick := MeshInstance3D.new()
				var sc := CylinderMesh.new()
				sc.top_radius = 0.018
				sc.bottom_radius = 0.018
				sc.height = 0.28
				stick.mesh = sc
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.15, 0.15, 0.18)
				smat.metallic = 0.6
				smat.roughness = 0.4
				stick.material_override = smat
				vlogger.add_child(stick)

				# Glowing ring light
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.11
				tm.outer_radius = 0.15
				tm.rings = 24
				tm.ring_segments = 14
				ring.mesh = tm
				ring.position = Vector3(0.0, 0.19, 0.02)
				ring.rotation_degrees = Vector3(85, 0, 0)
				var rmat := StandardMaterial3D.new()
				rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				rmat.albedo_color = Color(1.0, 0.15, 0.92) * 4.2
				ring.material_override = rmat
				vlogger.add_child(ring)

				# Smartphone
				var phone := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.08, 0.14, 0.012)
				phone.mesh = pm
				phone.position = Vector3(0.0, 0.19, 0.02)
				var pmat := StandardMaterial3D.new()
				pmat.albedo_color = Color(0.08, 0.08, 0.10)
				pmat.roughness = 0.2
				phone.material_override = pmat
				vlogger.add_child(phone)

				# Glowing screen
				var screen := MeshInstance3D.new()
				var scm := BoxMesh.new()
				scm.size = Vector3(0.068, 0.125, 0.005)
				screen.mesh = scm
				screen.position = Vector3(0.0, 0.19, 0.014)
				var scr_mat := StandardMaterial3D.new()
				scr_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				scr_mat.albedo_color = Color(0.85, 0.95, 1.0) * 2.5
				screen.material_override = scr_mat
				vlogger.add_child(screen)

				arm_sr.add_child(vlogger)

		"hunter":
			# Wooden baseball bat in right arm
			var arm_hr := visuals.find_child("arm-right", true, false) as Node3D
			if arm_hr != null:
				var bat := Node3D.new()
				bat.name = "ArchetypeProp_Bat"
				bat.position = Vector3(-0.20, -0.90, 0.15)
				bat.rotation_degrees = Vector3(-45, 15, 25)

				# Bat barrel
				var barrel := MeshInstance3D.new()
				var bm := CylinderMesh.new()
				bm.top_radius = 0.055
				bm.bottom_radius = 0.024
				bm.height = 0.70
				bm.radial_segments = 16
				barrel.mesh = bm
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.72, 0.54, 0.35)
				bmat.roughness = 0.65
				barrel.material_override = bmat
				bat.add_child(barrel)

				# Grip tape
				var grip := MeshInstance3D.new()
				var gm := CylinderMesh.new()
				gm.top_radius = 0.026
				gm.bottom_radius = 0.026
				gm.height = 0.20
				gm.radial_segments = 16
				grip.mesh = gm
				grip.position = Vector3(0.0, -0.22, 0.0)
				var gmat := StandardMaterial3D.new()
				gmat.albedo_color = Color(0.92, 0.90, 0.86)
				gmat.roughness = 0.85
				grip.material_override = gmat
				bat.add_child(grip)

				arm_hr.add_child(bat)


