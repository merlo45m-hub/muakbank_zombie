extends Node
class_name CameraShake

## CameraShake — Screen shake utility
## Attach anywhere; set `target` to the node to shake (usually the Camera3D).
## If `target` is unset, it auto-finds the first Camera3D in the scene.
##
## Shakes the camera's VIEW OFFSET (h_offset/v_offset) instead of its transform:
## the camera sits under a SpringArm3D that re-derives its position every physics
## frame, so direct position writes get overwritten — and a rest pose captured in
## _ready() is stale before the first frame renders (it stored the authored
## (0, 0.5, 0) while the arm's real rest is (0, 0, 4.2)), which slammed the
## camera ~4.2 units into the player on every hit.

@export var max_shake_strength: float = 0.5
@export var shake_decay: float = 5.0
@export var target: Node3D = null
@export var auto_find_camera: bool = true

var shake_strength: float = 0.0

func _ready() -> void:
	if not target and auto_find_camera:
		target = _find_camera()

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
	var cam: Camera3D = target as Camera3D
	if shake_strength > 0.01:
		if cam:
			cam.h_offset = randf_range(-1, 1) * shake_strength
			cam.v_offset = randf_range(-1, 1) * shake_strength
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
	else:
		if shake_strength != 0.0:
			if cam:
				cam.h_offset = 0.0
				cam.v_offset = 0.0
			shake_strength = 0.0
