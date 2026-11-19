extends RigidBody3D

## TriageRoundup industrial cargo unit — a secured crate/cell/module/bundle the
## player shoves into its matching containment pen. Reuses the
## TriageRoundupController capture contract via `unit_type`; the controller reads
## the declared type from the export, so no literal type strings live in the
## controller. L1's TriageAnimalBody is left untouched.

const SHOVE_IMPULSE_CAP := 14.0
const STALL_Y := 0.3

const TYPE_COLORS := {
	"crate": Color(0.85, 0.15, 0.15),
	"cell": Color(0.2, 0.35, 0.9),
	"module": Color(0.95, 0.8, 0.15),
	"bundle": Color(0.35, 0.75, 0.3),
}

@export var unit_type: String = "crate"
@export var tag_path: NodePath = ^"Tag"
@export var ring_path: NodePath = ^"Visual/ColorRing"
@export var visual_path: NodePath = ^"Visual"

var stall_position: Vector3 = Vector3.ZERO
var delivered: bool = false

func _ready() -> void:
	add_to_group("triage_animal")
	mass = 24.0
	linear_damp = 2.0
	angular_damp = 6.0
	var ring: MeshInstance3D = get_node_or_null(ring_path) as MeshInstance3D
	if ring:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TYPE_COLORS.get(unit_type, Color.WHITE)
		mat.emission_enabled = true
		mat.emission = TYPE_COLORS.get(unit_type, Color.WHITE)
		mat.emission_energy_multiplier = 0.7
		ring.material_override = mat
	var tag: Label3D = get_node_or_null(tag_path) as Label3D
	if tag:
		tag.text = unit_type.to_upper()

func reset_to_stall() -> void:
	delivered = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = stall_position + Vector3(0, STALL_Y, 0)
	freeze = false

func apply_shove(impulse: Vector3) -> void:
	if delivered:
		return
	var capped := impulse
	if capped.length() > SHOVE_IMPULSE_CAP:
		capped = capped.normalized() * SHOVE_IMPULSE_CAP
	apply_central_impulse(capped)

func park_at(pos: Vector3) -> void:
	delivered = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = pos
