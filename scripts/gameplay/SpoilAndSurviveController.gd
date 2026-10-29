extends Node3D
class_name SpoilAndSurviveController

## SpoilAndSurviveController — State machine and rules engine for the Spoil & Survive eating mini-game.
## Tracks 60s countdown, combo multipliers, 15 fresh dishes objective,
## strict tainted dish fairness (max 2), and reports to ObjectiveManager exactly once on win.

const OBJECTIVE_ID: String = "l1_spoil_and_survive"
const OBJECTIVE_TITLE: String = "Eat 15 fresh buffet dishes"
const ROUND_DURATION: float = 60.0
const TARGET_DISHES: int = 15
const MAX_TAINTED_COUNT: int = 2
const FRESH_HEAL: int = 10
const TAINTED_DAMAGE: int = 18
const TAINTED_TIME_PENALTY: float = 5.0
const MUKBANG_RUSH_DURATION: float = 2.5
const MUKBANG_RUSH_SPEED_MULT: float = 1.15
const TAINTED_STAGGER_DURATION: float = 0.6
const TAINTED_STAGGER_SPEED_MULT: float = 0.4
const MAX_COMBO: int = 5
const FAILURE_RESET_DELAY: float = 3.0

enum RunState { IDLE, ACTIVE, WON, FAILED }

@export var hud_path: NodePath = ^"../BuffetHUD"
@export var platters_container_path: NodePath = ^"../Platters"
@export var podium_path: NodePath = ^"Podium"

var state: RunState = RunState.IDLE
var dishes_eaten: int = 0
var combo_streak: int = 0
var time_remaining: float = ROUND_DURATION
var is_won: bool = false

var objective_manager: Node = null
var player: CharacterBody3D = null
var hud: CanvasLayer = null
var slots: Array[BuffetPlatterSlot] = []

var rush_timer: float = 0.0
var stagger_timer: float = 0.0
var original_move_speed: float = 4.5
var original_sprint_speed: float = 7.5
var speed_modified: bool = false
var vignette_tween: Tween = null

const FOOD_SCENES: Array[PackedScene] = [
	preload("res://scenes/world/food_burger.tscn"),
	preload("res://scenes/world/food_pizza.tscn"),
	preload("res://scenes/world/food_fries.tscn"),
	preload("res://scenes/world/food_sushi.tscn"),
	preload("res://scenes/world/food_takis.tscn"),
	preload("res://scenes/world/food_soda.tscn")
]

@onready var interaction_zone: Area3D = $InteractionZone
@onready var podium: Node3D = get_node_or_null(podium_path)
@onready var prompt: Label3D = $Podium/Prompt

func _ready() -> void:
	add_to_group("interactive_prop")
	hud = get_node_or_null(hud_path) as CanvasLayer
	# The HUD CanvasLayer root has no visible=false in the scene, only its child
	# labels are hidden, so the panel rendered its IDLE defaults (TIME 60.0s /
	# DISHES 0/15) from level start — a frozen fake round that never moved and
	# made the mini-game look broken-and-stuck rather than simply not started.
	# Hide the whole layer until a round is actually running.
	if hud:
		hud.visible = false
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	
	_discover_slots()
	
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_interaction_zone_body_entered)
		interaction_zone.body_exited.connect(_on_interaction_zone_body_exited)
	
	call_deferred("_register_objective")
	_refresh_podium_prompt()
	_update_hud()

func _exit_tree() -> void:
	_restore_original_speed()

func _discover_slots() -> void:
	slots.clear()
	var container := get_node_or_null(platters_container_path)
	if container:
		for child in container.get_children():
			if child is BuffetPlatterSlot:
				slots.append(child)
				child.controller = self

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
	
	# Process speed buffs/debuffs
	if rush_timer > 0.0:
		rush_timer -= delta
		if rush_timer <= 0.0:
			_clear_speed_modifier()
	elif stagger_timer > 0.0:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			_clear_speed_modifier()
	
	# Check failure triggers
	if time_remaining <= 0.0:
		time_remaining = 0.0
		_fail_round("TIME'S UP — SPOILED RUN")
		return
	
	_check_player_death()
	_update_hud()

## Interactor entrypoint for podium start
func interact() -> void:
	if state == RunState.IDLE:
		_start_round()

func _start_round() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	
	if player != null and (player.get("is_dead") == true or int(player.get("health")) <= 0):
		return
	
	state = RunState.ACTIVE
	dishes_eaten = 0
	combo_streak = 0
	time_remaining = ROUND_DURATION
	is_won = false
	rush_timer = 0.0
	stagger_timer = 0.0
	_clear_speed_modifier()
	# Show the HUD now that a round is genuinely running (hidden in _ready so the
	# idle panel never faked an in-progress round).
	if hud:
		hud.visible = true
	_update_hud()
	
	if interaction_zone:
		interaction_zone.set_deferred("monitoring", false)
	
	if prompt:
		prompt.visible = false
	
	_populate_initial_dishes()
	
	if Audio and Audio.has_method("play_powerup"):
		Audio.play_powerup()
	
	_hide_result()
	_update_hud()

func _populate_initial_dishes() -> void:
	if slots.is_empty():
		_discover_slots()
	
	# Exactly 2 tainted dishes, rest fresh
	var indices: Array[int] = []
	for i in range(slots.size()):
		indices.append(i)
	indices.shuffle()
	
	var tainted_indices: Array[int] = []
	for i in range(mini(MAX_TAINTED_COUNT, indices.size())):
		tainted_indices.append(indices[i])
	
	for i in range(slots.size()):
		var slot := slots[i]
		var is_tainted := tainted_indices.has(i)
		var food_scene := FOOD_SCENES[randi() % FOOD_SCENES.size()]
		slot.spawn_dish(food_scene, is_tainted)

func on_dish_eaten(slot: BuffetPlatterSlot, was_tainted: bool, target_player: Node3D) -> void:
	if state != RunState.ACTIVE:
		return
	
	var actual_player: Node3D = target_player if target_player != null else player
	if actual_player == null:
		actual_player = get_tree().get_first_node_in_group("player")
	
	if was_tainted:
		# Spoil Penalty
		if Audio and Audio.has_method("play_hurt"):
			Audio.play_hurt()
		if Audio and Audio.has_method("haptic_medium"):
			Audio.haptic_medium()
		
		if actual_player and actual_player.has_method("take_damage"):
			actual_player.take_damage(TAINTED_DAMAGE)
		
		combo_streak = 0
		time_remaining = maxf(0.0, time_remaining - TAINTED_TIME_PENALTY)
		_flash_poison_vignette()
		_apply_stagger(TAINTED_STAGGER_DURATION)
		
		if time_remaining <= 0.0:
			_fail_round("TIME'S UP — SPOILED RUN")
			return
		
		if actual_player and (actual_player.get("is_dead") == true or int(actual_player.get("health")) <= 0):
			_fail_round("PLAYER DOWN — BUFFET FAILED")
			return
	else:
		# Fresh Bite Reward
		if Audio and Audio.has_method("play_eat"):
			Audio.play_eat()
		if Audio and Audio.has_method("haptic_light"):
			Audio.haptic_light()
		
		if actual_player and actual_player.has_method("heal"):
			actual_player.heal(FRESH_HEAL)
		
		dishes_eaten += 1
		combo_streak = mini(combo_streak + 1, MAX_COMBO)
		
		if combo_streak >= MAX_COMBO:
			_apply_mukbang_rush()
		
		if dishes_eaten >= TARGET_DISHES and not is_won:
			_win_round()
			return
	
	_update_hud()

func replenish_slot(slot: BuffetPlatterSlot) -> void:
	if state != RunState.ACTIVE:
		return
	
	var current_tainted := _get_tainted_count()
	var spawn_tainted := false
	
	# Strict fairness: Never exceed 2 tainted dishes
	if current_tainted < MAX_TAINTED_COUNT:
		spawn_tainted = (randf() < 0.25) or (current_tainted == 0)
	
	var food_scene := FOOD_SCENES[randi() % FOOD_SCENES.size()]
	slot.spawn_dish(food_scene, spawn_tainted)

func _get_tainted_count() -> int:
	var count := 0
	for slot in slots:
		if slot.has_dish() and slot.is_tainted():
			count += 1
	return count

func _win_round() -> void:
	if state != RunState.ACTIVE or is_won:
		return
	
	is_won = true
	state = RunState.WON
	_clear_speed_modifier()
	
	if Audio and Audio.has_method("play_victory"):
		Audio.play_victory()
	
	# Dispatch progress to ObjectiveManager exactly once
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress(OBJECTIVE_ID, 1)
	
	for slot in slots:
		slot.despawn_dish()
	
	_show_result("BUFFET CONQUERED!")
	_refresh_podium_prompt()
	_update_hud()

func _fail_round(reason: String) -> void:
	if state != RunState.ACTIVE:
		return
	
	state = RunState.FAILED
	_clear_speed_modifier()
	
	if Audio and Audio.has_method("play_defeat"):
		Audio.play_defeat()
	
	for slot in slots:
		slot.despawn_dish()
	
	_show_result(reason + "\nBUFFET RESETTING (3s)")
	_refresh_podium_prompt()
	_update_hud()
	
	get_tree().create_timer(FAILURE_RESET_DELAY).timeout.connect(_reset_after_failure)

func _reset_after_failure() -> void:
	if state != RunState.FAILED:
		return
	
	state = RunState.IDLE
	dishes_eaten = 0
	combo_streak = 0
	time_remaining = ROUND_DURATION
	is_won = false
	
	if interaction_zone:
		interaction_zone.set_deferred("monitoring", true)
	
	_hide_result()
	_refresh_podium_prompt()
	_update_hud()

func _check_player_death() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and (player.get("is_dead") == true or int(player.get("health")) <= 0):
		_fail_round("PLAYER DOWN — BUFFET FAILED")

# ── SPEED MODIFIERS (MUKBANG RUSH / STAGGER) ──────────────────────────────────

func _apply_mukbang_rush() -> void:
	if not player or not is_instance_valid(player):
		return
	_restore_original_speed()
	original_move_speed = float(player.get("move_speed"))
	original_sprint_speed = float(player.get("sprint_speed"))
	player.set("move_speed", original_move_speed * MUKBANG_RUSH_SPEED_MULT)
	player.set("sprint_speed", original_sprint_speed * MUKBANG_RUSH_SPEED_MULT)
	speed_modified = true
	rush_timer = MUKBANG_RUSH_DURATION
	stagger_timer = 0.0

func _apply_stagger(duration: float) -> void:
	if not player or not is_instance_valid(player):
		return
	_restore_original_speed()
	original_move_speed = float(player.get("move_speed"))
	original_sprint_speed = float(player.get("sprint_speed"))
	player.set("move_speed", original_move_speed * TAINTED_STAGGER_SPEED_MULT)
	player.set("sprint_speed", original_sprint_speed * TAINTED_STAGGER_SPEED_MULT)
	speed_modified = true
	stagger_timer = duration
	rush_timer = 0.0

func _clear_speed_modifier() -> void:
	rush_timer = 0.0
	stagger_timer = 0.0
	_restore_original_speed()

func _restore_original_speed() -> void:
	if speed_modified and player and is_instance_valid(player):
		player.set("move_speed", original_move_speed)
		player.set("sprint_speed", original_sprint_speed)
		speed_modified = false

# ── HUD & VISUAL FEEDBACK ─────────────────────────────────────────────────────

func _update_hud() -> void:
	if not hud:
		return
	
	var timer_label: Label = hud.get_node_or_null("Panel/Margin/Rows/TimerText")
	if timer_label:
		timer_label.text = "TIME: %04.1fs" % time_remaining
	
	var timer_bar: ProgressBar = hud.get_node_or_null("Panel/Margin/Rows/TimerBar")
	if timer_bar:
		timer_bar.value = time_remaining
	
	var dishes_label: Label = hud.get_node_or_null("Panel/Margin/Rows/ScoreRow/DishesText")
	if dishes_label:
		dishes_label.text = "FRESH DISHES: %d / %d" % [dishes_eaten, TARGET_DISHES]
	
	var combo_label: Label = hud.get_node_or_null("Panel/Margin/Rows/ScoreRow/ComboText")
	if combo_label:
		combo_label.text = "COMBO: %dx" % combo_streak
		combo_label.modulate = Color(1.0, 0.85, 0.3) if combo_streak >= 3 else Color.WHITE
	
	var rush_label: Label = hud.get_node_or_null("Panel/Margin/Rows/RushText")
	if rush_label:
		rush_label.visible = (rush_timer > 0.0)

func _flash_poison_vignette() -> void:
	if not hud:
		return
	var vignette: ColorRect = hud.get_node_or_null("PoisonVignette")
	if not vignette:
		return
	
	if vignette_tween and vignette_tween.is_valid():
		vignette_tween.kill()
	
	vignette.color = Color(0.25, 0.55, 0.15, 0.45)
	vignette_tween = create_tween()
	vignette_tween.tween_property(vignette, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _show_result(text: String) -> void:
	if not hud:
		return
	var res_label: Label = hud.get_node_or_null("Result")
	if res_label:
		res_label.text = text
		res_label.visible = true

func _hide_result() -> void:
	if not hud:
		return
	var res_label: Label = hud.get_node_or_null("Result")
	if res_label:
		res_label.visible = false

func _refresh_podium_prompt() -> void:
	if not is_instance_valid(prompt):
		return
	
	match state:
		RunState.IDLE:
			prompt.text = "START BUFFET CHALLENGE\nEAT 15 FRESH DISHES IN 60s\n[ATTACK]"
			prompt.modulate = Color(1.0, 0.82, 0.3)
			prompt.visible = true
		RunState.ACTIVE:
			prompt.visible = false
		RunState.WON:
			prompt.text = "COMPLETED — CERTIFIED CLEAN"
			prompt.modulate = Color(0.3, 0.95, 0.45)
			prompt.visible = true
		RunState.FAILED:
			prompt.text = "BUFFET SPOILED\nRESETTING..."
			prompt.modulate = Color(0.9, 0.35, 0.25)
			prompt.visible = true

func _on_interaction_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and state == RunState.IDLE:
		if prompt:
			prompt.visible = true
		# Auto-start on entering the zone: the player is often mid-flight from
		# zombies when they reach a mini-game, and stopping to press ATTACK gets
		# them killed. Walking into the buffet begins the round.
		_start_round()

func _on_interaction_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and state == RunState.IDLE:
		pass
