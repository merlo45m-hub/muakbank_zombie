extends ZombieBase
class_name ZombieDog

## Zombie Dog — Fast pack hunter with lunge attack
## Overrides base behaviors with unique windup/lunge mechanic

# === DOG-SPECIFIC STATS ===
@export var bark_cooldown_time: float = 2.5
var bark_timer: float = 0.0

func _post_ready() -> void:
	max_health = 30
	move_speed = 4.0
	damage = 10
	attack_range = 1.6
	detection_range = 14.0
	attack_cooldown_time = 1.2

func _physics_process(delta: float) -> void:
	if bark_timer > 0:
		bark_timer -= delta
	super._physics_process(delta)

func _on_start_chase() -> void:
	_bark()

func _chase(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		target = null
		return
	
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	
	if dist > detection_range * 2.0:
		current_state = AIState.IDLE
		target = null
		return
	
	if dist < attack_range:
		# Start windup/lunge instead of basic attack
		current_state = AIState.SPECIAL
		return
	
	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	
	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 10 * delta)
	
	if bark_timer <= 0:
		_bark()
		bark_timer = bark_cooldown_time

func _special_behavior(delta: float) -> void:
	# Windup → lunge attack
	if not target or is_dead:
		current_state = AIState.IDLE
		return
	
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist > attack_range * 1.3:
		current_state = AIState.CHASE
		return
	
	velocity.x = move_toward(velocity.x, 0, 20 * delta)
	velocity.z = move_toward(velocity.z, 0, 20 * delta)
	
	if mesh:
		var to_target = target.global_transform.origin - global_transform.origin
		to_target.y = 0
		if to_target.length() > 0.1:
			var rot = atan2(to_target.x, to_target.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 15 * delta)
			mesh.scale = mesh.scale.lerp(Vector3(1.0, 0.7, 1.1), 8 * delta)
	
	if attack_timer <= 0 and not is_attacking:
		_perform_lunge()

func _perform_lunge() -> void:
	is_attacking = true
	attack_timer = attack_cooldown_time
	
	Audio.play_zombie_reach()
	
	if mesh:
		mesh.scale = Vector3(1.0, 0.6, 1.3)
		var lunge_dir = (target.global_transform.origin - global_transform.origin).normalized()
		lunge_dir.y = 0
		velocity.x = lunge_dir.x * 12
		velocity.z = lunge_dir.z * 12
	
	attack_timer_node.start(0.25)
	await attack_timer_node.timeout
	
	if target and not is_dead:
		var dist = global_transform.origin.distance_to(target.global_transform.origin)
		if dist < attack_range * 1.3:
			if target.has_method("take_damage"):
				target.take_damage(damage)
	
	if mesh:
		mesh.scale = Vector3(1, 1, 1)
	
	is_attacking = false
	current_state = AIState.CHASE

func _bark() -> void:
	Audio.play_zombie_reach()
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(1.15, 0.85, 1.0), 0.08)
		t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.12)
