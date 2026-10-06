extends Node

## Stretch (canvas_items) makes control rects logical-space; push_input wants
## window/screen space. Convert before feeding synthetic events.
func _to_screen(p: Vector2) -> Vector2:
	var win := Vector2(DisplayServer.window_get_size())
	var vis := get_viewport().get_visible_rect().size
	if vis.x <= 0.0 or vis.y <= 0.0:
		return p
	return Vector2(p.x * win.x / vis.x, p.y * win.y / vis.y)

## Gameplay boot probe: loads the real game scene under Xvfb + GL, lets the
## level build and the player placement run, screenshots the result, then
## simulates a touch drag on the mobile joystick and asserts the signal
## reaches the Player (mobile_move_vector). Run with the same invocation as
## menu_render_probe (Xvfb + real GL, NOT --headless).

const TAG := "GBP "
const SHOT_PATH := "res://tools/gameplay_boot.png"

var ok_all: bool = true


func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/main/game.tscn") as PackedScene
	if packed == null:
		print(TAG, "FAIL load game.tscn")
		get_tree().quit(1)
		return
	var g: Node = packed.instantiate()
	get_tree().root.add_child(g)
	get_tree().current_scene = g
	# Zombies spawn and attack while we wait; make the player unkillable and stop
	# spawning so a game-over scene change cannot free the scene mid-probe.
	var p0: Node = g.get_node_or_null("Player")
	if p0 != null:
		p0.set("health", 1000000)
		p0.set("max_health", 1000000)
	var zs: Node = g.get_node_or_null("ZombieSpawner")
	if zs != null and zs.has_method("stop_spawning"):
		zs.stop_spawning()
	# Let the environment build, _place_player probe physics, first frames render.
	for i in range(120):
		await get_tree().process_frame
	if not is_instance_valid(g):
		print(TAG, "FAIL game scene freed before diagnostics")
		get_tree().quit(1)
		return

	# 1. Player diagnostics.
	var p: Node = g.get_node_or_null("Player")
	if p == null:
		ok_all = false
		print(TAG, "FAIL no Player node")
	else:
		print(TAG, "player pos=", p.global_position, " on_floor=", p.is_on_floor(), " vel=", p.velocity)
		print(TAG, "game_active=", g.get("game_active"), " time_remaining=", g.get("time_remaining"))
		var cam: Node = p.get_node_or_null("Camera/Camera3D")
		if cam and cam is Camera3D:
			print(TAG, "camera current=", (cam as Camera3D).is_current(), " pos=", (cam as Camera3D).global_position)
		# Model + mesh visibility under PlayerVisuals.
		var visuals: Node = p.get_node_or_null("PlayerVisuals")
		var vis_count: int = 0
		var vis_visible: int = 0
		var kids: Array[String] = []
		if visuals != null:
			for c in visuals.get_children():
				kids.append(String(c.name))
			for m in visuals.find_children("*", "MeshInstance3D", true, false):
				vis_count += 1
				if (m as MeshInstance3D).visible:
					vis_visible += 1
		print(TAG, "visuals children=", kids, " meshes=", vis_count, " visible=", vis_visible)
		var cv: Node = null
		if visuals != null:
			cv = visuals.get_node_or_null("ProceduralAnimator/CharacterVisuals")
		if cv == null:
			ok_all = false
			print(TAG, "FAIL CharacterVisuals missing under ProceduralAnimator")
		else:
			print(TAG, "CharacterVisuals ok")
		if vis_visible < 3:
			ok_all = false
			print(TAG, "FAIL too few visible meshes on the character")
		print(TAG, "glb exists(res://assets/models/character_gamer.glb)=", ResourceLoader.exists("res://assets/models/character_gamer.glb"))
		print(TAG, "selected_character=", Save.selected_character if Save else "<no Save>")

	# 2. Mobile controls diagnostics + simulated joystick drag.
	var mc: Node = g.get_node_or_null("Player/MobileControls")
	if mc == null:
		ok_all = false
		print(TAG, "FAIL no MobileControls under Player")
	else:
		print(TAG, "MobileControls visible=", mc.visible, " filter=", mc.mouse_filter)
		mc.show()  # _ready hides it on non-mobile; force-show for render + touch test
		var ja: Control = mc.get_node_or_null("JoystickArea") as Control
		if ja == null:
			ok_all = false
			print(TAG, "FAIL no JoystickArea")
		else:
			print(TAG, "JoystickArea rect=", ja.get_global_rect(), " filter=", ja.mouse_filter, " visible=", ja.visible)
			# Spy: log every event the joystick's gui_input actually receives.
			ja.gui_input.connect(func(ev: InputEvent) -> void:
				print(TAG, "  [spy] gui_input: ", ev)
			)
			# The player captures the mouse on desktop; android keeps it VISIBLE.
			# Captured mode suppresses GUI hover/click routing for synthetic events,
			# so mirror the device input mode before testing.
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			await get_tree().process_frame
			var vp := get_viewport()
			var center: Vector2 = _to_screen(ja.get_global_rect().get_center())
			var mmh := InputEventMouseMotion.new()
			mmh.position = _to_screen(Vector2(60, 60))
			vp.push_input(mmh)
			await get_tree().process_frame
			var hov_hud: Control = vp.gui_get_hovered_control()
			print(TAG, "hovered at top-left point: ", hov_hud.get_name() if hov_hud != null else "<none>")
			var mmc := InputEventMouseMotion.new()
			mmc.position = center
			vp.push_input(mmc)
			await get_tree().process_frame
			var hovered: Control = vp.gui_get_hovered_control()
			print(TAG, "hovered at joystick center: ", hovered.get_name() if hovered != null else "<none>")

			# Stage A: raw ScreenTouch/Drag via push_input.
			var t0 := InputEventScreenTouch.new()
			t0.index = 0
			t0.pressed = true
			t0.position = center
			vp.push_input(t0)
			await get_tree().process_frame
			var d0 := InputEventScreenDrag.new()
			d0.index = 0
			d0.position = center + Vector2(0, -50)
			vp.push_input(d0)
			await get_tree().process_frame
			var mvA: Vector2 = Vector2.ZERO
			if p != null:
				mvA = p.get("mobile_move_vector")
			print(TAG, "A raw-touch push_input: mobile_move_vector=", mvA)
			var t0r := InputEventScreenTouch.new()
			t0r.index = 0
			t0r.pressed = false
			t0r.position = center + Vector2(0, -50)
			vp.push_input(t0r)
			await get_tree().process_frame

			# Stage B: mouse events via push_input (desktop emulate path).
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = true
			mb.position = center
			vp.push_input(mb)
			await get_tree().process_frame
			var mmv := InputEventMouseMotion.new()
			mmv.position = center + Vector2(0, -50)
			mmv.relative = Vector2(0, -50)
			vp.push_input(mmv)
			await get_tree().process_frame
			var mvB: Vector2 = Vector2.ZERO
			if p != null:
				mvB = p.get("mobile_move_vector")
			print(TAG, "B mouse push_input: mobile_move_vector=", mvB)
			var mbr := InputEventMouseButton.new()
			mbr.button_index = MOUSE_BUTTON_LEFT
			mbr.pressed = false
			mbr.position = center + Vector2(0, -50)
			vp.push_input(mbr)
			await get_tree().process_frame

			# Stage C: full input pipeline via Input.parse_input_event (device-like).
			var t2 := InputEventScreenTouch.new()
			t2.index = 0
			t2.pressed = true
			t2.position = center
			Input.parse_input_event(t2)
			await get_tree().process_frame
			var d2 := InputEventScreenDrag.new()
			d2.index = 0
			d2.position = center + Vector2(0, -60)
			Input.parse_input_event(d2)
			await get_tree().process_frame
			var mvC: Vector2 = Vector2.ZERO
			if p != null:
				mvC = p.get("mobile_move_vector")
			print(TAG, "C parse_input_event touch: mobile_move_vector=", mvC)
			var t3 := InputEventScreenTouch.new()
			t3.index = 0
			t3.pressed = false
			t3.position = center + Vector2(0, -60)
			Input.parse_input_event(t3)
			await get_tree().process_frame

			# Stage D: direct gui_input.emit — bypasses hit-testing entirely, proving
			# whether the handler itself works.
			var h0 := InputEventScreenTouch.new()
			h0.index = 0
			h0.pressed = true
			h0.position = center
			ja.gui_input.emit(h0)
			var h1 := InputEventScreenDrag.new()
			h1.index = 0
			h1.position = center + Vector2(0, -40)
			ja.gui_input.emit(h1)
			await get_tree().process_frame
			var mvD: Vector2 = Vector2.ZERO
			if p != null:
				mvD = p.get("mobile_move_vector")
			print(TAG, "D direct gui_input.emit: mobile_move_vector=", mvD)

			if mvA.length() > 0.1 or mvB.length() > 0.1 or mvC.length() > 0.1:
				print(TAG, "joystick reachable via viewport routing")
			elif mvD.length() > 0.1:
				ok_all = false
				print(TAG, "NOTE handler works (D) but hit-test routing found nothing — captured/desktop artifact suspected")
			else:
				ok_all = false
				print(TAG, "FAIL joystick handler dead even via direct emit")

	# 3. Render screenshot (reference image of the booted gameplay scene).
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(SHOT_PATH)
	if err == OK:
		print(TAG, "shot ok ", img.get_size())
	else:
		ok_all = false
		print(TAG, "FAIL shot err=", err)

	print(TAG, "RESULT ", "PASS" if ok_all else "FAIL")
	get_tree().quit(0 if ok_all else 1)