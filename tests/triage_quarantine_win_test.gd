extends GdUnitTestSuite

## Win-condition unit tests for the two LEVEL1_MINIGAMES_B mini-games:
## Triage Roundup (l1_triage_roundup) and Quarantine Breach
## (l1_quarantine_breach). Each test loads the REAL .tscn, instantiates the REAL
## controller and drives its state machine to WON and FAILED, asserting the
## l1_* objective is reported exactly once through a real ObjectiveManager.
##
## Same conventions as tests/minigame_win_conditions_test.gd: the CLI runner
## (GdUnitCmdTool extends SceneTree) has no current_scene, so tests install a
## wrapper scene and attach a real ObjectiveManager at the root.

# Controller RunState enum values (mirror the enum declarations):
const TRIAGE_ACTIVE := 1
const TRIAGE_WON := 2
const TRIAGE_FAILED := 3
const QUARANTINE_ACTIVE := 1
const QUARANTINE_WON := 2
const QUARANTINE_FAILED := 3

const TRIAGE_SCENE := "res://scenes/minigames/triage_roundup.tscn"
const QUARANTINE_SCENE := "res://scenes/minigames/quarantine_breach.tscn"

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

# ── TRIAGE ROUNDUP ────────────────────────────────────────────────────────────

func test_triage_wrong_type_never_counts_and_four_deliveries_win() -> void:
	var inst: Node = (load(TRIAGE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	assert_that(int(ctrl.get("state"))).is_equal(0)  # IDLE before start
	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(TRIAGE_ACTIVE)

	var animals: Node = inst.get_node("Animals")
	var pens: Node = inst.get_node("Pens")

	# Wrong-type attempt: dog inside the CAT pen must never count.
	var dog: Node3D = animals.get_node("AnimalDog")
	var pen_cat: Node3D = pens.get_node("PenCat")
	dog.global_position = pen_cat.global_position + Vector3(0, 0.4, 0)
	dog.linear_velocity = Vector3.ZERO
	ctrl._process(1.0)
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(ctrl.get("delivered_types").size()).is_equal(0)
	assert_that(int(ctrl.get("state"))).is_equal(TRIAGE_ACTIVE)

	# Correct deliveries in any order: each animal parked in its matching pen.
	var order: Array[String] = ["dog", "cat", "rabbit", "chicken"]
	for t in order:
		var pen: Node3D = pens.get_node("Pen%s" % t.capitalize())
		var animal: Node3D = animals.get_node("Animal%s" % t.capitalize())
		animal.global_position = pen.global_position + Vector3(0, 0.4, 0)
		animal.linear_velocity = Vector3.ZERO
		var guard := 0
		while guard < 10 and not bool(pen.get("delivered")):
			ctrl._process(1.0)
			guard += 1
		assert_that(bool(pen.get("delivered"))).is_true()
		assert_that(ctrl.get("delivered_types").size()).is_equal(order.find(t) + 1)

	# Fourth delivery flips the state machine to WON and reports once.
	assert_that(int(ctrl.get("state"))).is_equal(TRIAGE_WON)
	assert_that(bool(ctrl.get("is_won"))).is_true()
	assert_that(_objective_progress("l1_triage_roundup")).is_equal(1)

	# Win is sticky: a duplicate signal after WON must not double-report.
	ctrl._on_animal_delivered("dog", null)
	assert_that(_objective_progress("l1_triage_roundup")).is_equal(1)
	assert_that(int(ctrl.get("state"))).is_equal(TRIAGE_WON)

func test_triage_timeout_fails_without_reporting_progress() -> void:
	var inst: Node = (load(TRIAGE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(TRIAGE_ACTIVE)

	ctrl.set("time_remaining", 0.5)
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(TRIAGE_FAILED)
	assert_that(_objective_progress("l1_triage_roundup")).is_equal(0)

# ── QUARANTINE BREACH ─────────────────────────────────────────────────────────

func test_quarantine_seals_abc_in_order_and_wins() -> void:
	var inst: Node = (load(QUARANTINE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(QUARANTINE_ACTIVE)
	assert_that(String(ctrl.get("current_step"))).is_equal("A")

	var doors: Node = inst.get_node("Doors")
	var cases: Node = inst.get_node("Cases")
	var cart: Node3D = inst.get_node("ServiceCart")

	# Order guard: a brace on the WRONG (later) door must not seal while A runs.
	var door_c: Node = doors.get_node("DoorC")
	var case_c: Node3D = cases.get_node("CaseC")
	case_c.global_position = door_c.get_node("BraceSocket").global_position + Vector3(0, 0.1, 0)
	door_c.toggle_to_closed()
	ctrl._process(1.0)
	assert_that(bool(door_c.get("sealed"))).is_false()
	assert_that(String(ctrl.get("current_step"))).is_equal("A")

	# Seal A, then B, then C: brace into socket + close door + bounded ticks.
	var braces: Dictionary = {"A": cases.get_node("CaseA"), "B": cart, "C": case_c}
	for step in ["A", "B", "C"]:
		var door: Node = doors.get_node("Door%s" % step)
		var brace: Node3D = braces[step]
		brace.global_position = door.get_node("BraceSocket").global_position + Vector3(0, 0.1, 0)
		brace.linear_velocity = Vector3.ZERO
		door.toggle_to_closed()
		var guard := 0
		while guard < 12 and not bool(door.get("sealed")):
			ctrl._process(1.0)
			guard += 1
		assert_that(bool(door.get("sealed"))).is_true()
		assert_that(int(ctrl.get("state"))).is_equal(QUARANTINE_ACTIVE if step != "C" else QUARANTINE_WON)

	assert_that(int(ctrl.get("state"))).is_equal(QUARANTINE_WON)
	assert_that(bool(ctrl.get("is_won"))).is_true()
	assert_that(_objective_progress("l1_quarantine_breach")).is_equal(1)

func test_quarantine_timeout_fails_without_reporting_progress() -> void:
	var inst: Node = (load(QUARANTINE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(QUARANTINE_ACTIVE)

	ctrl.set("time_remaining", 0.5)
	ctrl._process(1.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(QUARANTINE_FAILED)
	assert_that(_objective_progress("l1_quarantine_breach")).is_equal(0)

func test_quarantine_unbraced_door_reopens_after_hold() -> void:
	var inst: Node = (load(QUARANTINE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	var door_a: Node = inst.get_node("Doors/DoorA")
	door_a.toggle_to_closed()  # no brace in the socket
	for i in range(6):
		ctrl._process(1.0)
	await get_tree().process_frame
	# Unbraced hold expired: door reopened, nothing sealed, activity still live.
	assert_that(bool(door_a.get("sealed"))).is_false()
	assert_that(bool(door_a.get("is_open"))).is_true()
	assert_that(int(ctrl.get("state"))).is_equal(QUARANTINE_ACTIVE)
	assert_that(_objective_progress("l1_quarantine_breach")).is_equal(0)
