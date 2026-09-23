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

	# SpawnTimer.timeout was never wired in game.tscn, so the timer ticked into
	# the void and no food ever spawned. Connect here (idempotent).
	if not spawn_timer.timeout.is_connected(_on_SpawnTimer_timeout):
		spawn_timer.timeout.connect(_on_SpawnTimer_timeout)

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
	
	# Ground detection via raycast. Start LOW (head height): casting from +50
	# hits rooftops and awnings, which strands food on top of buildings where the
	# player can never reach it — the same mistake fixed in ZombieSpawner3D.
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 3, 0), spawn_pos + Vector3(0, -60, 0))
	var result = space_state.intersect_ray(query)
	if result:
		spawn_pos.y = result.position.y + 0.5  # Offset above ground
	else:
		spawn_pos.y = 0.5  # Fallback
	# Anything still far above the player is a bogus surface (roof/ledge).
	if spawn_pos.y > player.global_transform.origin.y + 3.0:
		spawn_pos.y = player.global_transform.origin.y + 0.5
	
	# Add first, THEN place: a node outside the tree has no valid global_transform, so the
	# old order both errored ("Condition !is_inside_tree() is true") and silently dropped
	# the spawn position, leaving food wherever its local transform happened to be.
	add_child(food)
	food.global_position = spawn_pos
	active_food.append(food)
	
	if not food.is_connected("collected", _on_food_collected):
		food.collected.connect(_on_food_collected.bind(food))
	
	spawn_timer.start(spawn_interval)

func _on_food_collected(food: Node3D) -> void:
	active_food.erase(food)
	if food.get_parent():
		food.get_parent().remove_child(food)
