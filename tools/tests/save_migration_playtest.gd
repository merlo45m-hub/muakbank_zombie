## Save migration roundtrip test (C1-C4 defaults + version bump).
## Writes a v5-shaped payload via SaveSystem, loads through SaveManager._load_game(),
## asserts every C1-C4 default key is backfilled to documented defaults and version==6.
extends SceneTree

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	print("=== Save Migration Roundtrip (v5 -> v6) ===")

	var save_system = get_node_or_null("/root/SaveSystem")
	if save_system == null:
		printerr("SaveSystem autoload not found")
		quit(1)

	# Clean slate
	if FileAccess.file_exists("user://savegame.save"):
		save_system.delete_all()

	# --- v5-shaped payload (pre-GDD C1-C4 keys absent) ---
	var v5_payload: Dictionary = {
		"game_version": 5,
		"game_high_score": 1250,
		"game_total_zombies_fed": 42,
		"game_total_shifts_completed": 7,
		"game_total_likes_earned": 100,
		"game_unlocked_foods": ["burger", "noodles", "soda"],
		"game_unlocked_levels": [1, 2],
		"game_unlocked_achievements": ["first_kill", "combo_5"],
		"game_current_level": 2,
		"game_difficulty": 1,
		"game_selected_character": "gamer",
		"game_selected_skin": 1,
		"game_selected_skins": {"gamer": 1, "doctor": 0, "nurse": 0, "streamer": 0, "hunter": 0},
		"game_tutorial_completed": true,
		"game_haptics_enabled": false,
		"game_collection_items": {"scrap": 99},
		"game_collection_regions": {1: 5},
		# C1-C4 keys intentionally OMITTED (these are the new defaults we assert get backfilled):
		# dismantled_props, bestiary, museum_seen, museum_version,
		# world_current_region, world_unlocked_regions, world_tech,
		# world_transport_repaired, world_milestones, world_max_loot_tier,
		# world_visited_regions, world_region_state, post_cure,
		# world_bosses_defeated, cure_synthesized_at
	}

	# Write via SaveSystem (same API SaveManager uses)
	for key in v5_payload:
		save_system.set_var(key, v5_payload[key])
	save_system.save("user://savegame.save")
	print("[save_migration] Wrote v5 payload via SaveSystem")

	# --- Now instantiate SaveManager and trigger load (migration runs inside _load_game) ---
	# NB: SaveManager.gd declares no class_name (it is the "Save" autoload by path);
	# resolve it via load() — the --script-scope pitfall from the harness docs.
	var save_manager: Node = load("res://scripts/core/SaveManager.gd").new()
	save_manager.name = "Save"
	root.add_child(save_manager)
	# _ready() calls _load_game() which migrates v5 -> v6

	# Give it a frame to complete the async load
	await process_frame
	await process_frame

	# --- Assertions ---
	var sd: Dictionary = save_manager.save_data
	var ok: bool = true

	# Version bumped to 6
	if sd.get("version") != 6:
		printerr("FAIL: version not migrated to 6, got ", sd.get("version"))
		ok = false
	else:
		print("  PASS: version == 6")

	# C1-C4 default keys backfilled to _default_save_data() values
	var defaults: Dictionary = save_manager._default_save_data()
	for key in defaults:
		if key == "version":
			continue
		var expected = defaults[key]
		var actual = sd.get(key)
		if actual != expected:
			printerr("FAIL: key '", key, "' expected ", expected, " got ", actual)
			ok = false
		else:
			print("  PASS: ", key, " backfilled to default")

	# Original v5 values preserved where they existed
	if sd.get("high_score") != 1250:
		printerr("FAIL: high_score not preserved")
		ok = false
	else:
		print("  PASS: high_score preserved")

	if sd.get("selected_character") != "gamer":
		printerr("FAIL: selected_character not preserved")
		ok = false
	else:
		print("  PASS: selected_character preserved")

	if sd.get("world_current_region") != 1:
		printerr("FAIL: world_current_region default not applied")
		ok = false
	else:
		print("  PASS: world_current_region default applied")

	if sd.get("post_cure") != false:
		printerr("FAIL: post_cure default not applied")
		ok = false
	else:
		print("  PASS: post_cure default applied")

	if not sd.get("world_bosses_defeated", {}).has(1):
		printerr("FAIL: world_bosses_defeated default not applied")
		ok = false
	else:
		print("  PASS: world_bosses_defeated default applied")

	save_manager.queue_free()

	if ok:
		print("MIGRATION_ROUNDTRIP_PASS=true")
		quit(0)
	else:
		printerr("MIGRATION_ROUNDTRIP_FAIL")
		quit(1)