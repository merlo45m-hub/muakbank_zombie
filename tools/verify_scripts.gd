extends Node
## Load every .gd in the project; report compile failures.

func _ready() -> void:
	await get_tree().process_frame
	var files := []
	_collect("res://scripts", files)
	_collect("res://addons", files)
	_collect("res://tools", files)
	files.sort()
	# load base classes first (alphabetical is usually fine, but explicit)
	var broken := []
	var ok := 0
	for f in files:
		if not f.ends_with(".gd"):
			continue
		var s = load(f)
		if s == null:
			broken.append(f)
			print("SCRIPT_LOAD_FAILED: ", f)
		else:
			ok += 1
	print("=== SCRIPTS OK: %d BROKEN: %d ===" % [ok, broken.size()])
	for b in broken:
		print("  BROKEN: ", b)
	await get_tree().process_frame
	get_tree().quit(0 if broken.is_empty() else 1)

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
			elif f.ends_with(".gd"):
				out.append(dir_path + "/" + f)
		f = d.get_next()
	d.list_dir_end()
