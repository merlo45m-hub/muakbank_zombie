extends ZombieBase
class_name ZombieChicken

## Zombie Chicken — Swarm Fodder
## Fast, very low HP, flaps wildly when charging

# === CHICKEN-SPECIFIC STATS ===
@export var flap_interval_time: float = 0.3
var flap_timer: float = 0.0

func _post_ready() -> void:
	max_health = 10
	move_speed = 4.5
	damage = 8
	attack_range = 1.0
	detection_range = 8.0
	attack_cooldown_time = 0.5
	fade_duration = 0.3

func _physics_process(delta: float) -> void:
	if flap_timer > 0:
		flap_timer -= delta
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
	
	# Erratic chicken movement with flaps
	if flap_timer <= 0:
		_do_flap()
		flap_timer = flap_interval_time
	
	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	
	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 10 * delta)

func _do_flap() -> void:
	velocity.y = 3.0
	
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "rotation:z", deg_to_rad(15), 0.08)
		t.tween_property(mesh, "rotation:z", deg_to_rad(-15), 0.08)
		t.tween_property(mesh, "rotation:z", deg_to_rad(0), 0.08)

func _perform_attack() -> void:
	if not target or is_dead:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown_time
	
	Audio.play_zombie_reach()
	
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "position:z", mesh.position.z - 0.2, 0.05)
		t.tween_property(mesh, "position:z", mesh.position.z, 0.1)
	
	if target and not is_dead:
		var dist = global_transform.origin.distance_to(target.global_transform.origin)
		if dist < attack_range * 1.3:
			if target.has_method("take_damage"):
				target.take_damage(damage)
	
	await get_tree().create_timer(0.3).timeout
	is_attacking = false
