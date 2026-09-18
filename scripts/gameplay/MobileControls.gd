extends Control
class_name MobileControls

## Mobile Touch Controls — On-screen joystick + attack button + special ability
## Place as child of game.tscn root (Node3D) or as UI overlay

signal move_vector_changed(vector: Vector2)
signal attack_pressed
signal special_pressed

# === NODE REFS ===
@onready var joystick_area = $JoystickArea
@onready var joystick_knob = $JoystickArea/JoystickKnob
@onready var attack_btn = $AttackBtn

# Dynamically created special-ability button
var special_btn: Button = null

# === STATE ===
var joystick_touch_index: int = -1
var joystick_touch_start: Vector2 = Vector2.ZERO
var joystick_radius: float = 60.0
var move_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	if attack_btn:
		attack_btn.pressed.connect(func(): emit_signal("attack_pressed"))
	
	_build_special_button()
	
	# Hide on non-mobile platforms (optional)
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		hide()
	
	if joystick_area:
		joystick_area.gui_input.connect(_on_joystick_input)

func _build_special_button() -> void:
	"""Special ability button, above the attack button."""
	special_btn = Button.new()
	special_btn.text = "✨"
	special_btn.add_theme_font_size_override("font_size", 22)
	special_btn.anchor_left = 1.0
	special_btn.anchor_right = 1.0
	special_btn.anchor_top = 1.0
	special_btn.anchor_bottom = 1.0
	special_btn.offset_left = -120.0
	special_btn.offset_top = -230.0
	special_btn.offset_right = -20.0
	special_btn.offset_bottom = -140.0
	special_btn.pressed.connect(func(): emit_signal("special_pressed"))
	add_child(special_btn)

func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_index == -1:
			# Check if touch is in joystick area
			var local_pos = event.position - joystick_area.global_position
			if joystick_area.get_rect().has_point(local_pos):
				joystick_touch_index = event.index
				joystick_touch_start = event.position
				joystick_knob.position = joystick_area.size / 2
		elif not event.pressed and event.index == joystick_touch_index:
			joystick_touch_index = -1
			joystick_knob.position = joystick_area.size / 2
			move_input = Vector2.ZERO
			emit_signal("move_vector_changed", move_input)
	
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		var drag = event.position - joystick_touch_start
		if drag.length() > joystick_radius:
			drag = drag.normalized() * joystick_radius
		move_input = drag / joystick_radius
		emit_signal("move_vector_changed", move_input)
		joystick_knob.position = joystick_area.size / 2 + drag

func get_movement_vector() -> Vector2:
	return move_input
