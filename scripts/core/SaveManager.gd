## SaveManager.gd — Autoload Singleton
## Project > Project Settings > Autoload > add this as "Save"
## Handles progress, high scores, unlocks
## Integrates SaveMadeEasy addon (SaveSystem autoload) for nested-key saves

extends Node

# === SAVE VERSION (bump to trigger a re-save / migration on load) ===
const SAVE_VERSION: int = 1

# === SAVE DATA ===
# Filled by _load_game() at startup. _default_save_data() is the single source of
# defaults: any key the file lacks (a new key, or an older save) falls back to it.
var save_data: Dictionary = {}

var save_path: String = "user://savegame.save"
var selected_character: String = "doctor"   # real geometry (1146 verts); "gamer" is a 64-vert blockout
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

	var defaults := _default_save_data()
	# Fallback 0, not SAVE_VERSION: a pre-versioning file lacks the key and must read
	# as older so the migration below runs. Defaulting to SAVE_VERSION would mask it.
	var old_version: int = int(save_system.get_var(SAVE_KEY_PREFIX + "version", 0))
	for key in defaults:
		if key == "version":
			continue
		var value = save_system.get_var(SAVE_KEY_PREFIX + key, defaults[key])
		save_data[key] = _coerce(key, value, defaults[key])
	save_data["version"] = maxi(old_version, SAVE_VERSION)
	# Player._apply_character_model() reads the member var; save_data is what reaches
	# disk. Without this line they drift and a character choice survives exactly one run.
	selected_character = String(save_data.get("selected_character", selected_character))

	# A file written by an older build is rewritten in the current shape so the
	# defaults we just backfilled reach disk instead of being re-derived every launch.
	if old_version < SAVE_VERSION:
		print("[SaveManager] Migrating save v%d -> v%d" % [old_version, SAVE_VERSION])
		save_game()

func _coerce(key: String, value, fallback):
	"""Keep stored types stable across a JSON round-trip (a save file is JSON)."""
	if value == null:
		return fallback
	match key:
		"high_score", "total_zombies_fed", "total_shifts_completed", "total_likes_earned", "current_level", "difficulty":
			return int(value)
		"tutorial_completed", "haptics_enabled":
			return bool(value)
		"unlocked_levels":
			# JSON stores ints as floats; level ids must compare as ints
			# (is_level_unlocked uses has(level) against ints).
			var levels: Array[int] = []
			levels.assign(value)
			return levels
		_:
			return value

func save_game() -> void:
	"""Write save_data to disk via SaveMadeEasy's set_var + save."""
	# Copy the member var into the dictionary first, so the fallback path persists it too.
	save_data["selected_character"] = selected_character
	var save_system := _get_save_system()
	if save_system == null:
		_save_game_fallback()
		return

	# Push every save_data field into SaveMadeEasy's nested dictionary
	for key in save_data:
		save_system.set_var(SAVE_KEY_PREFIX + key, save_data[key])

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
	"""Reset all progress to defaults, including the selected-character member var."""
	save_data = _default_save_data()
	# save_game() copies the member var back into save_data, so it must be reset too
	# or the pre-reset character silently survives.
	selected_character = save_data["selected_character"]
	save_game()

func _default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"high_score": 0,
		"total_zombies_fed": 0,
		"total_shifts_completed": 0,
		"total_likes_earned": 0,
		"unlocked_foods": ["burger", "noodles", "soda", "donut", "pizza", "taco"],
		"unlocked_levels": [1],
		"unlocked_achievements": [],
		"current_level": 1,
		"difficulty": 0,  # 0=normal, 1=hard, 2=insane
		"selected_character": "doctor",  # drives which GLB Player._apply_character_model loads
		"tutorial_completed": false,
		"haptics_enabled": true
	}


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
