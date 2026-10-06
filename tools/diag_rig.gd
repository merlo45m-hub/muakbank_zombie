## diag_rig.gd — prints the exact transform chain of the gamer rig so the
## pedestal math stops being guesswork.
extends Node


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/characters/character_gamer.tscn")
	var full := scene.instantiate()
	var vis: Node3D = full.get_node_or_null("PlayerVisuals")
	full.remove_child(vis)
	full.free()
	vis.position = Vector3(0, 0.76, 0)
	add_child(vis)
	await get_tree().process_frame

	var model: Node3D = vis.get_node_or_null("Model")
	print("DIAG model=", model, " tf=", model.transform if model else "null")
	if model == null:
		get_tree().quit(1)
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		print("DIAG mesh node=", String(model.get_path_to(m)))
		print("DIAG   local_tf=", m.transform)
		print("DIAG   global_pos=", m.global_position)
		var ab: AABB = m.mesh.get_aabb() if m.mesh else AABB()
		print("DIAG   aabb pos=", ab.position, " size=", ab.size)
		var lowest := INF
		var lowest_corner := Vector3.ZERO
		for cx in [ab.position.x, ab.position.x + ab.size.x]:
			for cy in [ab.position.y, ab.position.y + ab.size.y]:
				for cz in [ab.position.z, ab.position.z + ab.size.z]:
					var w: Vector3 = m.global_transform * Vector3(cx, cy, cz)
					if w.y < lowest:
						lowest = w.y
						lowest_corner = Vector3(cx, cy, cz)
		print("DIAG   lowest_world_y=", lowest, " at corner=", lowest_corner)
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var sk: Skeleton3D = skels[0]
		print("DIAG skeleton path=", String(model.get_path_to(sk)), " tf=", sk.transform)
		var lo := INF
		var hi := -INF
		for b in range(sk.get_bone_count()):
			var p := sk.get_bone_global_pose(b).origin
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		print("DIAG bone y range (local to sk): ", lo, " .. ", hi)
		print("DIAG bone world y range: ", sk.global_position.y + lo * 0.425, " .. ", sk.global_position.y + hi * 0.425)
	get_tree().quit(0)