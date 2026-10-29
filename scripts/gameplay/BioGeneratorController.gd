extends Node3D
class_name BioGeneratorController

const OBJECTIVE_ID := "l1_generator_fed"
const OBJECTIVE_TITLE := "Power the Safe Zone Generator (90s)"
const RUN_DURATION := 90.0
const STARTING_FUEL := 40.0
const FUEL_DRAIN_PER_SECOND := 2.2
const BLACKOUT_RESERVE := 12.0
const FAILURE_RESET_DELAY := 5.0
const GENERATOR_MAX_HP := 400
const WALKER_SCENE: PackedScene = preload("res://scenes/characters/zombie_dog.tscn")
const RUNNER_SCENE: PackedScene = preload("res://scenes/characters/zombie_runner.tscn")
const BUTCHER_SCENE: PackedScene = preload("res://scenes/characters/zombie_butcher.tscn")

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var generator_path: NodePath = ^"../BioGenerator"
@export var hud_path: NodePath = ^"../GeneratorFedHUD"
@export var fence_path: NodePath = ^"../UVFence"

var state: RunState = RunState.IDLE
var fuel: float = 0.0
var generator_hp: int = GENERATOR_MAX_HP
var time_remaining: float = RUN_DURATION
var blackout_remaining: float = BLACKOUT_RESERVE
var wave_stage: int = 0
var objective_manager: Node
var player: Node3D
var generator: Node3D
var hud: CanvasLayer
var fence: Node3D
var _damage_tick: float = 0.0
var _player_in_console_zone: bool = false

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt: Label3D = $Prompt
@onready var status_light: MeshInstance3D = $Console/StatusLight
@onready var floodlights: Node3D = get_node_or_null("../Floodlights")

func _ready() -> void:
	add_to_group("interactive_prop")
	generator = get_node_or_null(generator_path) as Node3D
	hud = get_node_or_null(hud_path) as CanvasLayer
	fence = get_node_or_null(fence_path) as Node3D
	player = get_tree().get_first_node_in_group("player") as Node3D
	interaction_zone.body_entered.connect(_on_interaction_zone_body_entered)
	interaction_zone.body_exited.connect(_on_interaction_zone_body_exited)
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
	if fuel > 0.0:
		fuel = maxf(0.0, fuel - FUEL_DRAIN_PER_SECOND * delta)
		if fuel <= 0.0:
			blackout_remaining = BLACKOUT_RESERVE
	else:
		blackout_remaining = maxf(0.0, blackout_remaining - delta)
		if blackout_remaining <= 0.0:
			_fail_run("GENERATOR LOST — REBOOT AVAILABLE IN 5s")
			return
	_damage_tick += delta
	if _damage_tick >= 1.0:
		_damage_tick = 0.0
		_check_zombies_at_generator()
	_check_player_death()
	_check_wave_schedule()
	_sync_power_state()
	if time_remaining <= 0.0:
		if fuel > 0.0 and generator_hp > 0:
			_win_run()
		else:
			_fail_run("GENERATOR LOST — REBOOT AVAILABLE IN 5s")
			return
	_update_hud()

func interact() -> void:
	if state == RunState.IDLE:
		_start_run()

func start_run() -> void:
	interact()

func add_fuel(amount: float) -> void:
	if state != RunState.ACTIVE or amount <= 0.0:
		return
	fuel = minf(100.0, fuel + amount)
	if fuel > 0.0:
		blackout_remaining = BLACKOUT_RESERVE
	_sync_power_state()
	_update_hud()

func damage_generator(amount: int) -> void:
	if state != RunState.ACTIVE or amount <= 0:
		return
	generator_hp = maxi(0, generator_hp - amount)
	if generator_hp == 0:
		_fail_run("GENERATOR LOST — REBOOT AVAILABLE IN 5s")
	else:
		_update_hud()

func _start_run() -> void:
	if player == null or (player.get("is_dead") != null and bool(player.get("is_dead"))):
		return
	state = RunState.ACTIVE
	fuel = STARTING_FUEL
	generator_hp = GENERATOR_MAX_HP
	time_remaining = RUN_DURATION
	blackout_remaining = BLACKOUT_RESERVE
	wave_stage = 0
	status_light.material_override = _emissive_material(Color(0.15, 0.9, 0.35))
	prompt.visible = false
	_sync_power_state()
	_spawn_wave(0)
	_update_hud()

func _win_run() -> void:
	if state != RunState.ACTIVE or fuel <= 0.0 or generator_hp <= 0:
		return
	state = RunState.WON
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress(OBJECTIVE_ID, 1)
	if fence and fence.has_method("set_powered"):
		fence.set_powered(false)
	_trigger_victory_pulse()
	_show_result("GRID ONLINE")
	_refresh_prompt()

func _fail_run(message: String) -> void:
	if state != RunState.ACTIVE:
		return
	state = RunState.FAILED
	_sync_power_state()
	_show_result(message)
	_refresh_prompt()
	get_tree().create_timer(FAILURE_RESET_DELAY).timeout.connect(_reset_after_failure)

func _reset_after_failure() -> void:
	if state != RunState.FAILED:
		return
	state = RunState.IDLE
	fuel = 0.0
	generator_hp = GENERATOR_MAX_HP
	time_remaining = RUN_DURATION
	blackout_remaining = BLACKOUT_RESERVE
	wave_stage = 0
	interaction_zone.set_deferred("monitoring", true)
	status_light.material_override = _emissive_material(Color(0.95, 0.55, 0.08))
	_hide_result()
	_refresh_prompt()
	_update_hud()

func _sync_power_state() -> void:
	var powered := state == RunState.ACTIVE and fuel > 0.0
	if fence and fence.has_method("set_powered"):
		fence.set_powered(powered)
	_set_floodlights(powered)
	if generator:
		generator.set_meta("engine_running", powered)

func _set_floodlights(enabled: bool) -> void:
	if not floodlights:
		return
	for light in floodlights.get_children():
		if light is OmniLight3D:
			light.visible = enabled
			light.light_energy = 4.0 if enabled and fuel >= 25.0 else (1.2 if enabled else 0.0)
			light.light_color = Color(1.0, 0.72, 0.25) if fuel < 25.0 else Color(0.72, 0.88, 1.0)

func _trigger_victory_pulse() -> void:
	if not floodlights:
		return
	for light in floodlights.get_children():
		if light is OmniLight3D:
			light.visible = true
			light.light_color = Color(0.25, 1.0, 0.42)
			light.light_energy = 5.0

func _update_hud() -> void:
	if not hud:
		return
	hud.get_node("Panel/Margin/Rows/TimerText").text = "GRID SYNC: %02d s" % ceili(time_remaining)
	hud.get_node("Panel/Margin/Rows/FuelText").text = "FUEL: %d%%" % floori(fuel)
	hud.get_node("Panel/Margin/Rows/FuelBar").value = fuel
	hud.get_node("Panel/Margin/Rows/HealthText").text = "GENERATOR: %d HP" % generator_hp
	var warning: Label = hud.get_node("Panel/Margin/Rows/Warning")
	warning.text = "BLACKOUT RESERVE: %02d s" % ceili(blackout_remaining) if state == RunState.ACTIVE and fuel <= 0.0 else ("LOW FUEL — FEED THE HOPPER" if state == RunState.ACTIVE and fuel < 25.0 else "")
	warning.add_theme_color_override("font_color", Color(1.0, 0.28, 0.16) if fuel < 25.0 else Color(1.0, 0.75, 0.25))
	hud.visible = state != RunState.IDLE

func _show_result(message: String) -> void:
	if not hud:
		return
	var result: Label = hud.get_node("Result")
	result.text = message
	result.visible = true
	hud.visible = true

func _hide_result() -> void:
	if not hud:
		return
	hud.get_node("Result").visible = false
	hud.visible = false

func _on_interaction_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body
		_player_in_console_zone = true
		_refresh_prompt()

func _on_interaction_zone_body_exited(body: Node3D) -> void:
	if body == player:
		_player_in_console_zone = false
		_refresh_prompt()

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt):
		return
	prompt.text = "START AUXILIARY GENERATOR" if state == RunState.IDLE else ("GRID ONLINE" if state == RunState.WON else "")
	prompt.visible = _player_in_console_zone and (state == RunState.IDLE or state == RunState.WON)

func _check_player_death() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player) and bool(player.get("is_dead")):
		_fail_run("GENERATOR LOST — REBOOT AVAILABLE IN 5s")

func _check_zombies_at_generator() -> void:
	if not is_instance_valid(generator):
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(generator.global_position) <= 1.8:
			damage_generator(12)
			break

func _check_wave_schedule() -> void:
	var elapsed := RUN_DURATION - time_remaining
	if elapsed >= 60.0 and wave_stage < 3:
		wave_stage = 3
		_spawn_wave(2)
	elif elapsed >= 30.0 and wave_stage < 2:
		wave_stage = 2
		_spawn_wave(1)

func _spawn_wave(stage: int) -> void:
	var count := 6 if stage == 0 else (10 if stage == 1 else 13)
	for i in range(count):
		var scene := WALKER_SCENE
		if stage >= 1 and i >= 6:
			scene = RUNNER_SCENE
		if stage == 2 and i == count - 1:
			scene = BUTCHER_SCENE
		var enemy := scene.instantiate() as Node3D
		if enemy == null:
			continue
		get_tree().current_scene.add_child(enemy)
		var angle := (float(i) / float(count)) * TAU + float(stage) * 0.35
		enemy.global_position = global_position + Vector3(cos(angle) * 17.0, 0.0, sin(angle) * 17.0)
		if enemy.has_method("set"):
			enemy.set("target", player)

func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	return material
