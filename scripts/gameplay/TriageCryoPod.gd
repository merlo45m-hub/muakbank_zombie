extends RigidBody3D
class_name TriageCryoPod

## TriageCryoRecovery pod — a contained cryo-pod the player shoves into its
## matching recovery bay. It never takes damage from normal attacks; it is a
## physics body only.
##
## Type is assigned by the controller/scene (cryo_alpha|cryo_beta|cryo_gamma|cryo_delta).
## The body is confined to the thawing hall by the controller; leaving the hall
## costs clock time and teleports it back to its release stall (velocity cleared).

const TYPE_COLORS := {
	"cryo_alpha": Color(0.85, 0.15, 0.15),
	"cryo_beta": Color(0.2, 0.35, 0.9),
	"cryo_gamma": Color(0.95, 0.8, 0.15),
	"cryo_delta": Color(0.35, 0.75, 0.3),
}

const SHOVE_IMPULSE_CAP := 14.0
const STALL_Y := 0.3

const MODEL_PATHS := {
	"cryo_alpha": "res://assets/models/zombie_dog.glb",
	"cryo_beta": "res://assets/models/zombie_cat.glb",
	"cryo_gamma": "res://assets/models/zombie_rabbit.glb",
	"cryo_delta": "res://assets/models/zombie_chicken.glb",
}

@export var pod_type: String = "cryo_alpha"
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
	_spawn_model()
	var ring: MeshInstance3D = get_node_or_null(ring_path) as MeshInstance3D
	if ring:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TYPE_COLORS.get(pod_type, Color.WHITE)
		mat.emission_enabled = true
		mat.emission = TYPE_COLORS.get(pod_type, Color.WHITE)
		mat.emission_energy_multiplier = 0.7
		ring.material_override = mat
	var tag: Label3D = get_node_or_null(tag_path) as Label3D
	if tag:
		tag.text = pod_type.to_upper()

func _spawn_model() -> void:
	var visual := get_node_or_null(visual_path)
	if visual == null:
		return
	var path: String = MODEL_PATHS.get(pod_type, MODEL_PATHS["cryo_alpha"])
	var model: PackedScene = load(path) as PackedScene
	if model == null:
		return
	var inst := model.instantiate()
	inst.name = "Model"
	visual.add_child(inst)

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