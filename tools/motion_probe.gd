## motion_probe.gd — verifies the procedural walk animator actually drives the
## player: holds a joystick drag, samples the animator's live transform while
## moving, and saves a mid-walk screenshot.
extends Node

const SHOT_PATH := "res://tools/motion_walk.png"
const TAG := "MP"


func _ready() -> void:
	await get_tree().process_frame
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout

	var player: CharacterBody3D = game.get_node_or_null("Player")
	if player == null:
		print(TAG, " FAIL no Player")
		get_tree().quit(1)
		return
	var vis := player.get_node_or_null("PlayerVisuals")
	var anim: Node3D = null
	if vis:
		anim = vis.get_node_or_null("ProceduralAnimator")
	print(TAG, " player pos=", player.global_position, " in_group_player=", player.is_in_group("player"))
	print(TAG, " animator=", anim != null)

	# Hold a joystick drag: press at the stick centre, drag up, keep it held.
	var mc: Control = game.get_node_or_null("Player/MobileControls") as Control
	if mc != null:
		mc.show()  # _ready hides the touch UI on non-mobile; force-show for the test
	var jc := game.find_child("JoystickArea", true, false) as Control
	if jc == null:
		print(TAG, " FAIL no JoystickArea")
		get_tree().quit(1)
		return
	print(TAG, " jc path=", jc.get_path(), " rect=", jc.get_global_rect(),
		" filter=", jc.mouse_filter, " vis=", jc.is_visible_in_tree())
	# Captured mouse mode suppresses GUI routing for synthetic events.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	var center: Vector2 = jc.get_global_rect().get_center()
	var win := Vector2(DisplayServer.window_get_size())
	var visr := get_viewport().get_visible_rect().size
	var scale := Vector2(win.x / visr.x, win.y / visr.y) if visr.x > 0.0 and visr.y > 0.0 else Vector2.ONE
	center *= scale

	# Mirror the proven probe sequence: hover first, then press, then drag —
	# each with a frame between — or the joystick never latches the touch.
	var mm := InputEventMouseMotion.new()
	mm.position = center
	get_viewport().push_input(mm)
	await get_tree().process_frame
	var hov: Control = get_viewport().gui_get_hovered_control()
	print(TAG, " hovered at stick centre: ", hov.get_name() if hov != null else "<none>")
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = center
	get_viewport().push_input(press)
	# The joystick needs a frame to latch the press before the drag lands.
	await get_tree().process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(0, -90)
	get_viewport().push_input(drag)

	await get_tree().process_frame
	print(TAG, " player mobile_move_vector=", player.get("mobile_move_vector"),
		" raw_input_dir=", player.get("_raw_input_dir"))

	# Frame-by-frame internals while the stick is held. Re-push the drag every
	# frame: the synthetic touch gets dropped when the player re-captures the
	# mouse in headless, which zeroes the vector mid-test.
	var drag2 := InputEventScreenDrag.new()
	drag2.index = 0
	var y_min := 999.0
	var y_max := -999.0
	var rz_min := 999.0
	var rz_max := -999.0
	for i in range(30):
		drag2.position = center + Vector2(0, -80)
		get_viewport().push_input(drag2)
		await get_tree().physics_frame
		var arot: Vector3 = anim.rotation if anim else Vector3.ZERO
		var apos: Vector3 = anim.position if anim else Vector3.ZERO
		y_min = minf(y_min, apos.y)
		y_max = maxf(y_max, apos.y)
		rz_min = minf(rz_min, arot.z)
		rz_max = maxf(rz_max, arot.z)
		if i % 6 == 0:
			print(TAG, "  f", i, " vel=", player.velocity.snappedf(0.01),
				" anim y=", snappedf(apos.y, 0.001), " rz=", snappedf(arot.z, 0.001))
	print(TAG, " osc y=", snappedf(y_min, 0.001), "..", snappedf(y_max, 0.001),
		" rz=", snappedf(rz_min, 0.001), "..", snappedf(rz_max, 0.001))

	# Sample twice, 0.35s apart, while the stick stays held.
	await get_tree().create_timer(0.35).timeout
	var v1: Vector3 = player.velocity
	var r1: Vector3 = anim.rotation if anim else Vector3.ZERO
	var p1: Vector3 = anim.position if anim else Vector3.ZERO
	await get_tree().create_timer(0.35).timeout
	var v2: Vector3 = player.velocity
	var r2: Vector3 = anim.rotation if anim else Vector3.ZERO
	var p2: Vector3 = anim.position if anim else Vector3.ZERO

	print(TAG, " v1=", v1.snappedf(0.01), " anim1 rot=", r1.snappedf(0.001), " y=", snappedf(p1.y, 0.001))
	print(TAG, " v2=", v2.snappedf(0.01), " anim2 rot=", r2.snappedf(0.001), " y=", snappedf(p2.y, 0.001))

	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_PATH)

	var moving: bool = v1.length() > 0.5 or v2.length() > 0.5
	var animating: bool = false
	if anim:
		animating = (absf(r1.x) + absf(r1.z) + absf(r2.x) + absf(r2.z) > 0.005) or absf(p1.y - p2.y) > 0.004 or absf(p1.y) > 0.004
	print(TAG, " moving=", moving, " animating=", animating)
	var ok := moving and animating
	print(TAG, " RESULT ", "PASS" if ok else "FAIL")
	# release so the player doesn't keep walking during shutdown
	press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = false
	press.position = center
	get_viewport().push_input(press)
	get_tree().quit(0 if ok else 1)