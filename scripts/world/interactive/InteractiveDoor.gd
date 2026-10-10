extends Node3D
class_name InteractiveDoor

## Interactive Door — Two hinged panels that open/close on player interaction.
## Uses HingeJoint3D for realistic swing pivot. The door is kinematic:
## the player can nudge it but it does not float. Long-press holds open;
## quick tap toggles half-open; release resets after the player walks away.

@export var closed_angle: float = 0.0                     # radians, door face aligned to frame
@export var open_angle: float = deg_to_rad(90.0)          # fully open swing
@export var half_open_angle: float = deg_to_rad(45.0)     # tap-toggle intermediate
@export var swing_duration: float = 0.45                  # one-way open/close seconds
@export var hold_reset_delay: float = 4.0                 # seconds after player leaves before reset
@export var hinge_axis: Vector3 = Vector3.BACK            # local hinge axis (Z = yaw swing door)
@export var lock_collision_when_open: bool = true         # disable panel collisions while open

# Runtime state
var is_open: bool = false
var is_half_open: bool = false
var is_held_open: bool = false
var current_target_angle: float = 0.0
var player_near: bool = false
var long_press_hold: bool = false
var long_press_timer: float = 0.0
const LONG_PRESS_THRESHOLD: float = 0.6                  # seconds to qualify as long press

# Child panel references (set in _ready)
var panel_a: MeshInstance3D = null
var panel_b: MeshInstance3D = null
var hinge_a: HingeJoint3D = null
var hinge_b: HingeJoint3D = null
var interaction_zone: Area3D = null
var body_a: RigidBody3D = null
var body_b: RigidBody3D = null

# Audio
var door_open_sound: StringName = "door_open"
var door_close_sound: StringName = "door_close"
var door_lock_sound: StringName = "door_lock"

# Tween for smooth angle interpolation
var swing_tween: Tween = null
var _reset_idle_timer: float = 0.0
var _reset_pending: bool = false

func _ready() -> void:
	add_to_group("interactive_prop")
	# Discover children by name convention
	# Panels are now RigidBody3D with mesh children (PanelAMesh, PanelBMesh)
	panel_a = get_node_or_null("PanelA/PanelAMesh")
	panel_b = get_node_or_null("PanelB/PanelBMesh")
	hinge_a = get_node_or_null("HingeA")
	hinge_b = get_node_or_null("HingeB")
	interaction_zone = get_node_or_null("DoorInteractionZone")
	body_a = get_node_or_null("PanelA")
	body_b = get_node_or_null("PanelB")

	# Wire interaction zone
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

	# Set both panels to closed angle initially
	_current_angle = closed_angle
	_apply_angle_to_joints(closed_angle)

	# If audio autoload exists, resolve sound names
	if Audio:
		door_open_sound = "door_open" if Audio.has_sound("door_open") else ""
		door_close_sound = "door_close" if Audio.has_sound("door_close") else ""
		door_lock_sound = "door_lock" if Audio.has_sound("door_lock") else ""

# ── CHILD DISCOVERY ─────────────────────────────────────────────────────────────

func find_child_panel(name: String) -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with(name):
			return child
	return null

func find_child_hinge(name: String) -> HingeJoint3D:
	for child in get_children():
		if child is HingeJoint3D and child.name.begins_with(name):
			return child
	return null

# ── ZONE CALLBACKS ──────────────────────────────────────────────────────────────

func _on_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true
		long_press_timer = 0.0
		long_press_hold = false

func _on_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		# Start reset countdown if door was held open
		if is_held_open and not is_open:
			_reset_pending = true
			_reset_idle_timer = hold_reset_delay

# ── INTERACTION (called by Player or a standalone input check) ──────────────────

## Call from the player's interaction check or a zone script.
## door_interact() handles both quick-tap toggle and long-press hold.
func interact() -> void:
	door_interact()

func door_interact() -> void:
	if not player_near:
		return
	if lock_collision_when_open and (is_open or is_half_open):
		# Quick tap while open → close
		if long_press_hold:
			return
		toggle_to_closed()
		return

	# Building up long-press timer
	long_press_timer += get_process_delta_time()
	if long_press_timer >= LONG_PRESS_THRESHOLD and not long_press_hold:
		long_press_hold = true
		open_fully()

# ── OPEN / CLOSE LOGIC ──────────────────────────────────────────────────────────

func open_fully() -> void:
	if is_open:
		return
	is_open = true
	is_half_open = false
	is_held_open = true
	current_target_angle = open_angle
	_play_sound(door_open_sound)
	_set_panel_collisions(false)
	_start_swing(open_angle)

func toggle_to_half_open() -> void:
	# Quick tap: half-open state (cracked door)
	if is_open:
		return
	is_half_open = true
	is_open = false
	current_target_angle = half_open_angle
	_start_swing(half_open_angle)

func toggle_to_closed() -> void:
	is_open = false
	is_half_open = false
	is_held_open = false
	long_press_hold = false
	current_target_angle = closed_angle
	_play_sound(door_close_sound)
	_set_panel_collisions(true)
	_start_swing(closed_angle)

func _start_swing(target: float) -> void:
	if swing_tween:
		swing_tween.kill()
	swing_tween = create_tween()
	swing_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Animate both hinge joints' limit_angle to the target
	swing_tween.tween_callback(func(): _apply_angle_to_joints(target))
	# Also rotate the panel visuals directly for smooth frame-by-frame rendering
	swing_tween.tween_property(self, "_current_angle", target, swing_duration)

# ── ANGLE APPLICATION ────────────────────────────────────────────────────────────

var _current_angle: float = 0.0

func _apply_angle_to_joints(angle: float) -> void:
	# HingeJoint3D limit_angle is the swing from the node's initial orientation.
	# We set it each frame from our animated _current_angle.
	if hinge_a:
		hinge_a.set_limit_angle(angle)
	if hinge_b:
		hinge_b.set_limit_angle(-angle)  # panel B swings opposite for double-door

func _set_panel_collisions(enabled: bool) -> void:
	# When door is open, panels should not block the player.
	if body_a:
		body_a.collision_layer = 1 if enabled else 0
	if body_b:
		body_b.collision_layer = 1 if enabled else 0

# ── AUDIO ────────────────────────────────────────────────────────────────────────

func _play_sound(sound_name: StringName) -> void:
	if Audio and sound_name != "":
		Audio.play_sound(sound_name)

# ── PROCESS ──────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if long_press_hold and player_near and not is_open:
		# Holding: keep door open
		if not is_open:
			open_fully()
	elif long_press_hold and not player_near:
		# Player walked away while holding → start reset
		long_press_hold = false
		if is_held_open:
			is_held_open = false
			_reset_pending = true
			_reset_idle_timer = hold_reset_delay

	# Reset countdown
	if _reset_pending:
		_reset_idle_timer -= delta
		if _reset_idle_timer <= 0.0:
			_reset_pending = false
			toggle_to_closed()

func get_process_delta_time() -> float:
	return Engine.get_physics_frames() > 0 and get_tree().get_process_delta_time() or 0.016
