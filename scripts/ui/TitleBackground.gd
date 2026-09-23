## TitleBackground.gd — Loads zombie animals into the cemetery backdrop
## The .tscn has static geometry (floor, tombstones, trees, fog, lights).
## This script instances the zombie GLB models at runtime and attaches
## shambling animation.

extends Node3D

## Zombie spawn points: (x, z, scale, model_path)
# Spawn points must sit INSIDE the camera's cone. Godot's fov is vertical, so this portrait
# viewport has only ~30 degrees of HORIZONTAL field: at 5 m the visible band is about 2.5 m
# wide. The previous points (x -7 .. +4.5) were all outside it, which is why no animal ever
# appeared in the backdrop. These keep the bear centre-frame as the hero silhouette.
var _zombie_spawns = [
	{"x": -1.2, "z": -2.0, "scale": 1.0, "path": "res://assets/models/zombie_dog.glb", "y_offset": 0.5},
	{"x": 1.4,  "z": -3.2, "scale": 0.9, "path": "res://assets/models/zombie_cat.glb", "y_offset": 0.4},
	{"x": -0.2, "z": -4.6, "scale": 1.3, "path": "res://assets/models/zombie_bear.glb", "y_offset": 0.7},
]


func _ready() -> void:
	_setup_camera()
	_load_zombies()


func _setup_camera() -> void:
	# The scene file's camera sat at knee height looking 30 degrees down, so the frame
	# was mostly a flat grey slab of floor with the headstones cropped at the very top
	# edge - it read as a UI panel, not a cemetery. Frame it the way the cover art does:
	# eye level, horizon just above the middle, graves and trees as silhouettes against
	# the fog, sky and moon above them.
	var cam := get_node_or_null("Camera") as Camera3D
	if cam == null:
		printerr("[TitleBackground] no Camera child found - framing unchanged")
		return
	print("[TitleBackground] _setup_camera before: ", cam.global_position, " fov=", cam.fov, " in_tree=", is_inside_tree(), " parent=", get_parent().name if get_parent() else "<none>")
	cam.fov = 62.0
	cam.near = 0.1
	cam.far = 120.0
	# Aim at the tombstone cluster's centroid rather than straight down the empty middle of the
	# field: from (0,1.55,8) the look axis passed between every prop, which is what produced
	# two flat featureless bands. Closer eye, graves and animals inside the narrow portrait cone.
	cam.global_position = Vector3(-0.3, 1.5, 2.6)
	cam.look_at(Vector3(-0.7, 0.95, -5.3), Vector3.UP)
	print("[TitleBackground] _setup_camera after: ", cam.global_position, " fov=", cam.fov)
	await get_tree().process_frame
	print("[TitleBackground] _setup_camera next_frame: ", cam.global_position, " fov=", cam.fov)


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

		# Position the zombie. The spawn entries are Dictionary values (Variants) and the
		# Transform3D/Vector3 constructors reject Variant arguments - that parse error is
		# why this script never loaded at all. Convert explicitly.
		var pos := Vector3(float(spawn.x), float(spawn.y_offset), float(spawn.z))
		var scl := float(spawn.scale)
		# The mesh is still parented to the instantiated glTF scene, and add_child()
		# refuses a node that already has a parent - which is why the pet zombies never
		# showed up in the backdrop. Detach it first, then re-parent.
		if mesh_node.get_parent() != null:
			mesh_node.get_parent().remove_child(mesh_node)
		# owner is a packing concept; leaving it set makes Godot warn that the owner
		# ('zombie_dog') is inconsistent when the node lands under Zombies.
		mesh_node.owner = null
		mesh_node.transform = Transform3D(Basis.IDENTITY, pos)
		mesh_node.scale = Vector3(scl, scl, scl)

		# Assign a dark material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _zombie_color(str(spawn.path))
		mat.roughness = 0.85
		mat.metallic = 0.0
		mesh_node.material_override = mat

		# Add to the Zombies node
		var zombies_node = get_node_or_null("Zombies")
		if zombies_node:
			zombies_node.add_child(mesh_node)

		# Attach shambling animation script. TitleZombieAnim.gd declares no class_name, so
		# the bare identifier resolved to nothing; preload the script and instantiate it.
		var anim = preload("res://scripts/ui/TitleZombieAnim.gd").new()
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
