extends Node3D
class_name WeatherSystem

## WeatherSystem — Ambient weather effects
## Attach to root. Cycles weather states with particle effects.

@export var weather_cycle_time: float = 60.0
@export var rain_particles: CPUParticles3D = null
@export var fog_enabled: bool = true

enum Weather { CLEAR, RAIN, FOG, STORM }

var current_weather: Weather = Weather.CLEAR
var weather_timer: float = 0.0

func _ready() -> void:
	_apply_weather(Weather.CLEAR)

func _process(delta: float) -> void:
	weather_timer += delta
	if weather_timer >= weather_cycle_time:
		weather_timer = 0.0
		_random_weather()

func _random_weather() -> void:
	var roll = randf()
	if roll < 0.5:
		_apply_weather(Weather.CLEAR)
	elif roll < 0.75:
		_apply_weather(Weather.RAIN)
	elif roll < 0.9:
		_apply_weather(Weather.FOG)
	else:
		_apply_weather(Weather.STORM)

func _apply_weather(weather: Weather) -> void:
	current_weather = weather
	if rain_particles:
		rain_particles.emitting = weather in [Weather.RAIN, Weather.STORM]
		rain_particles.amount = 200 if weather == Weather.STORM else 100
	
	var env = get_viewport().get_environment()
	if env and fog_enabled:
		match weather:
			Weather.CLEAR:
				env.fog_enabled = false
			Weather.FOG:
				env.fog_enabled = true
				env.fog_density = 0.05
			Weather.RAIN, Weather.STORM:
				env.fog_enabled = true
				env.fog_density = 0.02

func get_weather_name() -> String:
	return Weather.keys()[current_weather]
