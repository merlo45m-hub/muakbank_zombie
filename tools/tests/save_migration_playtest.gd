## Save migration roundtrip test (C1-C4 defaults + version bump).
## Writes a v5-shaped payload via SaveSystem, loads through a fresh SaveManager
## instance (whose _ready -> _load_game() runs the migration), asserts:
##  - version == 6
##  - every C1-C4 key ABSENT from the v5 payload is backfilled to _default_save_data()
##  - v5 keys that were present keep their stored values (not overwritten by defaults)
extends SceneTree

const SAVE_PATH := "user://savegame.save"
const KEY_PREFIX := "game_"

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	print("=== Save Migration Roundtrip (v5 -> v6) ===")

	var save_system: Node = root.get_node_or_null("SaveSystem")
	if save_system == null:
		printerr("SaveSystem autoload not found")
		quit(1)

	# Clean slate (delete_all is the same API SaveManager._load_game uses)
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
		# C1-C4 keys intentionally OMITTED (these must be backfilled from defaults):
		# dismantled_props, bestiary, museum_seen, museum_version,
		# world_current_region, world_unlocked_regions, world_tech,
		# world_transport_repaired, world_milestones, world_max_loot_tier,
		# world_visited_regions, world_region_state, post_cure,
		# world_bosses_defeated, cure_synthesized_at
	}

	# Write via SaveSystem exactly as SaveManager._store does, then flush to the
	# same path SaveManager reads (save_path default in scripts/core/SaveManager.gd).
	for key in v5_payload:
		save_system.set_var(key, v5_payload[key])
	save_system.save(SAVE_PATH)
	print("[save_migration] Wrote v5 payload via SaveSystem to " + SAVE_PATH)

	# --- Instantiate the SaveManager script fresh; _ready() -> _load_game() migrates ---
	# NB: SaveManager.gd declares no class_name (it is the "Save" autoload by path);
	# resolve via load(). Name the probe distinctly so it does not collide with the
	# live "Save" autoload sibling under /root.
	var save_manager: Node = load("res://scripts/core/SaveManager.gd").new()
	save_manager.name = "SaveMigrationProbe"
	root.add_child(save_manager)

	# _ready runs synchronously on add_child; extra frames flush any deferred IO.
	await process_frame
	await process_frame

	# --- Assertions ---
	var ok: bool = true
	var sd: Dictionary = save_manager.save_data

	if int(sd.get("version", 0)) != 6:
		printerr("FAIL: version not migrated to 6, got ", sd.get("version"))
		ok = false
	else:
		print("  PASS: version == 6")

	# Keys the v5 payload already defined must PRESERVE stored values; keys it
	# omitted (the C1-C4 additions) must be BACKFILLED from _default_save_data().
	var present: Dictionary = {}
	for key in v5_payload:
		present[str(key).trim_prefix(KEY_PREFIX)] = true

	var defaults: Dictionary = save_manager._default_save_data()
	var checked_backfill: int = 0
	for key in defaults:
		if key == "version":
			continue
		var expected = defaults[key]
		var actual = sd.get(key)
		if present.has(key):
			var stored = v5_payload[KEY_PREFIX + key]
			if _canonicalize(actual) != _canonicalize(stored):
				printerr("FAIL: key '", key, "' overwritten or mangled by round-trip; expected ", stored, " (", type_string(typeof(stored)), ") got ", actual, " (", type_string(typeof(actual)), ")")
				ok = false
			continue
		if actual != expected:
			printerr("FAIL: backfill key '", key, "' expected ", expected, " got ", actual)
			ok = false
		else:
			checked_backfill += 1

	print("  backfill keys verified: ", checked_backfill)
	if checked_backfill < 10:
		printerr("FAIL: too few C1-C4 backfill keys exercised (expected >= 10)")
		ok = false

	# Explicit spot-checks (redundant with the loop, kept for readable failure output)
	if sd.get("high_score") != 1250:
		printerr("FAIL: high_score not preserved"); ok = false
	if sd.get("selected_character") != "gamer":
		printerr("FAIL: selected_character not preserved"); ok = false
	if int(sd.get("world_current_region", 0)) != 1:
		printerr("FAIL: world_current_region default not applied"); ok = false
	if bool(sd.get("post_cure", true)):
		printerr("FAIL: post_cure default not applied"); ok = false
	if not (sd.get("world_bosses_defeated") as Dictionary).has(1):
		printerr("FAIL: world_bosses_defeated default not applied"); ok = false

	# HARD asserts: no canonicalization — int keys/values must survive JSON round-trip
	if sd.get("collection_regions") is Dictionary:
		var regions: Dictionary = sd["collection_regions"] as Dictionary
		if not regions.has(1):
			printerr("FAIL: collection_regions missing int key 1"); ok = false
		elif typeof(regions[1]) != TYPE_INT:
			printerr("FAIL: collection_regions[1] is not int"); ok = false
	else:
		printerr("FAIL: collection_regions not a Dictionary"); ok = false

	if sd.get("selected_skins") is Dictionary:
		var skins: Dictionary = sd["selected_skins"] as Dictionary
		if not skins.has("gamer"):
			printerr("FAIL: selected_skins missing 'gamer'"); ok = false
		elif typeof(skins["gamer"]) != TYPE_INT or skins["gamer"] != 1:
			printerr("FAIL: selected_skins['gamer'] is not int 1"); ok = false
	else:
		printerr("FAIL: selected_skins not a Dictionary"); ok = false

	if sd.get("world_bosses_defeated") is Dictionary:
		var bosses: Dictionary = sd["world_bosses_defeated"] as Dictionary
		if not bosses.has(1):
			printerr("FAIL: world_bosses_defeated missing int key 1"); ok = false
	else:
		printerr("FAIL: world_bosses_defeated not a Dictionary"); ok = false

	save_manager.queue_free()

	if ok:
		print("MIGRATION_ROUNDTRIP_PASS=true")
		quit(0)
	else:
		printerr("MIGRATION_ROUNDTRIP_FAIL")
		quit(1)


func _canonicalize(v: Variant) -> Variant:
	# JSON-equivalent comparison: JSON files carry floats and string object
	# keys, so a stored Dictionary[int, Variant] legitimately comes back as
	# Dictionary[String, float]. Canonicalize BOTH sides before comparing;
	# semantic loss (a key/value actually changed) still fails the check.
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				var nk = k
				if typeof(nk) == TYPE_STRING and String(nk).is_valid_int():
					nk = int(nk)
				out[str(nk)] = _canonicalize(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(_canonicalize(x))
			return arr
		TYPE_FLOAT:
			if floorf(v) == v:
				return int(v)
			return v
		_:
			return v
