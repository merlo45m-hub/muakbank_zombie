extends Node3D
class_name GridSnap

## GridSnap — deterministic grid snapping for modular street/prop containers.
## Quantizes each direct child's position (X/Z only) to a cell grid and each
## child's rotation.y to rotation_step_deg. No RNG. Runs in _ready when
## auto_snap is on, so assembled streets stay spatially coherent for assembly.

@export var cell_size: float = 1.0
@export var rotation_step_deg: int = 90
@export var auto_snap: bool = true

func _ready() -> void:
func _ready() -> void:
	add_to_group("GridSnap")  # self-registered: tscn groups attr is not applied reliably
	if auto_snap:
		snap_children()

func snap_children() -> void:
	var cell: float = cell_size
	if cell <= 0.0:
		cell = 1.0
	var step: float = deg_to_rad(float(rotation_step_deg))
	if step <= 0.0:
		step = TAU
	for child in get_children():
		if not (child is Node3D):
			continue
		var node: Node3D = child as Node3D
		var pos: Vector3 = node.position
		pos.x = roundf(pos.x / cell) * cell
		pos.z = roundf(pos.z / cell) * cell
		node.position = pos
		var rot: Vector3 = node.rotation
		rot.y = roundf(rot.y / step) * step
		node.rotation = rot
