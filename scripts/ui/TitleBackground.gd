## TitleBackground.gd — Loads zombie animals into the cemetery backdrop
## The .tscn has static geometry (floor, tombstones, trees, fog, lights).
## This script instances the zombie GLB models at runtime and attaches
## shambling animation.

extends Node3D

## Zombie spawn points: (x, z, scale, model_path)
var _zombie_spawns = [
	{"x": -3.0, "z": -4.0, "scale": 1.0, "path": "res://assets/models/zombie_dog.glb", "y_offset": 0.5},
	{"x": 4.5,  "z": -5.5, "scale": 0.9, "path": "res://assets/models/zombie_cat.glb", "y_offset": 0.4},
	{"x": -7.0, "z": -3.0, "scale": 1.3, "path": "res://assets/models/zombie_bear.glb", "y_offset": 0.7},
]


func _ready() -> void:
	_load_zombies()


func _load_zombies() -> void:
	for spawn in _zombie_spawns:
		var packed = load(spawn.path)
		if packed == null:
			printerr("TitleBackground: could not load %s" % spawn.path)
			continue

		# PackedScene instancing: get the root node, find the mesh inside
		var scene = packed.instantiate()
		if scene == null:
			continue

		# Find the first MeshInstance3D in the instanced scene
		var mesh_node = scene.get_node_or_null("MeshInstance3D")
		if mesh_node == null:
			# Try to find any MeshInstance3D child
			for child in scene.get_children():
				if child is MeshInstance3D:
					mesh_node = child
					break

		if mesh_node == null:
			continue

		# Position the zombie
		mesh_node.transform = Transform3D(
			1, 0, 0,
			0, 1, 0,
			0, 0, 1,
			spawn.x, spawn.y_offset, spawn.z
		)
		mesh_node.scale = Vector3(spawn.scale, spawn.scale, spawn.scale)

		# Assign a dark material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _zombie_color(spawn.path)
		mat.roughness = 0.85
		mat.metallic = 0.0
		mesh_node.material_override = mat

		# Add to the Zombies node
		var zombies_node = get_node_or_null("Zombies")
		if zombies_node:
			zombies_node.add_child(mesh_node)

		# Attach shambling animation script
		var anim = TitleZombieAnim.new()
		anim.shamble_speed = 0.3 + randf() * 0.2
		anim.shamble_amount = 0.06 + randf() * 0.04
		anim.bob_amount = 0.02 + randf() * 0.02
		mesh_node.add_child(anim)


func _zombie_color(path: String) -> Color:
	if path.contains("dog"):
		return Color(0.55, 0.45, 0.35, 1.0)
	elif path.contains("cat"):
		return Color(0.5, 0.42, 0.32, 1.0)
	elif path.contains("bear"):
		return Color(0.58, 0.48, 0.38, 1.0)
	return Color(0.52, 0.43, 0.34, 1.0)
