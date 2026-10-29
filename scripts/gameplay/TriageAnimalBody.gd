extends RigidBody3D
class_name TriageAnimalBody

## TriageRoundup patient — a frightened, non-combatant zombie pet that the
## player must shove back into its matching ward pen. It never takes damage
## from normal attacks (no health/death logic); it is a physics body only.
##
## Type is assigned by the controller/scene (dog|cat|rabbit|chicken). The body
## is confined to the treatment hall by the controller; leaving the hall costs
## clock time and teleports it back to its release stall (velocity cleared).

const TYPE_COLORS := {
	"dog": Color(0.85, 0.15, 0.15),
	"cat": Color(0.2, 0.35, 0.9),
	"rabbit": Color(0.95, 0.8, 0.15),
	"chicken": Color(0.35, 0.75, 0.3),
}

const SHOVE_IMPULSE_CAP := 14.0
const STALL_Y := 0.3

const MODEL_PATHS := {
	"dog": "res://assets/models/zombie_dog.glb",
	"cat": "res://assets/models/zombie_cat.glb",
	"rabbit": "res://assets/models/zombie_rabbit.glb",
	"chicken": "res://assets/models/zombie_chicken.glb",
}

@export var animal_type: String = "dog"
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
	# Type color on the ring + readable tag, so the player can match an animal
	# to its pen at a glance from the third-person camera.
	var ring: MeshInstance3D = get_node_or_null(ring_path) as MeshInstance3D
	if ring:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TYPE_COLORS.get(animal_type, Color.WHITE)
		mat.emission_enabled = true
		mat.emission = TYPE_COLORS.get(animal_type, Color.WHITE)
		mat.emission_energy_multiplier = 0.7
		ring.material_override = mat
	var tag: Label3D = get_node_or_null(tag_path) as Label3D
	if tag:
		tag.text = animal_type.to_upper()

func _spawn_model() -> void:
	var visual := get_node_or_null(visual_path)
	if visual == null:
		return
	var path: String = MODEL_PATHS.get(animal_type, MODEL_PATHS["dog"])
	var model: PackedScene = load(path) as PackedScene
	if model == null:
		return
	var inst := model.instantiate()
	inst.name = "Model"
	visual.add_child(inst)

## Controller places the body at its release stall with velocity cleared.
func reset_to_stall() -> void:
	delivered = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = stall_position + Vector3(0, STALL_Y, 0)
	freeze = false

## Capped directional shove from the player's attack/bump. Front-on hits push
## toward the wrong ward just like a clean side shove does toward the right one.
func apply_shove(impulse: Vector3) -> void:
	if delivered:
		return
	var capped := impulse
	if capped.length() > SHOVE_IMPULSE_CAP:
		capped = capped.normalized() * SHOVE_IMPULSE_CAP
	apply_central_impulse(capped)

## Park a delivered animal inside its pen; later collisions cannot undo credit.
func park_at(pos: Vector3) -> void:
	delivered = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = pos
