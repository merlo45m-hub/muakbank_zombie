extends SceneTree

## tools/tests/verify_scene_resolves.gd — engine-level reference-resolution validator
## (issue #63 directive 2026-11-19). FULL-SWEEP MODE: iterates every .tscn in the
## project, loads and instantiates it, counts resolved MeshInstance3D. Production
## scenes must load; scenes under ALLOWED_WIP may fail and are counted, not fatal.
## FLOORS encode the mathematical/asset contracts (graveyard instance counts etc).

const ALLOWED_WIP: Array[String] = ["scenes/dev/", "wip/"]
const FLOORS: Dictionary = {
	"res://scenes/world/title_background.tscn": 25,
	"res://scenes/main/title_screen.tscn": 20,
	"res://scenes/main/game.tscn": 300,
	"res://scenes/world/environment/industrial_district.tscn": 100,
	"res://scenes/world/environment/endgame_heights.tscn": 100,
	"res://scenes/world/environment/old_town_enhanced.tscn": 200,
}

var failures: Array[String] = []
var allowed_fails: int = 0
var scanned: int = 0
var total_meshes: int = 0

func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	paths.sort()
	for pth in paths:
		scanned += 1
		var packed: PackedScene = load(pth) as PackedScene
		if packed == null:
			var is_wip: bool = false
			for w in ALLOWED_WIP:
				if pth.contains(w):
					is_wip = true
					break
			if is_wip:
				allowed_fails += 1
				print("ALLOWED-WIP load-null: " + pth)
			else:
				failures.append(pth + " :: load returned null")
			continue
		var inst: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		if inst == null:
			failures.append(pth + " :: instantiate null")
			continue
		root.add_child(inst)
		await process_frame
		var meshes: int = _count_meshes(inst)
		total_meshes += meshes
		root.remove_child(inst)
		inst.free()
		if FLOORS.has(pth) and meshes < int(FLOORS[pth]):
			failures.append(pth + " :: meshes=" + str(meshes) + " floor=" + str(int(FLOORS[pth])))
		if scanned % 25 == 0:
			print("SWEEP progress=" + str(scanned) + " failures=" + str(failures.size()))
	if failures.is_empty():
		print("SCENE_RESOLVES_PASS=true scenes=" + str(scanned) + " total_meshes=" + str(total_meshes) + " allowed_wip_fails=" + str(allowed_fails))
		quit(0)
	else:
		for f in failures:
			print("SCENE_RESOLVES_FAIL: " + f)
		quit(1)

func _collect(base: String, acc: Array[String]) -> void:
	var da: DirAccess = DirAccess.open(base)
	if da == null:
		return
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if name.begins_with("."):
			name = da.get_next()
			continue
		if da.current_is_dir():
			_collect(base + name + "/", acc)
		elif name.ends_with(".tscn"):
			acc.append(base + name)
		name = da.get_next()
	da.list_dir_end()

func _count_meshes(node: Node) -> int:
	var n: int = 0
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			n += 1
	for c in node.get_children():
		n += _count_meshes(c)
	return n
