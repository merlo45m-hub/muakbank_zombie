extends Node
## Menu render probe (v2, stage-based character select): boots the rebuilt
## character_select with autoloads, asserts the stage wiring, saves a render,
## then simulates REAL taps: on a pedestal zone (the old freeze was taps on the
## character doing nothing), on a name button, and on PLAY -> level_select ->
## first level -> game.tscn. Run under Xvfb + GL (NOT --headless).

const TAG := "MSP "
const SHOT_PATH := "res://tools/menu_render.png"

var ok_all: bool = true

## Stretch (canvas_items) makes control rects logical-space; push_input wants
## window/screen space. Convert before feeding synthetic events.
func _to_screen(p: Vector2) -> Vector2:
	var win := Vector2(DisplayServer.window_get_size())
	var vis := get_viewport().get_visible_rect().size
	if vis.x <= 0.0 or vis.y <= 0.0:
		return p
	return Vector2(p.x * win.x / vis.x, p.y * win.y / vis.y)




func _tap(control: Control) -> void:
	var vp := get_viewport()
	var pos: Vector2 = _to_screen(control.get_global_rect().get_center())
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	vp.push_input(mm)
	await get_tree().process_frame
	var hov: Control = vp.gui_get_hovered_control()
	print(TAG, "tap at ", pos, " hovered=", (hov.get_name() if hov != null else "<none>"))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	vp.push_input(press)
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = pos
	vp.push_input(rel)
	await get_tree().process_frame
	await get_tree().process_frame


func _find_button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n as Button
	return null


func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/ui/character_select.tscn") as PackedScene
	if packed == null:
		print(TAG, "FAIL load character_select.tscn")
		get_tree().quit(1)
		return
	var menu: Node = packed.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	for i in range(10):
		await get_tree().process_frame

	# 1. Stage wiring: five pedestal models + five zone buttons + name buttons.
	var models: Array = menu.get("_models")
	var zones: Array = []
	var zones_node: Node = menu.get_node_or_null("UI/StageZones")
	if zones_node != null:
		for c in zones_node.get_children():
			if c is Button:
				zones.append(c)
	print(TAG, "models=", (models.size() if models != null else -1), " zones=", zones.size())
	if models == null or models.size() != 5 or zones.size() != 5:
		ok_all = false
		print(TAG, "FAIL stage wiring")
	var min_h: float = 9999.0
	for z in zones:
		min_h = minf(min_h, (z as Button).get_global_rect().size.y)
	print(TAG, "zone min height=", min_h)
	if min_h < 44.0:
		ok_all = false
		print(TAG, "FAIL zone tap target under 44px")

	# 1b. Hard geometry check: lowest mesh vertex of each survivor must sit at
	# the pedestal top (0.7). Catches floaters/sinkers without relying on vision.
	for i in range(models.size()):
		var m: Node3D = models[i]
		var lowest := INF
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh_i: MeshInstance3D = mi
			if mesh_i.mesh == null:
				continue
			var ab: AABB = mesh_i.mesh.get_aabb()
			for cx in [ab.position.x, ab.position.x + ab.size.x]:
				for cy in [ab.position.y, ab.position.y + ab.size.y]:
					for cz in [ab.position.z, ab.position.z + ab.size.z]:
						var w: Vector3 = mesh_i.global_transform * Vector3(cx, cy, cz)
						lowest = minf(lowest, w.y)
		print(TAG, "survivor ", i, " lowest_y=", lowest, " pos=", m.global_position)
		if lowest > 0.90 or lowest < 0.60:
			ok_all = false
			print(TAG, "FAIL survivor ", i, " not standing on pedestal (y=", lowest, ")")

	# 2. Render one drawn frame and screenshot (the vision check target).
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(SHOT_PATH)
	if err == OK:
		print(TAG, "shot ok ", img.get_size())
	else:
		ok_all = false
		print(TAG, "FAIL shot err=", err)

	# 3. FREEZE FIX TEST: real tap on pedestal zone 3 (NURSE, index 2).
	if zones.size() >= 3:
		await _tap(zones[2])
		var sel: int = menu.get("selected_character")
		print(TAG, "after zone tap selected=", sel)
		if sel != 2:
			ok_all = false
			print(TAG, "FAIL zone tap did not select nurse")
	else:
		ok_all = false
		print(TAG, "FAIL no zones to tap")

	# 4. Name button tap: HUNTER -> index 4.
	var hunter_btn := _find_button(menu, "HUNTER")
	if hunter_btn == null:
		ok_all = false
		print(TAG, "FAIL HUNTER button missing")
	else:
		await _tap(hunter_btn)
		var sel2: int = menu.get("selected_character")
		print(TAG, "after name tap selected=", sel2)
		if sel2 != 4:
			ok_all = false
			print(TAG, "FAIL name tap did not select hunter")

	# 5. PLAY routing (real tap).
	var play: Button = menu.get("_play_btn") as Button
	if play == null:
		play = _find_button(menu, "PLAY")
	if play == null:
		ok_all = false
		print(TAG, "FAIL PLAY button missing")
	else:
		await _tap(play)
		await get_tree().process_frame
		await get_tree().process_frame
		var cur: Node = get_tree().current_scene
		var cur_path: String = "<null>"
		if cur != null and is_instance_valid(cur):
			cur_path = cur.scene_file_path
		var routed: bool = cur_path.ends_with("level_select.tscn")
		if not routed:
			ok_all = false
		print(TAG, "after PLAY scene=", cur_path, " routed=", routed)

	# 6. Level -> game hop: tap the first level button and assert game.tscn.
	var ls: Node = get_tree().current_scene
	if ls != null and is_instance_valid(ls) and ls.scene_file_path.ends_with("level_select.tscn"):
		var grid: Node = ls.get_node_or_null("VBoxMain/ScrollContainer/GridContainer")
		var btns: Array = []
		var locked: int = 0
		if grid != null:
			for child in grid.get_children():
				if child is Button:
					btns.append(child)
					if (child as Button).disabled:
						locked += 1
		print(TAG, "level buttons=", btns.size(), " locked=", locked)
		print(TAG, "level_count=", Level.get_level_count())
		if btns.size() > 0:
			var lb: Button = btns[0] as Button
			await _tap(lb)
			var game_ok: bool = false
			var p2: String = "<null>"
			for i in range(60):
				await get_tree().process_frame
				var cur2: Node = get_tree().current_scene
				if cur2 != null and is_instance_valid(cur2):
					p2 = cur2.scene_file_path
					if p2.ends_with("game.tscn"):
						game_ok = true
						break
			if not game_ok:
				ok_all = false
			print(TAG, "after level tap scene=", p2, " game_loaded=", game_ok)
		else:
			ok_all = false
			print(TAG, "FAIL no level buttons found")
	else:
		ok_all = false
		print(TAG, "FAIL not on level_select after PLAY")

	print(TAG, "RESULT ", "PASS" if ok_all else "FAIL")
	get_tree().quit(0 if ok_all else 1)
