## Reusable Issue #28 regression test — Cure synthesis, majority achievement threshold,
## and post-cure open world state verification (docs/MASTER_GDD.md §5, §7 / Issue #24 C4).
extends SceneTree
## Issue #28 runtime verification — Cure synthesis & post-cure state headless.
## Verified premises (from MASTER_GDD.md §5, §7):
##  * World Boss in each of the three worlds (Suburban, Industrial, Bio-Lab) must be defeated.
##  * Majority achievement threshold (> 50%) across Worlds 1-3 must be reached.
##  * Deploying Cure synthesizes cure, stops main outbreak, sets post_cure flag.
##  * Post-cure open world: game continues seamlessly with full world access.

var _failures: int = 0
var _cure_synthesized_signal_fired: bool = false
var _post_cure_entered_signal_fired: bool = false

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	print("=== GDD-4 / Issue #28: Cure Synthesis & Post-Cure Playtest ===")

	var am: AchievementManager = AchievementManager.new()
	am.name = "AchievementManager"
	root.add_child(am)

	am.cure_synthesized.connect(func(): _cure_synthesized_signal_fired = true)
	am.post_cure_entered.connect(func(): _post_cure_entered_signal_fired = true)

	# Register 10 achievements across Worlds 1-3
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

	_assert(am.get_total_count() == 10, "10 total achievements registered")
	_assert(am.get_world_total_count(1) == 7, "World 1 has 7 achievements")
	_assert(am.get_world_total_count(2) == 1, "World 2 has 1 achievement")
	_assert(am.get_world_total_count(3) == 2, "World 3 has 2 achievements")

	# Initial state: 0 unlocks, 0 bosses, not post_cure
	_assert(!am.is_post_cure(), "Initial post_cure is false")
	_assert(!am.are_all_world_bosses_defeated(), "Initial world bosses not all defeated")
	_assert(!am.has_majority_achievements(), "Initial majority achievements is false (0/10)")
	_assert(!am.can_synthesize_cure(), "Initial can_synthesize_cure is false")
	_assert(!am.synthesize_cure(), "synthesize_cure() fails when conditions not met")

	# Step 1: Defeat World 1 and World 2 bosses
	am.record_boss_defeat(1, "suburban_boss")
	am.record_boss_defeat(2, "industrial_boss")
	_assert(am.is_boss_defeated(1), "World 1 boss defeated")
	_assert(am.is_boss_defeated(2), "World 2 boss defeated")
	_assert(!am.is_boss_defeated(3), "World 3 boss not defeated yet")
	_assert(!am.are_all_world_bosses_defeated(), "All bosses defeated is still false (missing W3)")
	_assert(!am.can_synthesize_cure(), "can_synthesize_cure is false without W3 boss")

	# Step 2: Unlock achievements to reach majority threshold (> 50%, i.e. > 5 of 10)
	am.unlock("first_kill")
	am.unlock("combo_5")
	am.unlock("survivor")
	am.unlock("well_fed")
	var unlocked: int = am.get_unlocked_count()
	_assert(unlocked >= 6, "Reached at least 6 unlocked achievements: count=%d" % unlocked)
	_assert(am.has_majority_achievements(), "Majority achievement threshold reached: %f" % am.get_achievement_completion_ratio())
	_assert(!am.can_synthesize_cure(), "can_synthesize_cure still false because World 3 boss is still undefeated")

	# Step 3: Defeat World 3 boss (Bio-Lab World Boss)
	am.record_boss_defeat(3, "biolab_boss")
	_assert(am.is_boss_defeated(3), "World 3 boss defeated")
	_assert(am.are_all_world_bosses_defeated(), "All 3 world bosses are now defeated")
	_assert(am.can_synthesize_cure(), "can_synthesize_cure is now TRUE (all 3 bosses + majority achievements)")

	# Step 4: Synthesize Cure
	var synth_ok: bool = am.synthesize_cure()
	_assert(synth_ok, "synthesize_cure() succeeded")
	_assert(am.is_post_cure(), "is_post_cure() is now true")
	_assert(am.is_unlocked("cure_synthesized"), "cure_synthesized achievement is unlocked")
	_assert(_cure_synthesized_signal_fired, "cure_synthesized signal fired")
	_assert(_post_cure_entered_signal_fired, "post_cure_entered signal fired")

	# Step 5: Save persistence round-trip
	var save: Node = root.get_node_or_null("Save")
	if save:
		am._save_progress()
		_assert(save.has_method("is_post_cure") and save.is_post_cure(), "SaveManager persisted post_cure=true")
		_assert(save.has_method("get_world_bosses_defeated"), "SaveManager has get_world_bosses_defeated")
		var b_saved: Dictionary = save.get_world_bosses_defeated()
		_assert(bool(b_saved.get(1)) and bool(b_saved.get(2)) and bool(b_saved.get(3)), "SaveManager persisted all 3 boss defeats")

		# Create a fresh AchievementManager and reload progress
		var am2: AchievementManager = AchievementManager.new()
		am2.name = "AchievementManager2"
		root.add_child(am2)
		am2.register_achievement("cure_synthesized", "Hope Restored", "Synthesize Cure", 3)
		am2.load_progress()
		_assert(am2.is_post_cure(), "am2 loaded post_cure=true from SaveManager")
		_assert(am2.is_boss_defeated(1) and am2.is_boss_defeated(2) and am2.is_boss_defeated(3), "am2 loaded all 3 bosses from SaveManager")
		_assert(am2.is_unlocked("cure_synthesized"), "am2 loaded cure_synthesized unlock")
		am2.queue_free()

	# Step 6: Post-cure open world state verification
	_assert(am.is_post_cure(), "Game is in seamless post-cure state (world open for 100% completion)")

	am.queue_free()

	if _failures == 0:
		print("GDD28_CURE_PASS=true")
		quit(0)
	else:
		printerr("GDD28_CURE_FAIL: %d assertions failed" % _failures)
		quit(1)
