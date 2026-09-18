extends Node
class_name CameraShake

## CameraShake — Screen shake utility
## Attach anywhere; set `target` to the node to shake (usually the Camera3D).
## If `target` is unset, it auto-finds the first Camera3D in the scene.

@export var max_shake_strength: float = 0.5
@export var shake_decay: float = 5.0
@export var target: Node3D = null
@export var auto_find_camera: bool = true

var shake_strength: float = 0.0
var original_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	if not target and auto_find_camera:
		target = _find_camera()
	if target:
		original_position = target.position

func _find_camera() -> Camera3D:
	var scene = get_tree().current_scene
	if not scene:
		return null
	return _find_camera_recursive(scene)

func _find_camera_recursive(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found = _find_camera_recursive(child)
		if found:
			return found
	return null

func shake(strength: float = 0.3) -> void:
	shake_strength = min(max_shake_strength, shake_strength + strength)

func _process(delta: float) -> void:
	if not target:
		return
	if shake_strength > 0.01:
		target.position = original_position + Vector3(
			randf_range(-1, 1) * shake_strength,
			randf_range(-1, 1) * shake_strength,
			randf_range(-1, 1) * shake_strength
		)
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
	else:
		if shake_strength != 0.0:
			target.position = original_position
			shake_strength = 0.0
