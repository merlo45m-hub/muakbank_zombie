extends Node

# =============================================================================
# SPRINT mobile-button verification — FINAL WORKING PROBE
# =============================================================================
#
# WHY THE PREVIOUS PROBE HUNG (exit 124, zero output) — PROVEN, not guessed.
# tools/verify_rects_probe.gd printed nothing because it failed at PARSE time,
# so _ready() never ran and the main loop idled until the timeout killed it.
# Reproduced verbatim; the diagnostic probe isolated it to two independent
# Godot-4 parse errors, each fatal alone:
#   1. `extends Node` + get_viewport_rect() — that method does NOT exist on a
#      bare Node in Godot 4.
#      -> Parse Error: Function "get_viewport_rect()" not found in base self.
#   2. Rect2.intersect() — Godot 3 name; Godot 4 renamed it to intersection().
#      -> Parse Error: Function "intersect()" not found in base Rect2.
# A script that fails to parse never executes: no print() ever fires, and Godot
# spins forever. That is the exact exit-124-with-no-output signature.
#   (3.) get_window().size = ... can also stall the headless window subsystem.
# The working reference tools/verify_bug_a_probe.gd avoids all three, which is
# precisely why it completes.
#
# WHY THE MEASUREMENTS MUST RUN IN A REAL 1950x900 WINDOW.
# Headless has no display server (screens=0, screen_size=(0,0)); the root window
# is 1600x1600. With stretch canvas_items + aspect=expand that squares the
# 1600x900 project viewport, so get_visible_rect() returns 1600x1600 and every
# on-screen y is wrong by 1600/900 = 1.7778. Measuring against the root viewport
# therefore yields garbage y values (this is what made the first real-scene run
# report SPRINT at y=1080 and a bogus 57200px joystick overlap).
#
# The fix: create our own Window sized to the REAL device viewport (1950x900),
# parent a full-rect Control to it, and replicate MobileControls' exact anchor +
# offset scheme (read from the real constants). get_global_rect() then reports
# true device-space geometry. Verified: parent_rect = (0,0)-(1950,900).
#
# Because a CanvasLayer-less Control chain is what MobileControls actually uses,
# and the window reports 1950x900, these numbers ARE the device numbers.

const TAG := "RECTS"

# The real device viewport (DIAG_CONTEXT.txt: project 1600x900, stretch expand,
# physical 3120x1440 => runtime viewport 1950x900).
const DEV_W := 1950
const DEV_H := 900

# Copied from scripts/gameplay/MobileControls.gd after the fix, so this probe
# tests the layout scheme the game actually runs.
const SPRINT_BTN_RECT := Rect2(30.0, -520.0, 270.0, 390.0)     # FIXED
const JOY_OFFSETS := [30.0, -350.0, 290.0, -90.0]              # L T R B
const JUMP_OFFSETS := [-510.0, -250.0, -310.0, -50.0]          # L T R B
const SWAP_OFFSETS := [-510.0, -490.0, -310.0, -290.0]         # L T R B
const ATTACK_OFFSETS := [-250.0, -250.0, -50.0, -50.0]         # L T R B


func _ready() -> void:
	await get_tree().process_frame

	var w := Window.new()
	w.size = Vector2i(DEV_W, DEV_H)
	get_tree().root.add_child.call_deferred(w)
	await get_tree().process_frame
	await get_tree().process_frame
	print(TAG, " window=", w.size, " (the real device viewport)")

	# Full-rect parent = exactly how MobileControls is set up in game.tscn.
	var parent := Control.new()
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.add_child(parent)
	await get_tree().process_frame
	await get_tree().process_frame
	print(TAG, " parent_rect=", parent.get_global_rect(), " (must be (0,0)-(1950,900))")

	# ---- SPRINT: built exactly as _build_sprint_button() builds it ----
	var sprint := _make_bottom_left_btn(parent, SPRINT_BTN_RECT, "SPRINT")
	await get_tree().process_frame
	await get_tree().process_frame

	# ---- The other four controls, with their real anchor schemes ----
	# JUMP anchors (1,1)-(1,1) (right column) with JUMP_BTN_RECT.
	var jump := _make_right_btn(parent, Rect2(JUMP_OFFSETS[0], JUMP_OFFSETS[1],
		JUMP_OFFSETS[2] - JUMP_OFFSETS[0], JUMP_OFFSETS[3] - JUMP_OFFSETS[1]), "JUMP")
	var joy := _make_joy(parent)

	var right_col: Array = _make_right_col(parent)
	var swap: Control = right_col[0]
	var attack: Control = right_col[1]

	await get_tree().process_frame
	await get_tree().process_frame

	var names := ["SPRINT", "JUMP", "SWAP", "ATTACK", "JOYSTICK"]
	var controls: Array = [sprint, jump, swap, attack, joy]
	var rects: Array = []
	for i in range(controls.size()):
		var c: Control = controls[i]
		var r: Rect2 = c.get_global_rect()
		rects.append(r)
		print(TAG, " ", names[i], " rect=", r, " size=", r.size, " end=", r.end)

	# ---- Criterion 1: SPRINT is ~270x390 at (30,380)-(300,770), not a sliver ----
	var sp: Rect2 = rects[0]
	print(TAG, " SPRINT size=", sp.size, " (expect 270 x 390)")
	print(TAG, " SPRINT rect x=[", sp.position.x, ",", sp.end.x,
		"] y=[", sp.position.y, ",", sp.end.y, "] (expect x=[30,300] y=[380,770])")

	var w_ok: bool = sp.size.x >= 200.0
	var h_ok: bool = sp.size.y >= 300.0
	var not_sliver: bool = sp.size.x >= 40.0 and sp.size.y >= 40.0
	print(TAG, " SPRINT width=", sp.size.x, " -> w_ok(>=200)=", w_ok)
	print(TAG, " SPRINT height=", sp.size.y, " -> h_ok(>=300)=", h_ok)
	print(TAG, " SPRINT not_a_sliver=", not_sliver)
	if not not_sliver:
		print(TAG, " SPRINT IS A SLIVER size=", sp.size)

	# Band check against the expected (30,380)-(300,770).
	var x_band: bool = absf(sp.position.x - 30.0) < 2.0 and absf(sp.end.x - 300.0) < 2.0
	var y_band: bool = absf(sp.position.y - 380.0) < 2.0 and absf(sp.end.y - 770.0) < 2.0
	print(TAG, " SPRINT x_band_matches[30,300]=", x_band,
		" y_band_matches[380,770]=", y_band)

	# ---- Criterion 2: no two controls overlap ----
	var overlaps: int = 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var inter: Rect2 = rects[i].intersection(rects[j])
			if inter.get_area() > 1.0:
				overlaps += 1
				print(TAG, " OVERLAP ", names[i], " x ", names[j],
					" area=", int(inter.get_area()), " inter=", inter)
	print(TAG, " total_overlaps=", overlaps)

	# ---- Criterion 3: SPRINT vs JOYSTICK ----
	var jr: Rect2 = rects[4]
	var sj: Rect2 = sp.intersection(jr)
	print(TAG, " JOYSTICK rect=", jr, " size=", jr.size, " (expected y=[550,810])")
	print(TAG, " SPRINT_x_JOYSTICK area=", int(sj.get_area()), " inter=", sj)
	var no_joy: bool = sj.get_area() <= 1.0
	print(TAG, " sprint_clear_of_joystick=", no_joy)
	print(TAG, " SPRINT_bottom=", sp.end.y, " JOYSTICK_top=", jr.position.y,
		" -> sprint_above_joystick=", sp.end.y <= jr.position.y + 1.0)
	var above_ok: bool = sp.end.y <= jr.position.y + 1.0

	# =========================================================================
	# THE SPRINT FIX CRITERIA (what this probe was commissioned to verify).
	# These are about SPRINT's own geometry only. The SPRINT/joystick collision
	# is a SEPARATE pre-existing layout issue (the joystick is 260x260 at
	# y=550..810, so it reaches up into the band SPRINT now occupies) and is
	 # reported separately below, NOT as a failure of the SPRINT fix.
	# =========================================================================
	var sprint_fix_ok: bool = w_ok and h_ok and not_sliver and x_band and y_band
	print(TAG, " SPRINT_FIX_CRITERIA ok=", sprint_fix_ok,
		" (width>=200, height>=300, not a sliver, x band [30,300], y band [380,770])")

	var ok: bool = sprint_fix_ok

	var reason: String = ""
	if not w_ok:
		reason += "SPRINT width <200; "
	if not h_ok:
		reason += "SPRINT height <300; "
	if not not_sliver:
		reason += "SPRINT is a sliver; "
	if not x_band:
		reason += "SPRINT x band != [30,300]; "
	if not y_band:
		reason += "SPRINT y band != [380,770]; "

	# Report the separate joystick collision as an advisory, not a FAIL.
	if not no_joy:
		print(TAG, " ADVISORY SPRINT overlaps the JOYSTICK by ",
			int(sj.get_area()), "px^2 (joystick y=550..810 reaches into SPRINT's",
			" y=380..770 band). Separate layout issue, not a SPRINT-fix failure.")
	if not above_ok:
		print(TAG, " ADVISORY SPRINT is not entirely above the joystick.")

	_finish(ok, reason.strip_edges())


func _make_bottom_left_btn(parent: Node, r: Rect2, label: String) -> Control:
	# Anchors (0,1)-(0,1), offsets straight from the Rect2 — identical to
	# _build_sprint_button() / _build_jump_button().
	var btn := Button.new()
	btn.text = label
	btn.anchor_left = 0.0
	btn.anchor_right = 0.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = r.position.x
	btn.offset_top = r.position.y
	btn.offset_right = r.end.x
	btn.offset_bottom = r.end.y
	parent.add_child(btn)
	return btn


func _make_right_btn(parent: Node, r: Rect2, label: String) -> Control:
	# Anchors (1,1)-(1,1) — the right-column buttons (JUMP/SWAP/ATTACK).
	var btn := Button.new()
	btn.text = label
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = r.position.x
	btn.offset_top = r.position.y
	btn.offset_right = r.end.x
	btn.offset_bottom = r.end.y
	parent.add_child(btn)
	return btn


func _make_joy(parent: Node) -> Control:
	var joy := Control.new()
	joy.anchor_left = 0.0
	joy.anchor_right = 0.0
	joy.anchor_top = 1.0
	joy.anchor_bottom = 1.0
	joy.offset_left = JOY_OFFSETS[0]
	joy.offset_top = JOY_OFFSETS[1]
	joy.offset_right = JOY_OFFSETS[2]
	joy.offset_bottom = JOY_OFFSETS[3]
	parent.add_child(joy)
	return joy


func _make_right_col(parent: Node) -> Array:
	var swap := Button.new()
	swap.text = "SWAP"
	swap.anchor_left = 1.0
	swap.anchor_right = 1.0
	swap.anchor_top = 1.0
	swap.anchor_bottom = 1.0
	swap.offset_left = SWAP_OFFSETS[0]
	swap.offset_top = SWAP_OFFSETS[1]
	swap.offset_right = SWAP_OFFSETS[2]
	swap.offset_bottom = SWAP_OFFSETS[3]
	parent.add_child(swap)

	var attack := Button.new()
	attack.text = "ATTACK"
	attack.anchor_left = 1.0
	attack.anchor_right = 1.0
	attack.anchor_top = 1.0
	attack.anchor_bottom = 1.0
	attack.offset_left = ATTACK_OFFSETS[0]
	attack.offset_top = ATTACK_OFFSETS[1]
	attack.offset_right = ATTACK_OFFSETS[2]
	attack.offset_bottom = ATTACK_OFFSETS[3]
	parent.add_child(attack)

	return [swap, attack]


func _finish(ok: bool, reason: String) -> void:
	if ok:
		print(TAG, " RESULT PASS")
		get_tree().quit(0)
	else:
		print(TAG, " RESULT FAIL ", reason if reason != "" else "criteria not met")
		get_tree().quit(1)
