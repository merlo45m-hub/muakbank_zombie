extends Node3D
class_name LastStandStationController

const OBJECTIVE_ID := "l1_last_stand"
const OBJECTIVE_TITLE := "Survive 3 checkpoint assault waves"
const PREP_TIME := 10.0
const INTERMISSION_TIME := 12.0
const DESERTION_LIMIT := 6.0

const RUNNER_SCENE: PackedScene = preload("res://scenes/characters/zombie_runner.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/characters/zombie_spitter.tscn")
const BUTCHER_SCENE: PackedScene = preload("res://scenes/characters/zombie_butcher.tscn")

@export var hud_path: NodePath = ^"../LastStandHUD"
@export var terminal_path: NodePath = ^"../CheckpointTerminal"
@export var perimeter_path: NodePath = ^"../PerimeterBoundaryZone"
@export var crate_path: NodePath = ^"../SupplyDropCrate"

enum TrialState { IDLE, PREPARING, ACTIVE, INTERMISSION, WON, FAILED }

var state: TrialState = TrialState.IDLE
var wave: int = 0
var timer: float = 0.0
var desertion_time: float = 0.0
var player: Node3D
var objective_manager: Node
var hud: CanvasLayer
var terminal: Node3D
var supply_crate: Node3D
var perimeter: Area3D
var player_inside: bool = false
var is_won: bool = false
var active_enemies: Array[Node3D] = []
var ammo_totals: Dictionary = {"pistol": 15, "shotgun": 8}
var tracked_weapon: String = ""
var syncing_ammo: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	objective_manager = get_tree().root.find_child("ObjectiveManager", true, false)
	hud = get_node_or_null(hud_path) as CanvasLayer
	terminal = get_node_or_null(terminal_path) as Node3D
	perimeter = get_node_or_null(perimeter_path) as Area3D
	supply_crate = get_node_or_null(crate_path) as Node3D
	if perimeter:
		perimeter.body_entered.connect(_on_perimeter_body_entered)
		perimeter.body_exited.connect(_on_perimeter_body_exited)
	if objective_manager and objective_manager.has_method("add_objective"):
		var objectives: Dictionary = objective_manager.get("objectives")
		if not objectives.has(OBJECTIVE_ID):
			objective_manager.add_objective(OBJECTIVE_ID, OBJECTIVE_TITLE, 1)
	_update_hud()

func _process(delta: float) -> void:
	if state == TrialState.IDLE or state == TrialState.WON or state == TrialState.FAILED:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("is_dead") == true:
		_fail_trial("TRIAL FAILED — SURVIVOR DOWN")
		return
	if player_inside:
		desertion_time = 0.0
	else:
		desertion_time += delta
		if desertion_time > DESERTION_LIMIT:
			_fail_trial("TRIAL FAILED — DESERTION")
			return
	if state == TrialState.PREPARING or state == TrialState.INTERMISSION:
		timer = maxf(0.0, timer - delta)
		if timer <= 0.0:
			if state == TrialState.PREPARING:
				_start_wave(1)
			else:
				_start_wave(wave + 1)
	elif state == TrialState.ACTIVE:
		_prune_enemies()
		if active_enemies.is_empty():
			_on_wave_cleared()
	_update_hud()

func start_trial() -> void:
	if state != TrialState.IDLE:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("is_dead") == true:
		return
	state = TrialState.PREPARING
	wave = 0
	timer = PREP_TIME
	desertion_time = 0.0
	player_inside = true
	_prepare_weapons()
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("ACTIVE")
	_update_hud()

func _prepare_weapons() -> void:
	var weapon_system: Node = player.get("weapon_system")
	if weapon_system == null:
		return
	if weapon_system.has_method("add_weapon_to_inventory"):
		weapon_system.add_weapon_to_inventory("pistol")
		weapon_system.add_weapon_to_inventory("shotgun")
	if weapon_system.has_signal("weapon_equipped"):
		if not weapon_system.weapon_equipped.is_connected(_on_weapon_equipped):
			weapon_system.weapon_equipped.connect(_on_weapon_equipped)
	if weapon_system.has_signal("ammo_changed"):
		if not weapon_system.ammo_changed.is_connected(_on_ammo_changed):
			weapon_system.ammo_changed.connect(_on_ammo_changed)
	ammo_totals = {"pistol": 15, "shotgun": 8}
	weapon_system.equip_weapon("pistol")
	tracked_weapon = "pistol"
	weapon_system.current_ammo = int(ammo_totals["pistol"])

func _on_weapon_equipped(_weapon_data: Dictionary) -> void:
	var weapon_system: Node = player.get("weapon_system") if player else null
	if weapon_system == null:
		return
	tracked_weapon = str(weapon_system.get("current_weapon"))
	if ammo_totals.has(tracked_weapon):
		weapon_system.set("current_ammo", int(ammo_totals[tracked_weapon]))

func _on_ammo_changed(current: int, _maximum: int) -> void:
	if not syncing_ammo and ammo_totals.has(tracked_weapon):
		ammo_totals[tracked_weapon] = current

func _start_wave(wave_number: int) -> void:
	wave = wave_number
	state = TrialState.ACTIVE
	timer = 0.0
	if supply_crate and supply_crate.has_method("set_available"):
		supply_crate.set_available(false)
	var compositions: Array[Array] = [
		[14, 0, 0],
		[8, 2, 0],
		[10, 0, 1]
	]
	var composition: Array = compositions[clampi(wave - 1, 0, 2)]
	for i in range(int(composition[0])):
		_spawn_enemy(RUNNER_SCENE, _spawn_position(i))
	for i in range(int(composition[1])):
		_spawn_enemy(SPITTER_SCENE, _spawn_position(i + 4))
	for i in range(int(composition[2])):
		_spawn_enemy(BUTCHER_SCENE, _spawn_position(i + 8))
	_update_hud()

func _spawn_position(index: int) -> Vector3:
	var angle := TAU * float(index % 8) / 8.0
	return global_position + Vector3(cos(angle) * 3.8, 0.0, sin(angle) * 3.2)

func _spawn_enemy(scene: PackedScene, spawn_position: Vector3) -> void:
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_position
	active_enemies.append(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)

func _on_enemy_died(enemy: Node3D) -> void:
	active_enemies.erase(enemy)

func _prune_enemies() -> void:
	for enemy in active_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			active_enemies.erase(enemy)

func _on_wave_cleared() -> void:
	if wave >= 3:
		_win_trial()
		return
	state = TrialState.INTERMISSION
	timer = INTERMISSION_TIME
	if supply_crate and supply_crate.has_method("set_available"):
		supply_crate.set_available(true)
	_update_hud()

func claim_supply_drop() -> bool:
	if state != TrialState.INTERMISSION:
		return false
	var weapon_system: Node = player.get("weapon_system") if player else null
	if weapon_system == null:
		return false
	var additions: Dictionary = {"pistol": 14, "shotgun": 6} if wave == 1 else {"pistol": 16, "shotgun": 8}
	syncing_ammo = true
	for weapon_id in additions:
		var new_total := int(ammo_totals.get(weapon_id, 0)) + int(additions[weapon_id])
		weapon_system.equip_weapon(weapon_id)
		weapon_system.add_ammo(int(additions[weapon_id]))
		ammo_totals[weapon_id] = new_total
		weapon_system.set("current_ammo", new_total)
	weapon_system.equip_weapon("pistol")
	syncing_ammo = false
	if wave == 2 and player.has_method("heal"):
		player.heal(50)
	elif player.has_method("heal"):
		player.heal(15)
	return true

func _win_trial() -> void:
	if is_won:
		return
	is_won = true
	state = TrialState.WON
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("COMPLETED")
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress(OBJECTIVE_ID, 1)
	_update_hud()

func _fail_trial(message: String) -> void:
	state = TrialState.FAILED
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("FAILED")
	if supply_crate and supply_crate.has_method("set_available"):
		supply_crate.set_available(false)
	if hud:
		var status := hud.get_node_or_null("Panel/Layout/Status") as Label
		if status:
			status.text = message
	var reset_timer := get_tree().create_timer(8.0)
	reset_timer.timeout.connect(_reset_trial)

func _reset_trial() -> void:
	if state != TrialState.FAILED:
		return
	state = TrialState.IDLE
	wave = 0
	timer = 0.0
	desertion_time = 0.0
	is_won = false
	if terminal and terminal.has_method("set_trial_state"):
		terminal.set_trial_state("IDLE")
	_update_hud()

func _on_perimeter_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		desertion_time = 0.0

func _on_perimeter_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _update_hud() -> void:
	if hud:
		var status := hud.get_node_or_null("Panel/Layout/Status") as Label
		var warning := hud.get_node_or_null("Panel/Layout/Warning") as Label
		var remaining := active_enemies.size()
		var phase_text := "STATION READY"
		match state:
			TrialState.PREPARING:
				phase_text = "PREPARE: %.0f" % ceilf(timer)
			TrialState.ACTIVE:
				phase_text = "WAVE %d/3 — HOSTILES: %d" % [wave, remaining]
			TrialState.INTERMISSION:
				phase_text = "RESUPPLY: %.0f" % ceilf(timer)
			TrialState.WON:
				phase_text = "GATE CLEARED — TRANSIT OPEN"
			TrialState.FAILED:
				phase_text = "TRIAL FAILED — REARM AND RETRY"
		if status:
			status.text = phase_text
		if warning:
			warning.text = "DESERTION: %.1fs / 6.0s" % desertion_time if state != TrialState.IDLE else ""
