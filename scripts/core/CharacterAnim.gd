## CharacterAnim.gd — real skeletal animation for the survivor characters.
##
## The Kenney animated-character pipeline: model.glb carries the mesh + a
## 45-bone Skeleton3D (at "RootNode/Root/Skeleton3D"); idle/run/jump.glb carry
## clips whose tracks target the FBX node paths. Those paths do not resolve in
## the model scene (the joint nodes were absorbed into the Skeleton3D), so every
## track is retargeted onto "<skeleton path>:<bone>" — the last path segment is
## the bone name and the values are already bone-local.
##
## Usage: var ap := CharacterAnim.setup(visuals, "gamer"); ap.play("idle")
class_name CharacterAnim
extends RefCounted

const ANIM_DIR := "res://assets/models/cc0/kenney_anim/"

## Per-character skin: the survivor PNG skins + a tint that keeps the five
## survivors visually distinct while sharing one rigged model.
const SKINS := {
	"gamer": {"tex": "skaterMaleA.png", "tint": Color(0.86, 0.92, 1.0)},
	"doctor": {"tex": "survivorMaleB.png", "tint": Color(1.0, 1.0, 1.0)},
	"nurse": {"tex": "skaterFemaleA.png", "tint": Color(1.0, 0.94, 0.96)},
	"streamer": {"tex": "cyborgFemaleA.png", "tint": Color(0.94, 0.86, 1.0)},
	"hunter": {"tex": "criminalMaleA.png", "tint": Color(0.84, 1.0, 0.82)},
}

## Zombie types: the same rig, zombie skins, per-type tint.
const ZOMBIE_SKINS := {
	"runner": {"tex": "zombieA.png", "tint": Color(0.72, 1.0, 0.72)},
	"butcher": {"tex": "zombieC.png", "tint": Color(1.0, 0.72, 0.72)},
	"spitter": {"tex": "zombieA.png", "tint": Color(0.72, 1.0, 0.82)},
	"boss": {"tex": "zombieC.png", "tint": Color(0.86, 0.86, 0.92)},
	"zombie": {"tex": "zombieA.png", "tint": Color(0.80, 1.0, 0.78)},
}


## Attach merged idle/run/jump clips to the rigged model inside `visuals`.
## Returns the AnimationPlayer (with idle/run/jump), or null if no rigged
## model is present.
static func setup(visuals: Node3D, char_id: String) -> AnimationPlayer:
	var skin: Dictionary = SKINS.get(char_id, {})
	return setup_rigged(visuals, String(skin.get("tex", "")), skin.get("tint", Color.WHITE))

## Attach merged idle/run/jump clips to the rigged model inside `visuals` and
## apply an explicit skin (texture + tint) instead of the survivor SKINS map.
## Used by zombies, whose skins are keyed by type.
## Returns the AnimationPlayer (with idle/run/jump), or null if no rigged
## model is present.
static func setup_rigged(visuals: Node3D, tex_name: String, tint: Color) -> AnimationPlayer:
	var model: Node3D = null
	var direct := visuals.get_node_or_null("Model") as Node3D
	if direct != null and _has_skeleton(direct):
		model = direct
	else:
		for c in visuals.get_children():
			if c is Node3D and _has_skeleton(c):
				model = c
				break
	if model == null:
		return null

	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var sk: Skeleton3D = skels[0]
	var sk_path := String(model.get_path_to(sk))

	var ap := AnimationPlayer.new()
	ap.name = "CharacterAnim"
	model.add_child(ap)
	ap.root_node = ap.get_path_to(model)

	var lib := AnimationLibrary.new()
	var merged := 0
	for nm in ["idle", "run", "jump"]:
		var clip := _load_clip(nm)
		if clip != null:
			_retarget(clip, sk, sk_path)
			lib.add_animation(nm, clip)
			merged += 1
	if merged == 0:
		ap.queue_free()
		return null
	ap.add_animation_library("", lib)

	apply_skin_raw(model, tex_name, tint)
	print("[CharacterAnim] rigged: %d clips merged (%s)" % [merged, ", ".join(ap.get_animation_list())])
	return ap

static func _has_skeleton(n: Node) -> bool:
	return not n.find_children("*", "Skeleton3D", true, false).is_empty()


## Load one animation glb and return a private copy of its main clip (the
## "0_Targeting Pose" setup clip is skipped).
static func _load_clip(nm: String) -> Animation:
	var path := ANIM_DIR + nm + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var src: AnimationPlayer = null
	for a in inst.find_children("*", "AnimationPlayer", true, false):
		src = a
		break
	var clip: Animation = null
	if src != null:
		for c in src.get_animation_list():
			if not String(c).contains("Targeting"):
				clip = src.get_animation(c)
				break
	inst.free()
	if clip == null:
		return null
	# Track paths are mutated below — never touch the cached resource.
	return clip.duplicate(true) as Animation


## Rewrite every track onto the skeleton: "RootNode/Root/HipsCtrl/Hips" becomes
## "<sk_path>:Hips" (bone-local values are identical).
static func _retarget(anim: Animation, skeleton: Skeleton3D, sk_path: String) -> int:
	var fixed := 0
	for i in range(anim.get_track_count()):
		var p: NodePath = anim.track_get_path(i)
		if p.get_name_count() == 0:
			continue
		var last := String(p.get_name(p.get_name_count() - 1))
		if skeleton.find_bone(last) >= 0:
			anim.track_set_path(i, NodePath(sk_path + ":" + last))
			fixed += 1
	return fixed


## Texture + tint every mesh in the model so the five survivors read distinct.
static func _apply_skin(model: Node3D, char_id: String) -> void:
	var skin: Dictionary = SKINS.get(char_id, {})
	apply_skin_raw(model, String(skin.get("tex", "")), skin.get("tint", Color.WHITE))


## Texture + tint a rigged model from an explicit skin name (used by zombies,
## whose skins are keyed by type rather than by survivor id).
static func apply_skin_raw(model: Node3D, tex_name: String, tint: Color) -> void:
	var tex: Texture2D = null
	if tex_name != "" and ResourceLoader.exists(ANIM_DIR + tex_name):
		tex = load(ANIM_DIR + tex_name) as Texture2D
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.roughness = 0.85
	mat.metallic = 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat