extends Node
class_name AchievementManager

## AchievementManager — Achievement tracking with persistence
## Autoload or attach to root. Tracks and unlocks achievements, per-world milestones,
## boss defeats, majority threshold calculation, and post-cure endgame state.
## Canonical law of truth: docs/MASTER_GDD.md §5, §7 (Issue #28 / #24 C4).

signal achievement_unlocked(achievement_id: String)
signal boss_slain(world_id: int, boss_id: String)
signal cure_synthesized()
signal post_cure_entered()

# id -> {title: String, desc: String, unlocked: bool, world_id: int}
var achievements: Dictionary = {}

# world_id (1=Suburban, 2=Industrial, 3=Bio-Lab) -> bool
var world_bosses_defeated: Dictionary = {1: false, 2: false, 3: false}

# Flag indicating cure synthesis was deployed and post-cure open world is active
var post_cure: bool = false

func _ready() -> void:
	# Intentionally empty: achievements are registered by Game._setup_achievements()
	# AFTER this runs, and load_progress() only marks ids that already exist. Loading
	# here (as it did) found an empty dict and silently dropped every unlock.
	pass

func _get_save() -> Node:
	var root := get_tree().root if get_tree() else null
	if root and root.has_node("Save"):
		return root.get_node("Save")
	return null

func register_achievement(id: String, title: String, desc: String, world_id: int = 0) -> void:
	achievements[id] = {
		"title": title,
		"desc": desc,
		"unlocked": false,
		"world_id": world_id
	}

func unlock(id: String) -> void:
	if not achievements.has(id) or achievements[id]["unlocked"]:
		return
	achievements[id]["unlocked"] = true
	achievement_unlocked.emit(id)
	_save_progress()
	print("[Achievement] Unlocked: ", achievements[id]["title"])

func is_unlocked(id: String) -> bool:
	return achievements.has(id) and bool(achievements[id]["unlocked"])

func get_unlocked_count() -> int:
	var count := 0
	for a in achievements.values():
		if a["unlocked"]:
			count += 1
	return count

func get_total_count() -> int:
	return achievements.size()

# === PER-WORLD & MAJORITY THRESHOLD (GDD §5, §7) ===

func get_world_unlocked_count(world_id: int) -> int:
	var count := 0
	for a in achievements.values():
		if int(a.get("world_id", 0)) == world_id and bool(a.get("unlocked", false)):
			count += 1
	return count

func get_world_total_count(world_id: int) -> int:
	var count := 0
	for a in achievements.values():
		if int(a.get("world_id", 0)) == world_id:
			count += 1
	return count

func has_majority_achievements() -> bool:
	var total := get_total_count()
	if total == 0:
		return false
	return (float(get_unlocked_count()) / float(total)) > 0.5

func get_achievement_completion_ratio() -> float:
	var total := get_total_count()
	if total == 0:
		return 0.0
	return float(get_unlocked_count()) / float(total)

# === WORLD BOSSES (GDD §4, §5) ===

func record_boss_defeat(world_id: int, boss_id: String = "") -> void:
	world_bosses_defeated[world_id] = true
	boss_slain.emit(world_id, boss_id)
	if is_registered("boss_slayer"):
		unlock("boss_slayer")
	var world_boss_ach := "boss_w%d_defeated" % world_id
	if is_registered(world_boss_ach):
		unlock(world_boss_ach)
	_save_progress()
	print("[Achievement] World %d Boss Defeated: %s" % [world_id, boss_id])

func is_boss_defeated(world_id: int) -> bool:
	return bool(world_bosses_defeated.get(world_id, false))

func are_all_world_bosses_defeated() -> bool:
	return bool(world_bosses_defeated.get(1, false)) and \
		bool(world_bosses_defeated.get(2, false)) and \
		bool(world_bosses_defeated.get(3, false))

func is_registered(id: String) -> bool:
	return achievements.has(id)

# === CURE SYNTHESIS & POST-CURE STATE (GDD §5, §7) ===

func can_synthesize_cure() -> bool:
	# Requires defeating the World Boss in each of the three worlds
	# AND reaching a majority achievement threshold across Worlds 1–3
	return are_all_world_bosses_defeated() and has_majority_achievements()

func synthesize_cure() -> bool:
	if post_cure:
		return true
	if not can_synthesize_cure():
		print("[Achievement] Cannot synthesize cure: World bosses defeated=", are_all_world_bosses_defeated(), " majority=", has_majority_achievements())
		return false
	post_cure = true
	if is_registered("cure_synthesized"):
		unlock("cure_synthesized")
	cure_synthesized.emit()
	post_cure_entered.emit()
	_save_progress()
	print("[Achievement] CURE SYNTHESIZED! Outbreak mitigated; post-cure open world remains active.")
	return true

func is_post_cure() -> bool:
	return post_cure

# === PERSISTENCE ===

func _save_progress() -> void:
	"""Union this scene's unlocks into the global set, then persist.
	AchievementManager is a per-scene node that re-registers only its own ids, so
	writing just `achievements` would erase unlocks earned in other scenes."""
	var save := _get_save()
	if not save:
		return
	if save.has_method("get_unlocked_achievements") and save.has_method("set_unlocked_achievements"):
		var unlocked_ids: Array = save.get_unlocked_achievements().duplicate()
		for id in achievements:
			if achievements[id]["unlocked"] and not unlocked_ids.has(id):
				unlocked_ids.append(id)
		save.set_unlocked_achievements(unlocked_ids)
	if save.has_method("set_world_bosses_defeated"):
		save.set_world_bosses_defeated(world_bosses_defeated)
	if save.has_method("set_post_cure"):
		save.set_post_cure(post_cure)

func load_progress() -> void:
	"""Apply persisted unlocks. Must be called AFTER achievements are registered."""
	var save := _get_save()
	if not save:
		return
	if save.has_method("get_unlocked_achievements"):
		var unlocked_ids: Array = save.get_unlocked_achievements()
		for id in unlocked_ids:
			if achievements.has(id):
				achievements[id]["unlocked"] = true
	if save.has_method("get_world_bosses_defeated"):
		var b = save.get_world_bosses_defeated()
		if b is Dictionary:
			for w in [1, 2, 3]:
				world_bosses_defeated[w] = bool(b.get(w, false))
	if save.has_method("is_post_cure"):
		post_cure = bool(save.is_post_cure())
