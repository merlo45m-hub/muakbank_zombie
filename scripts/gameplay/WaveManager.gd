extends Node
class_name WaveManager

## WaveManager — Progressive zombie wave system
## Attach to root game node. Emits wave_started/wave_completed signals.

signal wave_started(wave_number, zombie_count)
signal wave_completed(wave_number)
signal all_waves_cleared

@export var waves_per_level: int = 5
@export var base_zombies_per_wave: int = 5
@export var zombies_per_wave_increment: int = 2
@export var wave_break_time: float = 10.0
@export var boss_scene: PackedScene = preload("res://scenes/characters/zombie_boss.tscn")

var current_wave: int = 0
var zombies_alive: int = 0
var wave_active: bool = false
var wave_timer: float = 0.0

@onready var spawner: Node3D = get_node_or_null("../ZombieSpawner")

func _ready() -> void:
	if spawner:
		spawner.zombie_killed.connect(_on_zombie_killed)

func start_waves() -> void:
	current_wave = 0
	_next_wave()

func _next_wave() -> void:
	current_wave += 1
	if current_wave > waves_per_level:
		all_waves_cleared.emit()
		return
	
	var count = base_zombies_per_wave + (current_wave - 1) * zombies_per_wave_increment
	zombies_alive = count
	wave_active = true
	wave_started.emit(current_wave, count)
	
	if spawner:
		spawner.max_zombies = count
		spawner.start_spawning()
	
	# Spawn boss on the final wave
	if current_wave == waves_per_level and boss_scene:
		_spawn_boss()
	
	print("[WaveManager] Wave ", current_wave, " started — ", count, " zombies")

func _spawn_boss() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var boss = boss_scene.instantiate()
	var angle = randf() * TAU
	var dist = 12.0
	boss.global_position = player.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	add_child(boss)
	zombies_alive += 1
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_died)
	print("[WaveManager] BOSS spawned!")

func _on_boss_died() -> void:
	zombies_alive -= 1
	_on_zombie_killed("boss")

func _on_zombie_killed(_type: String) -> void:
	zombies_alive -= 1
	if zombies_alive <= 0 and wave_active:
		wave_active = false
		wave_completed.emit(current_wave)
		if spawner:
			spawner.stop_spawning()
		wave_timer = wave_break_time
		print("[WaveManager] Wave ", current_wave, " cleared")

func _process(delta: float) -> void:
	if not wave_active and current_wave > 0 and current_wave <= waves_per_level:
		wave_timer -= delta
		if wave_timer <= 0:
			_next_wave()
