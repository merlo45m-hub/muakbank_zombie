extends RigidBody3D
class_name QuarantineSupplyCase

## QuarantineSupplyCase — a heavy rigid supply case used to brace quarantine
## doors (spec: docs/specs/LEVEL1_MINIGAMES_B.md §2). ~40 kg, high friction,
## pushed by capped player impulses; no teleport-to-socket. Seals a door only
## when it sits inside that door's BraceSocket while the door is closed.

const STAGE_Y := 0.35

var brace_type: String = "case"
var staged_position: Vector3 = Vector3.ZERO
var released: bool = false

func _ready() -> void:
	add_to_group("quarantine_brace")
	mass = 40.0
	linear_damp = 4.0
	angular_damp = 9.0
	# The scene placement IS the staging mark (drop point beside its crate).
	staged_position = global_position

## Staging mark set by the scene/controller (drop point beside its crate).
func stage(pos: Vector3) -> void:
	staged_position = pos

func reset_to_stage() -> void:
	released = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	global_position = staged_position + Vector3(0, STAGE_Y, 0)

## Called when its crate cracks: the case becomes a free physical brace.
func release() -> void:
	released = true
	freeze = false
