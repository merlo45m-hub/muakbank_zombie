## Casting-call probe: renders every CC0 character candidate in a neutral
## grid so the best model per role can be chosen from a real engine render.
## Set CAST_SET=blocks (18 blocky chars) or CAST_SET=minis (12 minis + aids).
extends Node3D

const DevMode := preload("res://scripts/core/DevMode.gd")

func _ready() -> void:
	var set_name := OS.get_environment("CAST_SET")
	if set_name == "":
		set_name = "blocks"
	var files: Array[String] = []
	var root := "res://assets/models/cc0/"
	if set_name == "blocks":
		for c in "abcdefghijklmnopqr":
			files.append(root + "blocks/character-" + c + ".glb")
	else:
		for g in "abcdef":
			files.append(root + "minis/character-male-" + g + ".glb")
		for g in "abcdef":
			files.append(root + "minis/character-female-" + g + ".glb")
		files.append(root + "minis/aid-mask.glb")
		files.append(root + "minis/aid-defibrillator-green.glb")
	_build_grid(files)
	_shoot(set_name)


func _build_grid(files: Array) -> void:
	var n := files.size()
	var cols := 9 if n > 9 else n
	var spacing := 0.82
	# camera + light
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 6.4)
	cam.fov = 45
	add_child(cam)
	cam.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_energy = 1.25
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.5, 3.5)
	fill.light_energy = 1.6
	fill.omni_range = 20
	add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.34, 0.35, 0.40)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	# back wall + floor so shapes read
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(20, 8, 0.2)
	wall.mesh = bm
	wall.position = Vector3(0, 3.0, -2.2)
	add_child(wall)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 8)
	floor_m.mesh = pm
	add_child(floor_m)
	var rows := int(ceil(float(n) / float(cols)))
	for i in range(n):
		var col := i % cols
		var row := int(i / cols)
		var ps := load(files[i]) as PackedScene
		if ps == null:
			print("CAST MISS ", files[i])
			continue
		var inst := ps.instantiate() as Node3D
		add_child(inst)
		var box := _aabb_of(inst)
		var s := 1.0 / maxf(box.size.y, 0.01)
		inst.scale = Vector3(s, s, s)
		var x := (float(col) - float(cols - 1) * 0.5) * spacing
		var y := float(rows - 1 - row) * 1.28 - box.position.y * s
		inst.position = Vector3(x, y, 0)
		inst.rotation.y = PI
		print("CAST ", i, " ", files[i].get_file(), " size=", box.size, " scale=", s)


func _aabb_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var local: AABB = m.transform * m.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _shoot(set_name: String) -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err: int = img.save_png("res://tools/charcast_" + set_name + ".png")
	print("CAST shot err=", err, " size=", img.get_size())
	get_tree().quit()
