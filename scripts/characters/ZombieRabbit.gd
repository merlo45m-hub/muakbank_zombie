extends ZombieBase
class_name ZombieRabbit

## Zombie Rabbit — Fast swarm enemy
## Very fast, very low HP, hops erratically, attacks in bursts

# === RABBIT-SPECIFIC STATS ===
@export var hop_interval_time: float = 0.4
var hop_timer: float = 0.0

func _post_ready() -> void:
	max_health = 10
	move_speed = 7.5
	damage = 5
	attack_range = 0.9
	detection_range = 8.0
	attack_cooldown_time = 0.4
	fade_duration = 0.3

func _physics_process(delta: float) -> void:
	if hop_timer > 0:
		hop_timer -= delta
	super._physics_process(delta)

func _chase(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		target = null
		return
	
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	
	if dist > detection_range * 1.5:
		current_state = AIState.IDLE
		target = null
		return
	
	if dist < attack_range:
		current_state = AIState.ATTACK
		return
	
	# Erratic hop movement
	if hop_timer <= 0 and is_on_floor():
		_do_hop()
		hop_timer = hop_interval_time
	
	# Face target
	if mesh:
		var dir = (target.global_transform.origin - global_transform.origin).normalized()
		dir.y = 0
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 12 * delta)

func _do_hop() -> void:
	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	
	# Add randomness
	var angle = randf() * 0.5 - 0.25
	dir = dir.rotated(Vector3.UP, angle)
	
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	velocity.y = 4.0
	
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(0.8, 1.3, 0.8), 0.1)
		t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.15)

func _perform_attack() -> void:
	if not target or is_dead:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown_time
	
	Audio.play_zombie_reach()
	
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.05)
		t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.1)
	
	if target and not is_dead:
		var dist = global_transform.origin.distance_to(target.global_transform.origin)
		if dist < attack_range * 1.3:
			if target.has_method("take_damage"):
				target.take_damage(damage)
	
	await get_tree().create_timer(0.2).timeout
	is_attacking = false

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	health -= amount
	_flash_red()
	
	# Big knockback for small creature
	if target:
		var kb = (global_transform.origin - target.global_transform.origin).normalized()
		velocity.x += kb.x * 6
		velocity.z += kb.z * 6
	
	Audio.play_hurt()
	
	if health <= 0:
		_die()
