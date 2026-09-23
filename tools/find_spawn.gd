extends Node

## Find an open, flat spot on the level for the player to spawn.
##
## The player spawned at the level origin, which put him behind a fence: the third
## person camera works, but the first thing a player sees is his own backside pressed
## against scenery with his legs occluded. This probes candidate positions and scores
## them by how much clear horizontal space surrounds them, so the spawn can be chosen
## from data instead of guessed.
##
##   FS_LEVEL=res://scenes/world/environment/old_town_enhanced.tscn \
##     godot --headless res://tools/find_spawn.tscn

const RAYS := 12          # horizontal probes per ring
const REACH := 6.0        # how far each probe reaches
const STEP := 2.0         # candidate grid spacing
const EXTENT := 24.0      # search a square this large, centred on the origin

func _ready() -> void:
	var level_path := OS.get_environment("FS_LEVEL")
	if level_path.is_empty():
		level_path = "res://scenes/world/environment/old_town_enhanced.tscn"
	var ps := load(level_path) as PackedScene
	if not ps:
		print("FINDSPAWN: cannot load %s" % level_path)
		get_tree().quit(1)
		return
	var level := ps.instantiate()
	add_child(level)

	# Let collision shapes register before querying.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# get_world_3d() is on Node3D/Viewport - this node is a plain Node, so go via the viewport.
	var space := get_viewport().world_3d.direct_space_state
	var results: Array = []
	var x := -EXTENT
	while x <= EXTENT:
		var z := -EXTENT
		while z <= EXTENT:
			var r := _score(space, Vector3(x, 0, z))
			if r["ok"]:
				results.append({"pos": Vector3(x, r["ground"], z), "clear": r["clear"], "min": r["min"]})
			z += STEP
		x += STEP

	results.sort_custom(func(a, b): return a["min"] > b["min"])
	print("FINDSPAWN: %d usable candidates" % results.size())
	var best := Vector3.ZERO
	for i in range(min(8, results.size())):
		var r: Dictionary = results[i]
		print("FINDSPAWN: candidate %d pos=(%.1f, %.2f, %.1f) clear_rays=%d/24 nearest_obstacle=%.1fm" % [
			i, r["pos"].x, r["pos"].y, r["pos"].z, r["clear"], r["min"]])
		if i == 0:
			best = r["pos"]
	print("FINDSPAWN: BEST=(%.2f, %.2f, %.2f)" % [best.x, best.y, best.z])
	get_tree().quit(0)

## Ground height at this XZ + how much room it has. ok=false if there is no floor or
## the spot is too tight to matter.
func _score(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	# Floor: cast down from 4 m. Old town rooftops are above that, so we get the street.
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 4, 0), at + Vector3(0, -6, 0))
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {"ok": false}
	var ground: float = hit.position.y
	# Ceiling: anything within 2.4 m above the floor means we are inside/under something.
	var up := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, ground + 0.3, at.z), Vector3(at.x, ground + 2.4, at.z))
	if not space.intersect_ray(up).is_empty():
		return {"ok": false}
	# Horizontal clearance from two heights (knees and chest).
	var clear := 0
	var nearest := REACH
	for level_y in [0.5, 1.2]:
		for i in RAYS:
			var ang := TAU * float(i) / float(RAYS)
			var dir := Vector3(cos(ang), 0, sin(ang))
			var h := PhysicsRayQueryParameters3D.create(
				Vector3(at.x, ground + level_y, at.z),
				Vector3(at.x, ground + level_y, at.z) + dir * REACH)
			var rhit := space.intersect_ray(h)
			if rhit.is_empty():
				clear += 1
			else:
				nearest = min(nearest, at.distance_to(rhit.position))
	return {"ok": true, "ground": ground, "clear": clear, "min": nearest}