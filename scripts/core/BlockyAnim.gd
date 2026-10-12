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
static func setup(visuals: Node3D, character_id: String = "") -> AnimationPlayer:
	if visuals == null:
		return null

	var ap := find_animation_player(visuals)
	if ap == null:
		push_warning("[BlockyAnim] AnimationPlayer not found under %s" % visuals.name)
		return null

	_setup_looping_and_aliases(ap)

	# Resolve the survivor id. The wrapper node is always named PlayerVisuals
	# in the character scenes (and renamed CharacterVisuals by Player.gd in
	# gameplay), so a name match on the WRAPPER never succeeds and the skin
	# silently never applied. Match on the rig node instead: the imported glb
	# root is named character-<x>, which is the only reliable key.
	var resolved_id := character_id
	if resolved_id.is_empty():
		resolved_id = _resolve_id_from_rig(visuals)

	if not resolved_id.is_empty():
		apply_skin_for_character(visuals, resolved_id)

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


## Apply survivor skin texture by character ID.
static func apply_skin_for_character(visuals: Node3D, character_id: String) -> void:
	var tex_path: String = SURVIVOR_TEXTURE_MAP.get(character_id, "")
	if not tex_path.is_empty():
		apply_skin(visuals, tex_path)


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
		new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	new_mat.albedo_texture = tex
	new_mat.albedo_color = Color.WHITE

	# Assign to all rig parts using surface override so mesh resources are untouched
	for mi in rig_parts:
		mi.set_surface_override_material(0, new_mat)
