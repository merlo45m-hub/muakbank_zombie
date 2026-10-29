extends Node
## Night mood probe — boots the REAL game scene, holds the player at a fixed
## position (Player.gd's own physics drifts a teleported body, so the position is
## re-applied every frame), installs a free camera and captures a PNG.
## Env: PLAYER_POS "px,py,pz" | DIAG_CAM "px,py,pz;tx,ty,tz" | FRAMES (default 60)
##      OUT (png path). Prints MOOD: lines; exit 0 on success.

func _ready() -> void:
	var out := OS.get_environment("OUT")
	if out.is_empty():
		out = "/root/muakbank_zombie/night_mood.png"
	var frames := 60
	if OS.get_environment("FRAMES") != "":
		frames = int(OS.get_environment("FRAMES"))
	var ppos := Vector3(-12.0, 0.15, -14.0)
	var pe := OS.get_environment("PLAYER_POS")
	if not pe.is_empty():
		var parts := pe.split(",")
		if parts.size() == 3:
			ppos = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

	var packed := load("res://scenes/main/game.tscn") as PackedScene
	if packed == null:
		print("MOOD: FAIL load game.tscn")
		get_tree().quit(1)
		return
	var inst := packed.instantiate()
	add_child(inst)

	var player: Node3D = null
	for n in _all_nodes(inst):
		if n is CharacterBody3D and String(n.name) == "Player":
			player = n
	if player == null:
		print("MOOD: FAIL no Player")
		get_tree().quit(1)
		return

	var cam_env := OS.get_environment("DIAG_CAM")
	if not cam_env.is_empty():
		var cp := cam_env.split(";")
		if cp.size() == 2:
			var pf := cp[0].split(",")
			var tf := cp[1].split(",")
			if pf.size() == 3 and tf.size() == 3:
				var cam := Camera3D.new()
				cam.name = "MoodCam"
				inst.add_child(cam)
				cam.global_position = Vector3(float(pf[0]), float(pf[1]), float(pf[2]))
				cam.look_at(Vector3(float(tf[0]), float(tf[1]), float(tf[2])), Vector3.UP)
				cam.current = true
				cam.far = 500.0

	# settle boot chains (level env, podiums, lamp gate), holding position
	for i in range(frames):
		player.global_position = ppos
		player.set("health", 9999)
		await get_tree().process_frame

	# one more hold, then the actual capture frame
	player.global_position = ppos
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	var on := 0
	for n in _all_nodes(inst):
		if n is Light3D and n.visible and n.light_energy > 0.0:
			on += 1
			print("MOOD-D: on %s@(%.1f,%.1f,%.1f)" % [n.name, (n as Node3D).global_position.x, (n as Node3D).global_position.y, (n as Node3D).global_position.z])
	print("MOOD: saved %s (%dx%d) err=%d enabled_lights=%d" % [out, img.get_width(), img.get_height(), err, on])
	if err == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out
