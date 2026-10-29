extends Node
## Light census probe — boots the REAL game scene and measures the enabled
## real-time light count (visible Light3D with light_energy > 0) at:
##   1. spawn     (default player start)
##   2. near-lamp (-7.5, 0.15, 5) — ~3.4 m from StreetLampWarm; that lamp MUST enable
##   3. far-min   a grid search over the map for the position farthest from the
##                street-lamp population; reports the minimum enabled count.
## The gate ticks on a 0.25 s process accumulator, so ALWAYS run with --fixed-fps 60.
## Prints CENSUS: lines. Exit 0 on success.

const NEAR_POS := Vector3(-7.5, 0.15, 5.0)

var _lights: Array = []


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out


func _enabled() -> Array:
	var out: Array = []
	for n in _lights:
		if n is Light3D and n.visible and n.light_energy > 0.0:
			out.append(n)
	return out


func _count() -> int:
	return _enabled().size()


func _census(tag: String) -> int:
	var on := _enabled()
	var by_type: Dictionary = {}
	for n in on:
		var cls: String = n.get_class()
		by_type[cls] = int(by_type.get(cls, 0)) + 1
	print("CENSUS: %s enabled=%d types=%s" % [tag, on.size(), str(by_type)])
	for n in on:
		var l := n as Node3D
		print("CENSUS-D: %s %s@(%.1f,%.1f,%.1f)" % [tag, n.name, l.global_position.x, l.global_position.y, l.global_position.z])
	return on.size()


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _ready() -> void:
	var packed := load("res://scenes/main/game.tscn") as PackedScene
	if packed == null:
		print("CENSUS: FAIL load game.tscn")
		get_tree().quit(1)
		return
	var inst := packed.instantiate()
	add_child(inst)
	var player: Node3D = null
	for n in _all_nodes(inst):
		if n is Light3D:
			_lights.append(n)
		elif n is CharacterBody3D and String(n.name) == "Player":
			player = n
	if player == null:
		print("CENSUS: FAIL no Player found")
		get_tree().quit(1)
		return

	await _settle(120)  # _ready chains + level env + podiums + gate registration
	print("CENSUS: player pos=%s" % str(player.global_position))
	_census("spawn")

	# --- NEAR: walk up to StreetLampWarm (-7.5,3.4,6) ; it must enable ---
	player.global_position = NEAR_POS
	await _settle(20)
	_census("near")
	var lamp1 := _find("StreetLampWarm")
	var lamp2 := _find("StreetLampWarm2")
	if lamp1 is Light3D and lamp2 is Light3D:
		var l1 := lamp1 as Node3D
		var l2 := lamp2 as Node3D
		print("CENSUS: near_diag player=%s lamp1_dist=%.1f lamp2_dist=%.1f lamp1_vis=%s lamp2_vis=%s" % [
			str(player.global_position), l1.global_position.distance_to(player.global_position),
			l2.global_position.distance_to(player.global_position), str(lamp1.visible), str(lamp2.visible)])
	if not (lamp1 is Light3D and lamp1.visible):
		print("CENSUS: FAIL StreetLampWarm did not enable when player near")
		get_tree().quit(1)
		return

	# --- FAR MIN: grid search for the position with the fewest enabled lights ---
	var best_pos := player.global_position
	var best_count := 999
	# coarse pass, then refine around the argmin
	var coarse := await _grid_search(player, 12.0, 60.0)
	if coarse.size() == 2:
		best_pos = coarse[0]
		best_count = coarse[1]
		# refine: step 3 m in a 18 m window around the coarse best
		var fine := await _grid_search(player, 3.0, 18.0, best_pos)
		if fine.size() == 2:
			best_pos = fine[0]
			best_count = fine[1]
	player.global_position = best_pos
	await _settle(20)
	var far_min := _census("far_min")
	print("CENSUS: far_min_pos=%s far_min=%d" % [str(best_pos), far_min])
	if far_min <= 3:
		print("CENSUS_RESULT: PASS")
		get_tree().quit(0)
	else:
		print("CENSUS: FAIL far_min enabled=%d expected <=3" % far_min)
		get_tree().quit(1)


## Teleport the player over a grid, settle past one gate tick, count enabled
## lights, and return the best [position, count]. Returns [] if nothing found.
func _grid_search(player: Node3D, step: float, extent: float, center: Vector3 = Vector3.ZERO) -> Array:
	var best_pos: Vector3 = player.global_position
	var best := 999
	for gx in range(-int(extent / step), int(extent / step) + 1):
		for gz in range(-int(extent / step), int(extent / step) + 1):
			var p := center + Vector3(float(gx) * step, 0.15, float(gz) * step)
			# keep the search inside the playable world disc (r <= 75 m road field)
			if p.distance_to(Vector3.ZERO) > 75.0:
				continue
			player.global_position = p
			await _settle(17)  # > one 0.25 s gate tick at fixed 60 fps
			var c := _count()
			if c < best:
				best = c
				best_pos = p
	return [best_pos, best]


func _find(nm: String) -> Node:
	for n in _lights:
		if String(n.name) == nm:
			return n
	return null
