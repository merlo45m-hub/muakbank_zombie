extends Node3D
class_name InteractiveVehicle

## Interactive Vehicle — Kinematic truck or cart prop. The player can nudge it
## but it does not float (no physics-based motion). Features:
##  - Door that opens on interaction (single panel, hinge swing)
##  - Cab hood that pops up once when pushed (one-shot)
##  - Wheels that rotate on a ground-aligned axis (visual only, kinematic)
##  - After open, the prop is a static lever; resets to closed when player walks away.

@export var door_open_angle: float = deg_to_rad(80.0)
@export var door_swing_duration: float = 0.4
@export var hood_pop_duration: float = 0.25
@export var wheel_rotation_speed: float = 3.0              # rad/s visual spin at "driving" state
@export var reset_on_player_away: bool = true
@export var reset_delay: float = 5.0

# State
var is_door_open: bool = false
var is_hood_popped: bool = false
var is_pushed: bool = false                          # became true when player nudged it
var player_near: bool = false
var reset_pending: bool = false
var reset_timer: float = 0.0

# Node refs
var door_panel: MeshInstance3D = null
var door_hinge: HingeJoint3D = null
var door_body: RigidBody3D = null
var hood_node: MeshInstance3D = null
var wheel_fl: MeshInstance3D = null     # front-left wheel
var wheel_fr: MeshInstance3D = null     # front-right wheel
var wheel_rl: MeshInstance3D = null     # rear-left wheel
var wheel_rr: MeshInstance3D = null     # rear-right wheel
var interaction_zone: Area3D = null
var body_node: StaticBody3D = null

# Tween refs
var door_tween: Tween = null
var hood_tween: Tween = null

# Sound
var door_sound: StringName = "door_open"
var hood_sound: StringName = "hood_pop"
var push_sound: StringName = "vehicle_push"

func _ready() -> void:
	add_to_group("interactive_prop")
	# Door panel
	door_panel = get_node_or_null("Door/DoorMesh")
	door_hinge = get_node_or_null("DoorHinge")
	door_body = get_node_or_null("Door")
	hood_node = find_child_mesh("Hood")
	interaction_zone = get_node_or_null("InteractionZone")
	body_node = get_node_or_null("Body") or get_node_or_null("Collision")
	# Wheels — look for any child MeshInstance3D whose name contains "Wheel"
	for child in get_children():
		if child is MeshInstance3D:
			var n := str(child.name).lower()
			if n.contains("wheel"):
				if n.contains("fl") or n.contains("front_left"):
					wheel_fl = child
				elif n.contains("fr") or n.contains("front_right"):
					wheel_fr = child
				elif n.contains("rl") or n.contains("rear_left"):
					wheel_rl = child
				elif n.contains("rr") or n.contains("rear_right"):
					wheel_rr = child

	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

	# Resolve sounds
	if Audio:
		door_sound = "door_open" if Audio.has_sound("door_open") else ""
		hood_sound = "hood_pop" if Audio.has_sound("hood_pop") else ""
		push_sound = "vehicle_push" if Audio.has_sound("vehicle_push") else ""

	# Start closed
	is_door_open = false
	is_hood_popped = false

# ── ZONE ────────────────────────────────────────────────────────────────────────

func _on_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true

func _on_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		if is_door_open and reset_on_player_away:
			reset_pending = true
			reset_timer = reset_delay

# ── INTERACTION ─────────────────────────────────────────────────────────────────

## Open the vehicle door. Called by player interaction.
func interact() -> void:
	open_door()

func open_door() -> void:
	if is_door_open:
		return
	is_door_open = true
	_play_sound(door_sound)
	_anim_open_door()

## Called when the vehicle is nudged (player bumps into it). One-shot hood pop.
func on_pushed() -> void:
	if is_pushed:
		return
	is_pushed = true
	if not is_hood_popped:
		is_hood_popped = true
		_play_sound(hood_sound)
		_anim_hood_pop()
	_play_sound(push_sound)

# ── DOOR ANIMATION ──────────────────────────────────────────────────────────────

func _anim_open_door() -> void:
	if not door_hinge:
		return
	if door_tween:
		door_tween.kill()
	door_tween = create_tween()
	door_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(door_hinge, "limit_angle", door_open_angle, door_swing_duration)
	# Also rotate the visual panel for smooth rendering
	if door_panel:
		door_tween.tween_property(door_panel, "rotation:y", door_open_angle, door_swing_duration)

# ── HOOD ANIMATION ──────────────────────────────────────────────────────────────

func _anim_hood_pop() -> void:
	if not hood_node:
		return
	if hood_tween:
		hood_tween.kill()
	hood_tween = create_tween()
	hood_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Hood lifts up on local X (forward pitch)
	hood_tween.tween_property(hood_node, "rotation:x", deg_to_rad(25.0), hood_pop_duration)
	hood_tween.tween_property(hood_node, "position:y", 0.3, hood_pop_duration)

# ── WHEEL VISUAL ROTATION ───────────────────────────────────────────────────────

## Call from _process to spin wheels visually. Only when the vehicle has been
## pushed (is_pushed) — wheels spin briefly then slow to a stop, kinematic feel.
func tick_wheels(delta: float) -> void:
	if not is_pushed:
		return
	# Spin all wheels on their local axis (typically Z for cylinder wheels)
	var rot_step := wheel_rotation_speed * delta
	if wheel_fl: wheel_fl.rotation.z += rot_step
	if wheel_fr: wheel_fr.rotation.z += rot_step
	if wheel_rl: wheel_rl.rotation.z += rot_step
	if wheel_rr: wheel_rr.rotation.z += rot_step
	# Decay spin over time (kinematic coast-down)
	if wheel_rotation_speed > 0.1:
		wheel_rotation_speed *= 0.98

# ── RESET ────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	tick_wheels(delta)
	if reset_pending:
		reset_timer -= delta
		if reset_timer <= 0.0:
			reset_pending = false
			_reset_vehicle()

func _reset_vehicle() -> void:
	is_door_open = false
	is_hood_popped = false
	is_pushed = false
	wheel_rotation_speed = 3.0
	# Close door
	if door_hinge:
		door_hinge.set_limit_angle(0.0)
	if door_panel:
		door_panel.rotation.y = 0.0
	# Close hood
	if hood_node:
		hood_node.rotation.x = 0.0
		hood_node.position.y = 0.0
	# Reset zone
	if interaction_zone:
		interaction_zone.monitoring = true

# ── HELPERS ──────────────────────────────────────────────────────────────────────

func find_child_mesh(prefix: String) -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with(prefix):
			return child
	return null

func find_child_hinge(prefix: String) -> HingeJoint3D:
	for child in get_children():
		if child is HingeJoint3D and child.name.begins_with(prefix):
			return child
	return null

# ── AUDIO ────────────────────────────────────────────────────────────────────────

func _play_sound(sound_name: StringName) -> void:
	if Audio and sound_name != "":
		Audio.play_sound(sound_name)
