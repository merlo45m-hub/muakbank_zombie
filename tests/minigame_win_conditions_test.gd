extends GdUnitTestSuite

## Win-condition unit tests for the three Level-1 mini-games.
##
## Each test loads the REAL .tscn, instantiates the REAL controller
## (BioGeneratorController / SpoilAndSurviveController /
## LastStandStationController via scripts/gameplay/*.gd) and drives its state
## machine through the happy path until it reaches the WON state — the same
## condition logic the tools/minigame_win_probe.gd exercises end-to-end, but
## with per-assertion granularity. Player behaviour comes from the shared
## tools/player_stub.gd (same stub the smoke-gate probe reuses).
##
## The CLI runner (GdUnitCmdTool extends SceneTree) has no current_scene, so
## tests install a wrapper scene as current_scene — the controllers spawn their
## waves via get_tree().current_scene.add_child().
##
## Run (Godot 4.7 headless on the VPS):
##   cd /root/muakbank_zombie
##   xvfb-run -a /root/Godot_v4.7-stable_linux.x86_64 --headless \
##       --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
##       -a res://tests --ignoreHeadlessMode

# Controller RunState/TrialState enum values (mirror the enum declarations):
const GENERATOR_ACTIVE := 1
const GENERATOR_WON := 2    # BioGeneratorController.RunState.WON
const SPOIL_ACTIVE := 1
const SPOIL_WON := 2        # SpoilAndSurviveController.RunState.WON
const LASTSTAND_PREPARING := 1
const LASTSTAND_ACTIVE := 2
const LASTSTAND_INTERMISSION := 3
const LASTSTAND_WON := 4    # LastStandStationController.TrialState.WON

const GENERATOR_SCENE := "res://scenes/minigames/keep_generator_fed.tscn"
const SPOIL_SCENE := "res://scenes/minigames/spoil_and_survive.tscn"
const LASTSTAND_SCENE := "res://scenes/minigames/last_stand_station.tscn"

var _instances: Array[Node] = []
var _current_scene_wrapper: Node = null

func before_test() -> void:
	# Provide a current_scene so controller wave-spawns have a home.
	_current_scene_wrapper = Node.new()
	_current_scene_wrapper.name = "MuakbankGDUnitTestScene"
	get_tree().root.add_child(_current_scene_wrapper)
	get_tree().current_scene = _current_scene_wrapper

func after_test() -> void:
	get_tree().current_scene = null
	if is_instance_valid(_current_scene_wrapper):
		_current_scene_wrapper.queue_free()
	_current_scene_wrapper = null
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

func _kill_all_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999)

# Zombie death is async (enemy _process flips is_dead / frees the body), so a
# wave only "clears" once the controller's _prune_enemies sees the empties.
# Loop kill + tick until the controller leaves ACTIVE (mirrors the smoke-gate
# probe's retry-until-state-change approach) — bounded so a stuck wave fails.
func _force_clear_wave(ctrl: Node, budget: int = 30) -> void:
	for i in range(budget):
		_kill_all_enemies()
		await get_tree().process_frame
		ctrl._process(0.1)
		if int(ctrl.get("state")) != LASTSTAND_ACTIVE:
			return

# ── BIO GENERATOR ───────────────────────────────────────────────────────────
func test_bio_generator_reaches_won_when_countdown_ends_with_fuel() -> void:
	var inst: Node = (load(GENERATOR_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(GENERATOR_ACTIVE)
	# STARTING_FUEL=60; engine frames may drain a hair, so assert a safe floor.
	assert_that(float(ctrl.get("fuel"))).is_greater(50.0)

	# Fast-forward the countdown: time_remaining is a plain public var, so the
	# test crunches 3 simulated seconds (fuel keeps draining 2.2/s from 60 and
	# stays positive; generator_hp stays 400) — the real _process clock then
	# observes time_remaining hit 0 with fuel>0 and HP>0 and flips to WON.
	ctrl.set("time_remaining", 3.0)
	for i in range(4):
		_kill_all_enemies()  # keep zombies off the generator
		ctrl._process(1.0)
		await get_tree().process_frame

	# Fuel and generator HP are the real win preconditions — assert them, then
	# the resulting state transition.
	assert_that(float(ctrl.get("fuel")) > 0.0).is_true()
	assert_that(int(ctrl.get("generator_hp")) > 0).is_true()
	assert_that(int(ctrl.get("state"))).is_equal(GENERATOR_WON)

# ── SPOIL & SURVIVE ─────────────────────────────────────────────────────────
func test_spoil_survive_reaches_won_only_after_15_fresh_dishes() -> void:
	var inst: Node = (load(SPOIL_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(SPOIL_ACTIVE)

	# 14 fresh dishes is not enough to win.
	for i in range(14):
		ctrl.on_dish_eaten(null, false, player)
	await get_tree().process_frame
	assert_that(int(ctrl.get("dishes_eaten"))).is_equal(14)
	assert_that(int(ctrl.get("state"))).is_equal(SPOIL_ACTIVE)

	# The 15th fresh dish flips the state machine to WON.
	ctrl.on_dish_eaten(null, false, player)
	assert_that(int(ctrl.get("dishes_eaten"))).is_equal(15)
	assert_that(bool(ctrl.get("is_won"))).is_true()
	assert_that(int(ctrl.get("state"))).is_equal(SPOIL_WON)

	# After WON the controller ignores further eats (win is sticky).
	ctrl.on_dish_eaten(null, false, player)
	assert_that(int(ctrl.get("state"))).is_equal(SPOIL_WON)

func test_spoil_survive_tainted_dish_penalizes_and_never_counts() -> void:
	var inst: Node = (load(SPOIL_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.interact()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(SPOIL_ACTIVE)

	ctrl.on_dish_eaten(null, true, player)
	# Spoiled bite: no progress, combo wiped, 5s time penalty, 18 damage.
	# (time_remaining: 60.0 - 5.0, minus any engine-frame drain — assert a band.)
	assert_that(int(ctrl.get("dishes_eaten"))).is_equal(0)
	assert_that(int(ctrl.get("combo_streak"))).is_equal(0)
	assert_that(float(ctrl.get("time_remaining"))).is_less(55.5)
	assert_that(float(ctrl.get("time_remaining"))).is_greater(53.0)
	assert_that(int(player.get("health"))).is_equal(82)
	assert_that(int(ctrl.get("state"))).is_equal(SPOIL_ACTIVE)

# ── LAST STAND STATION ──────────────────────────────────────────────────────
func test_last_stand_reaches_won_only_after_three_cleared_waves() -> void:
	var inst: Node = (load(LASTSTAND_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	_instances.append(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node("Controller")
	var player: Node3D = _make_player(inst)
	ctrl.set("player", player)
	await get_tree().process_frame

	ctrl.start_trial()
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_PREPARING)
	assert_that(int(ctrl.get("wave"))).is_equal(0)

	# Prep countdown (10s) -> wave 1 spawns.
	ctrl._process(10.0)
	await get_tree().process_frame
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_ACTIVE)
	assert_that(int(ctrl.get("wave"))).is_equal(1)
	assert_that(int(ctrl.get("active_enemies").size())).is_greater(0)

	# Clearing wave 1 -> intermission (not WON).
	await _force_clear_wave(ctrl)
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_INTERMISSION)
	assert_that(int(ctrl.get("wave"))).is_equal(1)
	assert_that(bool(ctrl.get("is_won"))).is_false()

	# Intermission (12s) -> wave 2 -> clear -> intermission.
	ctrl._process(12.0)
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_ACTIVE)
	assert_that(int(ctrl.get("wave"))).is_equal(2)
	await _force_clear_wave(ctrl)
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_INTERMISSION)

	# Intermission -> wave 3 -> clear -> WON (wave >= 3 is the win gate).
	ctrl._process(12.0)
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_ACTIVE)
	assert_that(int(ctrl.get("wave"))).is_equal(3)
	await _force_clear_wave(ctrl)
	assert_that(int(ctrl.get("state"))).is_equal(LASTSTAND_WON)
	assert_that(bool(ctrl.get("is_won"))).is_true()
