extends Node
class_name DifficultyManager

## DifficultyManager — Dynamic difficulty scaling
## Attach to root. Adjusts enemy stats based on player performance.

@export var base_difficulty: float = 1.0
@export var max_difficulty: float = 3.0
@export var difficulty_ramp_time: float = 60.0
@export var performance_window: int = 10
@export var window_seconds: float = 30.0  # sliding window for kill/damage tracking

var current_difficulty: float = 1.0
var kills_in_window: Array = []
var damage_taken_in_window: Array = []

func _process(delta: float) -> void:
	if current_difficulty < max_difficulty:
		current_difficulty = min(max_difficulty, current_difficulty + delta / difficulty_ramp_time)

func register_kill() -> void:
	kills_in_window.append(Time.get_ticks_msec())
	_prune_window(kills_in_window)
	_adjust_difficulty()

func register_damage_taken() -> void:
	damage_taken_in_window.append(Time.get_ticks_msec())
	_prune_window(damage_taken_in_window)
	_adjust_difficulty()

func _prune_window(window: Array) -> void:
	var cutoff = Time.get_ticks_msec() - int(window_seconds * 1000)
	while window.size() > 0 and window[0] < cutoff:
		window.pop_front()

func _adjust_difficulty() -> void:
	var kill_rate = kills_in_window.size() / window_seconds
	var damage_rate = damage_taken_in_window.size() / window_seconds
	# Player doing well -> harder; taking damage -> slightly easier
	var adjustment = (kill_rate * 0.1) - (damage_rate * 0.05)
	current_difficulty = clamp(current_difficulty + adjustment, base_difficulty, max_difficulty)

func reset() -> void:
	current_difficulty = base_difficulty
	kills_in_window.clear()
	damage_taken_in_window.clear()

func get_enemy_health_multiplier() -> float:
	return 1.0 + (current_difficulty - 1.0) * 0.5

func get_enemy_damage_multiplier() -> float:
	return 1.0 + (current_difficulty - 1.0) * 0.3

func get_enemy_speed_multiplier() -> float:
	return 1.0 + (current_difficulty - 1.0) * 0.2
