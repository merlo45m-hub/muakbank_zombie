extends Node3D
class_name WeatherSystem

## WeatherSystem — Ambient weather effects
## Attach to root. Cycles weather states with particle effects.
## Rain particles are created automatically if none are assigned.

@export var weather_cycle_time: float = 60.0
@export var rain_particles: CPUParticles3D = null
@export var fog_enabled: bool = true
@export var auto_create_rain: bool = true

enum Weather { CLEAR, RAIN, FOG, STORM }

var current_weather: Weather = Weather.CLEAR
var weather_timer: float = 0.0

func _ready() -> void:
	if not rain_particles and auto_create_rain:
		_build_rain_particles()
	_apply_weather(Weather.CLEAR)

func _build_rain_particles() -> void:
	"""Create a rain emitter above the play area."""
	rain_particles = CPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.amount = 150
	rain_particles.lifetime = 1.2
	rain_particles.emitting = false
	rain_particles.one_shot = false
	rain_particles.explosiveness = 0.0
	rain_particles.direction = Vector3(0, -1, 0)
	rain_particles.spread = 5.0
	rain_particles.initial_velocity_min = 18.0
	rain_particles.initial_velocity_max = 24.0
	rain_particles.gravity = Vector3(0, -20, 0)
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(30, 1, 30)
	rain_particles.position = Vector3(0, 25, 0)
	rain_particles.mesh = _make_rain_mesh()
	add_child(rain_particles)

func _make_rain_mesh() -> Mesh:
	var m = BoxMesh.new()
	m.size = Vector3(0.02, 0.5, 0.02)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.7, 0.9, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	return m

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
		rain_particles.amount = 250 if weather == Weather.STORM else 150
	
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
