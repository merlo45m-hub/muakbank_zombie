extends Node3D

## Zombie Spawner — Spawns all 5 enemy types
## Uses simple raycast ground detection (no nav mesh needed)

signal zombie_killed(zombie_type)

@export var max_zombies: int = 12
@export var spawn_interval: float = 3.0
@export var spawn_radius: float = 15.0
@export var min_spawn_distance: float = 8.0

var zombie_dog_scene = preload("res://scenes/characters/zombie_dog.tscn")
var zombie_cat_scene = preload("res://scenes/characters/zombie_cat.tscn")
var zombie_bear_scene = preload("res://scenes/characters/zombie_bear.tscn")
var zombie_rabbit_scene = preload("res://scenes/characters/zombie_rabbit.tscn")
var zombie_chicken_scene = preload("res://scenes/characters/zombie_chicken.tscn")

var player: Node3D = null
var active_zombies: Array = []
var can_spawn: bool = false

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("[ZombieSpawner] No player found!")

func start_spawning() -> void:
	can_spawn = true
	spawn_timer.start(spawn_interval)
	print("[ZombieSpawner] Started spawning zombies")

func stop_spawning() -> void:
	can_spawn = false
	spawn_timer.stop()
	for z in active_zombies:
		if is_instance_valid(z):
			z.queue_free()
	active_zombies.clear()

func _on_SpawnTimer_timeout() -> void:
	if not can_spawn or not player:
		return
	if active_zombies.size() >= max_zombies:
		spawn_timer.start(spawn_interval)
		return
	_spawn_random_zombie()

func _spawn_random_zombie() -> void:
	var scenes = [
		zombie_dog_scene,
		zombie_cat_scene,
		zombie_bear_scene,
		zombie_rabbit_scene,
		zombie_chicken_scene
	]
	
	var zombie_types = ["dog", "cat", "bear", "rabbit", "chicken"]
	
	var type_index = randi() % scenes.size()
	var zombie = scenes[type_index].instantiate()
	var zombie_type = zombie_types[type_index]
	
	var angle = randf() * TAU
	var dist = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
	var spawn_pos = player.global_transform.origin + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 50, 0), spawn_pos + Vector3(0, -50, 0))
	var result = space_state.intersect_ray(query)
	if result:
		spawn_pos.y = result.position.y
	
	zombie.global_transform.origin = spawn_pos
	add_child(zombie)
	active_zombies.append(zombie)
	zombie.set("zombie_type", zombie_type)  # Store type for scoring
	
	if not zombie.is_connected("died", _on_zombie_died):
		zombie.died.connect(_on_zombie_died.bind(zombie, zombie_type))
	
	spawn_timer.start(spawn_interval)

func _on_zombie_died(zombie: Node3D, zombie_type: String = "zombie") -> void:
	active_zombies.erase(zombie)
	if zombie.get_parent():
		zombie.get_parent().remove_child(zombie)
	emit_signal("zombie_killed", zombie_type)
	print("[ZombieSpawner] Zombie killed: ", zombie_type, ". Active: ", active_zombies.size())
