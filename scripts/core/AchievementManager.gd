extends Node
class_name AchievementManager

## AchievementManager — Achievement tracking
## Autoload or attach to root. Tracks and unlocks achievements.

signal achievement_unlocked(achievement_id)

var achievements: Dictionary = {}  # id -> {title, desc, unlocked}

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
