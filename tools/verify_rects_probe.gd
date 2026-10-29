extends Node

# Verifies the mobile control rects at the REAL runtime viewport, using the real
# MobileControls.gd constants (not hand-copied numbers). Proves SPRINT is no
# longer an 8px sliver and that no two controls overlap.

const TAG := "RECTS"


func _ready() -> void:
	await get_tree().process_frame

	# Force the real runtime viewport the device uses (1950x900, aspect=expand).
	# The probe sets the window size so anchors/offsets resolve identically.
	get_window().size = Vector2i(1950, 900)
	await get_tree().process_frame

	var mc: Control = load("res://scripts/gameplay/MobileControls.gd").new()
	add_child(mc)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var VW: float = float(get_viewport_rect().size.x)
	var VH: float = float(get_viewport_rect().size.y)
	print(TAG, " viewport=", get_viewport_rect().size)

	var controls: Array = []
	for b in [mc.sprint_btn, mc.jump_btn, mc.weapon_btn, mc.attack_btn]:
		if b is Control:
			controls.append(b as Control)
	if mc.joystick_area:
		controls.append(mc.joystick_area)

	var names := ["SPRINT", "JUMP", "SWAP", "ATTACK", "JOYSTICK"]
	var rects: Array = []
	for i in range(controls.size()):
		var c: Control = controls[i]
		var r: Rect2 = c.get_global_rect()
		rects.append(r)
		print(TAG, " ", names[i], " rect=", r, " size=", r.size)

	# Report any degenerate (sliver) control — the SPRINT bug signature.
	for i in range(rects.size()):
		var r: Rect2 = rects[i]
		if r.size.y < 40.0 or r.size.x < 40.0:
			print(TAG, " SLIVER ", names[i], " size=", r.size)

	# Report overlaps.
	var overlaps := 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var inter: Rect2 = rects[i].intersect(rects[j])
			if inter.get_area() > 1.0:
				overlaps += 1
				print(TAG, " OVERLAP ", names[i], " x ", names[j],
					" area=", int(inter.get_area()))

	var sprint_ok: bool = rects[0].size.y >= 300.0 and rects[0].size.x >= 200.0
	print(TAG, " RESULT ", "PASS" if (sprint_ok and overlaps == 0) else "FAIL")
	get_tree().quit(0 if (sprint_ok and overlaps == 0) else 1)
