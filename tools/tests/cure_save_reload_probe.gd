## cure_save_reload_probe.gd — GDD Issue #28 cure save→reload persistence probe.
##
## Modes (set via environment):
##   CURE_PROBE_MODE=SETUP   — synthesize the cure, persist to CURE_SAVE_PATH,
##                             prove the write landed on disk, exit 0.
##   CURE_PROBE_MODE=VERIFY  — fresh Godot process; reload CURE_SAVE_PATH and
##                             assert post_cure + 3 world bosses +
##                             cure_synthesized unlock, exit 0.
## CURE_SAVE_PATH must be an absolute path owned by the harness; no secrets.
extends SceneTree

const MODE_ENV: String = "CURE_PROBE_MODE"
const PATH_ENV: String = "CURE_SAVE_PATH"

var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _get_save() -> Node:
	var root: Node = get_tree().root
	if root and root.has_node("Save"):
		return root.get_node("Save")
	return null

func _register_cure_achievements(am: AchievementManager) -> void:
	am.register_achievement("first_kill", "First Blood", "Kill your first zombie", 1)
	am.register_achievement("combo_5", "Combo Master", "Reach a 5x kill combo", 1)
	am.register_achievement("boss_slayer", "Boss Slayer", "Defeat a boss zombie", 1)
	am.register_achievement("survivor", "Survivor", "Complete a level", 1)
	am.register_achievement("well_fed", "Well Fed", "Eat 10 food items", 1)
	am.register_achievement("untouchable", "Untouchable", "Complete a level without taking damage", 1)
	am.register_achievement("boss_w1_defeated", "Suburban Dominator", "Defeat Suburban Boss", 1)
	am.register_achievement("boss_w2_defeated", "Industrial Conqueror", "Defeat Industrial Boss", 2)
	am.register_achievement("boss_w3_defeated", "Bio-Lab Vanguard", "Defeat Bio-Lab Boss", 3)
	am.register_achievement("cure_synthesized", "Hope Restored", "Synthesize Cure", 3)

func _run_setup() -> void:
	var save: Node = _get_save()
	if not save:
		printerr("CURE_SETUP_FAIL: Save autoload not found")
		quit(1)
	var save_path: String = OS.get_environment(PATH_ENV)
	if save_path.is_empty():
		printerr("CURE_SETUP_FAIL: CURE_SAVE_PATH is not set")
		quit(1)
	save.save_path = save_path

	var am: AchievementManager = AchievementManager.new()
	am.name = "CureSetupManager"
	get_tree().root.add_child(am)
	_register_cure_achievements(am)

	# All three world bosses defeated and a majority of achievements unlocked.
	am.record_boss_defeat(1, "suburban_boss")
	am.record_boss_defeat(2, "industrial_boss")
	am.record_boss_defeat(3, "biolab_boss")
	am.unlock("first_kill")
	am.unlock("combo_5")
	am.unlock("survivor")
	am.unlock("well_fed")
	am.unlock("untouchable")
	am.unlock("boss_slayer")

	var synth_ok: bool = am.synthesize_cure()
	_assert(synth_ok, "synthesize_cure() succeeded")
	_assert(am.is_post_cure(), "post_cure is true after synthesis")
	_assert(am.are_all_world_bosses_defeated(), "all 3 world bosses recorded defeated")
	_assert(am.has_majority_achievements(), "majority achievement threshold reached")
	_assert(am.is_unlocked("cure_synthesized"), "cure_synthesized unlocked")
	_assert(save.is_post_cure(), "SaveManager persisted post_cure=true")
	var b: Dictionary = save.get_world_bosses_defeated()
	_assert(bool(b.get(1, false)) and bool(b.get(2, false)) and bool(b.get(3, false)), "SaveManager persisted all 3 boss defeats")

	save.save_game()
	if FileAccess.file_exists(save_path):
		print("CURE_SETUP_PASS=true")
		quit(0)
	else:
		printerr("CURE_SETUP_FAIL: save file was not written to disk at %s" % save_path)
		quit(1)

func _run_verify() -> void:
	var save: Node = _get_save()
	if not save:
		printerr("CURE_VERIFY_FAIL: Save autoload not found")
		quit(1)
	var save_path: String = OS.get_environment(PATH_ENV)
	if save_path.is_empty():
		printerr("CURE_VERIFY_FAIL: CURE_SAVE_PATH is not set")
		quit(1)
	save.save_path = save_path

	# Fresh process: reload the state the SETUP process wrote to disk.
	save._load_game()

	var am: AchievementManager = AchievementManager.new()
	am.name = "CureVerifyManager"
	get_tree().root.add_child(am)
	_register_cure_achievements(am)
	am.load_progress()

	_assert(am.is_post_cure(), "loaded post_cure=true from persisted save")
	_assert(am.is_boss_defeated(1) and am.is_boss_defeated(2) and am.is_boss_defeated(3), "loaded all 3 world bosses defeated")
	_assert(am.are_all_world_bosses_defeated(), "loaded are_all_world_bosses_defeated is true")
	_assert(am.is_unlocked("cure_synthesized"), "loaded cure_synthesized unlock")
	_assert(save.is_post_cure(), "SaveManager reports post_cure=true after reload")
	var vb: Dictionary = save.get_world_bosses_defeated()
	_assert(bool(vb.get(1, false)) and bool(vb.get(2, false)) and bool(vb.get(3, false)), "SaveManager reports all 3 bosses after reload")

	if _failures == 0:
		print("CURE_VERIFY_PASS=true")
		quit(0)
	else:
		printerr("CURE_VERIFY_FAIL: %d assertions failed" % _failures)
		quit(1)

func _ready() -> void:
	await process_frame
	var mode: String = OS.get_environment(MODE_ENV)
	if mode == "SETUP":
		_run_setup()
	elif mode == "VERIFY":
		_run_verify()
	else:
		printerr("CURE_PROBE_FAIL: CURE_PROBE_MODE must be SETUP or VERIFY, got: %s" % mode)
		quit(1)
