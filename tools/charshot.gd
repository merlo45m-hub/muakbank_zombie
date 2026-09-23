extends Node

## Asset viewer: render ONE model on a plain lit background so its true shape is
## unambiguous. The in-game camera framing repeatedly made a humanoid look like a
## capsule (torso+arms merge into a column at 2 m behind; scenery hides the legs),
## so never judge a model from a gameplay frame.
##
##   CHARS+m=res://assets/models/character_doctor.glb SHOT_OUT=/game/charshot.png \
##     godot --headless=false … res://tools/charshot.tscn
##
## Env: CHARS+M (model path), SHOT_OUT (png path), SHOT_YAW (degrees, default 0 =
## view from +Z), SHOT_FRAMES (default 3).

func _ready() -> void:
	var model_path := OS.get_environment("SHOT_MODEL")
	if model_path.is_empty():
		model_path = "res://assets/models/character_doctor.glb"
	var out := OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "/game/charshot.png"
	var yaw_deg := float(OS.get_environment("SHOT_YAW")) if OS.get_environment("SHOT_YAW") != "" else 0.0
	var frames := int(OS.get_environment("SHOT_FRAMES")) if OS.get_environment("SHOT_FRAMES") != "" else 3

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.24, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	# The scene-file serialization name (light_energy_multiplier) is NOT a valid
	# GDScript property on DirectionalLight3D — assigning it throws at runtime and
	# aborts _ready(), so no shot is ever taken. Set whichever name the class has.
	if "light_energy_multiplier" in key:
		key.light_energy_multiplier = 1.4
	elif "light_energy" in key:
		key.light_energy = 1.4
	else:
		key.set("light_energy", 1.4)
	add_child(key)

	var ps := load(model_path) as PackedScene
	if not ps:
		print("SHOT: FAILED to load %s" % model_path)
		get_tree().quit(1)
		return
	var mdl := ps.instantiate() as Node3D
	add_child(mdl)

	# Normalise to human height and sit on the origin (same rule as gameplay).
	var aabb := AABB()
	var first := true
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.mesh:
			continue
		var box: AABB = mdl.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	var h := aabb.size.y
	# maxf(): plain max() returns Variant, which breaks `:=` type inference
	var s: float = 2.0 / maxf(h, 0.01)
	mdl.scale = Vector3(s, s, s)
	mdl.position.y = -aabb.position.y * s

	# Readable surface (the shipped GLBs have no materials at all).
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.68, 0.64)
	skin.roughness = 0.8
	var verts := 0
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = skin
		var mm := (mi as MeshInstance3D)
		print("SHOT: mesh=%s visible=%s aabb_pos=%s size=%s" % [
			mm.name, str(mm.visible), str(mm.get_aabb().position), str(mm.get_aabb().size)])
		if mm.mesh:
			for si in range(mm.mesh.get_surface_count()):
				var a := mm.mesh.surface_get_arrays(si)
				if a.size() > 0 and a[0] != null:
					verts += (a[0] as PackedVector3Array).size()

	var cam := Camera3D.new()
	var rad := deg_to_rad(yaw_deg)
	var dist := 3.6
	cam.position = Vector3(sin(rad) * dist, 1.35, cos(rad) * dist)
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	cam.fov = 50.0

	print("SHOT: model=%s verts=%d raw_h=%.3f scale=%.3f yaw=%.0f out=%s" % [
		model_path.get_file(), verts, h, s, yaw_deg, out])

	for i in range(max(frames, 1)):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT: saved %s (%dx%d) err=%d" % [out, img.get_width(), img.get_height(), err])
	get_tree().quit(0)