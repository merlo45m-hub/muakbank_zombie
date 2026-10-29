extends Node

# =============================================================================
# SPRINT mobile-button verification — measures the REAL MobileControls code.
# =============================================================================
#
# A previous probe (verify_rects_probe / verify_sprint_final_probe) HARD-CODED a
# copy of SPRINT_BTN_RECT and rebuilt synthetic Buttons from it. It therefore
# proved nothing about the game: edit the real script and its numbers never
# move, yet it still printed "RESULT PASS". That is a fake verification.
#
# THIS probe loads res://scripts/gameplay/MobileControls.gd and reads the actual
# @onready nodes its own _ready() built (sprint_btn / jump_btn / weapon_btn /
# attack_btn / joystick_area). Change the real constant and these numbers change.
#
# Headless has no display server, so the root viewport is not the device size.
# The probe creates a Window at the real device viewport (1950x900, per
# DIAG_CONTEXT: project 1600x900 + stretch canvas_items/aspect=expand on a
# 3120x1440 panel) and parents MobileControls full-rect inside it, so anchors and
# offsets resolve to true device geometry.

const TAG := "RECTS"

const DEV_W := 1950
const DEV_H := 900

# Expected SPRINT geometry AFTER the fix (top -760, height 360):
#   y from 900-760=140 to 900-400=500  -> entirely above the joystick (y 550..810)
const EXPECT_SPRINT_X := [30.0, 300.0]
const EXPECT_SPRINT_Y := [140.0, 500.0]


func _ready() -> void:
	await get_tree().process_frame

	# Load the REAL script under test.
	var mc_script: GDScript = load("res://scripts/gameplay/MobileControls.gd")
	if mc_script == null:
		print(TAG, " FAIL could not load MobileControls.gd")
		get_tree().quit(1)
		return

	var w := Window.new()
	w.size = Vector2i(DEV_W, DEV_H)
	get_tree().root.add_child.call_deferred(w)
	await get_tree().process_frame
	await get_tree().process_frame
	print(TAG, " window=", w.size, " (device viewport)")

	var parent := Control.new()
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.add_child(parent)
	await get_tree().process_frame
	await get_tree().process_frame
	print(TAG, " parent_rect=", parent.get_global_rect(), " (must be (0,0)-(1950,900))")

	# Instantiate the REAL game scene so MobileControls arrives with its actual
	# child nodes (JoystickArea/JoystickKnob). Constructing MobileControls
	# standalone makes its _ready() fail on $JoystickArea and it builds nothing.
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	w.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout

	# Find the real MobileControls instance inside the live game scene.
	var mc: Control = null
	var stack: Array = [game]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MobileControls or (n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("MobileControls.gd")):
			mc = n as Control
			break
		for c in n.get_children():
			stack.append(c)

	if mc == null:
		print(TAG, " FAIL no MobileControls found in game.tscn")
		get_tree().quit(1)
		return
	print(TAG, " found_real_MobileControls=", mc.name, " at ", mc.get_path())

	await get_tree().process_frame
	await get_tree().process_frame

	# Prove the container is laid out before trusting any rect.
	print(TAG, " parent_size=", mc.size, " global=", mc.global_position,
		" (must be 1950x900 at 0,0)")
	if mc.size.x < 100.0 or mc.size.y < 100.0:
		print(TAG, " FAIL MobileControls never laid out - rects would be meaningless")
		get_tree().quit(1)
		return

	# Prove we are reading the real objects, not synthetic ones.
	var sprint_script: Variant = mc.get("sprint_btn")
	if sprint_script == null:
		print(TAG, " FAIL MobileControls did not build sprint_btn")
		get_tree().quit(1)
		return

	var pairs := [
		["SPRINT", mc.get("sprint_btn")],
		["JUMP", mc.get("jump_btn")],
		["SWAP", mc.get("weapon_btn")],
		["ATTACK", mc.get("attack_btn")],
		["JOYSTICK", mc.get("joystick_area")],
	]

	var names: Array = []
	var rects: Array = []
	for p in pairs:
		var c: Control = p[1]
		names.append(p[0])
		if c == null:
			print(TAG, " ", p[0], " MISSING")
			rects.append(Rect2())
			continue
		var r: Rect2 = c.get_global_rect()
		rects.append(r)
		print(TAG, " ", p[0], " rect=", r, " size=", r.size, " end=", r.end)

	# ---- Overlaps across all real controls ----
	var overlaps := 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var inter: Rect2 = rects[i].intersection(rects[j])
			if inter.get_area() > 1.0:
				overlaps += 1
				print(TAG, " OVERLAP ", names[i], " x ", names[j],
					" area=", int(inter.get_area()), " inter=", inter)
	print(TAG, " total_overlaps=", overlaps)

	# ---- SPRINT assertions ----
	var sp: Rect2 = rects[0]
	var jr: Rect2 = rects[4]

	var not_sliver: bool = sp.size.x >= 200.0 and sp.size.y >= 200.0
	var x_ok: bool = absf(sp.position.x - EXPECT_SPRINT_X[0]) < 2.0 \
		and absf(sp.end.x - EXPECT_SPRINT_X[1]) < 2.0
	var y_ok: bool = absf(sp.position.y - EXPECT_SPRINT_Y[0]) < 2.0 \
		and absf(sp.end.y - EXPECT_SPRINT_Y[1]) < 2.0
	var clear_of_joy: bool = sp.intersection(jr).get_area() <= 1.0

	print(TAG, " SPRINT size=", sp.size, " expect x=[", EXPECT_SPRINT_X[0], ",",
		EXPECT_SPRINT_X[1], "] y=[", EXPECT_SPRINT_Y[0], ",", EXPECT_SPRINT_Y[1], "]")
	print(TAG, " SPRINT not_sliver=", not_sliver, " x_ok=", x_ok, " y_ok=", y_ok)
	print(TAG, " SPRINT clear_of_joystick=", clear_of_joy,
		" (sprint_bottom=", sp.end.y, " joystick_top=", jr.position.y, ")")

	var ok: bool = not_sliver and x_ok and y_ok and clear_of_joy and overlaps == 0
	var reason := ""
	if not not_sliver:
		reason += "SPRINT is a sliver (%s); " % str(sp.size)
	if not x_ok:
		reason += "SPRINT x band wrong; "
	if not y_ok:
		reason += "SPRINT y band wrong; "
	if not clear_of_joy:
		reason += "SPRINT overlaps joystick; "
	if overlaps != 0:
		reason += "%d control overlap(s); " % overlaps

	if ok:
		print(TAG, " RESULT PASS")
		get_tree().quit(0)
	else:
		print(TAG, " RESULT FAIL ", reason.strip_edges())
		get_tree().quit(1)
