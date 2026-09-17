extends Node3D
class_name CameraShake

## CameraShake — Screen shake utility
## Attach to a Camera3D or SpringArm3D. Call shake() to trigger.

@export var max_shake_strength: float = 0.5
@export var shake_decay: float = 5.0

var shake_strength: float = 0.0
var original_position: Vector3

func _ready() -> void:
	original_position = position

func shake(strength: float = 0.3) -> void:
	shake_strength = min(max_shake_strength, shake_strength + strength)

func _process(delta: float) -> void:
	if shake_strength > 0.01:
		position = original_position + Vector3(
			randf_range(-1, 1) * shake_strength,
			randf_range(-1, 1) * shake_strength,
			randf_range(-1, 1) * shake_strength
		)
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
	else:
		position = original_position
		shake_strength = 0.0
