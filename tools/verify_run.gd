extends Node
## Boot-time scene verification: loads every .tscn with full engine init.

func _ready() -> void:
	await get_tree().process_frame
	_diag_warehouse()
	var scenes := []
	_collect("res://scenes", scenes)
	scenes.sort()

	var failed := []
	var checked := 0
	for p in scenes:
		checked += 1
		var res = load(p)
		if res == null:
			failed.append(p)
			print("LOAD_FAILED: ", p)
			continue
		if res is PackedScene:
			var inst = res.instantiate()
			if inst == null:
				failed.append(p)
				print("INSTANTIATE_FAILED: ", p)
			else:
				inst.free()
	print("=== SCENES CHECKED: %d FAILED: %d ===" % [checked, failed.size()])
	for f in failed:
		print("  FAIL: ", f)
	await get_tree().process_frame
	get_tree().quit(0 if failed.is_empty() else 1)

func _diag_warehouse() -> void:
	var ps = load("res://scenes/world/environment/warehouse_enhanced.tscn")
	if ps == null:
		print("WH-DIAG: load failed")
		return
	var st: SceneState = ps.get_state()
	print("WH-DIAG: node count=", st.get_node_count(), " root=", st.get_node_name(0))
	for i in range(min(3, st.get_node_count())):
		print("WH-DIAG node %d: name=%s type=%s" % [
			i, st.get_node_name(i), (st.get_node_type(i) as String)])
	var inst = ps.instantiate()
	print("WH-DIAG: instantiate -> ", "OK" if inst != null else "NULL")
	if inst:
		inst.free()

func _collect(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			if d.current_is_dir():
				_collect(dir_path + "/" + f, out)
			elif f.ends_with(".tscn"):
				out.append(dir_path + "/" + f)
		f = d.get_next()
	d.list_dir_end()
