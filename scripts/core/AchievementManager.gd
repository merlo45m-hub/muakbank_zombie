extends Node
class_name AchievementManager

## AchievementManager — Achievement tracking with persistence
## Autoload or attach to root. Tracks and unlocks achievements.

signal achievement_unlocked(achievement_id)

var achievements: Dictionary = {}  # id -> {title, desc, unlocked}

func _ready() -> void:
	_load_progress()

func register_achievement(id: String, title: String, desc: String) -> void:
	achievements[id] = {
		"title": title,
		"desc": desc,
		"unlocked": false
	}

func unlock(id: String) -> void:
	if not achievements.has(id) or achievements[id].unlocked:
		return
	achievements[id].unlocked = true
	achievement_unlocked.emit(id)
	_save_progress()
	print("[Achievement] Unlocked: ", achievements[id].title)

func is_unlocked(id: String) -> bool:
	return achievements.has(id) and achievements[id].unlocked

func get_unlocked_count() -> int:
	var count = 0
	for a in achievements.values():
		if a.unlocked:
			count += 1
	return count

func get_total_count() -> int:
	return achievements.size()

# === PERSISTENCE ===

func _save_progress() -> void:
	"""Save unlocked achievement ids via the Save singleton."""
	var unlocked_ids: Array = []
	for id in achievements:
		if achievements[id].unlocked:
			unlocked_ids.append(id)
	if Save and Save.has_method("set_unlocked_achievements"):
		Save.set_unlocked_achievements(unlocked_ids)

func _load_progress() -> void:
	"""Load unlocked achievement ids from the Save singleton."""
	if not Save or not Save.has_method("get_unlocked_achievements"):
		return
	var unlocked_ids: Array = Save.get_unlocked_achievements()
	for id in unlocked_ids:
		if achievements.has(id):
			achievements[id].unlocked = true
