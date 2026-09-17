extends Node3D
class_name DayNightCycle

## DayNightCycle — Time-of-day lighting system
## Attach anywhere in the scene; auto-finds the first DirectionalLight3D.
## Cycles day/night with smooth transitions.

@export var day_length: float = 120.0  # seconds for full day
@export var start_time: float = 0.5  # 0.0 = midnight, 0.5 = noon
@export var night_energy: float = 0.1
@export var day_energy: float = 1.0
@export var night_color: Color = Color(0.1, 0.1, 0.3)
@export var day_color: Color = Color(1, 1, 1)
@export var auto_find_light: bool = true

var time_of_day: float = 0.5
var is_day: bool = true
var light: DirectionalLight3D = null

func _ready() -> void:
	time_of_day = start_time
	_find_light()
	_update_light()

func _find_light() -> void:
	# Prefer parent if it's a DirectionalLight3D, else search the tree
	if get_parent() is DirectionalLight3D:
		light = get_parent()
		return
	if auto_find_light:
		for node in get_tree().get_nodes_in_group("day_night_light"):
			if node is DirectionalLight3D:
				light = node
				return
		# Fallback: scan current scene for any DirectionalLight3D
		var scene = get_tree().current_scene
		if scene:
			light = _find_light_recursive(scene)

func _find_light_recursive(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node
	for child in node.get_children():
		var found = _find_light_recursive(child)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	time_of_day += delta / day_length
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	_update_light()

func _update_light() -> void:
	if not light:
		return
	# Sun angle: 0 at midnight, 90 at noon
	var angle = time_of_day * TAU
	light.rotation_degrees.x = -90 + (time_of_day - 0.5) * 180
	
	# Day/night blend
	var day_factor = clamp(sin(angle), 0.0, 1.0)
	light.light_energy = lerp(night_energy, day_energy, day_factor)
	light.light_color = night_color.lerp(day_color, day_factor)
	is_day = day_factor > 0.5

func get_time_string() -> String:
	var hours = int(time_of_day * 24)
	var minutes = int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]
