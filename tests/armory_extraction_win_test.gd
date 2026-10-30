extends GdUnitTestSuite

## Win-condition unit tests for the two sandbox mini-games added in the
## 3-sandbox restructure: Armory Lockdown (SAND2, l2_armory_salvage) and
## Endgame Extraction (SAND3, l3_rooftop_extraction). Each test loads the REAL
## .tscn, instantiates the REAL controller and drives its state machine to
## WON / FAILED, asserting the l2_/l3_ objective is reported exactly once
## through a real ObjectiveManager.
##
## Same conventions as tests/triage_quarantine_win_test.gd: the CLI runner
## (GdUnitCmdTool extends SceneTree) has no current_scene, so tests install a
## wrapper scene and attach a real ObjectiveManager at the root.

# Controller RunState enum values (mirror the enum declarations):
const ARMORY_ACTIVE := 1
const ARMORY_WON := 2
const ARMORY_FAILED := 3
const ENDGAME_ACTIVE := 1
const ENDGAME_WON := 2
const ENDGAME_FAILED := 3

const ARMORY_SCENE := "res://scenes/minigames/armory_lockdown.tscn"
const ENDGAME_SCENE := "res://scenes/minigames/endgame_extraction.tscn"

var _instances: Array[Node] = []
var _current_scene_wrapper: Node = null
var _objective_manager: Node = null

func before_test() -> void:
	_current_scene_wrapper = Node.new()
	_current_scene_wrapper.name = "MuakbankGDUnitTestScene"
	get_tree().root.add_child(_current_scene_wrapper)
	get_tree().current_scene = _current_scene_wrapper
	_objective_manager = load("res://scripts/gameplay/ObjectiveManager.gd").new()
	_objective_manager.name = "ObjectiveManager"
	get_tree().root.add_child(_objective_manager)

func after_test() -> void:
	get_tree().current_scene = null
	if is_instance_valid(_current_scene_wrapper):
		_current_scene_wrapper.queue_free()
	_current_scene_wrapper = null
	if is_instance_valid(_objective_manager):
		_objective_manager.queue_free()
	_objective_manager = null
	for n in _instances:
		if is_instance_valid(n):
			n.queue_free()
	_instances.clear()
	await get_tree().process_frame

func _make_player(parent: Node) -> Node3D:
	var p: Node3D = load("res://tools/player_stub.gd").new()
	p.name = "ProbePlayer"
	parent.add_child(p)
	return p

func _objective_progress(id: String) -> int:
	var objectives: Dictionary = _objective_manager.get("objectives")
	if not objectives.has(id):
		return -1
	return int(objectives[id]["progress"])

# Simulate the player parked inside the crate's interaction zone (the real
# body_entered path) then crack it through the crate's own interact().
func _crack_crate(crate: Node) -> void:
	crate.set("player_near", true)
	crate.interact()
	assert_that(bool(crate.get("is_cracked"))).is_true()

# Breach via the door's real open path (no player_near gate on open_fully()).
func _open_door(door: Node) -> void:
	door.open_fully()
	assert_that(bool(door.get("is_open"))).is_true()

# ── ARMORY LOCKDOWN (SAND2) ─────────────────────────────────────────────────

func test_armory_needs_both_crates_and_open_door_before_winning() -> void:
	var inst: Node = (load(ARMORY_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	# The embedded controller registers its own objective on SAND2 load.
	assert_that(_objective_manager.objectives.has("l2_armory_salvage")).is_true()

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ARMORY_ACTIVE)

	# Both crates cracked, door still closed -> NOT won yet.
	_crack_crate(inst.get_node("Crate1"))
	_crack_crate(inst.get_node("Crate2"))
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ARMORY_ACTIVE)
	assert_that(_objective_progress("l2_armory_salvage")).is_equal(0)

	# Opening the door is the third and final condition.
	_open_door(inst.get_node("ArmoryDoor"))
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ARMORY_WON)
	assert_that(bool(ctrl.get("is_won"))).is_true()
	assert_that(_objective_progress("l2_armory_salvage")).is_equal(1)

	# Win is sticky: post-WON ticks must not double-report.
	ctrl._process(1.0)
	assert_that(_objective_progress("l2_armory_salvage")).is_equal(1)
	assert_that(int(ctrl.get("state"))).is_equal(ARMORY_WON)

func test_armory_timeout_fails_without_reporting_progress() -> void:
	var inst: Node = (load(ARMORY_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ARMORY_ACTIVE)

	ctrl.set("time_remaining", 0.5)
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ARMORY_FAILED)
	assert_that(_objective_progress("l2_armory_salvage")).is_equal(0)

# ── ENDGAME EXTRACTION (SAND3) ───────────────────────────────────────────────

func test_endgame_cracks_flare_and_breaches_door_to_win() -> void:
	var inst: Node = (load(ENDGAME_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	# The embedded controller registers its own objective on SAND3 load.
	assert_that(_objective_manager.objectives.has("l3_rooftop_extraction")).is_true()

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ENDGAME_ACTIVE)

	# Door breached but flare crate intact -> not won yet.
	_open_door(inst.get_node("MaintenanceDoor"))
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ENDGAME_ACTIVE)
	assert_that(_objective_progress("l3_rooftop_extraction")).is_equal(0)

	_crack_crate(inst.get_node("FlareCrate"))
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ENDGAME_WON)
	assert_that(bool(ctrl.get("is_won"))).is_true()
	assert_that(_objective_progress("l3_rooftop_extraction")).is_equal(1)

func test_endgame_timeout_fails_without_reporting_progress() -> void:
	var inst: Node = (load(ENDGAME_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ENDGAME_ACTIVE)

	ctrl.set("time_remaining", 0.5)
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(ENDGAME_FAILED)
	assert_that(_objective_progress("l3_rooftop_extraction")).is_equal(0)
