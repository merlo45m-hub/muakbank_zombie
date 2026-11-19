extends SceneTree

## tools/verify_scene_resolves.gd — engine-level reference-resolution validator
## (issue #63 directive 2026-11-19: static gates proved nothing on a scene whose
## GLB references silently failed to instantiate). Loads AND instantiates every
## presentation scene, awaits frames, and reports per-scene integrity.

const PRESENTATION_SCENES: Array[String] = [
	"res://scenes/main/title_screen.tscn",
	"res://scenes/main/game.tscn",
	"res://scenes/ui/character_select.tscn",
	"res://scenes/ui/level_select.tscn",
	"res://scenes/ui/level_backdrop.tscn",
	"res://scenes/world/title_background.tscn",
	"res://scenes/world/environment/old_town_enhanced.tscn",
	"res://scenes/world/environment/industrial_district.tscn",
	"res://scenes/world/environment/endgame_heights.tscn",
]

var failures: Array[String] = []

func _initialize() -> void:
	var total_meshes: int = 0
	for scene_path in PRESENTATION_SCENES:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			failures.append(scene_path + " :: load returned null")
			continue
		var inst: Node = packed.instantiate()
		if inst == null:
			failures.append(scene_path + " :: instantiate returned null")
			continue
		root.add_child(inst)
		await process_frame
		await process_frame
		var meshes: int = _count_meshes(inst)
		total_meshes += meshes
		if scene_path.contains("title_background") and meshes < 25:
			failures.append(scene_path + " :: only " + str(meshes) + " MeshInstance3D resolved (expected >=25 graveyard GLB instances)")
		root.remove_child(inst)
		inst.free()
		print("RESOLVES: " + scene_path + " meshes=" + str(meshes))
	if failures.is_empty():
		print("SCENE_RESOLVES_PASS=true total_meshes=" + str(total_meshes))
		quit(0)
	else:
		for f in failures:
			print("SCENE_RESOLVES_FAIL: " + f)
		quit(1)

func _count_meshes(node: Node) -> int:
	var n: int = 0
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			n += 1
	for c in node.get_children():
		n += _count_meshes(c)
	return n
