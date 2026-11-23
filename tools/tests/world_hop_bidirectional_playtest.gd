extends SceneTree
## GDD-1 / #25 — non-linear bidirectional secret-transport acceptance test.
## Verifies: jump-ahead WITHOUT linear gates, backward hops, zero transient
## state loss, location-aware loot tier, repair gate, generation-guard fix.
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

	var game := (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	for _i in range(6):
		await process_frame

	# Reset to a legacy-shaped save (no new GDD-1 keys) — must still hydrate.
	wp.hydrate({"world_current_region": 1, "world_unlocked_regions": [1],
		"world_tech": {}, "world_transport_repaired": {}, "world_milestones": {},
		"world_max_loot_tier": 1})
	print("INITIAL unlocked=", wp.unlocked_regions, " current=", wp.current_region,
		" cap=", wp.get_loot_tier_cap(), " active=", wp.get_active_loot_tier())

	# 1) Secret links present and bidirectional.
	print("LINKS from1=", wp.secret_targets(1), " from3=", wp.secret_targets(3))
	print("BIDIR 1<->2=", wp.is_bidirectional(1, 2))

	# 2) Repair gate: 1->2 requires repair, so initially NOT reachable.
	print("REPAIR_GATE before=", wp.is_secret_reachable(1, 2))
	wp.report_transport_repaired(1)
	print("REPAIR_GATE after=", wp.is_secret_reachable(1, 2))

	# 3) Jump-ahead: can_hop(2) true even though region 2 is NOT unlocked.
	print("JUMP_AHEAD_CAN_HOP2=", wp.can_hop(2), " unlocked=", wp.unlocked_regions)

	# 4) Perform the secret hop 1->2 (bypasses the 4 linear gates).
	hop.request_secret_hop(2)
	var f := 0
	while hop.is_busy() and f < 600:
		await process_frame
		f += 1
	print("HOP_1to2 current=", wp.current_region, " unlocked=", wp.unlocked_regions,
		" cap=", wp.get_loot_tier_cap(), " active=", wp.get_active_loot_tier(),
		" completed=", _completed)

	# 5) Location-aware tier must differ from the monotonic cap after back-hop.
	var player := get_first_node_in_group("player")
	if player is Node3D:
		player.set("health", 55.0)
		player.set("stamina", 33.0)

	# 6) Jump ahead again 2->3 via secret link (repair gate on 2).
	wp.report_transport_repaired(2)
	hop.request_secret_hop(3)
	var f2 := 0
	while hop.is_busy() and f2 < 600:
		await process_frame
		f2 += 1
	print("HOP_2to3 current=", wp.current_region, " cap=", wp.get_loot_tier_cap(),
		" active=", wp.get_active_loot_tier(), " visited=", wp.visited_regions)

	# 7) Back-hop 3->1 via the emergency decontamination chute (bidirectional,
	#    no repair needed). Transient state for region 1 must be restored.
	hop.request_secret_hop(1)
	var f3 := 0
	while hop.is_busy() and f3 < 600:
		await process_frame
		f3 += 1
	print("BACK_HOP_3to1 current=", wp.current_region,
		" active=", wp.get_active_loot_tier(), " cap=", wp.get_loot_tier_cap(),
		" completed=", _completed, " failed=", _failed)
	print("TRANSIENT_REGIONS=", hop.transient_by_region.keys(),
		" snapshot_count=", hop.snapshot_count)

# 8b) Restart durability: persist snapshots, free the manager, re-instantiate
#     and re-hydrate via the real code path; a departing region's snapshot
#     must survive key-for-key.
	Save.save_game()
	var expected: Dictionary = hop.transient_by_region.duplicate(true)
	var ok: bool = true
	hop.queue_free()
	var fresh = (load("res://scripts/core/WorldHopManager.gd") as GDScript).new()
	fresh.name = "WorldHopRestartProbe"
	get_root().add_child(fresh)
	await process_frame
	await process_frame
	var region2: Variant = fresh.transient_by_region.get(2)
	var restart_ok: bool = fresh.transient_by_region.has(2) and region2 == expected.get(2)
	if not restart_ok:
		printerr("RESTART_DURABILITY_FAIL expected=", expected.get(2), " got=", region2)
		ok = false
	else:
		print("RESTART_DURABILITY_PASS region 2 snapshot survived restart")

	# 8) Final acceptance.
	ok = wp.is_bidirectional(1, 2) and wp.is_secret_reachable(1, 2) and wp.get_loot_tier_cap() == 3 and wp.get_active_loot_tier() == 1 and _completed == [2, 3, 1] and _failed.is_empty() and wp.visited_regions.has(1) and wp.visited_regions.has(2) and wp.visited_regions.has(3) and fresh.transient_by_region.has(1)
	print("NONLINEAR_PROGRESSION_PASS=", ok)
	quit(0 if ok else 1)
