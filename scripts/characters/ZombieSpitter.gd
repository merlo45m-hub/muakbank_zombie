extends ZombieBase
class_name ZombieSpitter

## Zombie Spitter — Ranged attacker that lobs acid at the player
## Keeps distance, spits a projectile that damages on impact.

@export var preferred_range: float = 8.0
@export var spit_speed: float = 12.0

var is_spitting: bool = false

func _post_ready() -> void:
	max_health = 35
	move_speed = 2.2
	damage = 14
	attack_range = 9.0
	detection_range = 18.0
	attack_cooldown_time = 2.2
	fade_duration = 0.5

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

	# In spit range -> attack
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

func _perform_attack() -> void:
	if not target or is_dead or is_spitting:
		return

	is_spitting = true
	is_attacking = true
	attack_timer = attack_cooldown_time
	Audio.play_zombie_reach()

	# Wind-up animation
	if mesh:
		var t = create_tween()
		t.tween_property(mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.2)
		t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.15)
		await t.finished

	_spit()

	await get_tree().create_timer(0.4).timeout
	is_attacking = false
	is_spitting = false
	current_state = AIState.CHASE

func _spit() -> void:
	if not target or is_dead:
		return
	var from = global_transform.origin + Vector3(0, 1.0, 0)
	var to = target.global_transform.origin + Vector3(0, 0.8, 0)
	_spawn_projectile(from, (to - from).normalized())

func _spawn_projectile(from: Vector3, dir: Vector3) -> void:
	var proj = Area3D.new()
	proj.collision_layer = 0
	proj.collision_mask = 2  # player only

	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 0.15)
	sphere.material = mat
	mesh_inst.mesh = sphere
	proj.add_child(mesh_inst)

	var shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.25
	shape.shape = sphere_shape
	proj.add_child(shape)

	get_tree().current_scene.add_child(proj)
	proj.global_position = from

	# Simple straight-line flight with a lifetime
	var lifetime = 2.5
	var travelled = 0.0
	var speed = spit_speed
	var dmg = damage

	# Use a coroutine-style loop via a helper Timer
	var t = Timer.new()
	t.wait_time = 0.03
	t.one_shot = false
	proj.add_child(t)

	var step_fn = func():
		if not is_instance_valid(proj):
			return
		var delta_dist = speed * 0.03
		travelled += delta_dist
		proj.global_position += dir * delta_dist
		# Hit check against player
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and proj.global_position.distance_to(p.global_transform.origin + Vector3(0, 0.8, 0)) < 0.6:
				if p.has_method("take_damage"):
					p.take_damage(dmg)
				proj.queue_free()
				return
		if travelled > lifetime * speed:
			proj.queue_free()

	t.timeout.connect(step_fn)
	t.start()
