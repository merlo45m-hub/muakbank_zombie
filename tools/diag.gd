extends Node
## Visual bisect harness — loads a scene, optionally hides nodes by name substring,
## optionally installs a debug free camera, screenshots, and dumps structure.
## Non-destructive: never writes to project files, only reads scenes.
## Env: DIAG_SCENE, DIAG_HIDE (comma substrings), DIAG_CAM ("px,py,pz;tx,ty,tz"),
##      DIAG_AMBIENT (float, sets env ambient energy), DIAG_NOFOG (1 = fog_enabled=false),
##      DIAG_FRAMES (default 120), DIAG_OUT

func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out


func _ready() -> void:
	var scene_path := OS.get_environment("DIAG_SCENE")
	if scene_path.is_empty():
		scene_path = "res://scenes/main/game.tscn"
	var out := OS.get_environment("DIAG_OUT")
	if out.is_empty():
		out = "/game/diag.png"
	var frames := 120
	if OS.get_environment("DIAG_FRAMES") != "":
		frames = int(OS.get_environment("DIAG_FRAMES"))

	var packed: PackedScene = load(scene_path)
	if packed == null:
		print("DIAG: FAIL could not load %s" % scene_path)
		get_tree().quit(1)
		return
	var inst: Node = packed.instantiate()
	add_child(inst)

	# ---- optional time scale: advance several sim seconds per rendered frame so a
	#      slow (llvmpipe) capture can show mid-game action instead of frame #1 ----
	if OS.get_environment("DIAG_TIMESCALE") != "":
		Engine.time_scale = float(OS.get_environment("DIAG_TIMESCALE"))

	# ---- per-frame physics probe: runs from the FIRST frame (DIAG_PHYS=1) ----
	if OS.get_environment("DIAG_PHYS") == "1":
		var ph_player: CharacterBody3D = null
		for n in _all_nodes(inst):
			if String(n.name) == "Player" and n is CharacterBody3D:
				ph_player = n
		if ph_player:
			var probe_frames := 40
			if OS.get_environment("DIAG_PHYS_FRAMES") != "":
				probe_frames = int(OS.get_environment("DIAG_PHYS_FRAMES"))
			for i in range(probe_frames):
				if not is_instance_valid(ph_player) or not ph_player.is_inside_tree():
					print("DIAG-PHYS: player left the tree at frame %d — probe stopped (scene change or death)" % i)
					break
				await get_tree().physics_frame
				var cinfo := ""
				for c in range(ph_player.get_slide_collision_count()):
					var col := ph_player.get_slide_collision(c)
					if col:
						var cobj: Object = col.get_collider()
						cinfo += " [%s n=%s d=%.2f]" % [str(cobj.name) if cobj else "?", str(col.get_normal()), col.get_depth()]
				print("DIAG-PHYS: f=%d pos=%s vy=%.2f real_v=%s last_motion=%s on_floor=%s cols=%d%s" % [
					i, str(ph_player.global_position), ph_player.velocity.y, str(ph_player.get_real_velocity()),
					str(ph_player.get_last_motion()), str(ph_player.is_on_floor()),
					ph_player.get_slide_collision_count(), cinfo])
				if i % 90 == 0:
					var zs := get_tree().get_nodes_in_group("enemies")
					if zs.size() > 0:
						var z = zs[0]
						var zdist: float = z.global_position.distance_to(ph_player.global_position)
						print("DIAG-ZOMBIE: f=%d count=%d %s pos=%s dist=%.2f state=%s" % [
							i, zs.size(), z.name, str(z.global_position), zdist, str(z.get("current_state"))])
					else:
						print("DIAG-ZOMBIE: f=%d count=0 (none spawned)" % i)
	else:
		# let _ready chains / runtime scene loading settle
		for i in range(12):
			await get_tree().process_frame


	# ---- optional position trace ----
	if OS.get_environment("DIAG_TRACE") == "1":
		var tr_player: Node3D = null
		var tr_cam: Camera3D = null
		for n in _all_nodes(inst):
			if n is Camera3D and (n as Camera3D).current:
				tr_cam = n
			if String(n.name) == "Player" and n is Node3D:
				tr_player = n
		for step in range(7):
			var pstr := "-"
			var vstr := "-"
			var cstr := "-"
			if tr_player:
				pstr = str(tr_player.global_position)
				vstr = str(tr_player.get("velocity")) if tr_player.get("velocity") != null else "-"
			if tr_cam:
				cstr = str(tr_cam.global_position)
			print("DIAG-TRACE: f=%d player=%s vel=%s cam=%s" % [step * 30, pstr, vstr, cstr])
			for i in range(30):
				await get_tree().process_frame

	# ---- structure dump ----
	var mesh_count := 0
	var light_count := 0
	var cam_positions: Array[String] = []
	var envs: Array[String] = []
	var top: Array[String] = []
	for c in inst.get_children():
		top.append("%s(%s)" % [c.name, c.get_class()])
	for n in _all_nodes(inst):
		if n is MeshInstance3D:
			mesh_count += 1
		elif n is Light3D:
			light_count += 1
		elif n is Camera3D:
			cam_positions.append("%s pos=%s current=%s" % [n.name, str(n.global_position), str((n as Camera3D).current)])
		elif n is WorldEnvironment:
			var env := (n as WorldEnvironment).environment
			if env:
				envs.append("bg=%d fog=%s dens=%.3f ambient=%.2f" % [env.background_mode, str(env.fog_enabled), env.fog_density, env.ambient_light_energy])
	print("DIAG: scene=%s meshes=%d lights=%d" % [scene_path, mesh_count, light_count])
	print("DIAG: top-level: %s" % str(top))
	for c in cam_positions:
		print("DIAG: camera %s" % c)
	for e in envs:
		print("DIAG: env %s" % e)

	# ---- hide fog/mist nodes ----
	var hide_list := OS.get_environment("DIAG_HIDE").split(",", false)
	for sub in hide_list:
		var sub_clean := sub.strip_edges()
		if sub_clean.is_empty():
			continue
		for n in _all_nodes(inst):
			if sub_clean.to_lower() in String(n.name).to_lower():
				if n is Node3D:
					(n as Node3D).visible = false
					print("DIAG: hid %s (%s)" % [n.get_path(), n.get_class()])

	# ---- env tweaks ----
	var amb := OS.get_environment("DIAG_AMBIENT")
	var nofog := OS.get_environment("DIAG_NOFOG") == "1"
	if amb != "" or nofog:
		for n in _all_nodes(inst):
			if n is WorldEnvironment and (n as WorldEnvironment).environment:
				var e: Environment = (n as WorldEnvironment).environment
				if nofog:
					e.fog_enabled = false
					print("DIAG: fog disabled")
				if amb != "":
					e.ambient_light_energy = float(amb)
					e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					e.ambient_light_color = Color(0.55, 0.6, 0.7)
					print("DIAG: ambient set to %s" % amb)

	# ---- debug camera ----
	var cam_env := OS.get_environment("DIAG_CAM")
	if not cam_env.is_empty():
		var parts := cam_env.split(";")
		if parts.size() == 2:
			var pf := parts[0].split(",")
			var tf := parts[1].split(",")
			if pf.size() == 3 and tf.size() == 3:
				var p := Vector3(float(pf[0]), float(pf[1]), float(pf[2]))
				var t := Vector3(float(tf[0]), float(tf[1]), float(tf[2]))
				var cam := Camera3D.new()
				cam.name = "DiagCam"
				inst.add_child(cam)
				cam.global_position = p
				cam.look_at(t, Vector3.UP)
				cam.current = true
				cam.far = 500.0
				print("DIAG: debug camera at %s -> %s" % [str(p), str(t)])

	# ---- shoot ----
	for i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("DIAG: saved %s (%dx%d) err=%d" % [out, img.get_width(), img.get_height(), err])
	get_tree().quit(0)
