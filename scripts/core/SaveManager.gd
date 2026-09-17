## SaveManager.gd — Autoload Singleton
## Project > Project Settings > Autoload > add this as "Save"
## Handles progress, high scores, settings, unlocks

class_name SaveManager
extends Node

# === SAVE DATA ===
var save_data = {
    "high_score": 0,
    "total_zombies_fed": 0,
    "total_shifts_completed": 0,
    "total_likes_earned": 0,
    "unlocked_foods": ["burger", "noodles", "soda", "donut", "pizza", "taco"],
    "unlocked_levels": [1],
    "current_level": 1,
    "difficulty": 0,  # 0=normal, 1=hard, 2=insane
    "tutorial_completed": false,
    "sound_enabled": true,
    "music_enabled": true
}

var save_path = "user://savegame.save"
var selected_character: String = "gamer"
var pending_results: Dictionary = {}


func _ready():
    load_game()


# ── SAVE / LOAD ───────────────────────────────────────────────

func save_game():
    """Write save data to disk."""
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()
        print("[SaveManager] Game saved")
    else:
        push_warning("[SaveManager] Failed to save game: %s" % FileAccess.get_open_error())

func load_game():
    """Load save data from disk."""
    if not FileAccess.file_exists(save_path):
        save_game()  # Create default save
        return

    var file = FileAccess.open(save_path, FileAccess.READ)
    if file:
        var text = file.get_as_text()
        file.close()
        var json = JSON.new()
        var result = json.parse(text)
        if result == OK:
            var loaded = json.data
            # Merge with defaults (in case new fields added)
            for key in save_data:
                if loaded.has(key):
                    save_data[key] = loaded[key]
            print("[SaveManager] Game loaded")
        else:
            push_warning("[SaveManager] Failed to parse save: %s" % json.get_error_message())
    else:
        push_warning("[SaveManager] Failed to load save: %s" % FileAccess.get_open_error())


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

func is_food_unlocked(food_name) -> bool:
    return save_data["unlocked_foods"].has(food_name)

func is_level_unlocked(level) -> bool:
    return save_data["unlocked_levels"].has(level)

func is_tutorial_completed() -> bool:
    return save_data["tutorial_completed"]


# ── SETTERS ───────────────────────────────────────────────────

func update_high_score(score):
    if score > save_data["high_score"]:
        save_data["high_score"] = score
        save_game()

func add_zombies_fed(count):
    save_data["total_zombies_fed"] += count
    save_game()

func add_shifts_completed(count = 1):
    save_data["total_shifts_completed"] += count
    save_game()

func add_likes_earned(count):
    save_data["total_likes_earned"] += count
    save_game()

func set_current_level(level):
    save_data["current_level"] = level
    save_game()

func set_difficulty(diff):
    save_data["difficulty"] = diff
    save_game()

func unlock_food(food_name):
    if not save_data["unlocked_foods"].has(food_name):
        save_data["unlocked_foods"].append(food_name)
        save_game()

func unlock_level(level):
    if not save_data["unlocked_levels"].has(level):
        save_data["unlocked_levels"].append(level)
        save_game()

func complete_tutorial():
    save_data["tutorial_completed"] = true
    save_game()

func reset_progress():
    save_data = {
        "high_score": 0,
        "total_zombies_fed": 0,
        "total_shifts_completed": 0,
        "total_likes_earned": 0,
        "unlocked_foods": ["burger", "noodles", "soda", "donut", "pizza", "taco"],
        "unlocked_levels": [1],
        "current_level": 1,
        "difficulty": 0,
        "tutorial_completed": false,
        "sound_enabled": true,
        "music_enabled": true
    }
    save_game()
