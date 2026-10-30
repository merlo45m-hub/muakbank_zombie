extends Node3D
class_name ArmoryLockdownController

## ArmoryLockdownController — Mini-game cluster controller for SAND2 (Industrial District).
## Embeds BreakableSupplyCrate, CheckpointArmoryTerminal, and InteractiveDoor.
## Player activates the armory terminal, cracks the supply crates for gear/braces,
## and breaches/opens the security door to restore facility access.

const OBJECTIVE_ID := "l2_armory_salvage"
const OBJECTIVE_TITLE := "Recover armory supplies & breach lockdown"
const RUN_DURATION := 90.0

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var terminal_path: NodePath = ^"../Terminal"
@export var door_path: NodePath = ^"../ArmoryDoor"
@export var crate1_path: NodePath = ^"../Crate1"
@export var crate2_path: NodePath = ^"../Crate2"

var state: RunState = RunState.IDLE
var time_remaining: float = RUN_DURATION
var is_won: bool = false

var objective_manager: Node = null
var player: Node3D = null
var terminal: Node3D = null
var door: Node3D = null
var crate1: Node3D = null
var crate2: Node3D = null

func _ready() -> void:
	add_to_group("interactive_prop")
	terminal = get_node_or_null(terminal_path) as Node3D
	door = get_node_or_null(door_path) as Node3D
	crate1 = get_node_or_null(crate1_path) as Node3D
	crate2 = get_node_or_null(crate2_path) as Node3D
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
	print("[ArmoryLockdown] Trial started! Crack crates and breach armory door.")

func _process(delta: float) -> void:
	if state != RunState.ACTIVE:
		return

	time_remaining -= delta

	var c1_cracked: bool = bool(crate1.get("is_cracked")) if crate1 else true
	var c2_cracked: bool = bool(crate2.get("is_cracked")) if crate2 else true
	var door_open: bool = (bool(door.get("is_open")) or bool(door.get("is_half_open"))) if door else true

	if c1_cracked and c2_cracked and door_open:
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
	print("[ArmoryLockdown] WON! Armory lockdown cleared.")

func _fail_trial() -> void:
	state = RunState.FAILED
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("FAILED")
	print("[ArmoryLockdown] FAILED — lockdown timed out.")
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
