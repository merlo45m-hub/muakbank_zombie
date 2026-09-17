extends Node3D
class_name HitFeedback

## Hit Feedback — Particle effects for impacts, deaths, and game events
## Attach to a Node3D in the game scene for spawning effects

# === SCENE REFS ===
@export var blood_particles: PackedScene
@export var spark_particles: PackedScene
@export var death_particles: PackedScene
@export var pickup_particles: PackedScene

# === POOLS ===
var blood_pool: Array = []
var spark_pool: Array = []
var death_pool: Array = []
var pickup_pool: Array = []
const POOL_SIZE: int = 5


func _ready() -> void:
	# Pre-instantiate particles for performance
	for i in range(POOL_SIZE):
		blood_pool.append(_create_blood())
		spark_pool.append(_create_spark())
		death_pool.append(_create_death())
		pickup_pool.append(_create_pickup())


func _create_blood() -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 45.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.6
	particles.color = Color(0.7, 0.05, 0.05, 0.9)
	add_child(particles)
	return particles


func _create_spark() -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, -5.0, 0)
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.2
	particles.color = Color(1.0, 0.8, 0.3, 0.9)
	add_child(particles)
	return particles


func _create_death() -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 90.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 10.0
	particles.gravity = Vector3(0, -15.0, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.color = Color(0.3, 0.1, 0.05, 0.7)
	add_child(particles)
	return particles


func _create_pickup() -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.direction = Vector3.UP
	particles.spread = 30.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, -2.0, 0)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.4
	particles.color = Color(0.3, 0.8, 0.4, 0.9)
	add_child(particles)
	return particles


# ── PUBLIC API ─────────────────────────────────────────────────

func emit_blood(position: Vector3) -> void:
	var particles = blood_pool.pop_front()
	if particles:
		particles.global_transform.origin = position
		particles.emitting = true
		blood_pool.append(particles)


func emit_spark(position: Vector3) -> void:
	var particles = spark_pool.pop_front()
	if particles:
		particles.global_transform.origin = position
		particles.emitting = true
		spark_pool.append(particles)


func emit_death(position: Vector3) -> void:
	var particles = death_pool.pop_front()
	if particles:
		particles.global_transform.origin = position
		particles.emitting = true
		death_pool.append(particles)


func emit_pickup(position: Vector3) -> void:
	var particles = pickup_pool.pop_front()
	if particles:
		particles.global_transform.origin = position
		particles.emitting = true
		pickup_pool.append(particles)


func emit_hit(position: Vector3, enemy_type: String = "default") -> void:
	match enemy_type:
		"zombie_bear":
			emit_death(position)
		_:
			emit_blood(position)
