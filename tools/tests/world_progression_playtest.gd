extends SceneTree
## Reusable Issue #11 full-progression regression test (1->2->3).
## Run: xvfb-run -a $GODOT --headless --path . --script tools/tests/world_progression_playtest.gd
## Expect FULL_PROGRESSION_PASS=true, exit 0. Boots the real game.tscn so
## autoloads/player/spawners resolve. NOT wired into run_tests.gd (which is a
## fixed-schedule smoke suite); this is the world-hopping acceptance gate.
## Issue #11 FINAL — full 1->2->3 progression playtest (headless engine).
## Drives the real gate chain and the threaded hop between each region.

var _completed: Array[int] = []
var _failed: Array[String] = []

func _initialize() -> void:
	for _i in range(4):
		await process_frame
	var wp := get_root().get_node_or_null("WorldProgression")
	var hop := get_root().get_node_or_null("WorldHopManager")
	if wp == null or hop == null:
		print("NO_AUTOLOADS"); quit(1); return
	wp.hop_completed.connect(func(r: int): _completed.append(r))
	wp.hop_failed.connect(func(r: StringName): _failed.append(String(r)))

	# Boot the real game scene so player/spawners exist for relocation.
	var game := (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	for _i in range(6):
		await process_frame
	wp.hydrate({"world_current_region": 1, "world_unlocked_regions": [1],
		"world_tech": {}, "world_transport_repaired": {}, "world_milestones": {},
		"world_max_loot_tier": 1})
	print("START region=", wp.current_region, " cap=", wp.get_loot_tier_cap())

	# --- Region 2 gates: 3 tech + transport + 2 milestones in region 1 ---
	for i in range(3): wp.report_tech(1, &"circuit")
	wp.report_transport_repaired(1)
	wp.report_milestone(1, &"first_shift")
	wp.report_milestone(1, &"boss_defeated")
	print("AFTER_GATES_2 unlocked=", wp.unlocked_regions, " can_hop2=", wp.can_hop(2))

	# --- Hop 1 -> 2 (threaded) ---
	hop.request_hop(2)
	var f := 0
	while hop.is_busy() and f < 600:
		await process_frame
		f += 1
	print("HOP2 done=", wp.current_region == 2, " completed=", _completed,
		" failed=", _failed, " cap=", wp.get_loot_tier_cap())

	# --- Region 3 gates: 5 tech + transport + 2 milestones in region 2 ---
	for i in range(5): wp.report_tech(2, &"circuit")
	wp.report_transport_repaired(2)
	wp.report_milestone(2, &"survivors_saved")
	wp.report_milestone(2, &"extraction_ready")
	print("AFTER_GATES_3 unlocked=", wp.unlocked_regions, " can_hop3=", wp.can_hop(3))

	# --- Hop 2 -> 3 (threaded) ---
	hop.request_hop(3)
	var f2 := 0
	while hop.is_busy() and f2 < 600:
		await process_frame
		f2 += 1
	print("HOP3 done=", wp.current_region == 3, " completed=", _completed,
		" failed=", _failed, " cap=", wp.get_loot_tier_cap())

	# Final consistency.
	var root: Node = get_first_node_in_group("world_root")
	print("FINAL region=", wp.current_region, " unlocked=", wp.unlocked_regions,
		" cap=", wp.get_loot_tier_cap(), " hops=", _completed,
		" region_instances=", root.get_child_count() if root != null else -1)
	var save := get_root().get_node_or_null("Save")
	if save != null and save.has_method("get_world_state"):
		var ws: Dictionary = save.get_world_state()
		print("SAVE current_region=", ws.get("world_current_region", -1),
			" unlocked_regions=", ws.get("world_unlocked_regions", []),
			" max_loot_tier=", ws.get("world_max_loot_tier", -1))
	var ok: bool = wp.current_region == 3 and _completed == [2, 3] \
		and _failed.is_empty() and wp.get_loot_tier_cap() == 3
	print("FULL_PROGRESSION_PASS=", ok)
	quit(0 if ok else 1)
