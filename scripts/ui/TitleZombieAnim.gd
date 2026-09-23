## TitleZombieAnim.gd — Shambling animation for background zombie animals
## Attach to each zombie animal node in the title background

extends Node3D

@onready var model: MeshInstance3D = get_node_or_null("..") as MeshInstance3D

# Configurable shambling parameters
@export var shamble_speed: float = 0.4
@export var shamble_amount: float = 0.08
@export var bob_amount: float = 0.03

var _time: float = 0.0


func _process(delta: float) -> void:
	if not model:
		return
	_time += delta * shamble_speed

	# Slow side-to-side swaying (zombie shuffle)
	var sway = sin(_time * 1.3) * shamble_amount
	model.rotation.z = sway

	# Slight bobbing up and down
	var bob = sin(_time * 2.1) * bob_amount
	model.position.y = bob
