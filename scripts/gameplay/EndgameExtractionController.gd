extends Node3D
class_name EndgameExtractionController

## EndgameExtractionController — Campaign finale mini-game cluster controller for SAND3 (Endgame Heights).
## Embeds CheckpointArmoryTerminal, BreakableSupplyCrate, and InteractiveDoor.
## Player activates the emergency extraction terminal on the rooftop, breaches the maintenance door,
## and cracks the flare supply crate to signal the extraction chopper.

const OBJECTIVE_ID := "l3_rooftop_extraction"
const OBJECTIVE_TITLE := "Signal rooftop extraction & secure helipad"
const RUN_DURATION := 120.0

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var terminal_path: NodePath = ^"../Terminal"
@export var door_path: NodePath = ^"../MaintenanceDoor"
@export var crate_path: NodePath = ^"../FlareCrate"

var state: RunState = RunState.IDLE
var time_remaining: float = RUN_DURATION
var is_won: bool = false

var objective_manager: Node = null
var player: Node3D = null
var terminal: Node3D = null
var door: Node3D = null
var crate: Node3D = null

func _ready() -> void:
	add_to_group("interactive_prop")
	terminal = get_node_or_null(terminal_path) as Node3D
	door = get_node_or_null(door_path) as Node3D
	crate = get_node_or_null(crate_path) as Node3D
	player = get_tree().get_first_node_in_group("player") as Node3D
	call_deferred("_register_objective")

func _register_objective() -> void:
	objective_manager = get_tree().root.find_child("ObjectiveManager", true, false)
	if objective_manager and objective_manager.has_method("add_objective"):
		var objectives: Dictionary = objective_manager.get("objectives")
		if not objectives.has(OBJECTIVE_ID):
			objective_manager.add_objective(OBJECTIVE_ID, OBJECTIVE_TITLE, 1)

func start_trial() -> void:
	if state == RunState.ACTIVE or state == RunState.WON:
		return
	state = RunState.ACTIVE
	time_remaining = RUN_DURATION
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("ACTIVE")
	print("[EndgameExtraction] Extraction beacon activated! Breach door and crack flare crate.")

func _process(delta: float) -> void:
	if state != RunState.ACTIVE:
		return

	time_remaining -= delta

	var crate_cracked: bool = bool(crate.get("is_cracked")) if crate else true
	var door_open: bool = (bool(door.get("is_open")) or bool(door.get("is_half_open"))) if door else true

	if crate_cracked and door_open:
		_win_trial()
	elif time_remaining <= 0.0:
		_fail_trial()

func _win_trial() -> void:
	state = RunState.WON
	is_won = true
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("COMPLETED")
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress(OBJECTIVE_ID, 1)
	print("[EndgameExtraction] WON! Extraction beacon confirmed. Helipad secured.")

func _fail_trial() -> void:
	state = RunState.FAILED
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("FAILED")
	print("[EndgameExtraction] FAILED — extraction signal lost.")
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if state == RunState.FAILED:
			state = RunState.IDLE
			if terminal and terminal.has_method("set_trial_state"):
				terminal.set_trial_state("IDLE")
	)

func interact() -> void:
	if state == RunState.IDLE:
		start_trial()
