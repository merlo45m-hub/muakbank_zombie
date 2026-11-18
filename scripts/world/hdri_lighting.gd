extends Node3D
## Applies a Poly Haven HDRI as the world's sky + ambient source.
## Lighting only; no gameplay logic. Runs on the parent WorldEnvironment.

@export var hdri_path: String = ""
@export var ambient_energy: float = 0.35

func _ready() -> void:
	if hdri_path.is_empty() or not ResourceLoader.exists(hdri_path):
		push_warning("[HdriLighting] missing HDRI: " + hdri_path)
		return
	var tex := load(hdri_path) as Texture2D
	if tex == null:
		push_warning("[HdriLighting] not a texture: " + hdri_path)
		return
	var world_env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		for child in get_parent().get_children():
			if child is WorldEnvironment:
				world_env = child
				break
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		get_parent().add_child(world_env)
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = tex
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_energy
	world_env.environment = env
	print("[HdriLighting] ", hdri_path, " applied")
