extends ZombieBase
class_name ZombieRunner

## Zombie Runner — Fast skirmisher that dodges sideways between charges
## Low HP, high speed, erratic strafing. Extends ZombieBase.
## Uses the rigged zombie model (zombie_rigged.gltf) with baked animations.
## The procedural animator is neutralized for this subtype — all movement and
## combat visuals come from the AnimationPlayer instead.

@export var strafe_speed: float = 6.0
@export var strafe_interval: float = 1.2
@export var dodge_chance: float = 0.3

var strafe_timer: float = 0.0
var strafe_dir: float = 1.0

# Reference to the rigged model's animation library, set in _post_ready().
var _anim_lib = null

func _post_ready() -> void:
	max_health = 22
	move_speed = 6.5
	damage = 12
	attack_range = 1.3
	detection_range = 16.0
	attack_cooldown_time = 0.8
	fade_duration = 0.35

	# Neutralize the ProceduralAnimator for this subtype — all movement and
	# combat visuals come from the AnimationPlayer baked animations instead.
	var pa := get_node_or_null("ProceduralAnimator")
	if pa:
		pa.set_process(false)

	# Attach the rigged model's animation library to the AnimationPlayer.
	# The AnimationPlayer node is a child of Mesh (added in zombie_runner.tscn).
	var ap: AnimationPlayer = get_node_or_null("Mesh/AnimationPlayer")
	if ap:
		_anim_lib = preload("res://assets/models/zombie_rigged/zombie_rigged.gltf").animation_library
		if _anim_lib:
			ap.animation_library = _anim_lib
		# Start in IDLE.
		ap.play("IDLE")

func _physics_process(delta: float) -> void:
	if strafe_timer > 0:
		strafe_timer -= delta
	super._physics_process(delta)

	# Drive animations from movement speed (skip if dead — DEAD animation owns the corpse).
	if not is_dead:
		var ap: AnimationPlayer = get_node_or_null("Mesh/AnimationPlayer")
		if not ap or not _anim_lib:
			return
		var h_speed: float = Vector2(velocity.x, velocity.z).length()
		if h_speed < 0.2:
			if ap.get_current_animation() != "IDLE":
				ap.play("IDLE")
		elif h_speed < move_speed * 0.5:
			if ap.get_current_animation() != "WALK":
				ap.play("WALK")
		else:
			if ap.get_current_animation() != "RUN":
				ap.play("RUN")

func take_damage(amount: int) -> void:
	# Chance to dodge before taking damage
	if not is_dead and randf() < dodge_chance:
		if mesh:
			var t = create_tween()
			t.tween_property(mesh, "scale", Vector3(0.7, 1.3, 0.7), 0.08)
			t.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.12)
		# Play HIT animation on the rig instead of procedural squash.
		var ap: AnimationPlayer = get_node_or_null("Mesh/AnimationPlayer")
		if ap and _anim_lib:
			ap.play("HIT")
		return
	# Neutralize procedural hit reaction — the rig's HIT animation handles it.
	var ap: AnimationPlayer = get_node_or_null("Mesh/AnimationPlayer")
	if ap and _anim_lib:
		ap.play("HIT")
	super.take_damage(amount)

func _on_start_chase() -> void:
	# Neutralize procedural startle hop — the rig's animation handles movement visuals.
	pass

func _perform_attack() -> void:
	# Neutralize procedural 3-phase lunge — the rig's ATK/ATK_HEAD animation handles it.
	if not target or is_dead:
		return
	is_attacking = true
	attack_timer = attack_cooldown_time
	Audio.play_zombie_reach()
	if target.has_method("take_damage"):
		target.take_damage(damage)
	await _wait(0.3)
	is_attacking = false

func _attack(delta: float) -> void:
	# Override to prevent ProceduralAnimator auto-trigger on is_attacking rising edge.
	# The rig's ATK animation plays via _perform_attack() above.
	if not target or is_dead:
		current_state = AIState.IDLE
		return
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist > attack_range * 1.3:
		current_state = AIState.CHASE
		return
	if attack_timer <= 0 and not is_attacking:
		_perform_attack()

func _die() -> void:
	# Play the rig's DEAD animation and skip the procedural death tween entirely.
	# The rig's DEAD animation owns the corpse visuals (rotation, pose, fade).
	is_dead = true
	current_state = AIState.DEAD
	collision_layer = 0
	collision_mask = 0
	Audio.play_zombie_die()

	var ap: AnimationPlayer = get_node_or_null("Mesh/AnimationPlayer")
	if ap and _anim_lib:
		ap.play("DEAD")
		if is_inside_tree():
			await ap.animation_finished

	# Emit AFTER the animation so the spawner's detach/score/loot logic runs
	# once the corpse is already invisible — no corpse-pop.
	emit_signal("died")

	# Pooling: if pooled, do NOT queue_free — return to pool instead.
	if pooled:
		hide()
		process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		queue_free()


