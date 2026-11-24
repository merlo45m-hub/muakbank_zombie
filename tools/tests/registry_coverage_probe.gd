extends SceneTree
## GDD §7 registry coverage: 5 survivors, 5 zombie animals, core props.
## Proves registration at real sinks (CharacterRegistry, CollectionManager,
## Bestiary, CollectionLog, Save) on a clean user-data home.

var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _initialize() -> void:
	for _i in range(4):
		await process_frame
	print("=== GDD registry coverage probe ===")

	var cm: Node = root.get_node_or_null("CollectionManager")
	var save: Node = root.get_node_or_null("Save")
	var blog: Node = root.get_node_or_null("Bestiary")
	var clog: Node = root.get_node_or_null("CollectionLog")
	_assert(cm != null and save != null and blog != null and clog != null, "real registry autoloads present")

	# --- 1. Five survivors in the reproducible character registry -----------
	var reg_script: GDScript = load("res://scripts/core/rules/CharacterRegistry.gd") as GDScript
	var path: String = "res://assets/data/rules/characters.json"
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	_assert(reg_script != null and parsed is Dictionary, "CharacterRegistry and characters.json load")

	var reg: Object = reg_script.new()
	var cfg: Dictionary = parsed as Dictionary
	reg.call("load_from_config", cfg)
	var chars: Array = reg.call("get_all_characters")
	var ids: Array[String] = []
	for c in chars:
		if c is Dictionary:
			ids.append(String((c as Dictionary).get("id", "")))
	var want_survivors: Array[String] = ["gamer", "doctor", "nurse", "streamer", "hunter"]
	var survivors_ok: bool = ids.size() == 5
	for wanted in want_survivors:
		if not ids.has(wanted) or not bool(reg.call("has_character", wanted)):
			survivors_ok = false
		var rec: Dictionary = reg.call("get_character", wanted) as Dictionary
		var scene_path: String = String(rec.get("scene", ""))
		if not ResourceLoader.exists(scene_path):
			survivors_ok = false
		var stats: Variant = rec.get("base_stats", {})
		if not stats is Dictionary:
			survivors_ok = false
		else:
			for stat_key in ["health", "speed", "damage"]:
				if not (stats as Dictionary).has(stat_key):
					survivors_ok = false
	_assert(survivors_ok, "5 survivors registered with resolvable scenes and stats (%s)" % str(ids))

	# --- 2. Five zombie animals recorded through the sole writer ------------
	# Derive animal ids from the production spawner table, not a hardcoded list.
	var animals: Array[String] = []
	var spawner_src: String = FileAccess.get_file_as_string("res://scripts/characters/ZombieSpawner3D.gd")
	var animal_re: RegEx = RegEx.new()
	animal_re.compile("zombie_[a-z]+_scene.*\\[\"([a-z_]+)\\"\\]")
	for match in animal_re.search_all(spawner_src):
		animals.append(match.get_string(1))
	_assert(animals.size() == 5, "5 animal ids derived from ZombieSpawner3D table (%s)" % str(animals))
	var animal_before: Dictionary = cm.call("get_bestiary") as Dictionary
	for animal in animals:
		cm.call("record_defeat", animal)
	var animal_after: Dictionary = cm.call("get_bestiary") as Dictionary
	var animals_ok: bool = true
	for animal in animals:
		if not animal_after.has(animal) or int(blog.call("kills", animal)) < int(animal_before.get(animal, {}).get("kills", 0)) + 1:
			animals_ok = false
	_assert(animals_ok, "5 zombie animals reached record_defeat and Bestiary facade")

	# --- 3. Core props recorded through the sole writer ---------------------
	var table_path: String = "res://assets/data/dismantle_tables.json"
	var table_text: String = FileAccess.get_file_as_string(table_path)
	var table_parsed: Variant = JSON.parse_string(table_text)
	_assert(table_parsed is Dictionary, "dismantle_tables.json loads")
	var tables: Dictionary = ((table_parsed as Dictionary).get("tables", {})) as Dictionary
	var props_before: Dictionary = cm.call("get_dismantled_props") as Dictionary
	var core_ids: Array[String] = []
	for table_id in tables.keys():
		var entry: Variant = tables.get(table_id)
		if entry is Dictionary:
			core_ids.append(String((entry as Dictionary).get("asset_id", "")))
			cm.call("record_dismantle", String((entry as Dictionary).get("asset_id", "")), int((entry as Dictionary).get("tier", 1)))
	var props_after: Dictionary = cm.call("get_dismantled_props") as Dictionary
	var union: Dictionary = clog.call("union") as Dictionary
	var props_ok: bool = core_ids.size() == 6
	for core_id in core_ids:
		if not props_after.has(core_id) or not union.has(core_id):
			props_ok = false
		var before_entry: Variant = props_before.get(core_id, {})
		var after_entry: Variant = props_after.get(core_id, {})
		if int((after_entry as Dictionary).get("qty", 0)) != int((before_entry as Dictionary).get("qty", 0)) + 1:
			props_ok = false
	_assert(props_ok, "6 core props reached record_dismantle and CollectionLog union (%d ids)" % core_ids.size())

	# --- 4. Sole-writer invariant and persistence ---------------------------
	var writer_methods: Array[String] = ["record_item", "record_defeat", "record_dismantle", "set_registry", "save_game"]
	var facades_readonly: bool = true
	for method_name in writer_methods:
		if clog.has_method(method_name) or blog.has_method(method_name):
			facades_readonly = false
	_assert(facades_readonly, "read-only facades expose no registry writer or save method")

	# --- 5. Emitter source contracts (registry APIs have real gameplay callers) ---
	var game_src: String = FileAccess.get_file_as_string("res://scripts/core/Game.gd")
	var dc_src: String = FileAccess.get_file_as_string("res://scripts/gameplay/DismantleComponent.gd")
	var select_src: String = FileAccess.get_file_as_string("res://scripts/ui/CharacterSelect.gd")
	_assert(game_src.contains("cm.call(\"record_defeat\", zombie_type)"), "production kill emitter calls record_defeat")
	_assert(dc_src.contains("cm.call(\"record_dismantle\", prop_asset_id, required_tool_tier)") and dc_src.contains("cm.call(\"record_item\", String(item_id), int(loot_counts[item_id]))"), "production dismantle emitters call sole-writer APIs")
	var ui_has_all: bool = true
	for wanted in want_survivors:
		if not select_src.contains("\"" + wanted + "\""):
			ui_has_all = false
	_assert(ui_has_all, "character select exposes the same five survivor ids")
	var saved_props: Variant = save.call("get_registry", "dismantled_props")
	var saved_best: Variant = save.call("get_registry", "bestiary")
	var persisted: bool = saved_props is Dictionary and saved_best is Dictionary
	for core_id in core_ids:
		if persisted and not (saved_props as Dictionary).has(core_id):
			persisted = false
	for animal in animals:
		if persisted and not (saved_best as Dictionary).has(animal):
			persisted = false
	_assert(persisted, "registry coverage present in Save registry state after sole-writer calls")

	if _failures == 0:
		print("REGISTRY_COVERAGE_PASS=true survivors=5 animals=5 props=%d" % core_ids.size())
		quit(0)
	else:
		printerr("REGISTRY_COVERAGE_FAIL=%d" % _failures)
		quit(1)
