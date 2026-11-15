extends Node3D
## Editor visual sanity: instance the exploded GLB into a REAL scene with a
## camera, then capture the rendered viewport to a PNG. Run as a normal scene
## (not --script), so the viewport texture actually contains the geometry.

const GLB = "res://assets/models/screen_structures_exploded.glb"

func _ready() -> void:
	var ps: PackedScene = load(GLB)
	var inst: Node3D = ps.instantiate() as Node3D
	add_child(inst)
	await get_tree().process_frame
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	var stack: Array = [inst]
	var count := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			var a: AABB = mi.global_transform * mi.mesh.get_aabb()
			lo = lo.min(a.position); hi = hi.max(a.position + a.size)
			count += 1
		for c in n.get_children():
			stack.push_back(c)
	var centre: Vector3 = (lo + hi) * 0.5
	var span: float = (hi - lo).length()
	print("VISUAL_MESHES=", count, " span_m=", snappedf(span, 0.01))
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	var dir: Vector3 = Vector3(0.15, -1.0, 0.35).normalized()
	cam.position = centre + dir * (span * 0.85)
	cam.look_at(centre)
	cam.far = 500.0
	for _i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_absolute("res://build")
	var out := "res://build/scale_visual_sanity.png"
	img.save_png(out)
	print("VISUAL_PNG=", out, " size=", img.get_size())
	get_tree().quit(0)
