extends Node
class_name ComboSystem

## ComboSystem — Kill combo tracking
## Attach to root game node. Tracks consecutive kills within a time window.

signal combo_changed(combo_count)
signal combo_lost

@export var combo_window: float = 3.0
@export var combo_multiplier_step: float = 0.1

var combo_count: int = 0
var combo_timer: float = 0.0
var combo_multiplier: float = 1.0

func register_kill() -> void:
	combo_count += 1
	combo_timer = combo_window
	combo_multiplier = 1.0 + (combo_count - 1) * combo_multiplier_step
	combo_changed.emit(combo_count)

func _process(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_lost.emit()
			combo_count = 0
			combo_multiplier = 1.0

func get_score_multiplier() -> float:
	return combo_multiplier

func reset_combo() -> void:
	combo_count = 0
	combo_multiplier = 1.0
	combo_timer = 0.0
