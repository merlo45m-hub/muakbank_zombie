## frame_census.gd — WHICH node is actually occupying the frame?
##
## Projects every MeshInstance3D's world AABB into screen space and reports the fraction of
## the viewport each one covers. Use when a render shows "a big tan thing" and you have been
## guessing which node it is: this answers it with numbers instead.
##
## Raycasts are useless for this in this project - the tombstones and floor are StaticBody3D
## nodes with NO CollisionShape children, so nothing collides. AABBs do not lie.
##
## Run: CENSUS_SCENE=res://scenes/main/title_screen.tscn \
##      Godot --headless --script res://tools/frame_census.gd
extends SceneTree


func _initialize() -> void:
	var path := OS.get_environment("CENSUS_SCENE")
	if path == "":
		path = "res://scenes/main/title_screen.tscn"

	var ps := load(path) as PackedScene
	if ps == null:
		print("CENSUS: cannot load ", path)
		quit(1)
		return
	var scene := ps.instantiate()
	get_root().add_child(scene)

	# Headless still needs a viewport size for unproject_position to be meaningful.
	get_root().size = Vector2i(720, 1600)

	await process_frame
	await process_frame

	var cam := _find_camera(scene)
	if cam == null:
		print("CENSUS: no Camera3D in ", path)
		quit(1)
		return

	var vp := Vector2(720.0, 1600.0)
	var aspect := vp.x / vp.y
	var tan_v := tan(deg_to_rad(cam.fov) * 0.5)
	var tan_h := tan_v * aspect
	var inv := cam.global_transform.affine_inverse()
	print("CENSUS scene=", path, " cam=", cam.global_position, " fov=", cam.fov,
		" tan_h=", snappedf(tan_h, 0.001), "  (half-width at distance d = tan_h * d)")

	var rows: Array = []
	_collect_meshes(scene, rows)

	for r in rows:
		var m: MeshInstance3D = r["node"]
		var path_str: String = r["path"]
		var aabb: AABB = m.get_aabb()
		var xf := m.global_transform
		var min_s := Vector2(1e9, 1e9)
		var max_s := Vector2(-1e9, -1e9)
		var any_front := false
		for c in 8:
			var corner := aabb.position + Vector3(
				aabb.size.x * float(c & 1),
				aabb.size.y * float((c >> 1) & 1),
				aabb.size.z * float((c >> 2) & 1))
			var local := inv * (xf * corner)
			if local.z >= -0.05:
				continue          # at or behind the lens
			any_front = true
			var ndc := Vector2((local.x / -local.z) / tan_h, (local.y / -local.z) / tan_v)
			var sp := Vector2((ndc.x + 1.0) * 0.5 * vp.x, (1.0 - (ndc.y + 1.0) * 0.5) * vp.y)
			min_s = min_s.min(sp)
			max_s = max_s.max(sp)
		if not any_front:
			continue
		var rect := Rect2(min_s, max_s - min_s)
		# clip to the viewport
		var clipped := rect.intersection(Rect2(Vector2.ZERO, vp))
		var area_pct := 100.0 * (clipped.size.x * clipped.size.y) / (vp.x * vp.y)
		if area_pct < 0.5 or not m.is_visible_in_tree():
			continue
		var centre := clipped.get_center()
		var covers_mid: bool = absf(centre.x - vp.x * 0.5) < vp.x * 0.25 and absf(centre.y - vp.y * 0.5) < vp.y * 0.25
		print("CENSUS %6.2f%% x[%4d..%4d] y[%4d..%4d] mid=%s vis=%s  %s" % [
			area_pct, int(clipped.position.x), int(clipped.position.x + clipped.size.x),
			int(clipped.position.y), int(clipped.position.y + clipped.size.y),
			str(covers_mid), str(m.is_visible_in_tree()), path_str])

	print("CENSUS done meshes_visible=", rows.size())
	quit()


func _find_camera(n: Node) -> Camera3D:
	if n is Camera3D:
		return n
	for c in n.get_children():
		var found := _find_camera(c)
		if found != null:
			return found
	return null


func _collect_meshes(n: Node, out: Array, path: String = "") -> void:
	var here := path + "/" + n.name
	if n is MeshInstance3D:
		out.append({"node": n, "path": here})
	for c in n.get_children():
		_collect_meshes(c, out, here)
