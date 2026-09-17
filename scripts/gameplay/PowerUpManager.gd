extends Node
class_name PowerUpManager

## PowerUpManager — Spawns and manages power-ups
## Attach to root game node. Spawns power-ups at intervals.

signal powerup_collected(powerup_type)

@export var powerup_scenes: Array[PackedScene] = [preload("res://scenes/world/powerup.tscn")]
@export var spawn_interval: float = 15.0
@export var max_powerups: int = 3
@export var spawn_radius: float = 10.0

var active_powerups: Array = []
var can_spawn: bool = false

@onready var spawn_timer: Timer = Timer.new()

func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func start_spawning() -> void:
	can_spawn = true
	spawn_timer.start()

func stop_spawning() -> void:
	can_spawn = false
	spawn_timer.stop()
	for p in active_powerups:
		if is_instance_valid(p):
			p.queue_free()
	active_powerups.clear()

func _on_spawn_timer_timeout() -> void:
	if not can_spawn or powerup_scenes.is_empty():
		return
	if active_powerups.size() >= max_powerups:
		spawn_timer.start()
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player is Node3D:
		return
	
	var scene = powerup_scenes.pick_random()
	var powerup = scene.instantiate()
	var angle = randf() * TAU
	var dist = randf_range(3.0, spawn_radius)
	powerup.global_position = (player as Node3D).global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
	add_child(powerup)
	active_powerups.append(powerup)
	
	if powerup.has_signal("collected"):
		powerup.collected.connect(_on_powerup_collected.bind(powerup))
	
	spawn_timer.start()

func _on_powerup_collected(powerup: Node) -> void:
	active_powerups.erase(powerup)
	var type = powerup.get("powerup_type") if powerup.get("powerup_type") else "unknown"
	powerup_collected.emit(type)
