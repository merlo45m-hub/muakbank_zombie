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


## DIAG_GOD: hold the player alive from the very FIRST frame. If the player dies,
## Game.gd swaps scenes, which frees this harness - every later get_tree() then fails
## on a null tree and the PNG is never written. That is exactly how a 200-frame
## capture produced "Game over! Survived: false" in the log and no image on disk.
func _god_hold(inst: Node) -> bool:
	if OS.get_environment("DIAG_GOD") != "1":
		return false
	var found := false
	for n in _all_nodes(inst):
		if String(n.name) == "Player":
			n.set("health", 9999)
			found = true
	return found


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
	_god_hold(inst)  # before frame 1: a load-time game over was killing the capture

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
				if OS.get_environment("DIAG_GOD") == "1":
					ph_player.set("health", 9999)
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
						# report the NEAREST zombie (first-in-group may be a
						# stranded/inert one and hides what the others do)
						var nz: Node3D = null
						var nd: float = 1e9
						var parts: Array[String] = []
						for z in zs:
							var dz: float = z.global_position.distance_to(ph_player.global_position)
							if dz < nd:
								nd = dz
								nz = z
							parts.append("%s:%.1f" % [z.name.replace("zombie_", ""), dz])
						print("DIAG-ZOMBIE: f=%d count=%d nearest=%s dist=%.2f state=%s pos=%s | all=[%s]" % [
							i, zs.size(), nz.name, nd, str(nz.get("current_state")),
							str(nz.global_position), ", ".join(parts)])
					else:
						print("DIAG-ZOMBIE: f=%d count=0 (none spawned)" % i)
	else:
		# let _ready chains / runtime scene loading settle
		for i in range(12):
			_god_hold(inst)
			await get_tree().process_frame


	# ---- optional player-visual audit (DIAG_PLAYER=1) ----
	if OS.get_environment("DIAG_PLAYER") == "1":
		var pv := get_tree().get_first_node_in_group("player")
		if pv:
			print("DIAG-PLAYER: %s at %s" % [pv.name, str((pv as Node3D).global_position)])
			for mi3 in pv.find_children("*", "MeshInstance3D", true, false):
				var m3 := mi3 as MeshInstance3D
				var v3 := 0
				if m3.mesh:
					for si3 in range(m3.mesh.get_surface_count()):
						var a3 := m3.mesh.surface_get_arrays(si3)
						if a3.size() > 0 and a3[0] != null:
							v3 += (a3[0] as PackedVector3Array).size()
				print("DIAG-PLAYER:   mesh=%s visible=%s verts=%d world_pos=%s" % [
					m3.name, str(m3.visible), v3, str(m3.global_position)])

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
			cam_positions.append("%s pos=%s current=%s fwd=%s" % [n.name, str(n.global_position), str((n as Camera3D).current), str(-(n as Camera3D).global_transform.basis.z)])
		elif n is WorldEnvironment:
			var env := (n as WorldEnvironment).environment
			if env:
				envs.append("bg=%d fog=%s dens=%.3f ambient=%.2f" % [env.background_mode, str(env.fog_enabled), env.fog_density, env.ambient_light_energy])
	print("DIAG: scene=%s meshes=%d lights=%d" % [scene_path, mesh_count, light_count])
	print("DIAG: top-level: %s" % str(top))
	for c in cam_positions:
		print("DIAG: camera %s" % c)
	# Is the player actually IN FRONT of the current camera? A third-person camera
	# that looks away from its own player renders a frame with no character in it.
	var pl_node := get_tree().get_first_node_in_group("player")
	for n in _all_nodes(inst):
		if n is Camera3D and (n as Camera3D).current and pl_node is Node3D:
			var cam := n as Camera3D
			var to_p: Vector3 = (pl_node as Node3D).global_position - cam.global_position
			var dotf: float = (-cam.global_transform.basis.z).normalized().dot(to_p.normalized())
			print("DIAG: cam->player dist=%.2f dot_fwd_to_player=%.3f  %s" % [
				to_p.length(), dotf, "OK (player in view)" if dotf > 0.3 else "BROKEN: camera looks away from the player"])
			print("DIAG: player rot_y=%.1f deg  cam_arm_rot=%s" % [rad_to_deg((pl_node as Node3D).rotation.y), str(cam.get_parent().global_rotation if cam.get_parent() else Vector3.ZERO)])
			# What is actually filling the frame? Cast rays from the camera and name the
			# colliders. Guessing from pixels wasted three renders: a pale column could be
			# the player seen from directly behind OR a level prop.
			var space := cam.get_world_3d().direct_space_state
			for probe in [["centre", 0.0, 0.0], ["upper", 0.0, -0.35], ["left", -0.4, 0.0], ["right", 0.4, 0.0]]:
				var off := cam.project_position(Vector2(
					360.0 + float(probe[1]) * 360.0, 800.0 + float(probe[2]) * 800.0), 30.0)
				var from := cam.global_position
				var to: Vector3 = off
				var q := PhysicsRayQueryParameters3D.create(from, to)
				q.collide_with_areas = false
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					print("DIAG-LOOK: %s -> nothing (no collider: mesh-only prop or sky)" % probe[0])
				else:
					var col: Node = hit.collider
					var owner_path := ""
					var o := col.owner
					if o == null and col.get_parent():
						o = col.get_parent()
					if o:
						owner_path = str(o.scene_file_path) if o.scene_file_path != "" else str(o.name)
					print("DIAG-LOOK: %s -> %s (node=%s dist=%.2f owner=%s)" % [
						probe[0], col.name, col.get_class(), from.distance_to(hit.position), owner_path])
			print("DIAG-LOOK: player global_pos=%s  player_visible=%s" % [
				str((pl_node as Node3D).global_position),
				"y" if (pl_node as Node3D).is_visible_in_tree() else "n"])
			# How big is the player ON SCREEN, in pixels? "I can see something small and
			# red" is not evidence; the projected head/feet tells you if framing is right.
			var head := (pl_node as Node3D).global_position + Vector3(0, 1.75, 0)
			var feet := (pl_node as Node3D).global_position + Vector3(0, 0.05, 0)
			var hr := cam.unproject_position(head)
			var fr := cam.unproject_position(feet)
			print("DIAG-SCREEN: head_px=(%.0f,%.0f) feet_px=(%.0f,%.0f) height_px=%.0f behind=%s viewport=%s" % [
				hr.x, hr.y, fr.x, fr.y, absf(fr.y - hr.y),
				str(cam.is_position_behind(head)), str(cam.get_viewport().get_visible_rect().size)])
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
		# DIAG_GOD: keep the player alive through the capture. Without it the
		# player dies ~9s in (the harness sends no input), Game.gd swaps to the
		# game-over scene, this harness node is destroyed mid-loop and the PNG is
		# silently never written — which is how two renders produced nothing.
		if not is_inside_tree():
			print("DIAG: harness left the tree at frame %d (scene swap) - aborted, no PNG" % i)
			return
		_god_hold(inst)
		# Where is the player WHEN THE PICTURE IS TAKEN? The intro readout is frame 0 but
		# the PNG is written `frames` later; a player who drifted or got knocked away in
		# between turns "framing is correct" into "tiny figure at the horizon".
		if i % 10 == 0 or i == frames - 1:
			var pp = get_tree().get_first_node_in_group("player")
			var cam_now := get_viewport().get_camera_3d()
			if pp and cam_now:
				var d := (pp as Node3D).global_position.distance_to(cam_now.global_position)
				var hpx := 0.0
				var vsize := get_viewport().get_visible_rect().size
				if vsize.y > 0.0:
					var hh := cam_now.unproject_position((pp as Node3D).global_position + Vector3(0, 1.75, 0))
					var ff := cam_now.unproject_position((pp as Node3D).global_position + Vector3(0, 0.05, 0))
					hpx = absf(ff.y - hh.y)
				print("DIAG-POS: f=%d player=%s cam=%s dist=%.2f screen_height_px=%.0f" % [
					i, str((pp as Node3D).global_position), str(cam_now.global_position), d, hpx])
		# Zombie census during the capture: are enemies spawned, and is any of them in
		# FRONT of the camera? "No zombies in frame" needs a number, not a guess.
		if i % 30 == 0 or i == frames - 1:
			var zs := get_tree().get_nodes_in_group("enemies")
			var camz := get_viewport().get_camera_3d()
			var in_front := 0
			var nd := 1e9
			if camz:
				var fwd := -camz.global_transform.basis.z
				for z in zs:
					if not (z is Node3D):
						continue
					var toz: Vector3 = (z as Node3D).global_position - camz.global_position
					nd = min(nd, toz.length())
					if fwd.dot(toz.normalized()) > 0.0:
						in_front += 1
			print("DIAG-SHOOT: f=%d zombies=%d in_front=%d nearest=%.1f" % [i, zs.size(), in_front, nd])
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("DIAG: saved %s (%dx%d) err=%d" % [out, img.get_width(), img.get_height(), err])
	get_tree().quit(0)
