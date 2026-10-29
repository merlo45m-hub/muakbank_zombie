extends RigidBody3D
class_name PushableServiceCart

## PushableServiceCart — the heavy hospital laundry cart used to brace Door B
## (spec: docs/specs/LEVEL1_MINIGAMES_B.md §2). A real RigidBody3D (55 kg,
## damped, no engine/AI — unlike the kinematic InteractiveVehicle visual it
## replaces for this activity). Moved by player body contact or capped shoves;
## never snaps to its goal socket.

const STAGE_Y := 0.25

var brace_type: String = "cart"
var staged_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("quarantine_brace")
	mass = 55.0
	linear_damp = 3.0
	angular_damp = 8.0
	# The scene placement IS the staging mark.
	staged_position = global_position

func stage(pos: Vector3) -> void:
	staged_position = pos

func reset_to_stage() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	global_position = staged_position + Vector3(0, STAGE_Y, 0)
	freeze = false
