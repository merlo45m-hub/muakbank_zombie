extends ZombieBase
class_name ZombieButcher

## Zombie Butcher — Second boss. Heavy cleave + summons minions.
## Slower than the Bear boss, but summons adds and hits in a wide arc.

@export var cleave_arc: float = 120.0  # degrees
@export var cleave_range: float = 3.5
@export var summon_interval: float = 8.0
@export var summon_count: int = 3
@export var minion_scene: PackedScene = null

var summon_timer: float = 0.0

func _post_ready() -> void:
	max_health = 260
	move_speed = 2.8
	damage = 22
	attack_range = 3.0
	detection_range = 18.0
	attack_cooldown_time = 2.0
	fade_duration = 0.9
	scale = Vector3(1.8, 1.8, 1.8)
	if not minion_scene:
		minion_scene = load("res://scenes/characters/zombie_chicken.tscn")

func _physics_process(delta: float) -> void:
	if summon_timer > 0:
		summon_timer -= delta
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

	# Summon minions on cooldown
	if summon_timer <= 0:
		_summon_minions()

	if dist < attack_range:
		current_state = AIState.ATTACK
		return

	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 6 * delta)

func _summon_minions() -> void:
	summon_timer = summon_interval
	Audio.play_zombie_growl()
	if not minion_scene or not is_instance_valid(get_tree().current_scene):
		return
	for i in range(summon_count):
		var m = minion_scene.instantiate()
		var angle = randf() * TAU
		var dist = 3.0 + randf() * 2.0
		m.global_position = global_transform.origin + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		get_tree().current_scene.add_child(m)
	print("[Butcher] Summoned ", summon_count, " minions")

func _perform_attack() -> void:
	if not target or is_dead:
		return

	is_attacking = true
	attack_timer = attack_cooldown_time
	Audio.play_zombie_reach()

	# Cleave animation
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "rotation:y", mesh.rotation.y + deg_to_rad(cleave_arc / 2.0), 0.15)
		t.tween_property(mesh, "rotation:y", mesh.rotation.y - deg_to_rad(cleave_arc / 2.0), 0.2)
		await t.finished

	# Arc damage against the player
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		var to_p = p.global_transform.origin - global_transform.origin
		var dist = to_p.length()
		if dist > cleave_range:
			continue
		var forward = -global_transform.basis.z
		var angle = rad_to_deg(forward.angle_to(to_p.normalized()))
		if angle <= cleave_arc / 2.0:
			if p.has_method("take_damage"):
				p.take_damage(damage)

	await get_tree().create_timer(0.6).timeout
	is_attacking = false
	current_state = AIState.CHASE
