extends GdUnitTestSuite

## Regression test for the campaign gate (_all_minigames_done / _check_level_complete).
##
## Under the 3-sandbox architecture _setup_objectives() pre-registers the five
## SAND1 mini-game objectives on level 1 only; SAND2 (l2_armory_salvage) and
## SAND3 (l3_rooftop_extraction) objectives are registered by THEIR embedded
## controllers when the sandbox loads (ArmoryLockdownController /
## EndgameExtractionController). The count==0 "survivable" safety net in
## _all_minigames_done() therefore now only guards stripped/controller-less
## levels — none of the 3 sandboxes are controller-less, so a real run is always
## gated on its embedded mini-games.
##
## Uses the REAL classes via preload: Game.gd is instantiated WITHOUT entering the
## tree (no _ready side effects) and wired to a real ObjectiveManager. The current
## level is simulated through the Save autoload exactly the way Game.gd reads it
## (Save.get_current_level()), mutated in memory only — save_game() is never called,
## so the on-disk savefile is untouched and restored in after_test().

const L1_MINIGAME_IDS: Array[String] = ["l1_spoil_and_survive", "l1_generator_fed", "l1_last_stand", "l1_triage_roundup", "l1_quarantine_breach"]

var _original_level: int = 1
var _game: Node = null
var _objectives: Node = null

func before_test() -> void:
	# Game.gd reads the level with Save.get_current_level(); the autoload always
	# exists in the test runner. Simulate a non-level-1 run for the survivable case.
	_original_level = Save.get_current_level()
	_game = load("res://scripts/core/Game.gd").new()
	_objectives = load("res://scripts/gameplay/ObjectiveManager.gd").new()
	_game.objective_manager = _objectives

func after_test() -> void:
	Save.save_data["current_level"] = _original_level
	if is_instance_valid(_objectives):
		_objectives.free()
	if is_instance_valid(_game):
		_game.free()

## _setup_objectives() pre-registers mini-game objectives for level 1 only;
## a non-level-1 run registers NONE there (SAND2/SAND3 objectives arrive from
## the sandbox's embedded controllers instead). With zero registered the gate's
## safety net treats the level as survivable — the stripped-level escape hatch.
func test_non_level1_registers_no_minigame_objectives_and_is_survivable() -> void:
	Save.save_data["current_level"] = 2
	_game._setup_objectives()
	for id in L1_MINIGAME_IDS:
		assert_that(_objectives.objectives.has(id)).is_false()
	# Core objectives are still registered on every level.
	assert_that(_objectives.objectives.has("eat_food")).is_true()
	assert_that(_objectives.objectives.has("survive")).is_true()
	# The safety net: zero registered minigame objectives -> winnable.
	assert_that(_game._all_minigames_done()).is_true()

## Level 1 registers exactly the l1_* trio; while they are not completed the gate
## must NOT call the level complete (deadlock guard still active on level 1).
func test_level1_registered_but_uncompleted_minigames_block_completion() -> void:
	Save.save_data["current_level"] = 1
	_game._setup_objectives()
	for id in L1_MINIGAME_IDS:
		assert_that(_objectives.objectives.has(id)).is_true()
	assert_that(_game._all_minigames_done()).is_false()

## Level 1 with the full l1_* trio completed returns true (completion gate opens).
func test_level1_completed_minigames_open_the_gate() -> void:
	Save.save_data["current_level"] = 1
	_game._setup_objectives()
	for id in L1_MINIGAME_IDS:
		_game.objective_manager.update_progress(id, 1)
		assert_that(_game.objective_manager.is_objective_completed(id)).is_true()
	assert_that(_game._all_minigames_done()).is_true()

## SAND2 scoping: once l2_armory_salvage is registered (as the embedded
## ArmoryLockdownController does on sandbox load), the gate must block
## completion until it clears — a SAND2 run is NOT survivable without the
## minigame, unlike the old stripped-level fallback.
func test_sandbox2_registered_armory_minigame_blocks_and_opens_the_gate() -> void:
	Save.save_data["current_level"] = 2
	_game._setup_objectives()
	# No pre-registration from _setup_objectives on level 2.
	assert_that(_objectives.objectives.has("l2_armory_salvage")).is_false()
	_game.objective_manager.add_objective("l2_armory_salvage", "Recover armory supplies & breach lockdown", 1)
	assert_that(_game._all_minigames_done()).is_false()
	_game.objective_manager.update_progress("l2_armory_salvage", 1)
	assert_that(_objectives.is_objective_completed("l2_armory_salvage")).is_true()
	assert_that(_game._all_minigames_done()).is_true()
