## SaveManager.gd — Autoload Singleton
## Project > Project Settings > Autoload > add this as "Save"
## Handles progress, high scores, unlocks
## Integrates SaveMadeEasy addon (SaveSystem autoload) for nested-key saves

extends Node

# === SAVE VERSION (bump to trigger a re-save / migration on load) ===
const SAVE_VERSION: int = 7

# === SAVE DATA ===
# Filled by _load_game() at startup. _default_save_data() is the single source of
# defaults: any key the file lacks (a new key, or an older save) falls back to it.
var save_data: Dictionary = {}

var save_path: String = "user://savegame.save"
var selected_character: String = "nurse"   # default survivor per character select overhaul
var selected_skin: int = 0
var selected_skins: Dictionary = {}
var pending_results: Dictionary = {}

# SaveMadeEasy key prefix — all save_data fields stored under "game_" namespace
const SAVE_KEY_PREFIX: String = "game_"

func _ready() -> void:
	save_data = _default_save_data()
	_load_game()


# ── SAVE / LOAD (SaveMadeEasy integration) ─────────────────────

func _get_save_system() -> Node:
	"""Return the SaveSystem autoload from SaveMadeEasy, or null if unavailable."""
	return get_node_or_null("/root/SaveSystem")

func _load_game() -> void:
	"""Load game data via SaveMadeEasy's _load + get_var, with JSON fallback."""
	var save_system := _get_save_system()
	if save_system == null:
		# Read-only defaults — never write here. A missing addon must not clobber
		# whatever real save file already exists on disk.
		push_warning("[SaveManager] SaveSystem autoload not found — using in-memory defaults")
		return

	# _load() is a no-op on a missing file and does not clear prior state, which would
	# resurrect whatever SaveMadeEasy last held (it auto-saves on exit). Start clean.
	if not FileAccess.file_exists(save_path):
		save_system.delete_all()
	save_system._load(save_path)

	var raw: Dictionary = {}
	var defaults := _default_save_data()
	var old_version: int = int(save_system.get_var(SAVE_KEY_PREFIX + "version", 0))
	for key in defaults:
		if key == "version":
			continue
		raw[key] = save_system.get_var(SAVE_KEY_PREFIX + key, defaults[key])
	raw["version"] = maxi(old_version, SAVE_VERSION)

	# All conversion happens in SaveSchema; game state sees only typed data.
	save_data = SaveSchema.deserialize(raw)

	# Player._apply_character_model() reads the member var; save_data is what reaches
	# disk. Without this line they drift and a character choice survives exactly one run.
	selected_character = String(save_data.get("selected_character", selected_character))
	selected_skin = int(save_data.get("selected_skin", 0))
	var loaded_skins = save_data.get("selected_skins", {})
	if loaded_skins is Dictionary:
		selected_skins = loaded_skins.duplicate()
	else:
		selected_skins = defaults["selected_skins"].duplicate()

	# A file written by an older build is rewritten in the current shape so the
	# defaults we just backfilled reach disk instead of being re-derived every launch.
	if old_version < SAVE_VERSION:
		print("[SaveManager] Migrating save v%d -> v%d" % [old_version, SAVE_VERSION])
		save_game()

func save_game() -> void:
	"""Write save_data to disk via SaveMadeEasy's set_var + save."""
	# Copy member vars into the dictionary first, so the fallback path persists them too.
	save_data["selected_character"] = selected_character
	save_data["selected_skin"] = selected_skin
	save_data["selected_skins"] = selected_skins

	# Serialize through SaveSchema so on-disk format stays byte-compatible with v6.
	var to_store := SaveSchema.serialize(save_data)

	var save_system := _get_save_system()
	if save_system == null:
		_save_game_fallback()
		return

	# Push every save_data field into SaveMadeEasy's nested dictionary
	for key in to_store:
		save_system.set_var(SAVE_KEY_PREFIX + key, to_store[key])

	save_system.save(save_path)
	print("[SaveManager] Game saved")

func _save_game_fallback() -> void:
	"""Fallback: manual JSON save when SaveSystem is unavailable.
	Keys carry SAVE_KEY_PREFIX so the file stays readable by the normal load path."""
	var out: Dictionary = {}
	for key in save_data:
		out[SAVE_KEY_PREFIX + key] = save_data[key]
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out))
		file.close()
		print("[SaveManager] Game saved (fallback JSON)")
	else:
		push_warning("[SaveManager] Failed to save game: %s" % FileAccess.get_open_error())

func reset_progress() -> void:
	"""Reset all progress to defaults, including selected character and skin."""
	save_data = _default_save_data()
	# save_game() copies member vars back into save_data, so they must be reset too.
	selected_character = save_data["selected_character"]
	selected_skin = save_data.get("selected_skin", 0)
	selected_skins = save_data.get("selected_skins", {}).duplicate()
	save_game()

func _default_save_data() -> Dictionary:
	"""Defaults derived from SaveSchema — single source of truth."""
	return SaveSchema.get_defaults()


# ── GETTERS ───────────────────────────────────────────────────

func get_high_score() -> int:
	return save_data["high_score"]

func get_total_zombies_fed() -> int:
	return save_data["total_zombies_fed"]

func get_total_shifts_completed() -> int:
	return save_data["total_shifts_completed"]

func get_total_likes_earned() -> int:
	return save_data["total_likes_earned"]

func get_current_level() -> int:
	return save_data["current_level"]

func get_difficulty() -> int:
	return save_data["difficulty"]

func is_food_unlocked(food_name: String) -> bool:
	return save_data["unlocked_foods"].has(food_name)

func is_level_unlocked(level: int) -> bool:
	return save_data["unlocked_levels"].has(level)

func is_tutorial_completed() -> bool:
	return save_data["tutorial_completed"]

func is_haptics_enabled() -> bool:
	# Audio autoload may read this before Save has populated its defaults.
	return save_data.get("haptics_enabled", true)

func get_selected_skin(character_id: String = "") -> int:
	var char_id := character_id if not character_id.is_empty() else selected_character
	return int(selected_skins.get(char_id, selected_skin))


# ── SETTERS ───────────────────────────────────────────────────

func update_high_score(score: int) -> void:
	if score > save_data["high_score"]:
		save_data["high_score"] = score
		save_game()

func add_zombies_fed(count: int) -> void:
	save_data["total_zombies_fed"] += count
	save_game()

func add_shifts_completed(count: int = 1) -> void:
	save_data["total_shifts_completed"] += count
	save_game()

func add_likes_earned(count: int) -> void:
	save_data["total_likes_earned"] += count
	save_game()

func set_current_level(level: int) -> void:
	save_data["current_level"] = level
	save_game()

func set_difficulty(diff: int) -> void:
	save_data["difficulty"] = diff
	save_game()

func set_selected_character(character_name: String) -> void:
	selected_character = character_name
	save_data["selected_character"] = character_name
	selected_skin = int(selected_skins.get(character_name, 0))
	save_data["selected_skin"] = selected_skin
	save_game()

func set_selected_skin(variant_index: int, character_id: String = "") -> void:
	var char_id := character_id if not character_id.is_empty() else selected_character
	selected_skin = variant_index
	selected_skins[char_id] = variant_index
	save_data["selected_skin"] = selected_skin
	save_data["selected_skins"] = selected_skins
	save_game()

func set_haptics_enabled(enabled: bool) -> void:
	save_data["haptics_enabled"] = enabled
	save_game()

func unlock_food(food_name: String) -> void:
	if not save_data["unlocked_foods"].has(food_name):
		save_data["unlocked_foods"].append(food_name)
		save_game()

func unlock_level(level: int) -> void:
	if not save_data["unlocked_levels"].has(level):
		save_data["unlocked_levels"].append(level)
		save_game()

func complete_tutorial() -> void:
	save_data["tutorial_completed"] = true
	save_game()

func set_unlocked_achievements(ids: Array) -> void:
	save_data["unlocked_achievements"] = ids
	save_game()

func get_unlocked_achievements() -> Array:
	return save_data.get("unlocked_achievements", [])


# ── WORLD STATE (Issue #11) ───────────────────────────────────

func get_world_state() -> Dictionary:
	"""Read-only snapshot of the world_* save keys for WorldProgression.hydrate()."""
	var out: Dictionary = {}
	var defaults := _default_save_data()
	for key in defaults:
		if key.begins_with("world_"):
			var v = save_data.get(key, defaults[key])
			out[key] = v.duplicate(true) if v is Dictionary or v is Array else v
	return out

func set_world_state(data: Dictionary) -> void:
	"""Single writer for world_* state; persists once via save_game()."""
	var defaults := _default_save_data()
	for key in data:
		if key.begins_with("world_"):
			var field_def := SaveSchema.get_field_def(key)
			if field_def:
				save_data[key] = SaveSchema._deserialize_field(field_def.type, data[key], defaults.get(key))
			else:
				save_data[key] = data[key]
	save_game()

func get_world_transient_snapshots() -> Dictionary:
	"""Return a copy of the per-region transient snapshots (crash-durable hop state)."""
	var d = save_data.get("world_transient_snapshots", {})
	if d is Dictionary:
		return d.duplicate(true)
	return {}

func set_world_transient_snapshots(snapshots: Dictionary) -> void:
	"""Mirror WorldHopManager.transient_by_region into the save field and persist."""
	var defaults := _default_save_data()
	save_data["world_transient_snapshots"] = SaveSchema._deserialize_field(
		SaveSchema.FieldType.TYPE_DICT_INT_KEYS, snapshots, defaults.get("world_transient_snapshots"))
	save_game()

# ── COLLECTION REGISTRY (sole-writer path) ─────────────────────

func get_registry(key: String) -> Variant:
	"""Read one registry key through the save layer (values are coerced on load)."""
	return save_data.get(key, _default_save_data().get(key))

func set_registry(key: String, value: Variant) -> void:
	"""Coerce one registry key against its default; caller persists via save_game().

	CollectionManager (sole writer of collection_*/museum_*/dismantled_props/
	bestiary) writes through this instead of mutating save_data directly.
	"""
	var defaults := _default_save_data()
	if not defaults.has(key):
		push_warning("[SaveManager] set_registry: unknown key %s" % key)
		return
	var field_def := SaveSchema.get_field_def(key)
	if field_def:
		save_data[key] = SaveSchema._deserialize_field(field_def.type, value, defaults.get(key))
	else:
		save_data[key] = value


# ── POST-CURE & WORLD BOSSES (GDD §5, §7 / Issue #28) ────────

func set_post_cure(val: bool) -> void:
	save_data["post_cure"] = val
	if val and str(save_data.get("cure_synthesized_at", "")).is_empty():
		save_data["cure_synthesized_at"] = Time.get_datetime_string_from_system(true)
	save_game()

func is_post_cure() -> bool:
	return bool(save_data.get("post_cure", false))

func set_world_bosses_defeated(data: Dictionary) -> void:
	save_data["world_bosses_defeated"] = data.duplicate(true)
	save_game()

func get_world_bosses_defeated() -> Dictionary:
	var d = save_data.get("world_bosses_defeated", {})
	if d is Dictionary:
		return d.duplicate(true)
	return {1: false, 2: false, 3: false}
