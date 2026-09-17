extends ZombieBase
class_name ZombieBoss

## Zombie Boss — Massive tank with slam + charge attacks
## Appears at wave 5 / boss levels. High HP, devastating damage.

@export var charge_speed: float = 8.0
@export var charge_cooldown: float = 4.0
@export var slam_radius: float = 4.0
@export var slam_damage: int = 30

var charge_timer: float = 0.0
var is_charging: bool = false
var is_enraged: bool = false

func _post_ready() -> void:
	max_health = 300
	move_speed = 2.5
	damage = 25
	attack_range = 3.0
	detection_range = 20.0
	attack_cooldown_time = 2.5
	fade_duration = 1.0
	scale = Vector3(2.0, 2.0, 2.0)

func _physics_process(delta: float) -> void:
	if charge_timer > 0:
		charge_timer -= delta
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
	
	# Charge attack when close and off cooldown
	if dist < attack_range * 3.0 and charge_timer <= 0 and not is_charging:
		_start_charge()
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
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 5 * delta)

func _start_charge() -> void:
	is_charging = true
	charge_timer = charge_cooldown
	Audio.play_zombie_reach()
	
	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	velocity.x = dir.x * charge_speed
	velocity.z = dir.z * charge_speed
	
	# Charge for 1 second
	await get_tree().create_timer(1.0).timeout
	is_charging = false
	current_state = AIState.CHASE

func _perform_attack() -> void:
	if not target or is_dead:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown_time
	Audio.play_zombie_reach()
	
	# Slam AoE
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(2.2, 1.5, 2.2), 0.2)
		t.tween_property(mesh, "scale", Vector3(2.0, 2.0, 2.0), 0.3)
		await t.finished
	
	# AoE damage
	var enemies = get_tree().get_nodes_in_group("player")
	for p in enemies:
		if is_instance_valid(p):
			var dist = global_transform.origin.distance_to(p.global_transform.origin)
			if dist < slam_radius:
				if p.has_method("take_damage"):
					p.take_damage(slam_damage)
	
	await get_tree().create_timer(1.0).timeout
	is_attacking = false
	current_state = AIState.CHASE

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	# Enrage at 50% HP
	if not is_enraged and health > 0 and float(health) <= float(max_health) * 0.5:
		_enrage()

func _enrage() -> void:
	is_enraged = true
	move_speed *= 1.5
	damage *= 1.5
	Audio.play_frenzy()
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(2.3, 2.3, 2.3), 0.3)
		t.tween_property(mesh, "scale", Vector3(2.0, 2.0, 2.0), 0.3)
