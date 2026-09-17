extends ZombieBase
class_name ZombieCat

## Zombie Cat — Ambush predator with pounce attack
## Uses SPECIAL state for stalking and high-arc pounce

# === CAT-SPECIFIC STATS ===
@export var stalk_speed: float = 1.5

func _post_ready() -> void:
	max_health = 20
	move_speed = 5.5
	damage = 15
	attack_range = 1.4
	detection_range = 10.0
	attack_cooldown_time = 1.0

func _chase(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		target = null
		return
	
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	
	# Got close enough to pounce
	if dist < attack_range * 3.0:
		current_state = AIState.SPECIAL
		return
	
	# Lost the player
	if dist > detection_range * 1.5:
		current_state = AIState.IDLE
		target = null
		return
	
	# Slow, silent stalk
	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	
	velocity.x = dir.x * stalk_speed
	velocity.z = dir.z * stalk_speed
	
	# Crouch while stalking
	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 6 * delta)
		mesh.scale = mesh.scale.lerp(Vector3(1.0, 0.5, 1.0), 5 * delta)

func _special_behavior(delta: float) -> void:
	# Pounce windup → arc pounce
	if not target or is_dead:
		current_state = AIState.IDLE
		return
	
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist > attack_range * 4.0:
		current_state = AIState.CHASE
		return
	
	velocity.x = move_toward(velocity.x, 0, 25 * delta)
	velocity.z = move_toward(velocity.z, 0, 25 * delta)
	
	if mesh:
		var to_target = target.global_transform.origin - global_transform.origin
		to_target.y = 0
		if to_target.length() > 0.1:
			var rot = atan2(to_target.x, to_target.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 20 * delta)
			mesh.scale = mesh.scale.lerp(Vector3(1.0, 0.3, 1.2), 12 * delta)
	
	if attack_timer <= 0 and not is_attacking:
		_perform_pounce()

func _perform_pounce() -> void:
	is_attacking = true
	attack_timer = attack_cooldown_time
	
	Audio.play_zombie_reach()
	
	var to_target = target.global_transform.origin - global_transform.origin
	var pounce_dir = to_target.normalized()
	var pounce_dist = to_target.length()
	
	if mesh:
		mesh.scale = Vector3(1.0, 0.4, 1.5)
		
		# High arc pounce
		var t = create_tween()
		t.tween_property(self, "position", position + Vector3(pounce_dir.x * pounce_dist * 0.8, 3, pounce_dir.z * pounce_dist * 0.8), 0.2)
		t.tween_property(self, "position", position + Vector3(pounce_dir.x * pounce_dist * 0.8, 0, pounce_dir.z * pounce_dist * 0.8), 0.25)
		t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.15)
		await t.finished
	
	# Damage check
	if target and not is_dead:
		var dist = global_transform.origin.distance_to(target.global_transform.origin)
		if dist < attack_range * 1.5:
			if target.has_method("take_damage"):
				target.take_damage(damage)
	
	is_attacking = false
	current_state = AIState.CHASE
