extends SceneTree
## Verify every .tscn in the project loads without errors.

func _init():
	var scenes := []
	_collect("res://scenes", scenes)
	scenes.sort()

	var failed := []
	for p in scenes:
		var res = load(p)
		if res == null:
			failed.append(p)
			print("FAILED: ", p)
		else:
			var inst = res.instantiate() if res is PackedScene else null
			if res is PackedScene and inst == null:
				failed.append(p)
				print("INSTANTIATE FAILED: ", p)
			elif inst:
				inst.free()
	print("=== SCENES CHECKED: ", scenes.size(), " FAILED: ", failed.size(), " ===")
	if failed.size() > 0:
		for f in failed:
			print("  -> ", f)
	quit(0 if failed.is_empty() else 1)

func _collect(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with("."):
			pass
		elif d.current_is_dir():
			_collect(dir_path + "/" + f, out)
		elif f.ends_with(".tscn"):
			out.append(dir_path + "/" + f)
		f = d.get_next()
	d.list_dir_end()
