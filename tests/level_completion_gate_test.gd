extends GdUnitTestSuite

## Regression test for the campaign deadlock: _setup_objectives() used to register
## the three l1_* mini-game objectives on EVERY level, so _all_minigames_done()
## never observed registered_count == 0. Levels 2+ have no mini-game controllers,
## the completion gate looped, the clock expired into end_game(false) and the next
## level never unlocked. The count==0 "survivable" safety net in _all_minigames_done()
## is deliberately NOT changed — it is the designed escape hatch.
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

## A non-level-1 run must register NO l1_* mini-game objectives, so
## _all_minigames_done() sees registered_count == 0 and the level is survivable
## (waves cleared -> end_game(true) -> next level unlocks).
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
