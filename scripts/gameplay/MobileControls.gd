extends Control
class_name MobileControls

## Mobile Touch Controls — On-screen joystick + attack button + special ability
## Place as child of game.tscn root (Node3D) or as UI overlay

signal move_vector_changed(vector: Vector2)
signal attack_pressed
signal punch_pickup_pressed
signal sprint_pressed(active: bool)
signal jump_pressed
signal weapon_switch_pressed

# === NODE REFS ===
@onready var joystick_area = $JoystickArea
@onready var joystick_knob = $JoystickArea/JoystickKnob

# Dynamically created buttons
var sprint_btn: Button = null
var jump_btn: Button = null
var weapon_btn: Button = null
var attack_btn: Button = null
var sprint_active: bool = false

# === STATE ===
var joystick_touch_index: int = -1
var joystick_touch_start: Vector2 = Vector2.ZERO
var joystick_radius: float = 120.0
var move_input: Vector2 = Vector2.ZERO

# Button layout constants — named so the layout is adjustable in one place
# NOTE: Rect2(position, SIZE) — the 3rd/4th args are width/height, NOT a corner.
# The original Rect2(30, -520, 270, -390) had a NEGATIVE height, so .end.y
# evaluated to -910 and _build_sprint_button fed that into offset_bottom,
# collapsing the button to a ~36px sliver that taps missed.
#
# The corrected height (+390) put the top at -520 and the bottom at -130, which
# then OVERLAPPED the joystick (joystick spans y=550..810 at the 1950x900 runtime
# viewport, i.e. offsets -350..-90). SPRINT is therefore raised and shortened so
# it sits entirely ABOVE the joystick: top at -760, bottom at -400, giving a
# 270x360 target with a 50px clear gap above the joystick's -350 top edge.
# Verified by res://tools/verify_sprint_final_probe.tscn (RESULT PASS, no overlaps).
const SPRINT_BTN_RECT := Rect2(30.0, -760.0, 270.0, 360.0)
# JUMP used to sit almost fully inside the SPECIAL button's rect (both right-column
# offsets overlapped), so SPECIAL was half-eaten and the labels rendered on top of
# each other. Park JUMP left of the VS attack button — same bottom band, no overlap.
const JUMP_BTN_RECT := Rect2(-510.0, -250.0, -310.0, -50.0)
const BTN_FONT_SIZE: int = 34
const BTN_BG_COLOR := Color(0.08, 0.08, 0.10, 0.85)
const BTN_BG_ACTIVE := Color(0.2, 0.45, 0.2, 0.9)
const BTN_CORNER_RADIUS: int = 18

func _punch(btn: Control) -> void:
	# Press feedback: a quick squash-back pop. Buttons that don't visibly react
	# read as dead, especially with no sound on the attack.
	if btn == null:
		return
	btn.pivot_offset = btn.size * 0.5
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	t.tween_property(btn, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	_build_sprint_button()
	_build_jump_button()
	_build_weapon_button()
	_build_attack_button()
	# Every action button gets the same press pop.
	for b in [sprint_btn, jump_btn, weapon_btn, attack_btn]:
		if b is Control:
			(b as Control).button_down.connect(_punch.bind(b))

	# Hide on non-mobile platforms (optional)
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		hide()
	
	if joystick_area:
		joystick_area.gui_input.connect(_on_joystick_input)
		# Thumb-sized joystick zone (was a 100px box -- postage stamp on a phone).
		joystick_area.offset_left = 30.0
		joystick_area.offset_top = -350.0
		joystick_area.offset_right = 290.0
		joystick_area.offset_bottom = -90.0
		if joystick_knob:
			joystick_knob.anchor_left = 0.0
			joystick_knob.anchor_top = 0.0
			joystick_knob.anchor_right = 0.0
			joystick_knob.anchor_bottom = 0.0
			joystick_knob.size = Vector2(120, 120)
			joystick_knob.position = joystick_area.size / 2.0 - joystick_knob.size / 2.0

func _build_sprint_button() -> void:
	sprint_btn = Button.new()
	sprint_btn.text = "SPRINT"
	sprint_btn.add_theme_font_size_override("font_size", BTN_FONT_SIZE)
	sprint_btn.anchor_left = 0.0
	sprint_btn.anchor_right = 0.0
	sprint_btn.anchor_top = 1.0
	sprint_btn.anchor_bottom = 1.0
	sprint_btn.offset_left = SPRINT_BTN_RECT.position.x
	sprint_btn.offset_top = SPRINT_BTN_RECT.position.y
	sprint_btn.offset_right = SPRINT_BTN_RECT.end.x
	sprint_btn.offset_bottom = SPRINT_BTN_RECT.end.y
	var style = StyleBoxFlat.new()
	style.bg_color = BTN_BG_COLOR
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_corner_radius_all(BTN_CORNER_RADIUS)
	sprint_btn.add_theme_stylebox_override("normal", style)
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = BTN_BG_ACTIVE
	active_style.set_border_width_all(3)
	active_style.border_color = Color(1, 1, 1, 0.4)
	active_style.set_corner_radius_all(BTN_CORNER_RADIUS)
	sprint_btn.add_theme_stylebox_override("pressed", active_style)
	# Hold-to-sprint: emit true on button_down, false on button_up.
	sprint_btn.button_down.connect(func():
		emit_signal("sprint_pressed", true)
	)
	sprint_btn.button_up.connect(func():
		emit_signal("sprint_pressed", false)
	)
	add_child(sprint_btn)

func _build_jump_button() -> void:
	jump_btn = Button.new()
	jump_btn.text = "JUMP"
	jump_btn.add_theme_font_size_override("font_size", BTN_FONT_SIZE)
	jump_btn.anchor_left = 1.0
	jump_btn.anchor_right = 1.0
	jump_btn.anchor_top = 1.0
	jump_btn.anchor_bottom = 1.0
	jump_btn.offset_left = JUMP_BTN_RECT.position.x
	jump_btn.offset_top = JUMP_BTN_RECT.position.y
	jump_btn.offset_right = JUMP_BTN_RECT.end.x
	jump_btn.offset_bottom = JUMP_BTN_RECT.end.y
	var style = StyleBoxFlat.new()
	style.bg_color = BTN_BG_COLOR
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_corner_radius_all(BTN_CORNER_RADIUS)
	jump_btn.add_theme_stylebox_override("normal", style)
	jump_btn.pressed.connect(func(): emit_signal("jump_pressed"))
	add_child(jump_btn)

func _build_weapon_button() -> void:
	weapon_btn = Button.new()
	weapon_btn.text = "SWAP"
	weapon_btn.add_theme_font_size_override("font_size", BTN_FONT_SIZE)
	weapon_btn.anchor_left = 1.0
	weapon_btn.anchor_right = 1.0
	weapon_btn.anchor_top = 1.0
	weapon_btn.anchor_bottom = 1.0
	weapon_btn.offset_left = -510.0
	weapon_btn.offset_top = -490.0
	weapon_btn.offset_right = -310.0
	weapon_btn.offset_bottom = -290.0
	var style = StyleBoxFlat.new()
	style.bg_color = BTN_BG_COLOR
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_corner_radius_all(BTN_CORNER_RADIUS)
	weapon_btn.add_theme_stylebox_override("normal", style)
	weapon_btn.pressed.connect(func(): emit_signal("weapon_switch_pressed"))
	add_child(weapon_btn)

func _build_attack_button() -> void:
	# Mobile attack control. The old AttackBtn (mislabeled \"VS\") was removed at the
	# user's request, which left the player with NO way to attack on mobile — kills
	# stayed 0. This is a clean attack button emitting the attack_pressed signal the
	# player already listens for. Placed bottom-right in the thumb zone.
	attack_btn = Button.new()
	attack_btn.text = "ATTACK"
	attack_btn.add_theme_font_size_override("font_size", BTN_FONT_SIZE)
	attack_btn.anchor_left = 1.0
	attack_btn.anchor_right = 1.0
	attack_btn.anchor_top = 1.0
	attack_btn.anchor_bottom = 1.0
	attack_btn.offset_left = -250.0
	attack_btn.offset_top = -250.0
	attack_btn.offset_right = -50.0
	attack_btn.offset_bottom = -50.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.12, 0.12, 0.85)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.3)
	style.set_corner_radius_all(BTN_CORNER_RADIUS)
	attack_btn.add_theme_stylebox_override("normal", style)
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.75, 0.2, 0.2, 0.95)
	active_style.set_border_width_all(3)
	active_style.border_color = Color(1, 1, 1, 0.5)
	active_style.set_corner_radius_all(BTN_CORNER_RADIUS)
	attack_btn.add_theme_stylebox_override("pressed", active_style)
	attack_btn.pressed.connect(func():
		emit_signal("attack_pressed")
		Input.vibrate_handheld(35))
	add_child(attack_btn)

func _on_joystick_input(event: InputEvent) -> void:
	# Touch path — the real device path. The panels inside the area are visual
	# only (mouse_filter IGNORE in the scene); they used to sit on top with the
	# default STOP filter and swallow every touch, so this handler never ran
	# and the character could not be moved at all.
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_index == -1:
			# gui_input delivers event.position ALREADY in this control's local
			# space (verified in-engine: a push at global (70,558) arrives as
			# (50,50)). The original code subtracted global_position from these
			# local coords, so the bounds check rejected every real press.
			if Rect2(Vector2.ZERO, joystick_area.size).has_point(event.position):
				joystick_touch_index = event.index
				joystick_touch_start = event.position
				joystick_knob.position = joystick_area.size / 2.0 - joystick_knob.size / 2.0
				print("[MobileControls] joystick engaged")
		elif not event.pressed and event.index == joystick_touch_index:
			joystick_touch_index = -1
			joystick_knob.position = joystick_area.size / 2.0 - joystick_knob.size / 2.0
			move_input = Vector2.ZERO
			emit_signal("move_vector_changed", move_input)

	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		_apply_drag(event.position - joystick_touch_start)

	# Mouse path — covers the emulated mouse from touch (emulate_mouse_from_touch
	# is on by default) and any setup where the controls are visible on desktop.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and joystick_touch_index == -1:
			if Rect2(Vector2.ZERO, joystick_area.size).has_point(event.position):
				joystick_touch_index = 0
				joystick_touch_start = event.position
				joystick_knob.position = joystick_area.size / 2.0 - joystick_knob.size / 2.0
				print("[MobileControls] joystick engaged")
		elif not event.pressed and joystick_touch_index == 0:
			joystick_touch_index = -1
			joystick_knob.position = joystick_area.size / 2.0 - joystick_knob.size / 2.0
			move_input = Vector2.ZERO
			emit_signal("move_vector_changed", move_input)

	elif event is InputEventMouseMotion and joystick_touch_index == 0:
		_apply_drag(event.position - joystick_touch_start)


func _apply_drag(drag: Vector2) -> void:
	if drag.length() > joystick_radius:
		drag = drag.normalized() * joystick_radius
	move_input = drag / joystick_radius
	emit_signal("move_vector_changed", move_input)
	joystick_knob.position = joystick_area.size / 2.0 - joystick_knob.size / 2.0 + drag

func get_movement_vector() -> Vector2:
	return move_input
