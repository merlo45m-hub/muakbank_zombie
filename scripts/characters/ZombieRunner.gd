extends ZombieBase
class_name ZombieRunner

## Zombie Runner — Fast skirmisher that dodges sideways between charges
## Low HP, high speed, erratic strafing. Extends ZombieBase.

@export var strafe_speed: float = 6.0
@export var strafe_interval: float = 1.2
@export var dodge_chance: float = 0.3

var strafe_timer: float = 0.0
var strafe_dir: float = 1.0

func _post_ready() -> void:
	max_health = 22
	move_speed = 6.5
	damage = 12
	attack_range = 1.3
	detection_range = 16.0
	attack_cooldown_time = 0.8
	fade_duration = 0.35

func _physics_process(delta: float) -> void:
	if strafe_timer > 0:
		strafe_timer -= delta
	super._physics_process(delta)

func _chase(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		target = null
		return

	var dist = global_transform.origin.distance_to(target.global_transform.origin)

	if dist > detection_range * 1.6:
		current_state = AIState.IDLE
		target = null
		return

	if dist < attack_range:
		current_state = AIState.ATTACK
		return

	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0

	# Periodically strafe sideways while closing
	if strafe_timer <= 0:
		strafe_dir = 1.0 if randf() < 0.5 else -1.0
		strafe_timer = strafe_interval

	var strafe = Vector3(-dir.z, 0, dir.x) * strafe_dir * strafe_speed * 0.4
	velocity.x = dir.x * move_speed + strafe.x
	velocity.z = dir.z * move_speed + strafe.z

	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 12 * delta)

func take_damage(amount: int) -> void:
	# Chance to dodge before taking damage
	if not is_dead and randf() < dodge_chance:
		if mesh:
			var t = create_tween()
			t.tween_property(mesh, "scale", Vector3(0.7, 1.3, 0.7), 0.08)
			t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.12)
		return
	super.take_damage(amount)
