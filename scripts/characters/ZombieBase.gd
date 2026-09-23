extends CharacterBody3D
class_name ZombieBase

## Zombie Base — Shared AI for all zombie animals
## All enemy types extend this class and override _get_stats() and _setup()
## Supports object pooling (dead/pooled props) and VectorFieldNavigation (vfn_field)

signal died

# === EXPORTED STATS (override in subclasses) ===
@export var max_health: int = 30
@export var move_speed: float = 3.0
@export var damage: int = 10
@export var attack_range: float = 1.5
@export var detection_range: float = 12.0
@export var gravity: float = 18.0
@export var attack_cooldown_time: float = 1.5
@export var fade_duration: float = 0.5

# === STATE ===
var health: int
var is_dead: bool = false
var target: Node3D = null
var is_attacking: bool = false
var attack_timer: float = 0.0
var hit_flash_tween: Tween = null
var is_hidden: bool = false

# === POOLING SUPPORT ===
var dead: bool = false          # Object-pool compatibility: must be false when alive, true when in dead pool
var pooled: bool = false       # True when managed by ZombieSpawner3D's pool — suppresses queue_free()

# === VFN NAVIGATION ===
var vfn_field = null  # Reference to the active VFNField (untyped: addon class may be absent)

# === NODE REFS ===
@onready var mesh: Node3D = $Mesh
@onready var attack_timer_node: Timer = $AttackTimer

# === AI STATES ===
enum AIState { IDLE, CHASE, ATTACK, SPECIAL, DEAD }
var current_state: AIState = AIState.IDLE

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_post_ready()


func _post_ready() -> void:
	"""Override for subclass-specific setup"""
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_attack_timer_tick(delta)

	match current_state:
		AIState.IDLE:
			_idle(delta)
		AIState.CHASE:
			_chase(delta)
		AIState.ATTACK:
			_attack(delta)
		AIState.SPECIAL:
			_special_behavior(delta)

	if current_state != AIState.ATTACK:
		velocity.x = move_toward(velocity.x, 0, 6 * delta)
		velocity.z = move_toward(velocity.z, 0, 6 * delta)

	# ── VFN OVERRIDE: if a field is set and we're chasing, use vector field ──
	if vfn_field and current_state == AIState.CHASE:
		var vfn_vec = vfn_field.get_vector_smooth_world(global_transform.origin)
		if vfn_vec.length() > 0.01:
			velocity.x = vfn_vec.x * move_speed
			velocity.z = vfn_vec.z * move_speed
			if mesh:
				var rot = atan2(vfn_vec.x, vfn_vec.z)
				mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 8 * delta)

	move_and_slide()


func _attack_timer_tick(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta


# ── AI BEHAVIORS ───────────────────────────────────────────────

func _idle(delta: float) -> void:
	if not target:
		return
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist < detection_range:
		current_state = AIState.CHASE
		_on_start_chase()


func _chase(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		target = null
		return

	var dist = global_transform.origin.distance_to(target.global_transform.origin)

	if dist > detection_range * 1.8:
		current_state = AIState.IDLE
		target = null
		return

	if dist < attack_range:
		current_state = AIState.ATTACK
		return

	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 8 * delta)


func _attack(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		return

	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist > attack_range * 1.3:
		current_state = AIState.CHASE
		return

	if attack_timer <= 0 and not is_attacking:
		_perform_attack()


func _special_behavior(delta: float) -> void:
	"""Override for unique behaviors (pounce, stalk, etc.)"""
	pass


# ── COMBAT ─────────────────────────────────────────────────────

func _perform_attack() -> void:
	if not target or is_dead:
		return

	is_attacking = true
	attack_timer = attack_cooldown_time

	Audio.play_zombie_reach()

	if target.has_method("take_damage"):
		target.take_damage(damage)

	await get_tree().create_timer(0.3).timeout
	is_attacking = false


func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	_flash_red()

	if target:
		var kb = (global_transform.origin - target.global_transform.origin).normalized()
		velocity.x += kb.x * 3
		velocity.z += kb.z * 3

	Audio.play_hurt()

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	current_state = AIState.DEAD
	emit_signal("died")

	Audio.play_zombie_die()

	var t = create_tween()
	if mesh:
		t.tween_property(mesh, "rotation:x", deg_to_rad(85), fade_duration)
		t.parallel().tween_property(mesh, "position:y", position.y - 0.2, fade_duration)
		t.parallel().tween_property(mesh, "modulate", Color(1, 1, 1, 0), fade_duration * 0.6)
	else:
		t.tween_property(self, "modulate", Color(1, 1, 1, 0), fade_duration)

	await t.finished

	# ── POOLING: if pooled, do NOT queue_free — return to pool instead ──
	if pooled:
		# Hide and pause so the pool can recycle us
		hide()
		process_mode = Node.PROCESS_MODE_PAUSABLE
		# The spawner's _return_to_pool will call pool._on_killed() to
		# move us from alive→dead in the pool dictionary.
	else:
		queue_free()


# ── HELPERS ───────────────────────────────────────────────────

func _flash_red() -> void:
	if not mesh:
		return
	if hit_flash_tween and hit_flash_tween.is_running():
		hit_flash_tween.kill()

	var mat = mesh.get_surface_override_material(0)
	if mat:
		mat.emissive_color = Color(1, 0.2, 0.2)
		hit_flash_tween = create_tween()
		hit_flash_tween.tween_property(mat, "emissive_color", Color(0, 0, 0), 0.15)


func set_target(new_target: Node3D) -> void:
	target = new_target
	if current_state == AIState.IDLE:
		current_state = AIState.CHASE


func set_vfn_field(field) -> void:
	"""Inject a VectorFieldNavigation field for horde-style movement."""
	vfn_field = field


func _on_DetectionArea_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_dead:
		set_target(body)


func _on_start_chase() -> void:
	"""Called when starting to chase (override for sounds/animation)"""
	pass


func attack(target: Node3D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
