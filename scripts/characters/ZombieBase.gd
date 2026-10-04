extends CharacterBody3D
class_name ZombieBase

## Zombie Base — Shared AI for all zombie animals
## All enemy types extend this class and override _get_stats() and _setup()
## Supports object pooling (dead/pooled props) and VectorFieldNavigation (vfn_field)

signal died

# Per-type death animation parameters (spec §3).
# Keys match zombie_type; fall back to "default" if not found.
# pitch = final rotation.x degrees, spin = rotation.y delta degrees,
# bounce = upward position.y kick at impact, fall_t = fall tween duration,
# fade_t = transparency fade duration, spin_dir = fixed dir (0 = randomize).
const DEATH_PARAMS: Dictionary = {
	"dog":     {"pitch": 95,  "spin": 130, "bounce": 0.25, "fall_t": 0.45, "fade_t": 0.5,  "spin_dir": 0},
	"cat":     {"pitch": 100, "spin": 200, "bounce": 0.30, "fall_t": 0.40, "fade_t": 0.45, "spin_dir": 0},
	"rabbit":  {"pitch": 90,  "spin": 260, "bounce": 0.40, "fall_t": 0.35, "fade_t": 0.4,  "spin_dir": 0},
	"chicken": {"pitch": 105, "spin": 300, "bounce": 0.35, "fall_t": 0.30, "fade_t": 0.35, "spin_dir": 0},
	"bear":    {"pitch": 75,  "spin": 60,  "bounce": 0.10, "fall_t": 0.9,  "fade_t": 0.9,  "spin_dir": 0},
	"runner":  {"pitch": 95,  "spin": 170, "bounce": 0.28, "fall_t": 0.40, "fade_t": 0.5,  "spin_dir": 0},
	"spitter": {"pitch": 85,  "spin": 90,  "bounce": 0.15, "fall_t": 0.6,  "fade_t": 0.7,  "spin_dir": 0},
	"boss":    {"pitch": 70,  "spin": 40,  "bounce": 0.08, "fall_t": 1.2,  "fade_t": 1.4,  "spin_dir": 0},
	"default": {"pitch": 85,  "spin": 120, "bounce": 0.2,  "fall_t": 0.5,  "fade_t": 0.5,  "spin_dir": 0},
}

# === EXPORTED STATS (override in subclasses) ===
@export var max_health: int = 30
@export var move_speed: float = 3.0
@export var damage: int = 10
@export var attack_range: float = 1.5
@export var detection_range: float = 12.0
@export var gravity: float = 18.0
@export var attack_cooldown_time: float = 1.5
@export var fade_duration: float = 0.5

# === DIFFICULTY MULTIPLIER (set by spawner at spawn time) ===
var difficulty_multiplier: float = 1.0

# === BASE STATS (snapshot in _ready, used by apply_difficulty for safe scaling) ===
# Stored so apply_difficulty always scales from the original values and reset_for_pool
# can restore them on pool return. Without these, object pooling causes exponential
# inflation: each reuse multiplies an already-scaled stat (2.5x → 6.25x → 15.6x).
var base_max_health: int = 0
var base_damage: int = 0
var base_move_speed: float = 0.0

# === AI CONFIGURATION ===
# Separation stops a horde from collapsing into a single point at the player's feet.
# SCAN_RADIUS is the broadphase cutoff so we don't test every enemy; RADIUS is where
# the push actually starts, and FORCE scales the overlap depth into a velocity nudge.
const SEPARATION_SCAN_RADIUS = 3.0
const SEPARATION_RADIUS = 1.5
const SEPARATION_FORCE = 2.0
# Attackers are planted (velocity zeroed), so full-strength separation would slide
# them straight off the player. A fraction lets them jostle for the ring instead.
const ATTACK_SEPARATION_FACTOR = 0.3

# AI LOD: distant zombies still drift toward the player, but skip the state machine
# and VFN lookup — that is where the per-frame cost actually lives. The trigger is
# derived from detection_range instead of a flat 25m: zombies abandon the chase at
# detection_range * 1.8, so a fixed 25m sat past the give-up range of every common
# type and the block almost never ran.
const LOD_DISTANCE_FACTOR = 1.2
const LOD_INTERVAL = 0.5
const LOD_SPEED_FACTOR = 0.5

# === STATE ===
var health: int
var is_dead: bool = false
var target: Node3D = null
var is_attacking: bool = false
var attack_timer: float = 0.0
var hit_flash_tween: Tween = null
var is_hidden: bool = false
var _lod_timer: float = 0.0

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
	# Snapshot base stats before any difficulty scaling, so apply_difficulty
	# always scales from the original values and reset_for_pool can restore them.
	base_max_health = max_health
	base_damage = damage
	base_move_speed = move_speed
	add_to_group("enemies")
	if mesh:
		_mesh_rest_xform = mesh.transform  # pristine transform, restored by reset_for_pool()
		if mesh.is_inside_tree():
			var _anim := ProceduralAnimator.new()
			_anim.name = "ProceduralAnimator"
			# Reparent: body > ProceduralAnimator > mesh > GLB geometry.
			# The animator must be an ANCESTOR of the geometry so its own-transform
			# writes affect the subtree. Previously it was a sibling of the GLB root
			# (child of mesh) — transforms on a node only propagate to its children,
			# so nothing was ever visible.
			var holder := mesh.get_parent()
			holder.remove_child(mesh)
			_anim.add_child(mesh)
			holder.add_child(_anim)
			_anim.attach(self, mesh)
	_post_ready()


func _post_ready() -> void:
	"""Override for subclass-specific setup"""
	pass


func _get_animator() -> ProceduralAnimator:
	return get_node_or_null("ProceduralAnimator") as ProceduralAnimator


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		# Pooled zombies are parked by taking them out of the tree, and a body outside the
		# tree has no global transform, so the move_and_slide() at the end of this function
		# errored on every physics frame ("Condition !is_inside_tree() is true. Returning:
		# Transform3D()") instead of failing loudly once. The slot is inert anyway.
		return
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Cooldown ticks on every frame, including LOD frames — freezing it while a
	# zombie is far away left its attack timer stale on re-approach.
	_attack_timer_tick(delta)

	# AI LOD: past the LOD distance a zombie stops running the state machine and
	# VFN lookup (the expensive parts) and just drifts at the player on a slow tick.
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist_to_player = global_transform.origin.distance_to(player.global_transform.origin)
		if dist_to_player > detection_range * LOD_DISTANCE_FACTOR:
			_lod_timer += delta
			if _lod_timer < LOD_INTERVAL:
				if target:
					var dir = (target.global_transform.origin - global_transform.origin).normalized()
					dir.y = 0
					velocity.x = dir.x * move_speed * LOD_SPEED_FACTOR
					velocity.z = dir.z * move_speed * LOD_SPEED_FACTOR
					# Distant hordes are where clumping starts, so separation has to
					# run on the LOD path too — not only once they arrive.
					_apply_separation()
				else:
					# Targetless (player freed, or a spawn the idle scan has not picked
					# up yet). Without this the zombie keeps its last horizontal
					# velocity and slides off forever, since the damp below is skipped.
					velocity.x = move_toward(velocity.x, 0, 6 * delta)
					velocity.z = move_toward(velocity.z, 0, 6 * delta)
				if is_inside_tree():
					move_and_slide()
				return
			_lod_timer = 0.0
			# Fall through to a full state machine update this tick.

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
	else:
		# An attacker plants its feet. The damp above deliberately skips ATTACK, so
		# without this the zombie keeps its chase velocity and slides into the player
		# for the whole swing.
		velocity.x = 0.0
		velocity.z = 0.0

	# ── VFN OVERRIDE: if a field is set and we're chasing, use vector field ──
	if vfn_field and current_state == AIState.CHASE:
		var vfn_vec = vfn_field.get_vector_smooth_world(global_transform.origin)
		if vfn_vec.length() > 0.01:
			velocity.x = vfn_vec.x * move_speed
			velocity.z = vfn_vec.z * move_speed
			if mesh:
				var rot = atan2(vfn_vec.x, vfn_vec.z)
				mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 8 * delta)

	# Local avoidance runs last so it composes with navigation instead of being
	# overwritten by it. ATTACK is included deliberately — the ring of zombies pressed
	# against the player is exactly the cluster that needs separating — but at reduced
	# strength, so attackers jostle for position instead of sliding off the player.
	if current_state == AIState.CHASE:
		_apply_separation()
	elif current_state == AIState.ATTACK:
		_apply_separation(ATTACK_SEPARATION_FACTOR)

	# Guarded: the frame log showed three 'Condition "!is_inside_tree()" is true' errors with
	# a backtrace ending here. A zombie can be freed (killed, despawned, level change) between
	# the top-of-function guard and this call, and move_and_slide() then errors on a body with
	# no space. Re-checking costs nothing.
	if is_inside_tree():
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

	# Subtypes decide whether to commit to an attack here — a runner deals contact
	# damage and never stops, so it overrides _should_engage() to stay in CHASE.
	if _should_engage(dist):
		current_state = AIState.ATTACK
		return

	var dir = (target.global_transform.origin - global_transform.origin).normalized()
	dir.y = 0

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	if mesh:
		var rot = atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, rot, 8 * delta)


func _apply_separation(strength: float = 1.0) -> void:
	# Local avoidance, layered on top of whatever global navigation produced (VFN
	# vector or direct chase). It must run AFTER navigation — applying it inside
	# _chase() meant the VFN override silently overwrote it, so hordes still piled up.
	# `strength` scales it down for stationary attackers, which should jostle for
	# position rather than slide.
	var tree := get_tree()
	if tree == null:
		return
	var separation_vec = Vector3.ZERO
	for other in tree.get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		# The group is nominally ZombieBase-only, but a future decoy/turret that
		# joins it must not crash every separation pass on a transform access.
		if not (other is Node3D):
			continue
		if other is ZombieBase and other.is_dead:
			continue
		var to_other = global_transform.origin - other.global_transform.origin
		var other_dist = to_other.length()
		if other_dist < 0.01 or other_dist > SEPARATION_SCAN_RADIUS:
			continue
		if other_dist < SEPARATION_RADIUS:
			var overlap = SEPARATION_RADIUS - other_dist
			separation_vec += to_other.normalized() * overlap * SEPARATION_FORCE
	# Clamp to the zombie's own move speed — an unclamped sum over a dense horde
	# can add many times move_speed and launch zombies erratically.
	separation_vec = separation_vec.limit_length(move_speed) * strength
	velocity.x += separation_vec.x
	velocity.z += separation_vec.z


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


func _should_engage(dist: float) -> bool:
	"""Whether a chasing zombie should commit to an attack at this distance.
	Overridden by subtypes whose threat model differs — a runner never stops."""
	return dist < attack_range


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

	# Notify animator for hit-reaction squash envelope (V5 §3: directional roll).
	var _a := _get_animator()
	if _a:
		# Compute horizontal direction of the blow relative to this zombie's facing.
		# _kb points FROM the attacker TO this zombie; _side > 0 = blow came from the right.
		if target:
			var _kb := global_transform.origin - target.global_transform.origin
			var _side := clampf(
				(global_transform.origin.x - target.global_transform.origin.x) / (abs(_kb.x) + 0.001),
				-1.0, 1.0)
			_a.trigger_hit_reaction(_side)
		else:
			_a.trigger_hit_reaction()

	if target:
		var kb = (global_transform.origin - target.global_transform.origin).normalized()
		velocity.x += kb.x * 3
		velocity.z += kb.z * 3

	Audio.play_zombie_hit()

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	current_state = AIState.DEAD
	# Zero collision immediately — corpse is a ghost while the anim plays.
	# reset_for_pool() restores layer 8 / mask 1 on the next checkout.
	collision_layer = 0
	collision_mask = 0

	Audio.play_zombie_die()

	# Resolve per-type death params.
	var dp: Dictionary = DEATH_PARAMS.get(zombie_type, DEATH_PARAMS["default"])
	var fall_t: float = float(dp["fall_t"])
	var fade_t: float = float(dp["fade_t"])
	var pitch_deg: float = float(dp["pitch"])
	var spin_deg: float = float(dp["spin"])
	var bounce_amt: float = float(dp["bounce"])
	var spin_fixed: int = int(dp["spin_dir"])
	var spin_dir: int = spin_fixed if spin_fixed != 0 else (1 if randi() % 2 == 0 else -1)

	var t = create_tween()
	if mesh:
		# t1: fall — pitch over, spin yaw, small upward bounce (ground-contact feel).
		# V5 §2: overshoot the rest pitch by 12% during the fall for a physical flop feel.
		# Bear/boss are heavier — smaller overshoot (+8%) and slower rebound.
		var is_heavy: bool = (zombie_type == "bear" or zombie_type == "boss")
		var overshoot_factor: float = 1.08 if is_heavy else 1.12
		var target_pitch: float = deg_to_rad(pitch_deg)
		var fall_pitch: float   = target_pitch * overshoot_factor  # overshoot target for fall
		var target_yaw: float = mesh.rotation.y + deg_to_rad(spin_deg) * spin_dir
		var bounce_y: float = mesh.position.y + bounce_amt * 0.9
		t.tween_property(mesh, "rotation:x", fall_pitch, fall_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(mesh, "rotation:y", target_yaw, fall_t).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mesh, "position:y", bounce_y, fall_t)
		# t2: impact settle — slight rotation settle + position dip.
		t.tween_property(mesh, "rotation:x", target_pitch * 0.97, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mesh, "position:y", bounce_y - 0.05, 0.12)
		# t3: V5 §2 — spring rebound: rotation.x bounces back to the true rest pitch.
		var rebound_t: float = 0.28 if is_heavy else 0.18
		t.tween_property(mesh, "rotation:x", target_pitch, rebound_t).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		for mi in _mesh_instances():
			# Node3D has no `modulate` — fade 3D meshes via
			# GeometryInstance3D.transparency (0 = opaque, 1 = invisible).
			t.parallel().tween_property(mi, "transparency", 1.0, fade_t)
	else:
		# no Mesh child — nothing visual to fade, just wait out the duration
		t.tween_interval(fall_t + fade_t)

	# The zombie IS still in the tree (signal fires after this await).
	# A tween on a node out-of-tree never finishes, so guard anyway.
	if is_inside_tree():
		await t.finished

	# ── BIG DEATH IMPACT SHAKE (bear / boss only) ──────────────────────────
	if zombie_type == "bear" or zombie_type == "boss":
		var _cs := get_tree().current_scene if get_tree() else null
		if _cs and _cs.has_method("_shake"):
			_cs._shake(0.3 if zombie_type == "boss" else 0.18)

	# Emit AFTER the animation so the spawner's detach/score/loot logic runs
	# once the corpse is already invisible — no corpse-pop.
	emit_signal("died")

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
	# Restore stats to base values so apply_difficulty scales from the original
	# numbers on the next checkout — without this, pool reuse compounds the multiplier.
	max_health = base_max_health
	health = base_max_health
	damage = base_damage
	move_speed = base_move_speed
	difficulty_multiplier = 1.0
	current_state = AIState.IDLE
	is_attacking = false
	attack_timer = 0.0
	target = null
	hit_flash_tween = null
	_lod_timer = 0.0
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	# Parked instances are taken out of the tree with collisions zeroed (see
	# ZombieSpawner3D._create_pool) — restore world interaction on checkout.
	collision_layer = 8
	collision_mask = 1
	if mesh:
		mesh.transform = _mesh_rest_xform
		var _a := _get_animator()
		if _a:
			_a.reset_anim()
		# Stop any in-flight animation on pool reuse (harmless if absent).
		var ap := mesh.get_node_or_null("AnimationPlayer")
		if ap:
			ap.stop()
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
	var _a := _get_animator()
	if _a:
		_a.on_start_chase()


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

# ── DIFFICULTY ──────────────────────────────────────────────────

func apply_difficulty(multiplier: float) -> void:
	"""Scale enemy stats based on difficulty multiplier.

	Called by ZombieSpawner3D at spawn time. The multiplier combines the
	static per-level difficulty (LevelManager.difficulty_map) with the
	dynamic difficulty (DifficultyManager.current_difficulty).

	Scales FROM base stats (captured in _ready) so that object-pool reuse
	does not compound the multiplier on already-scaled values.
	"""
	difficulty_multiplier = multiplier
	max_health = int(base_max_health * multiplier)
	health = max_health
	damage = int(base_damage * multiplier)
	move_speed = base_move_speed * multiplier
