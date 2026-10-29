extends Node3D
class_name QuarantineBreachController

## QuarantineBreachController — state machine + rules engine for the Quarantine
## Breach mini-game (spec: docs/specs/LEVEL1_MINIGAMES_B.md §2).
##
## Seal three breaches (A—Intake, B—Laundry, C—Loading Bay) IN ORDER before the
## 120s seal-down clock expires. Each door is sealed by closing it with its
## assigned brace (supply case for A/C, laundry cart for B) seated in the door's
## socket for 0.75s. The active lane leaks one zombie every 7s; six zombies
## crossing the interior red line (BreachKillZone) loses the route. Reports to
## ObjectiveManager exactly once on win (l1_quarantine_breach).

const OBJECTIVE_ID := "l1_quarantine_breach"
const OBJECTIVE_TITLE := "Seal the service route"
const RUN_DURATION := 120.0
const SPAWN_INTERVAL := 7.0
const MAX_LEAKERS := 6
const FAILURE_RESET_DELAY := 3.0
const KILLZONE_CROWD_LIMIT := 6

const STEP_ORDER: Array[String] = ["A", "B", "C"]
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/zombie_dog.tscn")

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var hud_path: NodePath = ^"../QuarantineHUD"
@export var doors_path: NodePath = ^"../Doors"
@export var crates_path: NodePath = ^"../Crates"
@export var cart_path: NodePath = ^"../ServiceCart"
@export var cases_path: NodePath = ^"../Cases"
@export var kill_zone_path: NodePath = ^"../BreachKillZone"
@export var lanes_path: NodePath = ^"../Lanes"
@export var board_path: NodePath = ^"../Board"

var state: RunState = RunState.IDLE
var time_remaining: float = RUN_DURATION
var step_index: int = 0
var current_step: String = "A"
var is_won: bool = false
var spawn_timer: float = 0.0
var leak_count: int = 0

var objective_manager: Node = null
var player: Node3D = null
var hud: CanvasLayer = null
var doors: Dictionary = {}          # "A" -> QuarantineSealDoor
var crates: Array[Node] = []
var cases: Array[Node] = []
var cart: Node = null
var kill_zone: Area3D = null
var lane_markers: Dictionary = {}    # "A"/"B"/"C" -> Marker3D
var board: Node3D = null

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt: Label3D = $Board/Prompt

func _ready() -> void:
	add_to_group("interactive_prop")
	hud = get_node_or_null(hud_path) as CanvasLayer
	doors = _collect_doors(doors_path)
	crates = _collect_children(crates_path)
	cases = _collect_children(cases_path)
	cart = get_node_or_null(cart_path)
	kill_zone = get_node_or_null(kill_zone_path) as Area3D
	lane_markers = _collect_named(lanes_path)
	board = get_node_or_null(board_path) as Node3D
	player = get_tree().get_first_node_in_group("player") as Node3D
	for step in STEP_ORDER:
		if doors.has(step) and doors[step].has_signal("door_sealed"):
			doors[step].door_sealed.connect(_on_door_sealed)
	if cart and cart.has_method("reset_to_stage"):
		cart.call("reset_to_stage")
	for c in cases:
		if c and c.has_method("reset_to_stage"):
			c.call("reset_to_stage")
	call_deferred("_register_objective")
	_refresh_prompt()
	_update_hud()

func _register_objective() -> void:
	objective_manager = get_tree().root.find_child("ObjectiveManager", true, false)
	if objective_manager and objective_manager.has_method("add_objective"):
		var objectives: Dictionary = objective_manager.get("objectives")
		if not objectives.has(OBJECTIVE_ID):
			objective_manager.add_objective(OBJECTIVE_ID, OBJECTIVE_TITLE, 1)

func _process(delta: float) -> void:
	if state != RunState.ACTIVE:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	# Leak pressure at the ACTIVE lane only (max 6 simultaneous).
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL and _active_leakers() < MAX_LEAKERS:
		spawn_timer = 0.0
		_spawn_leaker()
	# Order-enforced sealing: only the current unsealed step may progress.
	for step in STEP_ORDER:
		var door: Node = doors.get(step)
		if door == null or not is_instance_valid(door):
			continue
		if not bool(door.get("sealed")):
			door.call("seal_tick", delta)
			break
	# Crowd failure: 6 hostiles across the interior red line.
	if kill_zone and _zombies_in_zone() >= KILLZONE_CROWD_LIMIT:
		_fail_run("ROUTE LOST — RETREAT AND RESET")
		return
	_check_player_death()
	if time_remaining <= 0.0:
		_fail_run("SEALDOWN FAILED — ROUTE LOST")
		return
	_update_hud()

## Start the seal-down (probe/tests and the in-world START prompt both use this).
func interact() -> void:
	if state == RunState.IDLE:
		_start_run()

func start_run() -> void:
	interact()

func _start_run() -> void:
	if player == null or (player.get("is_dead") != null and bool(player.get("is_dead"))):
		return
	state = RunState.ACTIVE
	time_remaining = RUN_DURATION
	step_index = 0
	current_step = STEP_ORDER[0]
	is_won = false
	spawn_timer = 0.0
	leak_count = 0
	for step in STEP_ORDER:
		var door: Node = doors.get(step)
		if door and is_instance_valid(door) and door.has_method("reset_door"):
			door.call("reset_door")
	for c in crates:
		if c and is_instance_valid(c) and c.has_method("reset_crate"):
			c.call("reset_crate")
	if cart and is_instance_valid(cart) and cart.has_method("reset_to_stage"):
		cart.call("reset_to_stage")
	for c in cases:
		if c and is_instance_valid(c) and c.has_method("reset_to_stage"):
			c.call("reset_to_stage")
	interaction_zone.set_deferred("monitoring", false)
	prompt.visible = false
	if hud:
		hud.visible = true
	_open_active_breach()
	_update_hud()

func _on_door_sealed(step: String) -> void:
	if state != RunState.ACTIVE or is_won:
		return
	if step != STEP_ORDER[step_index]:
		return  # order guard: a later socket never banks before the current one
	step_index += 1
	if step_index >= STEP_ORDER.size():
		_win_run()
		return
	current_step = STEP_ORDER[step_index]
	_open_active_breach()
	_update_hud()

func _open_active_breach() -> void:
	# The next breach lane opens; zombies start entering at that lane.
	var door: Node = doors.get(current_step)
	if door and is_instance_valid(door) and door.has_method("open_fully"):
		door.call("open_fully")

func _win_run() -> void:
	if state != RunState.ACTIVE:
		return
	state = RunState.WON
	is_won = true
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress(OBJECTIVE_ID, 1)
	_show_result("SERVICE ROUTE SEALED")
	_refresh_prompt()

func _fail_run(message: String) -> void:
	if state != RunState.ACTIVE:
		return
	state = RunState.FAILED
	_show_result(message)
	_refresh_prompt()
	get_tree().create_timer(FAILURE_RESET_DELAY).timeout.connect(_reset_after_failure)

func _reset_after_failure() -> void:
	if state != RunState.FAILED:
		return
	state = RunState.IDLE
	time_remaining = RUN_DURATION
	step_index = 0
	current_step = STEP_ORDER[0]
	spawn_timer = 0.0
	leak_count = 0
	for step in STEP_ORDER:
		var door: Node = doors.get(step)
		if door and is_instance_valid(door) and door.has_method("reset_door"):
			door.call("reset_door")
	for c in crates:
		if c and is_instance_valid(c) and c.has_method("reset_crate"):
			c.call("reset_crate")
	if cart and is_instance_valid(cart) and cart.has_method("reset_to_stage"):
		cart.call("reset_to_stage")
	for c in cases:
		if c and is_instance_valid(c) and c.has_method("reset_to_stage"):
			c.call("reset_to_stage")
	interaction_zone.set_deferred("monitoring", true)
	_hide_result()
	_refresh_prompt()
	_update_hud()

func _spawn_leaker() -> void:
	var inst := ZOMBIE_SCENE.instantiate()
	var lane: Node3D = lane_markers.get(current_step)
	var spawn_pos: Vector3 = lane.global_position if lane else global_position + Vector3(0, 0, -14)
	get_tree().current_scene.add_child(inst)
	inst.global_position = spawn_pos + Vector3(0, 0.1, 0)
	if not inst.is_in_group("enemies"):
		inst.add_to_group("enemies")
	leak_count += 1

func _active_leakers() -> int:
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			count += 1
	return count

func _zombies_in_zone() -> int:
	if kill_zone == null:
		return 0
	# Count only hostiles actually INSIDE the BreachKillZone volume (the marked
	# interior red-line area), by geometry — not by world radius, so unrelated
	# world zombies elsewhere can never trip the activity's fail condition.
	var center: Vector3 = kill_zone.global_position
	var half: Vector3 = Vector3(7.0, 2.0, 5.0)  # matches the zone's BoxShape3D
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: Vector3 = e.global_position - center
		if absf(d.x) <= half.x and absf(d.y) <= half.y + 2.0 and absf(d.z) <= half.z:
			count += 1
	return count

func _check_player_death() -> void:
	if player != null and player.get("is_dead") != null and bool(player.get("is_dead")):
		_fail_run("ROUTE LOST — RETREAT AND RESET")

func _refresh_prompt() -> void:
	if prompt == null:
		return
	prompt.visible = state == RunState.IDLE

func _update_hud() -> void:
	if hud == null:
		return
	var timer: Label = hud.get_node_or_null("Panel/Margin/Rows/TimerText")
	if timer:
		timer.text = "SEALDOWN: %02d s" % ceili(time_remaining)
		timer.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2) if time_remaining <= 30.0 else Color(1.0, 0.85, 0.6))
	var step_names := {"A": "INTAKE", "B": "LAUNDRY", "C": "LOADING BAY"}
	for step in STEP_ORDER:
		var door: Node = doors.get(step)
		if door == null:
			continue
		var row: Label = hud.get_node_or_null("Panel/Margin/Rows/Step%sRow" % step)
		if row:
			var done: bool = bool(door.get("sealed"))
			var label: String = "%s — %s" % [step, step_names.get(step, step)]
			row.text = ("%s: SEALED" % label) if done else ("%s: BREACH" % label)
			row.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if done else Color(1.0, 0.45, 0.2))
	var active: Label = hud.get_node_or_null("Panel/Margin/Rows/ActiveText")
	if active:
		active.text = "BREACH ACTIVE: %s" % current_step
	var warning: Label = hud.get_node_or_null("Panel/Margin/Rows/Warning")
	if warning:
		warning.text = "BRACE THE DOOR WITH ITS SUPPLY" if state == RunState.ACTIVE else ""
	_update_board_lamps()
	hud.visible = state != RunState.IDLE

func _update_board_lamps() -> void:
	if board == null:
		return
	for step in STEP_ORDER:
		var lamp: MeshInstance3D = board.get_node_or_null("Lamp%s" % step) as MeshInstance3D
		if lamp == null:
			continue
		var door: Node = doors.get(step)
		var done: bool = door != null and bool(door.get("sealed"))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.9, 0.35) if done else Color(0.9, 0.2, 0.15)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 0.35) if done else Color(0.9, 0.2, 0.15)
		mat.emission_energy_multiplier = 2.5 if done else 1.2
		lamp.material_override = mat

func _show_result(message: String) -> void:
	if hud == null:
		return
	var result: Label = hud.get_node_or_null("Result")
	if result:
		result.text = message
		result.visible = true
	hud.visible = true

func _hide_result() -> void:
	if hud == null:
		return
	var result: Label = hud.get_node_or_null("Result")
	if result:
		result.visible = false

func _collect_children(path: NodePath) -> Array[Node]:
	var container := get_node_or_null(path)
	if container == null:
		return []
	var out: Array[Node] = []
	for c in container.get_children():
		out.append(c)
	return out

func _collect_named(path: NodePath) -> Dictionary:
	var container := get_node_or_null(path)
	var out := {}
	if container == null:
		return out
	for c in container.get_children():
		out[c.name] = c
	return out

func _collect_doors(path: NodePath) -> Dictionary:
	# Quote-break doors by their seal_step (A/B/C), not their node name, so the
	# step-order logic can look them up directly.
	var container := get_node_or_null(path)
	var out := {}
	if container == null:
		return out
	for c in container.get_children():
		out[c.get("seal_step")] = c
	return out
