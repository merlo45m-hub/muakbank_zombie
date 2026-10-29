extends Node3D
class_name TriageRoundupController

## TriageRoundupController — state machine + rules engine for the Triage Roundup
## mini-game (spec: docs/specs/LEVEL1_MINIGAMES_B.md §1).
##
## Four frightened zombie pets (dog/cat/rabbit/chicken) must be shoved back into
## their matching ward pens before a 90s overrun clock expires. Pens run a
## 1.25s stable-dwell capture; wrong-type animals bounce out; escapes cost 8s.
## Reports to ObjectiveManager exactly once on win (l1_triage_roundup).

const OBJECTIVE_ID := "l1_triage_roundup"
const OBJECTIVE_TITLE := "Return escaped animals"
const RUN_DURATION := 90.0
const ESCAPE_PENALTY := 8.0
const FAILURE_RESET_DELAY := 3.0
const OVERRUN_SETTLE := 2.0
const HALL_HALF_EXTENT := Vector3(11.0, 4.0, 22.0)

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var hud_path: NodePath = ^"../TriageHUD"
@export var pens_path: NodePath = ^"../Pens"
@export var animals_path: NodePath = ^"../Animals"
@export var overrun_zone_path: NodePath = ^"../OverrunZone"

var state: RunState = RunState.IDLE
var time_remaining: float = RUN_DURATION
var delivered_types: Array[String] = []
var is_won: bool = false

var objective_manager: Node = null
var player: Node3D = null
var hud: CanvasLayer = null
var pens: Array[Node] = []
var animals: Array[Node] = []
var overrun_zone: Area3D = null
var overrun_dwell: float = 0.0
var hud_flash: String = ""

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt: Label3D = $Board/Prompt

func _ready() -> void:
	add_to_group("interactive_prop")
	hud = get_node_or_null(hud_path) as CanvasLayer
	pens = _collect_children(pens_path)
	animals = _collect_children(animals_path)
	overrun_zone = get_node_or_null(overrun_zone_path) as Area3D
	player = get_tree().get_first_node_in_group("player") as Node3D
	for pen in pens:
		if pen and pen.has_signal("animal_delivered"):
			pen.animal_delivered.connect(_on_animal_delivered)
	for animal in animals:
		if animal and animal.has_method("reset_to_stall"):
			# The scene placement IS the release stall; record it before reset.
			animal.set("stall_position", animal.global_position)
			animal.call("reset_to_stall")
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
	# Pens run the stable-dwell capture; deliveries arrive via signal.
	for pen in pens:
		if is_instance_valid(pen):
			pen.call("process_capture", delta)
	_check_escapes()
	_check_overrun(delta)
	_check_player_death()
	if time_remaining <= 0.0:
		_fail_run("TRIAGE OVERRUN — TRY AGAIN")
		return
	_update_hud()

## Start the round (probe/tests and the in-world START prompt both use this).
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
	delivered_types.clear()
	is_won = false
	overrun_dwell = 0.0
	hud_flash = ""
	for animal in animals:
		if is_instance_valid(animal) and animal.has_method("reset_to_stall"):
			animal.call("reset_to_stall")
	for pen in pens:
		if is_instance_valid(pen) and pen.has_method("reset_pen"):
			pen.call("reset_pen")
	interaction_zone.set_deferred("monitoring", false)
	prompt.visible = false
	if hud:
		hud.visible = true
	_update_hud()

func _on_animal_delivered(animal_type: String, _pen: Node) -> void:
	if state != RunState.ACTIVE or is_won:
		return
	if animal_type in delivered_types:
		return  # unique-delivery guard: a duplicate signal cannot double-count
	delivered_types.append(animal_type)
	# Park the matching body inside its pen so later collisions cannot undo it.
	for animal in animals:
		if is_instance_valid(animal) and animal.get("animal_type") == animal_type:
			animal.call("park_at", _pen.global_position + Vector3(0, 0.3, 0))
			break
	if delivered_types.size() >= 4:
		_win_run()
	else:
		_update_hud()

func _win_run() -> void:
	if state != RunState.ACTIVE:
		return
	state = RunState.WON
	is_won = true
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress(OBJECTIVE_ID, 1)
	_show_result("ALL PATIENTS ACCOUNTED FOR")
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
	delivered_types.clear()
	overrun_dwell = 0.0
	hud_flash = ""
	for animal in animals:
		if is_instance_valid(animal) and animal.has_method("reset_to_stall"):
			animal.call("reset_to_stall")
	for pen in pens:
		if is_instance_valid(pen) and pen.has_method("reset_pen"):
			pen.call("reset_pen")
	interaction_zone.set_deferred("monitoring", true)
	_hide_result()
	_refresh_prompt()
	_update_hud()

func _check_escapes() -> void:
	if hud_flash != "":
		hud_flash = ""
	for animal in animals:
		if not is_instance_valid(animal) or bool(animal.get("delivered")):
			continue
		var d: Vector3 = animal.global_position - global_position
		if absf(d.x) > HALL_HALF_EXTENT.x or absf(d.z) > HALL_HALF_EXTENT.z:
			animal.call("reset_to_stall")
			time_remaining = maxf(0.0, time_remaining - ESCAPE_PENALTY)
			hud_flash = "%s ESCAPED — 8s LOST" % String(animal.get("animal_type")).to_upper()

func _check_overrun(delta: float) -> void:
	if overrun_zone == null:
		return
	# Hostile intrusion counts only inside the HallOverrunZone volume geometry,
	# so unrelated world zombies elsewhere can never trip the activity fail.
	var center: Vector3 = overrun_zone.global_position
	var half: Vector3 = Vector3(8.0, 2.0, 4.0)  # matches the zone's BoxShape3D
	var hostile_inside := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: Vector3 = e.global_position - center
		if absf(d.x) <= half.x and absf(d.y) <= half.y + 2.0 and absf(d.z) <= half.z:
			hostile_inside = true
			break
	if hostile_inside:
		overrun_dwell += delta
		if overrun_dwell >= OVERRUN_SETTLE:
			_fail_run("HALL OVERRUN — TRY AGAIN")
	else:
		overrun_dwell = 0.0

func _check_player_death() -> void:
	if player != null and player.get("is_dead") != null and bool(player.get("is_dead")):
		_fail_run("TRIAGE OVERRUN — TRY AGAIN")

func _refresh_prompt() -> void:
	if prompt == null:
		return
	prompt.visible = state == RunState.IDLE

func _update_hud() -> void:
	if hud == null:
		return
	var timer: Label = hud.get_node_or_null("Panel/Margin/Rows/TimerText")
	if timer:
		timer.text = "OVERRUN CLOCK: %02d s" % ceili(time_remaining)
		timer.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2) if time_remaining <= 15.0 else Color(1.0, 0.85, 0.6))
	for pen in pens:
		if not is_instance_valid(pen):
			continue
		var t: String = String(pen.get("required_animal_type"))
		var row: Label = hud.get_node_or_null("Panel/Margin/Rows/%sRow" % t.capitalize())
		if row:
			var done: bool = t in delivered_types
			row.text = "%s — WARDED" % t.to_upper() if done else "%s — LOOSE" % t.to_upper()
			row.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if done else Color(1.0, 0.75, 0.25))
	var warning: Label = hud.get_node_or_null("Panel/Margin/Rows/Warning")
	if warning:
		var msg: String = hud_flash if hud_flash != "" else ("%d/4 PATIENTS RETURNED" % delivered_types.size())
		warning.text = msg
	hud.visible = state != RunState.IDLE

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
