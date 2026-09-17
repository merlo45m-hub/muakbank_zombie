extends ZombieBase
class_name ZombieBear

## Zombie Bear — Heavy Tank
## Slow, massive HP pool, devastating slam attack. Charges when enraged.

# === BEAR-SPECIFIC STATS ===
@export var enraged_speed: float = 3.5
@export var enrage_threshold: float = 0.3
var is_enraged: bool = false

func _post_ready() -> void:
	max_health = 80
	move_speed = 2.0
	damage = 25
	attack_range = 2.2
	detection_range = 15.0
	attack_cooldown_time = 2.0
	fade_duration = 0.8

func _process(delta: float) -> void:
	super._process(delta)
	# Check enrage
	if not is_enraged and health > 0 and float(health) <= float(max_health) * enrage_threshold:
		_enrage()

func _enrage() -> void:
	is_enraged = true
	Audio.play_zombie_reach()
	
	# Roar animation
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(1.3, 1.5, 1.3), 0.2)
		t.tween_property(mesh, "scale", Vector3(1.1, 1.1, 1.1), 0.3)

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
	
	var speed = enraged_speed if is_enraged else move_speed
	
	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	
	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 5 * delta)

func _attack(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		return
	
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist > attack_range * 1.5:
		current_state = AIState.CHASE
		return
	
	# Raise up on hind legs
	if mesh:
		mesh.scale = mesh.scale.lerp(Vector3(1.0, 1.4, 1.0), 8 * delta)
	
	if attack_timer <= 0 and not is_attacking:
		_perform_slam()

func _perform_slam() -> void:
	is_attacking = true
	attack_timer = attack_cooldown_time
	
	Audio.play_zombie_reach()
	
	# Slam down
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(1.3, 0.5, 1.3), 0.15)
		t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.2)
		await t.finished
	
	# AoE damage check
	if target and not is_dead:
		var dist = global_transform.origin.distance_to(target.global_transform.origin)
		if dist < attack_range * 1.5:
			if target.has_method("take_damage"):
				target.take_damage(damage)
	
	await get_tree().create_timer(1.0).timeout
	is_attacking = false
	current_state = AIState.CHASE
