extends MultiMeshInstance3D
class_name PropScatter

## PropScatter — Batches many identical props into a single draw call
## Attach to a MultiMeshInstance3D. Configure mesh + count + spread in the inspector.
## Use for repetitive background clutter (crates, barrels, debris, gravestones).

@export var prop_mesh: Mesh = null
@export var prop_count: int = 50
@export var spread_size: Vector2 = Vector2(80, 80)  # X/Z area
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var random_rotation: bool = true
@export var seed_value: int = 0

func _ready() -> void:
	_build_scatter()

func _build_scatter() -> void:
	if not prop_mesh:
		push_warning("[PropScatter] No prop_mesh assigned — nothing to scatter")
		return
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = prop_mesh
	mm.instance_count = prop_count
	multi_mesh = mm
	
	var rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	
	for i in range(prop_count):
		var x = rng.randf_range(-spread_size.x * 0.5, spread_size.x * 0.5)
		var z = rng.randf_range(-spread_size.y * 0.5, spread_size.y * 0.5)
		var s = rng.randf_range(min_scale, max_scale)
		var rot_y = rng.randf_range(0.0, TAU) if random_rotation else 0.0
		
		var transform = Transform3D()
		transform = transform.scaled(Vector3(s, s, s))
		transform = transform.rotated(Vector3.UP, rot_y)
		transform.origin = Vector3(x, 0.0, z)
		
		mm.set_instance_transform(i, transform)
