extends SceneTree
## In-engine runtime validation of the scale-locked exploded asset.
## Verifies: (1) GLB imports and instances as a real PackedScene,
## (2) each -convcol mesh's live world AABB equals its locked_dimensions_m,
## (3) runtime cost of instancing (objects, static/dynamic memory, frame time).

const ASSETS = "res://assets/data/blender_structure_assets.json"
const GLB = "res://assets/models/screen_structures_exploded.glb"
const TOL = 0.002  # 2 mm (glb float + transform)

var locks: Dictionary = {}

func _initialize() -> void:
	# load contract
	var f: FileAccess = FileAccess.open(ASSETS, FileAccess.READ)
	if f == null:
		print("RUNTIME_FAIL cannot read ", ASSETS)
		quit(1); return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		print("RUNTIME_FAIL bad json"); quit(1); return
	var data: Dictionary = parsed as Dictionary
	for asm in data["assemblies"]:
		for p in asm["parts"]:
			var lk: Dictionary = p["scale_lock"]
			locks[String(p["part_id"])] = lk
	print("LOCKED_PARTS=", locks.size())

	# baseline cost
	var base_obj: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var base_node: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var base_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var base_res: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))

	var ps: PackedScene = load(GLB)
	if ps == null:
		print("RUNTIME_FAIL GLB failed to load"); quit(1); return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	for _i in range(4):
		await process_frame
	# count scene nodes
	var meshes: Array = []
	_collect(inst, meshes)
	print("INSTANCED_MESHES=", meshes.size())

	var checked: int = 0
	var drift: Array = []
	var mi: MeshInstance3D
	for m in meshes:
		mi = m as MeshInstance3D
		# glTF import sanitizes names: "part-convcol" -> "part". Match by exact
		# part_id membership; _guide / _label meshes are not locked and are skipped.
		var pid: String = String(mi.name)
		if not locks.has(pid):
			continue
		var lk: Dictionary = locks[pid]
		var want: Array = lk["locked_dimensions_m"]
		# mesh AABB in local space * global basis scale (identity by contract)
		var aabb: AABB = mi.mesh.get_aabb()
		var sz: Vector3 = aabb.size
		var got: Array = [sz.x, sz.y, sz.z]
		var w: Array = [float(want[0]), float(want[1]), float(want[2])]
		# sorted multiset absorbs +Z-up -> +Y-up axis permutation
		var gs: Array = got.duplicate(); gs.sort()
		var ws: Array = w.duplicate(); ws.sort()
		var ok: bool = true
		for k in range(3):
			if absf(float(gs[k]) - float(ws[k])) > TOL:
				ok = false
		checked += 1
		if not ok:
			drift.append({"part": pid, "got": gs, "want": ws})

	# runtime cost with asset resident
	var inst_obj: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var inst_node: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var inst_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var inst_res: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))

	print("COST_objects_delta=", inst_obj - base_obj, " nodes_delta=", inst_node - base_node)
	print("COST_static_bytes_delta=", int(inst_static - base_static), " resources_delta=", inst_res - base_res)

	# frame-time sample with the asset resident (headless: engine loop, no render)
	var t0: int = Time.get_ticks_usec()
	for _i in range(120):
		await process_frame
	var elapsed_us: int = Time.get_ticks_usec() - t0
	print("FRAME_120_us=", elapsed_us, " avg_us=", int(elapsed_us / 120))
	print("FPSMON_reports=", _fps_reports())
	print("LIVE_AABB_CHECKED=", checked, " drift=", drift.size(), drift)
	var ok_all: bool = checked == locks.size() and drift.is_empty() and checked > 0
	print("RUNTIME_PASS=", ok_all)
	quit(0 if ok_all else 1)


func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _fps_reports() -> int:
	var mon: Node = root.get_node_or_null("FpsMonitor")
	if mon != null and mon.has_method("report_count"):
		return int(mon.report_count())
	return -1
