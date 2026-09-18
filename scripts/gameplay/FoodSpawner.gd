extends Node3D

## Food Spawner — Spawns all 6 food types
## Burger, Soda, Pizza, Fries, Sushi, Takis

@export var max_food: int = 8
@export var spawn_interval: float = 8.0
@export var spawn_radius: float = 12.0
@export var min_spawn_distance: float = 4.0

var food_burger_scene = preload("res://scenes/world/food_burger.tscn")
var food_soda_scene = preload("res://scenes/world/food_soda.tscn")
var food_pizza_scene = preload("res://scenes/world/food_pizza.tscn")
var food_fries_scene = preload("res://scenes/world/food_fries.tscn")
var food_sushi_scene = preload("res://scenes/world/food_sushi.tscn")
var food_takis_scene = preload("res://scenes/world/food_takis.tscn")
var food_medkit_scene = preload("res://scenes/world/food_medkit.tscn")
var food_coffee_scene = preload("res://scenes/world/food_coffee.tscn")
var food_battery_scene = preload("res://scenes/world/food_battery.tscn")
var food_ammo_scene = preload("res://scenes/world/food_ammo.tscn")

var player: Node3D = null
var active_food: Array = []
var can_spawn: bool = false

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("[FoodSpawner] No player found!")

func start_spawning() -> void:
	can_spawn = true
	spawn_timer.start(spawn_interval)
	print("[FoodSpawner] Started spawning food")

func stop_spawning() -> void:
	can_spawn = false
	spawn_timer.stop()
	for f in active_food:
		if is_instance_valid(f):
			f.queue_free()
	active_food.clear()

func _on_SpawnTimer_timeout() -> void:
	if not can_spawn or not player:
		return
	if active_food.size() >= max_food:
		spawn_timer.start(spawn_interval)
		return
	_spawn_random_food()

func _spawn_random_food() -> void:
	var scenes = [
		food_burger_scene,
		food_soda_scene,
		food_pizza_scene,
		food_fries_scene,
		food_sushi_scene,
		food_takis_scene,
		food_medkit_scene,
		food_coffee_scene,
		food_battery_scene,
		food_ammo_scene
	]
	
	var food = scenes[randi() % scenes.size()].instantiate()
	var angle = randf() * TAU
	var dist = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
	var spawn_pos = player.global_transform.origin + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	
	# Ground detection via raycast (fix for finding 9.3)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 50, 0), spawn_pos + Vector3(0, -50, 0))
	var result = space_state.intersect_ray(query)
	if result:
		spawn_pos.y = result.position.y + 0.5  # Offset above ground
	else:
		spawn_pos.y = 0.5  # Fallback
	
	food.global_transform.origin = spawn_pos
	add_child(food)
	active_food.append(food)
	
	if not food.is_connected("collected", _on_food_collected):
		food.collected.connect(_on_food_collected.bind(food))
	
	spawn_timer.start(spawn_interval)

func _on_food_collected(food: Node3D) -> void:
	active_food.erase(food)
	if food.get_parent():
		food.get_parent().remove_child(food)
