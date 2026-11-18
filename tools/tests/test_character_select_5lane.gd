extends SceneTree
## Test harness for Issue #12 — 5-Lane Character Selection Screen

const EXPECTED_IDS: Array[String] = ["gamer", "doctor", "nurse", "streamer", "hunter"]
const EXPECTED_COLORS: Array[Color] = [
	Color(1.0, 0.176, 0.482),     # gamer #ff2d7b
	Color(0.435, 0.659, 1.0),    # doctor #6fa8ff
	Color(0.176, 0.878, 1.0),     # nurse #2de0ff
	Color(0.627, 0.361, 1.0),    # streamer #a05cff
	Color(1.0, 0.839, 0.039),    # hunter #ffd60a
]

func _initialize() -> void:
	print("--- BEGIN 5-LANE CHARACTER SELECT TEST ---")

	var packed: PackedScene = load("res://scenes/ui/character_select.tscn") as PackedScene
	if packed == null:
		push_error("FAIL: Could not load res://scenes/ui/character_select.tscn")
		quit(1)
		return
	print("PASS: character_select.tscn loaded")

	var cs: Control = packed.instantiate() as Control
	root.add_child(cs)
	print("PASS: character_select.tscn instantiated and added to tree")

	# Wait for ready and first frames
	for _f in range(4):
		await process_frame

	# Check 1: 5 survivors spawned and visible
	var models: Array = cs.get("_models")
	if models.size() != 5:
		push_error("FAIL: Expected 5 models, got %d" % models.size())
		quit(1)
		return
	for i in range(5):
		var m: Node3D = models[i] as Node3D
		if m == null or not is_instance_valid(m):
			push_error("FAIL: Model %d is null or invalid" % i)
			quit(1)
			return
		if not m.visible:
			push_error("FAIL: Model %d (%s) is not visible! All 5 must be visible in lineup." % [i, EXPECTED_IDS[i]])
			quit(1)
			return
	print("PASS: All 5 survivor models present and visible simultaneously")

	# Check 2: 5 pedestal neon materials & lights
	var neon_mats: Array = cs.get("_pedestal_neon_mats")
	var lights: Array = cs.get("_pedestal_lights")
	if neon_mats.size() != 5:
		push_error("FAIL: Expected 5 pedestal neon materials, got %d" % neon_mats.size())
		quit(1)
		return
	if lights.size() != 5:
		push_error("FAIL: Expected 5 pedestal lights, got %d" % lights.size())
		quit(1)
		return
	for i in range(5):
		var mat: StandardMaterial3D = neon_mats[i] as StandardMaterial3D
		var light: OmniLight3D = lights[i] as OmniLight3D
		if mat == null or light == null:
			push_error("FAIL: Pedestal element %d is null" % i)
			quit(1)
			return
		# Verify canonical colors
		var exp_col: Color = EXPECTED_COLORS[i]
		if not mat.emission.is_equal_approx(exp_col):
			push_error("FAIL: Mat emission %s does not match expected %s" % [mat.emission, exp_col])
			quit(1)
			return
		if not light.light_color.is_equal_approx(exp_col):
			push_error("FAIL: Light color %s does not match expected %s" % [light.light_color, exp_col])
			quit(1)
			return
	print("PASS: All 5 pedestals have canonical neon emission & upward lighting")

	# Check 3: 5 lane buttons & 5 tap zones
	var lane_btns: Array = cs.get("_lane_buttons")
	var zone_btns: Array = cs.get("_zone_buttons")
	if lane_btns.size() != 5 or zone_btns.size() != 5:
		push_error("FAIL: Expected 5 lane buttons and 5 zone buttons, got %d / %d" % [lane_btns.size(), zone_btns.size()])
		quit(1)
		return
	print("PASS: 5 lane buttons and 5 tap zones present")

	# Check 4: Selection transitions
	# Select Gamer (0)
	cs.call("_select_character", 0, false, false)
	var active_idx: int = cs.get("selected_character")
	if active_idx != 0:
		push_error("FAIL: Expected selected_character=0, got %d" % active_idx)
		quit(1)
		return
	var gamer_mat: StandardMaterial3D = neon_mats[0] as StandardMaterial3D
	if gamer_mat.emission_energy_multiplier < 2.0:
		push_error("FAIL: Selected pedestal emission multiplier not boosted")
		quit(1)
		return

	# Select Hunter (4)
	cs.call("_select_character", 4, false, false)
	active_idx = cs.get("selected_character")
	if active_idx != 4:
		push_error("FAIL: Expected selected_character=4, got %d" % active_idx)
		quit(1)
		return

	# Simulate button press on Nurse lane button (2)
	var nurse_btn: Button = lane_btns[2] as Button
	nurse_btn.emit_signal("pressed")
	active_idx = cs.get("selected_character")
	if active_idx != 2:
		push_error("FAIL: Pressing Nurse lane button did not select Nurse (got %d)" % active_idx)
		quit(1)
		return
	print("PASS: Selection transitions and button signals verified")

	# Check 5: Tap zones unprojection
	cs.call("_update_tap_zones")
	for i in range(5):
		var z: Button = zone_btns[i] as Button
		if z.size.x <= 0.0 or z.size.y <= 0.0:
			push_error("FAIL: Zone %d has invalid rect size: %s" % [i, z.size])
			quit(1)
			return
	print("PASS: Unprojected tap zones successfully calculated across viewport")

	# Render capture
	for _f in range(4):
		await process_frame
	var img: Image = root.get_texture().get_image()
	if img != null:
		var err: Error = img.save_png("/tmp/charselect_5lane_render.png")
		if err == OK:
			print("PASS: Render capture saved to /tmp/charselect_5lane_render.png")

	print("CHARSELECT_5LANE_PASS=true")
	print("--- 5-LANE CHARACTER SELECT TEST COMPLETED SUCCESSFULLY ---")
	quit(0)
