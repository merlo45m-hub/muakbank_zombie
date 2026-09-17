## SaveManager.gd — Autoload Singleton
## Project > Project Settings > Autoload > add this as "Save"
## Handles progress, high scores, settings, unlocks
## Integrates SaveMadeEasy addon (SaveSystem autoload) for nested-key saves

class_name SaveManager
extends Node

# === SAVE VERSION (for future migrations) ===
const SAVE_VERSION: int = 1

# === SAVE DATA ===
var save_data: Dictionary = {
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
	"tutorial_completed": false,
	"sound_enabled": true,
	"music_enabled": true
}

var save_path: String = "user://savegame.save"
var selected_character: String = "gamer"
var pending_results: Dictionary = {}

# SaveMadeEasy key prefix — all save_data fields stored under "save:" namespace
const SAVE_KEY_PREFIX: String = "save:"

func _ready() -> void:
	_load_game()


# ── SAVE / LOAD (SaveMadeEasy integration) ─────────────────────

func _get_save_system() -> Node:
	"""Return the SaveSystem autoload from SaveMadeEasy, or null if unavailable."""
	return get_node_or_null("/root/SaveSystem")

func _load_game() -> void:
	"""Load game data via SaveMadeEasy's _load + get_var, with JSON fallback."""
	var save_system := _get_save_system()
	if save_system == null:
		push_warning("[SaveManager] SaveSystem autoload not found — using defaults")
		save_data = _default_save_data()
		_save_game_fallback()
		return

	# Load the encrypted/nested save file through SaveMadeEasy
	save_system._load(save_path)

	# Pull values out of SaveSystem's current_state_dictionary into save_data
	var defaults := _get_defaults()
	for key in defaults:
		var value = save_system.get_var(SAVE_KEY_PREFIX + key, defaults[key])
		# Type-safety: ensure ints stay ints, bools stay bools
		if key == "high_score" or key == "total_zombies_fed" or key == "total_shifts_completed" or key == "total_likes_earned" or key == "current_level" or key == "difficulty":
			value = int(value) if value != null else defaults[key]
		elif key == "tutorial_completed" or key == "sound_enabled" or key == "music_enabled":
			value = bool(value) if value != null else defaults[key]
		save_data[key] = value
	save_data["version"] = SAVE_VERSION

func save_game() -> void:
	"""Write save_data to disk via SaveMadeEasy's set_var + save."""
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
	"""Fallback: manual JSON save when SaveSystem is unavailable."""
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[SaveManager] Game saved (fallback JSON)")
	else:
		push_warning("[SaveManager] Failed to save game: %s" % FileAccess.get_open_error())

func reset_progress() -> void:
	"""Reset all progress to defaults."""
	save_data = _default_save_data()
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
		"difficulty": 0,
		"tutorial_completed": false,
		"sound_enabled": true,
		"music_enabled": true
	}

func _get_defaults() -> Dictionary:
	return {
		"high_score": 0,
		"total_zombies_fed": 0,
		"total_shifts_completed": 0,
		"total_likes_earned": 0,
		"unlocked_foods": ["burger", "noodles", "soda", "donut", "pizza", "taco"],
		"unlocked_levels": [1],
	"unlocked_achievements": [],
		"current_level": 1,
		"difficulty": 0,
		"tutorial_completed": false,
		"sound_enabled": true,
		"music_enabled": true
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

func is_sound_enabled() -> bool:
	return save_data["sound_enabled"]

func is_music_enabled() -> bool:
	return save_data["music_enabled"]


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

func set_sound_enabled(enabled: bool) -> void:
	save_data["sound_enabled"] = enabled
	save_game()

func set_music_enabled(enabled: bool) -> void:
	save_data["music_enabled"] = enabled
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
	if save_data.has("unlocked_achievements"):
		return save_data["unlocked_achievements"]
	return []
