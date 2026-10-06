## diag_rig2.gd — walks the full node chain of the rigged model and prints
## every transform so the hidden scale in the glb hierarchy is visible.
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
	print("DIAG model tf=", model.transform)

	# Walk down to the mesh, printing every local transform.
	var path := "RootNode/Root/Skeleton3D/characterMedium"
	var node: Node = model
	for seg in path.split("/"):
		node = node.get_node_or_null(seg)
		if node == null:
			print("DIAG missing node at ", seg)
			break
		if node is Node3D:
			var t: Transform3D = (node as Node3D).transform
			print("DIAG node=", String(node.name), " local_basis_scale=", t.basis.get_scale(),
				" origin=", t.origin)
	var m: MeshInstance3D = node as MeshInstance3D
	if m == null:
		get_tree().quit(1)
		return
	var gt: Transform3D = m.global_transform
	print("DIAG mesh GLOBAL basis=", gt.basis, " scale=", gt.basis.get_scale(), " origin=", gt.origin)
	var ab: AABB = m.mesh.get_aabb()
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for cx in [ab.position.x, ab.position.x + ab.size.x]:
		for cy in [ab.position.y, ab.position.y + ab.size.y]:
			for cz in [ab.position.z, ab.position.z + ab.size.z]:
				var w: Vector3 = gt * Vector3(cx, cy, cz)
				mn = mn.min(w)
				mx = mx.max(w)
	print("DIAG world aabb min=", mn, " max=", mx, " size=", mx - mn)
	print("DIAG world height=", mx.y - mn.y, " lowest_y=", mn.y)
	get_tree().quit(0)