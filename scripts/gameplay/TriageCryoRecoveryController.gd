extends Node3D
class_name TriageCryoRecoveryController

## TriageCryoRecoveryController — state machine + rules engine for the Triage
## Roundup Bio-Lab variant (spec: docs/specs/LEVEL3_MINIGAMES_A.md §1).
##
## Four contained cryo-pods (alpha/beta/gamma/delta) must be shoved back into
## their matching recovery bays before a 90s overrun clock expires. Bays run a
## 1.25s stable-dwell capture; wrong-type pods bounce out; escapes cost 8s.
## Reports to ObjectiveManager exactly once on win (l3_triage_cryo_recovery).
## Loot tier from WorldProgression.get_active_loot_tier() is passed through
## to the loot-drop path on victory.

@export var objective_id: String = "l3_triage_cryo_recovery"
@export var objective_title: String = "Recover cryo-pods from containment"
const RUN_DURATION := 90.0
const ESCAPE_PENALTY := 8.0
const FAILURE_RESET_DELAY := 3.0
const OVERRUN_SETTLE := 2.0
const HALL_HALF_EXTENT := Vector3(11.0, 4.0, 22.0)

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var hud_path: NodePath = ^"../TriageHUD"
@export var pens_path: NodePath = ^"../Bays"
@export var animals_path: NodePath = ^"../Pods"
@export var overrun_zone_path: NodePath = ^"../OverrunZone"
@export var gate_region: int = 3  # Bio-Lab = Region 3

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
var last_loot_tier: int = 0

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt: Label3D = $Board/Prompt

func _ready() -> void:
	if gate_region > 0:
		var wp: Node = get_node_or_null("/root/WorldProgression")
		if wp == null or not wp.has_method("can_hop") or not bool(wp.call("can_hop", gate_region)):
			queue_free()
			return
	add_to_group("interactive_prop")
	hud = get_node_or_null(hud_path) as CanvasLayer
	pens = _collect_children(pens_path)
	animals = _collect_children(animals_path)
	overrun_zone = get_node_or_null(overrun_zone_path) as Area3D
	player = get_tree().get_first_node_in_group("player") as Node3D
	for pen in pens:
		if pen and pen.has_signal("pod_delivered"):
			pen.pod_delivered.connect(_on_pod_delivered)
	for animal in animals:
		if animal and animal.has_method("reset_to_stall"):
			animal.set("stall_position", animal.global_position)
			animal.call("reset_to_stall")
	call_deferred("_register_objective")
	_refresh_prompt()
	_update_hud()

func _register_objective() -> void:
	objective_manager = get_tree().root.find_child("ObjectiveManager", true, false)
	if objective_manager and objective_manager.has_method("add_objective"):
		var objectives: Dictionary = objective_manager.get("objectives")
		if not objectives.has(objective_id):
			objective_manager.add_objective(objective_id, objective_title, 1)

func _process(delta: float) -> void:
	if state != RunState.ACTIVE:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	for pen in pens:
		if is_instance_valid(pen):
			pen.call("process_capture", delta)
	_check_escapes()
	_check_overrun(delta)
	_check_player_death()
	if time_remaining <= 0.0:
		_fail_run("CRYO RECOVERY OVERRUN — TRY AGAIN")
		return
	_update_hud()

## Start the round (probe/tests and the in-world START prompt both use this).
func interact() -> void:
	if state == RunState.IDLE:
		if gate_region > 0:
			var wp: Node = get_node_or_null("/root/WorldProgression")
			if wp != null and wp.has_method("can_hop") and not bool(wp.call("can_hop", gate_region)):
				if prompt:
					prompt.text = "BIO-LAB ACCESS REQUIRED"
				return
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

func _on_pod_delivered(pod_type: String, _pen: Node) -> void:
	if state != RunState.ACTIVE or is_won:
		return
	if pod_type in delivered_types:
		return
	delivered_types.append(pod_type)
	for animal in animals:
		if is_instance_valid(animal) and _type_of(animal) == pod_type:
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
		objective_manager.update_progress(objective_id, 1)
		var wp: Node = get_node_or_null("/root/WorldProgression")
		last_loot_tier = int(wp.call("get_active_loot_tier")) if wp != null and wp.has_method("get_active_loot_tier") else 1
		_show_result("ALL CRYO-PODS RECOVERED")
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
		hud_flash = "%s ESCAPED — 8s LOST" % String(_type_of(animal)).to_upper()

func _check_overrun(delta: float) -> void:
	if overrun_zone == null:
		return
	var center: Vector3 = overrun_zone.global_position
	var half: Vector3 = Vector3(8.0, 2.0, 4.0)
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
		_fail_run("CRYO RECOVERY OVERRUN — TRY AGAIN")

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
		var t: String = String(_pen_required_type(pen))
		# HUD rows are named CryoAlphaRow, CryoBetaRow, etc.
		var row_name: String = t.replace("cryo_", "Cryo") + "Row"
		var row: Label = hud.get_node_or_null("Panel/Margin/Rows/%s" % row_name)
		if row:
			var done: bool = t in delivered_types
			row.text = "%s — RECOVERED" % t.to_upper() if done else "%s — LOOSE" % t.to_upper()
			row.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if done else Color(1.0, 0.75, 0.25))
	var warning: Label = hud.get_node_or_null("Panel/Margin/Rows/Warning")
	if warning:
		var msg: String = hud_flash if hud_flash != "" else ("%d/4 PODS RETURNED" % delivered_types.size())
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

func _has_prop(obj: Object, prop: String) -> bool:
	for pi in obj.get_property_list():
		if String(pi.get("name", "")) == prop:
			return true
	return false

func _type_of(body: Node) -> String:
	if _has_prop(body, "pod_type"):
		return String(body.get("pod_type"))
	if _has_prop(body, "unit_type"):
		return String(body.get("unit_type"))
	if _has_prop(body, "animal_type"):
		return String(body.get("animal_type"))
	return ""

func _pen_required_type(pen: Node) -> String:
	if _has_prop(pen, "required_pod_type"):
		return String(pen.get("required_pod_type"))
	if _has_prop(pen, "required_unit_type"):
		return String(pen.get("required_unit_type"))
	if _has_prop(pen, "required_animal_type"):
		return String(pen.get("required_animal_type"))
	return ""

func _collect_children(path: NodePath) -> Array[Node]:
	var container := get_node_or_null(path)
	if container == null:
		return []
	var out: Array[Node] = []
	for c in container.get_children():
		out.append(c)
	return out