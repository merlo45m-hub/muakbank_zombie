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
@onready var attack_btn = $AttackBtn

# Dynamically created buttons
var special_btn: Button = null
var sprint_btn: Button = null
var jump_btn: Button = null
var weapon_btn: Button = null
var sprint_active: bool = false

# === STATE ===
var joystick_touch_index: int = -1
var joystick_touch_start: Vector2 = Vector2.ZERO
var joystick_radius: float = 120.0
var move_input: Vector2 = Vector2.ZERO

# Button layout constants — named so the layout is adjustable in one place
const SPRINT_BTN_RECT := Rect2(30.0, -520.0, 270.0, -390.0)
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
	if attack_btn:
		attack_btn.pressed.connect(func():
			emit_signal("attack_pressed")
			Input.vibrate_handheld(35))
		# Thumb-sized attack button, 2x2 right-hand cluster with PUNCH/PICKUP/JUMP/SWAP.
		# Its scene anchor is center-right; re-anchor to the bottom or the offsets
		# below land it halfway up the screen.
		attack_btn.anchor_top = 1.0
		attack_btn.anchor_bottom = 1.0
		attack_btn.offset_left = -250.0
		attack_btn.offset_top = -250.0
		attack_btn.offset_right = -50.0
		attack_btn.offset_bottom = -50.0
		attack_btn.add_theme_font_size_override("font_size", BTN_FONT_SIZE + 6)

	_build_punch_pickup_button()
	_build_sprint_button()
	_build_jump_button()
	_build_weapon_button()
	# Every action button gets the same press pop.
	for b in [attack_btn, special_btn, sprint_btn, jump_btn, weapon_btn]:
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

func _build_punch_pickup_button() -> void:
	"""PUNCH/PICKUP button — Roblox-style dual-action.
	Short press (< 0.3s): punch attack.
	Long press OR near pickup: grab/use nearby food or weapon."""
	special_btn = Button.new()
	special_btn.text = "PUNCH/PICKUP"
	special_btn.add_theme_font_size_override("font_size", BTN_FONT_SIZE)
	special_btn.anchor_left = 1.0
	special_btn.anchor_right = 1.0
	special_btn.anchor_top = 1.0
	special_btn.anchor_bottom = 1.0
	special_btn.offset_left = -250.0
	special_btn.offset_top = -490.0
	special_btn.offset_right = -50.0
	special_btn.offset_bottom = -290.0
	# Hold detection: track press time, emit different signals on short vs long release.
	var press_start := 0.0
	var hold_timer: float = 0.0
	const SHORT_PRESS_MAX: float = 0.3
	var pressed_down := false
	special_btn.button_down.connect(func():
		pressed_down = true
		press_start = Time.get_ticks_msec() / 1000.0
		hold_timer = 0.0
	)
	special_btn.button_up.connect(func():
		if not pressed_down:
			return
		pressed_down = false
		hold_timer = Time.get_ticks_msec() / 1000.0 - press_start
		if hold_timer < SHORT_PRESS_MAX:
			# Short press = punch
			emit_signal("punch_pickup_pressed", false)
			Input.vibrate_handheld(20)
		else:
			# Long press = grab attempt
			emit_signal("punch_pickup_pressed", true)
			Input.vibrate_handheld(30)
	)
	add_child(special_btn)

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
