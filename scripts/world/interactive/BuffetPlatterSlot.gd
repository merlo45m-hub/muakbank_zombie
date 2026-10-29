extends Node3D
class_name BuffetPlatterSlot

## BuffetPlatterSlot — Serves one dish on the buffet table.
## Handles dish spawning, eat interaction routing, 0.6s replenishment cooldown,
## and local plate bounce feedback.

signal food_eaten(slot: BuffetPlatterSlot, is_tainted: bool, player: Node3D)
signal replenish_requested(slot: BuffetPlatterSlot)

const COOLDOWN_DURATION: float = 0.6
const STATIONARY_EAT_THRESHOLD: float = 0.45

@export var slot_index: int = 0
@export var controller_path: NodePath = ^"../../Controller"

var controller: Node = null
var current_food: BuffetFoodItem = null
var is_cooling_down: bool = false
var cooldown_timer: float = 0.0

var player_in_zone: CharacterBody3D = null
var stationary_timer: float = 0.0

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt: Label3D = $Prompt
@onready var plate_mesh: MeshInstance3D = get_node_or_null("PlateMesh")
@onready var plate_glow: CPUParticles3D = get_node_or_null("PlateGlow")

func _ready() -> void:
	add_to_group("interactive_prop")
	controller = get_node_or_null(controller_path)
	
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_interaction_zone_body_entered)
		interaction_zone.body_exited.connect(_on_interaction_zone_body_exited)
	
	_refresh_prompt()

func _process(delta: float) -> void:
	if is_cooling_down:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_cooling_down = false
			cooldown_timer = 0.0
			_request_replenishment()
		return
	
	# Mobile stationary consumption fallback: if player is resting in front of dish
	if player_in_zone != null and has_dish():
		if player_in_zone.velocity.length() < 0.25:
			stationary_timer += delta
			if stationary_timer >= STATIONARY_EAT_THRESHOLD:
				stationary_timer = 0.0
				interact()
		else:
			stationary_timer = 0.0

## Main interaction route invoked by Player._try_prop_interaction / Interactor.try_interact
func interact() -> void:
	if not has_dish() or is_cooling_down:
		return
	
	if controller != null and controller.get("state") != null:
		# RunState.ACTIVE == 1
		if int(controller.get("state")) != 1:
			return
	
	var target_player: Node3D = player_in_zone
	if target_player == null:
		target_player = get_tree().get_first_node_in_group("player")
	
	_consume_dish(target_player)

func _consume_dish(player: Node3D) -> void:
	if not has_dish():
		return
	
	var was_tainted := current_food.is_tainted
	current_food.eat_dish(player)
	current_food = null
	
	food_eaten.emit(self, was_tainted, player)
	
	if controller != null and controller.has_method("on_dish_eaten"):
		controller.on_dish_eaten(self, was_tainted, player)
	
	_play_plate_bounce()
	
	is_cooling_down = true
	cooldown_timer = COOLDOWN_DURATION
	stationary_timer = 0.0
	_refresh_prompt()

func spawn_dish(template_scene: PackedScene, tainted: bool) -> void:
	despawn_dish()
	
	var food_item := BuffetFoodItem.new()
	food_item.name = "BuffetDish"
	food_item.position = Vector3(0.0, 0.12, 0.0)
	add_child(food_item)
	food_item.setup_dish(template_scene, tainted)
	current_food = food_item
	
	_play_spawn_pop()
	_refresh_prompt()

func despawn_dish() -> void:
	if current_food != null and is_instance_valid(current_food):
		current_food.queue_free()
	current_food = null
	is_cooling_down = false
	cooldown_timer = 0.0
	stationary_timer = 0.0
	_refresh_prompt()

func has_dish() -> bool:
	return current_food != null and is_instance_valid(current_food) and not current_food.is_eaten

func is_tainted() -> bool:
	return has_dish() and current_food.is_tainted

func _request_replenishment() -> void:
	replenish_requested.emit(self)
	if controller != null and controller.has_method("replenish_slot"):
		controller.replenish_slot(self)

func _play_plate_bounce() -> void:
	if not plate_mesh:
		return
	var tw := create_tween()
	tw.tween_property(plate_mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
	tw.tween_property(plate_mesh, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_spawn_pop() -> void:
	if current_food != null and is_instance_valid(current_food):
		current_food.scale = Vector3(0.2, 0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(current_food, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_interaction_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_zone = body as CharacterBody3D
		stationary_timer = 0.0
		_refresh_prompt()

func _on_interaction_zone_body_exited(body: Node3D) -> void:
	if body == player_in_zone:
		player_in_zone = null
		stationary_timer = 0.0
		_refresh_prompt()

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt):
		return
	
	var is_active := true
	if controller != null and controller.get("state") != null:
		is_active = (int(controller.get("state")) == 1)
	
	if player_in_zone != null and has_dish() and not is_cooling_down and is_active:
		prompt.visible = true
		prompt.text = "EAT [ATTACK]"
		prompt.modulate = Color(0.9, 0.45, 0.2) if is_tainted() else Color(0.4, 0.95, 0.4)
	else:
		prompt.visible = false
