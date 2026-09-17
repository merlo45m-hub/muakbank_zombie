extends Node3D
class_name DayNightCycle

## DayNightCycle — Time-of-day lighting system
## Attach as a CHILD of a DirectionalLight3D. Cycles day/night with smooth transitions.

@export var day_length: float = 120.0  # seconds for full day
@export var start_time: float = 0.5  # 0.0 = midnight, 0.5 = noon
@export var night_energy: float = 0.1
@export var day_energy: float = 1.0
@export var night_color: Color = Color(0.1, 0.1, 0.3)
@export var day_color: Color = Color(1, 1, 1)

var time_of_day: float = 0.5
var is_day: bool = true

@onready var light: DirectionalLight3D = get_parent() as DirectionalLight3D

func _ready() -> void:
	time_of_day = start_time
	_update_light()

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
