## script_gate.gd — the two failure modes that "53 scenes load clean" does NOT catch:
##   1. A scene that attaches a script with the Godot 3 inline form (script="res://..."),
##      which Godot 4 silently ignores - the node ends up scriptless, so no _ready, no
##      button connections, no error message. Loading the .tscn alone still "succeeds".
##   2. A .gd that fails to parse. load() returns null and the script silently never runs.
## Run:  Godot_v4.7.2-stable_linux.arm64 --headless --script res://tools/script_gate.gd
## Exit code 0 = clean, 1 = failures (so it can gate a build).
extends SceneTree

var fails: int = 0


func _walk(dir_path: String, out: Array, ext: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_walk(full, out, ext)
		elif name.ends_with(ext):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _initialize() -> void:
	var scenes: Array = []
	_walk("res://scenes", scenes, ".tscn")
	for s in scenes:
		var f := FileAccess.open(s, FileAccess.READ)
		if f == null:
			continue
		var txt := f.get_as_text()
		f.close()
		if txt.contains('script="res://'):
			print("GATE FAIL inline-script form (script will NOT attach): ", s)
			fails += 1

	var scripts: Array = []
	_walk("res://scripts", scripts, ".gd")
	for sc in scripts:
		if load(sc) == null:
			print("GATE FAIL parse error: ", sc)
			fails += 1

	print("SCRIPT GATE: scenes=%d scripts=%d FAILS=%d" % [scenes.size(), scripts.size(), fails])
	quit(0 if fails == 0 else 1)
