extends CharacterBody3D
class_name ZombieBase

## Zombie Base — Shared AI for all zombie animals
## All enemy types extend this class and override _get_stats() and _setup()
## Supports object pooling (dead/pooled props) and VectorFieldNavigation (vfn_field)

signal died

# === EXPORTED STATS (override in subclasses) ===
@export var max_health: int = 30
@export var move_speed: float = 3.0
@export var damage: int = 10
@export var attack_range: float = 1.5
@export var detection_range: float = 12.0
@export var gravity: float = 18.0
@export var attack_cooldown_time: float = 1.5
@export var fade_duration: float = 0.5

# === STATE ===
var health: int
var is_dead: bool = false
var target: Node3D = null
var is_attacking: bool = false
var attack_timer: float = 0.0
var hit_flash_tween: Tween = null
var is_hidden: bool = false

# === POOLING SUPPORT ===
var dead: bool = false          # Object-pool compatibility: must be false when alive, true when in dead pool
var pooled: bool = false       # True when managed by ZombieSpawner3D's pool — suppresses queue_free()
var pool_entry = null          # Set by ZombieSpawner3D on checkout ({pool, scene, type}) — used to return us
var zombie_type: String = ""   # Set by ZombieSpawner3D on checkout
var _mesh_rest_xform: Transform3D = Transform3D()  # pristine mesh transform, restored on pool reuse

# === VFN NAVIGATION ===
var vfn_field = null  # Reference to the active VFNField (untyped: addon class may be absent)

# === NODE REFS ===
@onready var mesh: Node3D = $Mesh
@onready var attack_timer_node: Timer = $AttackTimer

# === AI STATES ===
enum AIState { IDLE, CHASE, ATTACK, SPECIAL, DEAD }
var current_state: AIState = AIState.IDLE

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	if mesh:
		_mesh_rest_xform = mesh.transform  # pristine transform, restored by reset_for_pool()
	_post_ready()


func _post_ready() -> void:
	"""Override for subclass-specific setup"""
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_attack_timer_tick(delta)

	match current_state:
		AIState.IDLE:
			_idle(delta)
		AIState.CHASE:
			_chase(delta)
		AIState.ATTACK:
			_attack(delta)
		AIState.SPECIAL:
			_special_behavior(delta)

	if current_state != AIState.ATTACK:
		velocity.x = move_toward(velocity.x, 0, 6 * delta)
		velocity.z = move_toward(velocity.z, 0, 6 * delta)

	# ── VFN OVERRIDE: if a field is set and we're chasing, use vector field ──
	if vfn_field and current_state == AIState.CHASE:
		var vfn_vec = vfn_field.get_vector_smooth_world(global_transform.origin)
		if vfn_vec.length() > 0.01:
			velocity.x = vfn_vec.x * move_speed
			velocity.z = vfn_vec.z * move_speed
			if mesh:
				var rot = atan2(vfn_vec.x, vfn_vec.z)
				mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 8 * delta)

	move_and_slide()


func _attack_timer_tick(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta


# ── AI BEHAVIORS ───────────────────────────────────────────────

func _idle(delta: float) -> void:
	# body_entered on DetectionArea only fires when the player ENTERS the sphere,
	# so a zombie spawned outside it (the spawner places them 8-15 units out, and
	# the sphere is r=12) never acquires a target and idles forever — no chase,
	# no attacks, an empty-feeling game. Acquire by RANGE instead.
	if not target:
		var p = get_tree().get_first_node_in_group("player")
		if p is Node3D:
			var pd: float = global_transform.origin.distance_to(p.global_transform.origin)
			if pd < detection_range:
				set_target(p)
		if not target:
			return
	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist < detection_range:
		current_state = AIState.CHASE
		_on_start_chase()


func _chase(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		target = null
		return

	var dist = global_transform.origin.distance_to(target.global_transform.origin)

	if dist > detection_range * 1.8:
		current_state = AIState.IDLE
		target = null
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
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 8 * delta)


func _attack(delta: float) -> void:
	if not target or is_dead:
		current_state = AIState.IDLE
		return

	var dist = global_transform.origin.distance_to(target.global_transform.origin)
	if dist > attack_range * 1.3:
		current_state = AIState.CHASE
		return

	if attack_timer <= 0 and not is_attacking:
		_perform_attack()


func _special_behavior(delta: float) -> void:
	"""Override for unique behaviors (pounce, stalk, etc.)"""
	pass


# ── COMBAT ─────────────────────────────────────────────────────

func _perform_attack() -> void:
	if not target or is_dead:
		return

	is_attacking = true
	attack_timer = attack_cooldown_time

	Audio.play_zombie_reach()

	if target.has_method("take_damage"):
		target.take_damage(damage)

	await _wait(0.3)
	is_attacking = false


func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	_flash_red()

	if target:
		var kb = (global_transform.origin - target.global_transform.origin).normalized()
		velocity.x += kb.x * 3
		velocity.z += kb.z * 3

	Audio.play_hurt()

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	current_state = AIState.DEAD
	emit_signal("died")

	Audio.play_zombie_die()

	var t = create_tween()
	if mesh:
		t.tween_property(mesh, "rotation:x", deg_to_rad(85), fade_duration)
		t.parallel().tween_property(mesh, "position:y", position.y - 0.2, fade_duration)
		for mi in _mesh_instances():
			# Node3D has no `modulate` — fade 3D meshes via
			# GeometryInstance3D.transparency (0 = opaque, 1 = invisible).
			t.parallel().tween_property(mi, "transparency", 1.0, fade_duration * 0.6)
	else:
		# no Mesh child — nothing visual to fade, just wait out the duration
		t.tween_interval(fade_duration)

	# The spawner's died-handler runs synchronously on the signal above, so a
	# pooled zombie is already detached from the tree by now — a tween bound to
	# a node outside the tree never finishes, so only await while still inside.
	if is_inside_tree():
		await t.finished

	# ── POOLING: if pooled, do NOT queue_free — return to pool instead ──
	if pooled:
		# Hide and pause so the pool can recycle us; reset_for_pool() restores
		# health, visibility and the mesh transform on the next checkout.
		hide()
		process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		queue_free()


func reset_for_pool() -> void:
	# Restore full working state when ZombieSpawner3D checks this zombie out of
	# the object pool (called before add_child on every reuse).
	is_dead = false
	dead = false
	health = max_health
	current_state = AIState.IDLE
	is_attacking = false
	attack_timer = 0.0
	target = null
	hit_flash_tween = null
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	# Parked instances are taken out of the tree with collisions zeroed (see
	# ZombieSpawner3D._create_pool) — restore world interaction on checkout.
	collision_layer = 8
	collision_mask = 1
	if mesh:
		mesh.transform = _mesh_rest_xform
	for mi in _mesh_instances():
		mi.transparency = 0.0
		mi.material_overlay = null


# ── HELPERS ───────────────────────────────────────────────────

func _mesh_instances() -> Array[MeshInstance3D]:
	# Collect the MeshInstance3D nodes under the Mesh container — the model is
	# an instanced GLB, so they live one or more levels down and 3D tint/fade
	# operations (which Node3D itself has no property for) must target them.
	var out: Array[MeshInstance3D] = []
	if not mesh:
		return out
	var stack: Array[Node] = [mesh]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is MeshInstance3D:
				out.append(c)
			stack.push_back(c)
	return out


func _set_overlay_alpha(a: float) -> void:
	for mi in _mesh_instances():
		var m := mi.material_overlay as StandardMaterial3D
		if m == null:
			m = StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_overlay = m
		m.albedo_color = Color(1, 0.2, 0.2, a)


func _flash_red() -> void:
	if not mesh:
		return
	if hit_flash_tween and hit_flash_tween.is_running():
		hit_flash_tween.kill()

	# 3D meshes expose no `modulate`/`emissive_color` on the Node3D container —
	# tint the GLB's MeshInstance3D children through a fading material_overlay.
	if _mesh_instances().is_empty():
		return
	_set_overlay_alpha(0.55)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_method(_set_overlay_alpha, 0.55, 0.0, 0.15)


func set_target(new_target: Node3D) -> void:
	target = new_target
	if current_state == AIState.IDLE:
		current_state = AIState.CHASE


func set_vfn_field(field) -> void:
	"""Inject a VectorFieldNavigation field for horde-style movement."""
	vfn_field = field


func _on_DetectionArea_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_dead:
		set_target(body)


func _on_start_chase() -> void:
	"""Called when starting to chase (override for sounds/animation)"""
	pass


func attack(target: Node3D) -> void:
	"""Contact-triggered attack (hurtbox overlap / AI call).

	Shares the AI's cooldown so a body merely brushing the player cannot
	machine-gun damage. Dead instances never deal damage.

	NOTE: do NOT guard on `pooled` here. `pooled` is set once on spawn
	(ZombieSpawner3D) and must stay true for the zombie's whole life — it is what
	tells _die() to return the instance to the pool instead of queue_free()ing it.
	Using it as a "not currently in the world" test disabled this whole damage
	path for every live zombie (a chasing zombie that bumped the player dealt
	nothing). Parked instances are detached from the tree, so they cannot receive
	body_entered signals anyway.
	"""
	if is_dead:
		return
	if attack_timer > 0.0:
		return
	if target == null or not target.has_method("take_damage"):
		return
	print("[ATTACK] %s (dmg=%d) at %s  dist_to_%s=%.2f  dead=%s pooled=%s" % [
		name, damage, str(global_position), target.name,
		global_position.distance_to(target.global_position), str(is_dead), str(pooled)])
	attack_timer = attack_cooldown_time
	target.take_damage(damage)

func _wait(sec: float) -> bool:
	# Both the player and zombies can be freed/pooled while a timer await is
	# pending (death, pool return), and get_tree() is null once the node is out of
	# the tree — awaiting it blindly throws "Cannot call method 'create_timer' on
	# a null value" and abandons the rest of the coroutine. Skip instead.
	var t := get_tree()
	if not t or not is_inside_tree():
		return false
	await t.create_timer(sec).timeout
	return is_instance_valid(self) and is_inside_tree()
