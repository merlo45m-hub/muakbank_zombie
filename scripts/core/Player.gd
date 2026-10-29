extends CharacterBody3D
class_name Player

## Player Character — Third Person Survival (Improved)
## Adapted with best practices from gdquest-demos/godot-4-3d-third-person-controller (MIT)
## Public API preserved for all external callers (Game.gd, FoodItem3D.gd, weapon/pickup systems).

signal health_changed(new_health: int, max_health: int)
signal stamina_changed(new_stamina: int, max_stamina: int)
signal died
signal damaged(amount: int)
signal ate_food(food_type: String, amount: int)
signal picked_up_weapon(weapon_name: String)
signal food_picked_up(food_type: String)

# === STATS ===
@export var max_health: int = 100
@export var max_stamina: int = 100
@export var move_speed: float = 4.5
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 6.0
@export var gravity: float = 18.0
@export var stamina_regen: float = 15.0

# === COMBAT STATS ===
@export var attack_damage: int = 25
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 0.4
@export var weapon_swing_duration: float = 0.25

# === CHARACTER STATS ===
var character_stats: CharacterStats = null

# === STATE ===
var health: int = 100
var stamina: int = 100
var is_dead: bool = false
var is_eating: bool = false
var is_attacking: bool = false
var is_rage_active: bool = false
var is_shield_active: bool = false
# Brief post-hit invulnerability so a swarm of fast zombies (each on its own
# ~0.4s attack cooldown) cannot stack hits and melt the player in seconds.
# Without this, 3-4 rabbits landing hits simultaneously dealt 100->20 in ~3s.
var _hurt_cooldown: float = 0.0
# Was 1.2s. An attached rabbit hit every 1.2s for ~9 dmg -> 110 HP gone in 15s while
# the player navigated (no knockback because they weren't attacking). A longer window
# (2.5s) cuts the incoming DPS roughly in half so a chasing enemy is a bleed you can
# outrun or turn and fight, not an instant death.
const HURT_INVULN_TIME: float = 2.5
# Damage-free window right after spawn so the player can orient before the first
# zombie reaches them.
var _spawn_grace: float = 0.0
const SPAWN_GRACE_TIME: float = 5.0
var current_weapon: String = "bat"
# Inventory: food_type -> {"count": int, "heal": int}.
# The heal value rides along because the food SCENE is the single source of truth for
# it (food_burger.tscn declares health_amount = 35). A second hard-coded table in
# Game.consume_food() disagreed with the scenes on every type, so the same burger
# healed 35 when walked over and 25 when eaten from the bar.
# Food inventory, now backed by a GLoot Inventory (addons/gloot). Each food type
# is one stacked InventoryItem, keyed by the "food_type" item property (no
# protoset is used, so we cannot rely on GLoot's prototype_id lookup). The public
# API below (get_food_count / has_food / get_food_heal / add_food /
# consume_food_type) is unchanged for external callers.
var _inventory: Inventory = null
var attack_timer: float = 0.0
var weapon_tween: Tween = null
var special_timer: float = 0.0

# === NODE REFS (null-safe) ===
@onready var mesh: Node3D = $PlayerVisuals/Body if has_node("PlayerVisuals/Body") else null
@onready var camera_arm: SpringArm3D = $Camera if has_node("Camera") else null
@onready var camera: Camera3D = $Camera/Camera3D if has_node("Camera/Camera3D") else null
@onready var collision: CollisionShape3D = $PlayerCollision if has_node("PlayerCollision") else null

# === CAMERA STATE (improved — basis from gdquest controller) ===
var camrot_h: float = 0.0
# Default 10 deg down-tilt. At vertical look 0 the camera sits at the arm's height
# looking horizontally and a wall-clamped arm (2 m) drops the player below frame.
var camrot_v: float = -0.18
var h_sensitivity: float = 0.015
var v_sensitivity: float = 0.012
var _camera_follow_offset: Vector3 = Vector3.ZERO
var _camera_follow_speed: float = 12.0

# === INPUT STATE (improved — separates raw from processed) ===
var _raw_input_dir: Vector2 = Vector2.ZERO
var _camera_oriented_dir: Vector3 = Vector3.ZERO
var _last_strong_direction: Vector3 = Vector3.FORWARD

@onready var weapon_system = $WeaponSystem if has_node("WeaponSystem") else null
@onready var mobile_controls = $MobileControls if has_node("MobileControls") else null

# === DAMAGE NUMBERS (minos-damage-numbers autoload) ===
@onready var damage_numbers = MinosDamageNumbers3D

# === MOBILE STATE ===
var mobile_move_vector: Vector2 = Vector2.ZERO
var is_mobile_sprinting: bool = false

# Touch drag camera tracking (mobile only — single touch on right half)
var _camera_touch_index: int = -1
var _camera_touch_last: Vector2 = Vector2.ZERO

# Track start position for respawn/reset
var _start_position: Vector3 = Vector3.ZERO

# Skeletal animation (Kenney rigged survivors). Null = procedural animator only.
var _skeletal: AnimationPlayer = null
var _anim_state := ""
var _jump_lock := 0.0
# One-shot state locks. Without these, _update_skeletal_anim() (which runs every
# frame and derives state purely from speed) immediately overwrites a one-shot
# state such as "attack" on the very next frame, so the clip is clobbered before
# it is ever seen. Mirrors the _jump_lock pattern already used for jumping.
var _attack_lock := 0.0
# Fallback-punch state: used only when the rig has no "attack-melee-right" clip.
# _punch_arm is the visible arm mesh; _punch_t is the swing clock in seconds.
var _punch_arm: MeshInstance3D = null
var _punch_t := 0.0

# The visible character root applied by _apply_character_model (scene visuals,
# GLB fallback, or null when the placeholder body is the only visual).
var _applied_visual: Node3D = null


func _ready() -> void:
	# Initialize the GLoot inventory node. Each food type is one stacked item.
	_inventory = Inventory.new()
	_inventory.name = "GootInventory"
	add_child(_inventory)

	if camera_arm:
		# Preserve the authored camera height while detaching the arm from player motion.
		_camera_follow_offset = global_basis * camera_arm.position
		camera_arm.top_level = true
		camera_arm.global_position = global_position + _camera_follow_offset

	var char_id := _selected_character_id()
	var stats_path := "res://assets/materials/stats_%s.tres" % char_id
	if ResourceLoader.exists(stats_path):
		character_stats = load(stats_path) as CharacterStats
	if character_stats:
		_apply_character_stats()

	health = max_health
	stamina = max_stamina
	add_to_group("player")
	_apply_character_model()

	# Setup weapon system
	if weapon_system and weapon_system.has_method("equip_weapon"):
		weapon_system.equip_weapon("bat")

	# Attach procedural animator to the VISIBLE model root (same reparent pattern as
	# ZombieBase). Tree becomes: PlayerVisuals > ProceduralAnimator > <visible root>.
	# It used to wrap the placeholder Body, which _apply_character_model hides — so
	# the visible model never animated and read as a frozen statue.
	var anim_target: Node3D = _applied_visual if _applied_visual != null else mesh
	if anim_target and anim_target.is_inside_tree():
		var _anim := ProceduralAnimator.new()
		_anim.name = "ProceduralAnimator"
		var holder := anim_target.get_parent()  # $PlayerVisuals
		holder.remove_child(anim_target)
		_anim.add_child(anim_target)
		holder.add_child(_anim)
		_anim.attach(self, anim_target)
		# Skeletal clips drive the whole body now; the procedural walk would
		# fight the run cycle. Keep the node (die pose, weapon hooks) but stop
		# its per-frame transform writes.
		if _skeletal != null:
			_anim.set_process(false)

	# Setup mobile controls
	if mobile_controls:
		mobile_controls.move_vector_changed.connect(_on_mobile_move)
		mobile_controls.attack_pressed.connect(_on_mobile_attack)
		if mobile_controls.has_signal("punch_pickup_pressed"):
			mobile_controls.punch_pickup_pressed.connect(_on_mobile_punch_pickup)
		if mobile_controls.has_signal("sprint_pressed"):
			mobile_controls.sprint_pressed.connect(_on_mobile_sprint)
		if mobile_controls.has_signal("jump_pressed"):
			mobile_controls.jump_pressed.connect(_on_mobile_jump)
		if mobile_controls.has_signal("weapon_switch_pressed"):
			mobile_controls.weapon_switch_pressed.connect(_on_mobile_weapon_switch)
		if mobile_controls.has_signal("special_pressed"):
			mobile_controls.special_pressed.connect(_on_mobile_special)

	# Mouse capture on desktop; mobile keeps touch-visible mode
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# When copying this character to a new project, the project may lack required
	# input actions. Register them at runtime if missing (adapted from gdquest).
	if not InputMap.has_action("forward"):
		_register_input_actions()

	# Remember start position for respawn/reset
	_start_position = global_transform.origin


func _apply_character_stats() -> void:
	if not character_stats:
		return
	max_health = character_stats.max_health
	max_stamina = character_stats.max_stamina
	move_speed = character_stats.move_speed
	sprint_speed = character_stats.sprint_speed
	attack_damage = character_stats.attack_damage
	stamina_regen = character_stats.stamina_regen


func _unhandled_input(event: InputEvent) -> void:
	# Desktop mouse look — only when mouse is captured (standard desktop behavior).
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_dead:
			camrot_h -= event.relative.x * h_sensitivity
			camrot_v -= event.relative.y * v_sensitivity
			camrot_v = clamp(camrot_v, deg_to_rad(-75), deg_to_rad(60))

	# Mobile touch-drag camera look — track a single touch starting on the right half.
	# Left half is the joystick area; UI buttons on the right are Control nodes that
	# consume their own events via _gui_input, so unhandled touches reaching here are
	# safe to use for camera control.
	if OS.has_feature("android") or OS.has_feature("ios"):
		if event is InputEventScreenTouch:
			if event.pressed and _camera_touch_index == -1:
				# Only track touches starting on the right half of the screen.
				var screen_size: Vector2i = get_viewport().size
				if event.position.x > screen_size.x / 2:
					_camera_touch_index = event.index
					_camera_touch_last = event.position
			elif not event.pressed and event.index == _camera_touch_index:
				# Touch ended — stop tracking.
				_camera_touch_index = -1

		elif event is InputEventScreenDrag:
			if event.index == _camera_touch_index and not is_dead:
				var delta: Vector2 = event.position - _camera_touch_last
				camrot_h -= delta.x * h_sensitivity
				camrot_v -= delta.y * v_sensitivity
				camrot_v = clamp(camrot_v, deg_to_rad(-75), deg_to_rad(60))
				_camera_touch_last = event.position


func _process(delta: float) -> void:
	if is_dead:
		return

	# Apply camera rotation to the SpringArm each frame.
	# Doing this in _process (not _physics_process) keeps the camera smooth
	# independent of physics tick rate — adapted from gdquest approach.
	_smooth_camera_follow(delta)
	_apply_camera_rotation()

	# Tick the weapon system so fire_timer decrements and cooldowns expire.
	if weapon_system and weapon_system.has_method("tick"):
		weapon_system.tick(delta)

	# Regenerate stamina — uses the exported stamina_regen value (was hardcoded 15).
	if stamina < max_stamina:
		stamina = min(max_stamina, stamina + delta * stamina_regen)
		emit_signal("stamina_changed", stamina, max_stamina)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Tick post-hit invulnerability so the player can be hit again after the window.
	if _hurt_cooldown > 0.0:
		_hurt_cooldown -= delta

	# Tick the spawn grace window down.
	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Gather and process input
	_handle_movement_input(delta)
	_handle_jump(delta)
	_update_skeletal_anim(delta)
	_handle_attack(delta)

	# Apply movement
	move_and_slide()

	# Stuck detection — DISABLED. The old code nudged the player 0.05 units every
	# physics frame whenever horizontal velocity was nonzero — with no check that he
	# was actually stuck. At 60 ticks/s that injected up to 3 units/second of phantom
	# movement (overspeed, sliding, jitter). move_and_slide() already resolves wall
	# collisions correctly; this manual shove fought it. Only reintroduce a nudge if
	# a genuine "had velocity but moved < epsilon for N frames" stuck condition is
	# ever observed.

	# ── SAFETY ────────────────────────────────────────────────────────────
	# Nothing may launch the player: clamp vertical speed to sane values and
	# recover to the last safe position if he somehow leaves the playable
	# volume (a character body overlapping the player used to do exactly that).
	velocity.y = clampf(velocity.y, -60.0, 15.0)
	if global_position.y > 30.0 or global_position.y < -25.0:
		global_position = _start_position
		velocity = Vector3.ZERO


# ──────────────────────────────────────────────
#  INPUT — improved to mirror gdquest controller patterns
# ──────────────────────────────────────────────

func mark_safe_spawn(pos: Vector3) -> void:
	# Called by Game once it has probed a legal spawn point. The safety net below must
	# recover to THAT spot: the scene file's transform is only correct for one of the
	# eight levels, and recovering into a wall is the bug this project spent a night
	# chasing.
	_start_position = pos
	# Spawn grace: the first rabbit can reach the player ~6s after spawn and a new
	# player is still learning the joystick then. A short damage-free window at the
	# start turns an instant melt into a fair fight.
	_spawn_grace = SPAWN_GRACE_TIME


func _handle_movement_input(delta: float) -> void:
	# 1. Collect raw 2D input (keyboard or mobile joystick)
	_raw_input_dir = _get_raw_input_dir()

	# 2. Normalize diagonal input so diagonals aren't stronger than cardinals.
	#    Adapted from gdquest player._get_camera_oriented_input().
	var raw_len: float = _raw_input_dir.length()
	if raw_len > 0.01:
		# Apply the gdquest normalization: each axis is scaled so that
		# the resulting vector length never exceeds 1 regardless of angle.
		var norm_x: float = _raw_input_dir.x * sqrt(1.0 - _raw_input_dir.y * _raw_input_dir.y / 2.0)
		var norm_y: float = _raw_input_dir.y * sqrt(1.0 - _raw_input_dir.x * _raw_input_dir.x / 2.0)
		_raw_input_dir = Vector2(norm_x, norm_y).normalized()
	else:
		_raw_input_dir = Vector2.ZERO

	# 3. Build camera-relative 3D direction
	#    Use camera_arm's basis (or fallback to identity) for mobile compatibility.
	var cam_basis: Basis
	if camera_arm:
		cam_basis = camera_arm.global_transform.basis
	else:
		cam_basis = Basis()

	_camera_oriented_dir = (cam_basis * Vector3(_raw_input_dir.x, 0, _raw_input_dir.y))
	_camera_oriented_dir.y = 0.0

	# 4. Update _last_strong_direction so the character keeps facing a good direction
	#    even when momentarily stationary (from gdquest controller).
	if _camera_oriented_dir.length() > 0.2:
		_last_strong_direction = _camera_oriented_dir.normalized()

	# 5. Sprint
	var wants_sprint: bool = (Input.is_action_pressed("sprint") or is_mobile_sprinting) and stamina > 10 and _raw_input_dir != Vector2.ZERO
	var speed: float = sprint_speed if wants_sprint else move_speed

	if wants_sprint:
		stamina = max(0, stamina - delta * 30.0)
		emit_signal("stamina_changed", stamina, max_stamina)

	# 6. Apply velocity with acceleration feel (lerp toward target, from gdquest).
	#    When no input, decelerate toward zero.
	var target_vel: Vector3
	if _camera_oriented_dir.length() > 0.01:
		target_vel = _camera_oriented_dir * speed
		# Face movement direction (smooth rotation, from gdquest _orient_character_to_direction).
		_rotate_toward_direction(_camera_oriented_dir.normalized(), delta)
	else:
		target_vel = Vector3.ZERO
		# Keep facing the last strong direction when idle.
		if _raw_input_dir == Vector2.ZERO:
			_rotate_toward_direction(_last_strong_direction, delta)

	var accel: float = 26.0
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	# Zero out tiny drift
	if velocity.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0


func _get_raw_input_dir() -> Vector2:
	# Device branch is the phone path; the extra vector check keeps desktop /
	# headless probe runs honest (a live joystick vector is always real input).
	if OS.has_feature("android") or OS.has_feature("ios") or mobile_move_vector != Vector2.ZERO:
		return mobile_move_vector
	else:
		return Vector2(
			Input.get_action_strength("right") - Input.get_action_strength("left"),
			Input.get_action_strength("forward") - Input.get_action_strength("backward")
		)


func _rotate_toward_direction(direction: Vector3, delta: float) -> void:
	var vis: Node3D = _visual_root()
	if vis == null:
		return
	if direction.length() < 0.01:
		return
	var target_rot: float = atan2(direction.x, direction.z) + PI
	var rot_speed: float = 18.0
	vis.rotation.y = lerp_angle(vis.rotation.y, target_rot, rot_speed * delta)


func _visual_root() -> Node3D:
	# The node the animation / facing / flash code should drive: the applied
	# character visuals when present, else the placeholder body.
	if _applied_visual != null and is_instance_valid(_applied_visual):
		return _applied_visual
	return mesh


func _play_jump_anim() -> void:
	if _skeletal != null and is_instance_valid(_skeletal) and _skeletal.has_animation("jump"):
		_jump_lock = 0.42
		_anim_state = "jump"
		_skeletal.play("jump", 0.08)


## Drive idle/run/jump from actual speed every physics tick.
func _update_skeletal_anim(delta: float) -> void:
	# A one-shot state owns the rig until its lock expires. Without this guard the
	# speed-derived state below overwrites "attack" on the very next frame and the
	# melee clip is never seen (this was the real reason the punch read as a flop).
	#
	# The lock is ticked HERE (before the _skeletal null check) on purpose: the
	# fallback procedural punch runs on rigs where _skeletal IS null, so bailing
	# out early would leave its swing frozen mid-arc.
	if _attack_lock > 0.0:
		_attack_lock -= delta
		# Tick the arm-only fallback swing when the rig clip path was not taken.
		if _punch_arm != null:
			_update_procedural_punch(delta)
		return
	if _skeletal == null or not is_instance_valid(_skeletal):
		return
	if _jump_lock > 0.0:
		_jump_lock -= delta
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	# The blocky rig ships 'walk' and 'sprint' clips but NOT a literal 'run' clip.
	# BlockyAnim.setup registers a 'run'->'sprint' alias, but if that setup path
	# was skipped the play("run") call silently no-ops and the character slides
	# with no cycle. Resolve the moving clip to a clip that actually exists.
	var want := "idle" if spd < 0.35 else _moving_clip()
	if _anim_state != want:
		_anim_state = want
		if _skeletal.has_animation(want):
			_skeletal.play(want, 0.18)
	if want != "idle":
		_skeletal.speed_scale = clampf(spd / 2.3, 0.75, 1.7)
	else:
		_skeletal.speed_scale = 1.0


## Return the best available locomotion clip: prefer 'walk', fall back to
## 'sprint'/'run' if 'walk' is somehow absent. Never returns a clip the rig lacks.
func _moving_clip() -> String:
	if _skeletal.has_animation("walk"):
		return "walk"
	if _skeletal.has_animation("run"):
		return "run"
	if _skeletal.has_animation("sprint"):
		return "sprint"
	return "idle"


func _handle_jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		_play_jump_anim()
		stamina = max(0, stamina - 10)
		emit_signal("stamina_changed", stamina, max_stamina)


func _handle_attack(delta: float) -> void:
	# ── INTERACTION CHECK ──────────────────────────────────────────────────────
	# If the player presses attack near an interactive prop, route THAT press to
	# the prop instead of combat (opens doors, punches walls, rummages crates).
	# Gated on the attack press: calling _try_prop_interaction() every physics
	# frame made props interact continuously just by standing near them.
	var attack_just_pressed: bool = Input.is_action_just_pressed("attack")
	if attack_just_pressed and _try_prop_interaction():
		return

	if attack_timer > 0:
		attack_timer -= delta

	if attack_just_pressed and not is_attacking and attack_timer <= 0 and not is_dead:
		_perform_attack()
	
	# Special ability (keyboard "Q" on desktop; the mobile button signals directly)
	if Input.is_action_just_pressed("special") and not is_dead:
		use_special_ability()
	
	# Tick the special cooldown
	if special_timer > 0:
		special_timer -= delta


# ──────────────────────────────────────────────
#  CAMERA — improved rotation handling
# ──────────────────────────────────────────────

func _apply_camera_rotation() -> void:
	if not camera_arm:
		return
	# Apply yaw and pitch to the SpringArm so the camera orbits the player.
	# Adapted from gdquest camera_controller._process rotation handling.
	camera_arm.rotation.y = camrot_h
	if camera:
		camera.rotation.x = camrot_v


func _smooth_camera_follow(delta: float) -> void:
	if not camera_arm:
		return
	# Exponential easing keeps follow lag consistent across different frame rates.
	var target_position: Vector3 = global_position + _camera_follow_offset
	var follow_weight: float = 1.0 - exp(-_camera_follow_speed * delta)
	camera_arm.global_position = camera_arm.global_position.lerp(target_position, follow_weight)


# ──────────────────────────────────────────────
#  MOBILE CALLBACKS
# ──────────────────────────────────────────────

func _on_mobile_move(vector: Vector2) -> void:
	mobile_move_vector = vector


func _on_mobile_attack() -> void:
	if is_dead:
		return
	# Interactive props first, exactly like the keyboard path in _handle_attack().
	# The mobile button used to call _perform_attack() directly, which skipped this
	# gate entirely — so on touch NO mini-game podium, terminal, hopper, platter or
	# supply crate could ever be interacted with, making every Level 1 objective
	# unreachable by touch. Props win the press when one is in range; otherwise
	# this falls through to a normal melee swing.
	if _try_prop_interaction():
		return
	_perform_attack()

func _on_mobile_punch_pickup(grab: bool) -> void:
	"""PUNCH/PICKUP button handler.
	grab=false: short press -> punch attack.
	grab=true: long press -> attempt to pick up nearby food/weapon."""
	if not is_dead:
		if grab:
			# Long press: try to pick up nearby items
			_pickup_nearby()
		else:
			# Short press: punch attack
			_perform_attack()

func _pickup_nearby() -> void:
	"""Detect and pick up nearby food or weapon pickups within range."""
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var pick_range := 3.0
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = pick_range
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.5, 0))
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var results := space.intersect_shape(query, 10)
	if results.is_empty():
		return
	# Check each result for food or weapon pickup areas
	for result in results:
		var body: Object = result["collider"] if result.has("collider") else null
		if body == null:
			continue
		# Food pickup
		if body.has_method("collect") and not (body.get("is_collected") == true):
			var food_type: Variant = body.get("food_type") if body.has("food_type") else ""
			var heal := int(body.get("health_amount")) if body.has("health_amount") else 0
			if food_type != "":
				body.collect(self)
				add_food(food_type, heal)
				Audio.play_pickup()
				Input.vibrate_handheld(15)
				return
		# Weapon pickup
		if body.has_method("take") and not (body.get("taken") == true):
			var weapon_id: Variant = body.get("weapon_id") if body.has("weapon_id") else ""
			if weapon_id != "":
				body.take()
				equip_weapon(weapon_id)
				Audio.play_pickup()
				Input.vibrate_handheld(25)
				return

func _on_mobile_sprint(active: bool) -> void:
	is_mobile_sprinting = active

func _on_mobile_jump() -> void:
	if not is_dead and is_on_floor():
		velocity.y = jump_velocity
		_play_jump_anim()
		stamina = max(0, stamina - 10)
		emit_signal("stamina_changed", stamina, max_stamina)

func _on_mobile_weapon_switch() -> void:
	if weapon_system and weapon_system.has_method("switch_to_next_weapon"):
		weapon_system.switch_to_next_weapon()

func _on_mobile_special() -> void:
	# Mobile SPECIAL button routes into the EXACT same handler the keyboard
	# 'special' action (G key) drives in _handle_attack(): use_special_ability().
	# The is_dead gate mirrors the keyboard check; the ability itself (heal/rage/
	# stealth/shield) lives only in use_special_ability(), no duplicated logic.
	if is_dead:
		return
	use_special_ability()


# ──────────────────────────────────────────────
#  ATTACK
# ──────────────────────────────────────────────

func _perform_attack() -> void:
	is_attacking = true
	_trigger_attack_feedback()
	var weapon_data := _fire_weapon()
	if weapon_data.is_empty():
		await _wait(weapon_swing_duration)
		is_attacking = false
		return
	_apply_damage_to_enemies(weapon_data)
	await _wait(weapon_swing_duration)
	is_attacking = false

func _trigger_attack_feedback() -> void:
	var _pv := get_node_or_null("PlayerVisuals")
	if _pv:
		# ── BUG A FIX ("punch = flop") ────────────────────────────────────────
		# This used to call ProceduralAnimator.trigger_attack() unconditionally,
		# which runs the ZOMBIE 3-phase pounce curve: a forward pos.z lunge plus a
		# rot.x pitch-down. On the human player that reads as the whole body
		# flopping over instead of throwing a punch.
		# The rig's real "attack-melee-right" clip (below) already drives the arm
		# swing, and this animator's _process is disabled for the player anyway
		# (Player.gd _ready), so there is nothing to animate here — skip it.
		# Zombies are untouched: they never call this function and their own
		# animator pipeline is unchanged.
		pass
	if Audio:
		Audio.play_click()
	# ── PUNCH (bug A — "punch = flop") ────────────────────────────────────────
	# The Kenney Blocky rig ships a real right-hand melee clip; BlockyAnim already
	# maps the "attack" state onto it. Play it so the strike reads as an arm swing
	# rather than the whole body pitching over.
	#
	# ROOT CAUSE of "the clip plays but the arm never moves" (proven at runtime on
	# the VPS by instantiating the real authored scene, character_nurse.tscn):
	# `_skeletal` ends up NULL, so the whole block below never ran and the arms
	# simply hung at rest. In _apply_character_model()'s preferred branch the rig
	# is taken from the authored character_*.tscn scene, and BlockyAnim's
	# apply_skin_variant()/setup() chain re-instantiates that rig (freeing the old
	# one) while _ready() then RE-PARENTS the visual under a new
	# ProceduralAnimator. The handle captured through all that reordering does not
	# survive, and the old `is_instance_valid()` guard swallowed the failure
	# silently instead of recovering.
	# FIX: resolve the AnimationPlayer fresh from the CURRENT tree at attack time,
	# so the punch no longer depends on any of that ordering.
	_skeletal = _resolve_skeletal_player()
	if _skeletal != null and _skeletal.has_animation("attack-melee-right"):
		# Hold the state so _update_skeletal_anim() cannot overwrite it next frame.
		_anim_state = "attack"
		# The clip is 0.417s long (14 keys, arm-right sweeping 0° → -162° → 0°).
		# The old lock was weapon_swing_duration + 0.05 = 0.30s, which CUT THE CLIP
		# OFF before its recovery half — the arm snapped back to rest mid-swing,
		# which reads as a twitch rather than a punch. Hold for the full clip.
		_attack_lock = _skeletal.get_animation("attack-melee-right").length + 0.05
		_skeletal.play("attack-melee-right", 0.04)
	else:
		# No usable rig clip (placeholder capsule, or rig without the melee clip).
		# Fall back to a tight arm-only swing on the visible body so the punch
		# still reads as a strike — never the old whole-body pitch/flop.
		_attack_lock = 0.30
		_procedural_punch()
	# The old whole-body swing tween is gone on purpose. It targeted
	# _visual_root() — the entire applied character model — pitching the whole
	# body 45 degrees forward and back, which is exactly the "flop" the player
	# reported. WeaponSystem is logic-only (no weapon mesh / attach node exists to
	# swing), and the rig's real "attack-melee-right" clip already animates the
	# arm, so no transform tween is needed at all.


## Re-resolve the rig's AnimationPlayer from the CURRENT tree.
##
## WHY THIS EXISTS (the "punch shows no arm motion" bug, proven at runtime): the
## `_skeletal` handle resolved once during _apply_character_model() does not
## survive the rig swaps and the ProceduralAnimator re-parent that happen in
## _ready(), so by the time the player punches it is null and the melee clip is
## never played — the arms just hang. Resolving fresh from the live visual
## subtree at attack time makes the punch independent of all that ordering.
## Returns null when no rig is present (placeholder body).
func _resolve_skeletal_player() -> AnimationPlayer:
	var root := _visual_root()
	if root == null or not is_instance_valid(root):
		return null
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		# The Blocky rig ships the AnimationPlayer as a SIBLING of the glb root,
		# so also look beside the visual root (see BlockyAnim.find_animation_player).
		var parent := root.get_parent()
		if parent != null:
			ap = parent.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return ap


## Fallback punch for rigs with no melee clip: swing the visible arm node only.
## Drives rotation.x on "arm-right" (the same channel the real clip uses), so the
## motion is identical in character to the clip — never a whole-body pitch.
func _procedural_punch() -> void:
	var arm := _find_visible_arm()
	if arm == null:
		return
	_punch_arm = arm
	_punch_t = 0.0


## Locate the right-arm mesh under the currently applied visual.
func _find_visible_arm() -> MeshInstance3D:
	var root := _visual_root()
	if root == null or not is_instance_valid(root):
		return null
	for mi in root.find_children("arm-right", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			return mi as MeshInstance3D
	return null


## Tick the fallback punch swing. Called from _physics_process while
## _attack_lock > 0 and the rig clip path was not taken.
func _update_procedural_punch(delta: float) -> void:
	if _punch_arm == null or not is_instance_valid(_punch_arm):
		return
	_punch_t += delta
	var dur := 0.30
	var u: float = clampf(_punch_t / dur, 0.0, 1.0)
	# Wind-up (0→25%), strike (25→55%), recover (55→100%) — matches the shape of
	# the rig's real clip: 0° → -162° → 0°.
	var angle: float
	if u < 0.25:
		angle = lerpf(0.0, deg_to_rad(-30.0), u / 0.25)
	elif u < 0.55:
		angle = lerpf(deg_to_rad(-30.0), deg_to_rad(-162.0), (u - 0.25) / 0.30)
	else:
		angle = lerpf(deg_to_rad(-162.0), 0.0, (u - 0.55) / 0.45)
	_punch_arm.rotation.x = angle
	if u >= 1.0:
		_punch_arm.rotation.x = 0.0
		_punch_arm = null


func _fire_weapon() -> Dictionary:
	if not weapon_system or not weapon_system.has_method("fire"):
		return {}
	var weapon_data: Dictionary = weapon_system.fire()
	if weapon_data.get("type", "") == "none":
		return {}
	if weapon_data.get("type", "") == "heal":
		heal(int(weapon_data.get("heal", 0)))
		return {}
	return weapon_data

func _apply_damage_to_enemies(weapon_data: Dictionary) -> void:
	var weapon_damage: int = int(weapon_data.get("damage", attack_damage))
	var weapon_range: float = float(weapon_data.get("range", attack_range))
	var weapon_fire_rate: float = float(weapon_data.get("fire_rate", attack_cooldown))
	var speed_mult: float = character_stats.attack_speed if character_stats else 1.0
	attack_timer = weapon_fire_rate * speed_mult
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy.is_in_group("enemies"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead:
			continue
		var dist: float = global_transform.origin.distance_to(enemy.global_transform.origin)
		var hit_range: float = weapon_range * (character_stats.attack_range / 2.0 if character_stats else 1.0)
		if dist < hit_range:
			if enemy.has_method("take_damage"):
				var damage: int = weapon_damage
				if character_stats:
					damage = int(damage * character_stats.weapon_damage_multiplier)
				if is_rage_active:
					damage *= 2
				var is_crit: bool = false
				if character_stats and randf() < character_stats.critical_chance:
					damage = int(damage * character_stats.critical_multiplier)
					is_crit = true
				# zombie_type carries the spawner's short key ("bear", "runner") that
				# HitFeedback matches on; get_class() returns the native class instead,
				# ignoring class_name, so the bear branch was unreachable.
				if has_node("HitFeedback") and $HitFeedback.has_method("emit_hit"):
					$HitFeedback.emit_hit(enemy.global_transform.origin, str(enemy.get("zombie_type")))
				enemy.take_damage(damage)
				# Knock the enemy back so it can't plant on the player and deal
				# free damage every 1.25s until death — gives the player a window
				# to reposition or finish it.
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback(global_transform.origin, 7.0)
				# Impact feel: a light camera kick + haptic tick per landed hit.
				Input.vibrate_handheld(18)
				var game_scene := get_tree().current_scene
				if game_scene and game_scene.has_method("_shake"):
					game_scene._shake(0.10 if not is_crit else 0.18)
				if damage_numbers:
					var dmg_type: int = MinosDamageNumbers3D.DamageType.CRITICAL_HIT if is_crit else MinosDamageNumbers3D.DamageType.NORMAL
					damage_numbers.display_number(damage, enemy.global_transform.origin, dmg_type)

	# Shove triage animals (Triage Roundup)
	for animal in get_tree().get_nodes_in_group("triage_animal"):
		if not is_instance_valid(animal) or bool(animal.get("delivered")):
			continue
		var dist: float = global_transform.origin.distance_to(animal.global_transform.origin)
		var hit_range: float = weapon_range * 1.5
		if dist < hit_range:
			var shove_dir: Vector3 = (animal.global_transform.origin - global_transform.origin).normalized()
			if shove_dir.length_squared() < 0.001:
				shove_dir = -global_transform.basis.z
			if animal.has_method("apply_shove"):
				animal.apply_shove(shove_dir * 12.0)
			Input.vibrate_handheld(12)

	# Push quarantine braces (Quarantine Breach)
	for brace in get_tree().get_nodes_in_group("quarantine_brace"):
		if not is_instance_valid(brace) or (brace is RigidBody3D and brace.freeze):
			continue
		var dist: float = global_transform.origin.distance_to(brace.global_transform.origin)
		var hit_range: float = weapon_range * 1.5
		if dist < hit_range:
			var push_dir: Vector3 = (brace.global_transform.origin - global_transform.origin).normalized()
			if push_dir.length_squared() < 0.001:
				push_dir = -global_transform.basis.z
			if brace is RigidBody3D:
				brace.apply_central_impulse(Vector3(push_dir.x, 0.0, push_dir.z) * 15.0)
			Input.vibrate_handheld(12)


# ──────────────────────────────────────────────
#  SPECIAL ABILITIES (preserved exactly)
# ──────────────────────────────────────────────

func use_special_ability() -> void:
	if special_timer > 0 or not character_stats:
		return

	var ability: String = character_stats.special_ability

	match ability:
		"heal":
			health = min(max_health, health + 50)
			special_timer = character_stats.special_cooldown
			print("[SPECIAL] Healed 50 HP!")
		"rage":
			is_rage_active = true
			special_timer = character_stats.special_cooldown
			await _wait(character_stats.special_duration)
			is_rage_active = false
			print("[SPECIAL] Rage ended.")
		"iron_skin":
			is_shield_active = true
			special_timer = character_stats.special_cooldown
			await _wait(character_stats.special_duration)
			is_shield_active = false
			print("[SPECIAL] Iron Skin ended.")
		"rush":
			move_speed *= 2.0
			special_timer = character_stats.special_cooldown
			await _wait(character_stats.special_duration)
			move_speed /= 2.0
			print("[SPECIAL] Rush ended.")
		"heal_aura":
			special_timer = character_stats.special_cooldown
			for i in range(5):
				health = min(max_health, health + 10)
				await _wait(1.0)
			print("[SPECIAL] Heal Aura ended.")


# ──────────────────────────────────────────────
#  PUBLIC API — preserved exactly (take_damage, heal, eat, equip_weapon, signals)
# ──────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if is_dead:
		return
	# Spawn grace: no damage during the first moments after spawning.
	if _spawn_grace > 0.0:
		return
	# Post-hit invulnerability: ignore hits during the brief window so a swarm
	# cannot stack damage. This is the single biggest survival-balance lever.
	if _hurt_cooldown > 0.0:
		return
	_hurt_cooldown = HURT_INVULN_TIME

	# Apply damage reduction from character stats
	if character_stats:
		amount = int(amount * (1.0 - character_stats.damage_reduction))

	# Iron Skin: 50% damage reduction
	if is_shield_active:
		amount = int(amount * 0.5)

	health -= amount
	health = max(0, health)
	emit_signal("health_changed", health, max_health)
	# Game reacts to this (shake, haptic, difficulty); damage itself is applied here
	# so there is exactly one funnel.
	emit_signal("damaged", amount)

	_flash_red()

	print("[Player] Took ", amount, " damage — HP: ", health)

	Audio.play_hurt()

	if health <= 0:
		_die()


func heal(amount: int) -> void:
	health += amount
	health = min(max_health, health)
	emit_signal("health_changed", health, max_health)
	print("[Player] Healed ", amount, " HP — HP: ", health)


func _die() -> void:
	is_dead = true
	print("[Player] DIED!")
	emit_signal("died")

	# Fall + fade visual on the VISIBLE model (was the hidden placeholder body,
	# so deaths were invisible on the actual character). Does not block gameplay.
	var die_vis: Node3D = _visual_root()
	if die_vis:
		var dt = create_tween()
		dt.tween_property(die_vis, "rotation:x", deg_to_rad(100.0), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		dt.parallel().tween_property(die_vis, "position:y", die_vis.position.y - 0.15, 0.5)
		# Transparency requires MeshInstance3D children — iterate them.
		for _mi in die_vis.find_children("*", "MeshInstance3D", true, false):
			var _mi3 := _mi as MeshInstance3D
			if _mi3:
				dt.parallel().tween_property(_mi3, "transparency", 1.0, 0.8).set_delay(0.3)

	# Release mouse on desktop so the player can interact with UI
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func eat(food_type: String, amount: int) -> void:
	if is_eating or is_dead:
		return

	is_eating = true
	heal(amount)
	emit_signal("ate_food", food_type, amount)

	await _wait(0.5)
	is_eating = false


# ── INVENTORY (food, GLoot-backed) ─────────────────────────────
# Storage lives in a GLoot Inventory node (_inventory). Each food type is one
# stacked InventoryItem keyed by the "food_type" item property (no protoset is
# used, so GLoot's prototype_id lookup cannot match; we match on the property).
# The heal value rides on the "heal" item property. Public API unchanged.

const FOOD_MAX_STACK: int = 99

func _food_item(food_type: String) -> InventoryItem:
	for it in _inventory.get_items():
		if it.has_property("food_type") and it.get_property("food_type") == food_type:
			return it
	return null

func get_food_count(food_type: String) -> int:
	var it := _food_item(food_type)
	return it.get_stack_size() if it != null else 0

func has_food(food_type: String) -> bool:
	return get_food_count(food_type) > 0

func get_food_heal(food_type: String) -> int:
	# The heal the scene declared for this type, remembered at pickup time.
	var it := _food_item(food_type)
	return int(it.get_property("heal", 0)) if it != null else 0

func add_food(food_type: String, heal: int) -> void:
	var it := _food_item(food_type)
	if it == null:
		it = _inventory.create_item(food_type)
		it.set_property("food_type", food_type)
		it.set_max_stack_size(FOOD_MAX_STACK)
		it.set_property("heal", heal)
		_inventory.add_item(it)
	else:
		it.set_property("heal", heal)
		it.set_stack_size(it.get_stack_size() + 1)
	emit_signal("food_picked_up", food_type)

func consume_food_type(food_type: String) -> bool:
	var it := _food_item(food_type)
	if it == null or it.get_stack_size() <= 0:
		return false
	var remaining: int = it.get_stack_size() - 1
	if remaining > 0:
		it.set_stack_size(remaining)
	else:
		_inventory.remove_item(it)
	emit_signal("food_picked_up", food_type)
	return true


func equip_weapon(weapon_name: String) -> void:
	current_weapon = weapon_name
	# Forward to the WeaponSystem so the actual weapon stats change
	if weapon_system and weapon_system.has_method("equip_weapon"):
		weapon_system.equip_weapon(weapon_name)
		if weapon_system.has_method("add_weapon_to_inventory"):
			weapon_system.add_weapon_to_inventory(weapon_name)
	emit_signal("picked_up_weapon", weapon_name)
	Audio.haptic_light()
	print("[Player] Equipped: ", weapon_name)


# ──────────────────────────────────────────────
#  VISUAL FEEDBACK
# ──────────────────────────────────────────────

func _flash_red() -> void:
	var vis: Node3D = _visual_root()
	if vis == null:
		return
	# Override every mesh with a shared emissive red material, then restore the
	# previous overrides. The old version only flashed a mesh that already had a
	# material_override, which the character visuals never have.
	var meshes: Array[MeshInstance3D] = []
	for m in vis.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m as MeshInstance3D)
	if meshes.is_empty():
		return
	var prev: Array = []
	for m in meshes:
		prev.append(m.material_override)
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color(1.0, 0.25, 0.25)
	flash.emission_enabled = true
	flash.emission = Color(1.0, 0.2, 0.2)
	flash.emission_energy_multiplier = 0.8
	for m in meshes:
		m.material_override = flash
	await _wait(0.15)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	for i in meshes.size():
		var m := meshes[i]
		if is_instance_valid(m):
			m.material_override = prev[i]


# ──────────────────────────────────────────────
#  AREA CALLBACKS (preserved — used by food/pickup/enemy-hitbox areas)
# ──────────────────────────────────────────────

func _on_FoodArea_area_entered(area: Area3D) -> void:
	if not area.is_in_group("food"):
		return
	# `area` IS the FoodItem3D — the script sits on the Area3D ROOT of food_*.tscn
	# (verified: food_burger.tscn:57). The old code took area.get_parent(), which is
	# the FoodSpawner (or the scene root), so has_method("collect") was always false
	# and pickups never fired: no heal, no score, no inventory, no food_eaten.
	if not area.has_method("collect"):
		return
	var food_type: String = area.get("food_type") if area.get("food_type") != null else ""
	var heal: int = int(area.get("health_amount")) if area.get("health_amount") != null else 0
	area.collect(self)
	if food_type.is_empty():
		return
	# Record the scene's own heal value with the item so consuming it later uses the
	# same number it healed for on pickup.
	add_food(food_type, heal)


# PickupArea (mask=256) matched nothing in the scene — dead code removed.
# WeaponPickup._on_body_entered handles weapon collection via its own body_entered.


func _on_EnemyHitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("attack"):
			body.attack(self)


# ──────────────────────────────────────────────
#  INPUT ACTION REGISTRATION (from gdquest controller — adapted)
# ──────────────────────────────────────────────

func _register_input_actions() -> void:
	const INPUT_ACTIONS: Dictionary = {
		"left": KEY_A,
		"right": KEY_D,
		"forward": KEY_W,
		"backward": KEY_S,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"attack": MOUSE_BUTTON_LEFT,
		"special": KEY_G,
		"aim": MOUSE_BUTTON_RIGHT,
		"swap_weapons": KEY_TAB,
		"pause": KEY_ESCAPE,
		"camera_left": KEY_Q,
		"camera_right": KEY_E,
		"camera_up": KEY_R,
		"camera_down": KEY_F,
	}
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var input_key: InputEventKey = InputEventKey.new()
		input_key.keycode = INPUT_ACTIONS[action]
		InputMap.action_add_event(action, input_key)

func _try_prop_interaction() -> bool:
	## Check if the player is near an interactive prop and route the attack press to it.
	## Returns true if the interaction was consumed (no combat this press).
	## The door's long-press hold is handled by InteractiveDoor itself — it tracks
	## hold duration internally via its own timer.
	if not is_instance_valid(self) or not is_inside_tree():
		return false

	var player_pos := global_transform.origin
	var nearest_prop: Node3D = null
	var nearest_dist: float = 3.5  # interact_range

	for prop in get_tree().get_nodes_in_group("interactive_prop"):
		if not is_instance_valid(prop) or not prop.is_inside_tree():
			continue
		# Check player is in the prop's interaction zone
		var zone: Area3D = null
		for child in prop.get_children():
			if child is Area3D and str(child.name).contains("InteractionZone"):
				zone = child
				break
		var check_pos: Vector3 = zone.global_transform.origin if zone != null else prop.global_transform.origin
		var dist := player_pos.distance_to(check_pos)
		var player_in_zone := false
		if zone:
			var overlapping: Array = zone.get_overlapping_bodies()
			for body in overlapping:
				if body.is_in_group("player"):
					player_in_zone = true
					break
			if not player_in_zone and dist <= 3.5:
				player_in_zone = true
			if not player_in_zone:
				continue
		elif dist > nearest_dist:
			continue

		# Found a candidate
		if nearest_prop == null or dist < nearest_dist:
			nearest_prop = prop
			nearest_dist = dist

	if nearest_prop == null:
		return false

	# Route to prop's interact method
	if nearest_prop.has_method("interact"):
		nearest_prop.interact()
		# Feedback
		var hf := get_node_or_null("HitFeedback")
		if hf and hf.has_method("emit_pickup"):
			hf.emit_pickup(nearest_prop.global_transform.origin)
		Input.vibrate_handheld(12)
		return true

	if nearest_prop.has_method("process_capture"):
		nearest_prop.process_capture(0.0)
		return true

	if nearest_prop.has_method("seal_tick"):
		nearest_prop.seal_tick(0.0)
		return true

	# Special case: wall punch
	if nearest_prop.has_method("punch"):
		nearest_prop.punch()
		return true

	return false

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

# ──────────────────────────────────────────────
#  CHARACTER MODEL
# ──────────────────────────────────────────────

## The character select writes SaveManager.selected_character (autoload "Save") and
## the five character_*.glb models ship in assets/models/ — but gameplay always drew
## a placeholder capsule. Attach the chosen model, normalised to human height.
const CHARACTER_MODEL_DIR := "res://assets/models/character_%s.glb"
const CHARACTER_SCENE_DIR := "res://scenes/characters/character_%s.tscn"
const CHARACTER_HEIGHT := 1.8
const MODEL_YAW_OFFSET := 0.0   # flip to PI if the model faces backwards

func _apply_character_model() -> void:
	var visuals := get_node_or_null("PlayerVisuals")
	if not visuals:
		return
	var id := _selected_character_id()
	# Preferred: the authored character scene — the SAME visuals the character
	# select shows. Extract only its PlayerVisuals subtree; the scene root carries
	# a full player rig (script, camera, mobile controls) that must not enter
	# gameplay. The old GLB path shipped 64-vert blockout placeholders, so the
	# character picked in the menu was never the character you played.
	var scene_path := CHARACTER_SCENE_DIR % id
	if ResourceLoader.exists(scene_path):
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene != null:
			var full := packed_scene.instantiate()
			var vis := full.get_node_or_null("PlayerVisuals") as Node3D
			if vis != null:
				full.remove_child(vis)
				full.free()
				vis.name = "CharacterVisuals"
				vis.position = Vector3.ZERO
				visuals.add_child(vis)
				# The menu-built scenes sink the model so its feet rest on a
				# pedestal (-0.8035 baked in). Here the character root IS the
				# feet line (capsule bottom), so re-ground by AABB: without
				# this the body renders half-sunk into the floor.
				var aabb := _model_aabb(vis)
				if aabb.size.y > 0.01:
					vis.position.y = -aabb.position.y
				var skin_idx := _selected_skin_index(id)
				# apply_skin_variant -> apply_body_variant FREES the existing rig
				# and instantiates a fresh one, so any AnimationPlayer resolved
				# before it is a dangling freed node. Resolve _skeletal AFTER all
				# rig swaps, or _update_skeletal_anim's is_instance_valid check
				# fails every frame and the walk/run clips never play (the
				# character just slides).
				if skin_idx > 0:
					_skeletal = BlockyAnim.apply_body_variant(vis, id, skin_idx)
				else:
					BlockyAnim.apply_skin_variant(vis, id, 0)
					_skeletal = BlockyAnim.setup(vis, id, 0)
				if _skeletal != null:
					_skeletal.play("idle")
					_anim_state = "idle"
				_applied_visual = vis
				_hide_placeholder_meshes(visuals, vis)
				var vcount := 0
				for mi in vis.find_children("*", "MeshInstance3D", true, false):
					if (mi as MeshInstance3D).visible:
						vcount += 1
				print("[Player] character visuals: %s meshes=%d" % [scene_path, vcount])
				return
			full.free()
	# Fallback: the GLB blockout models.
	var path := CHARACTER_MODEL_DIR % id
	if not ResourceLoader.exists(path):
		print("[Player] character model %s missing — keeping the placeholder capsule" % path)
		return
	var packed := load(path) as PackedScene
	if not packed:
		print("[Player] could not load %s" % path)
		return
	var mdl := packed.instantiate() as Node3D
	if not mdl:
		return
	visuals.add_child(mdl)
	_applied_visual = mdl
	var aabb := _model_aabb(mdl)
	var h := aabb.size.y
	_normalise_model_transform(mdl, aabb)
	var mesh_nodes := _collect_mesh_nodes(mdl)
	_hide_placeholder_meshes(visuals, mdl)
	_apply_model_material(mesh_nodes)
	_play_model_animations(mdl)
	_report_model_stats(mdl, path, h)

func _selected_character_id() -> String:
	var save := get_node_or_null("/root/Save")
	if save and save.get("selected_character") != null:
		return String(save.get("selected_character"))
	return "nurse"

func _selected_skin_index(id: String) -> int:
	var save := get_node_or_null("/root/Save")
	if save and save.has_method("get_selected_skin"):
		return save.get_selected_skin(id)
	return 0

func _normalise_model_transform(mdl: Node3D, aabb: AABB) -> void:
	# The exported GLBs come at wildly different scales, so measure the real
	# bounding box and scale to human height, then drop it onto the origin.
	var h := aabb.size.y
	if h > 0.01:
		var s := CHARACTER_HEIGHT / h
		mdl.scale = Vector3(s, s, s)
		mdl.position.y = -aabb.position.y * s
	mdl.rotate_y(MODEL_YAW_OFFSET)

func _collect_mesh_nodes(mdl: Node3D) -> Array[MeshInstance3D]:
	# Walk the tree ONCE and collect all MeshInstance3D nodes. The old code
	# traversed the tree three separate times (visibility, materials, stats).
	var out: Array[MeshInstance3D] = []
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		out.append(mi as MeshInstance3D)
	return out

func _hide_placeholder_meshes(visuals: Node3D, mdl: Node3D) -> void:
	# The placeholder capsule/head stay as a fallback only.
	for mi in visuals.find_children("*", "MeshInstance3D", true, false):
		if not mdl.is_ancestor_of(mi):
			(mi as MeshInstance3D).visible = false

func _apply_model_material(mesh_nodes: Array[MeshInstance3D]) -> void:
	# The shipped GLBs carry NO materials (verified in the GLB JSON: every model is
	# one primitive with no material index), so they render as Godot's default
	# white — backlit at night that reads as a flat dark blob with no silhouette
	# detail. Give them a consistent readable surface.
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.34, 0.07, 0.09)  # dark blood-red: pale cream vanished against the pale plaza floor
	skin.roughness = 0.85
	skin.metallic = 0.0
	for mi in mesh_nodes:
		mi.material_override = skin

func _play_model_animations(mdl: Node3D) -> void:
	for n in mdl.find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		var list := ap.get_animation_list()
		if list.size() > 0 and not ap.is_playing():
			ap.play(list[0])

func _report_model_stats(mdl: Node3D, path: String, raw_height: float) -> void:
	var verts := 0
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var mm := (mi as MeshInstance3D).mesh
		if mm:
			for si in range(mm.get_surface_count()):
				var arr := mm.surface_get_arrays(si)
				if arr.size() > 0 and arr[0] != null:
					verts += (arr[0] as PackedVector3Array).size()
	print("[Player] character model: %s  raw_h=%.3f  scale=%.3f  verts=%d" % [path, raw_height, mdl.scale.y, verts])
	if verts < 200:
		push_warning("[Player] character model %s has only %d verts - it is a blockout placeholder" % [path, verts])


func _model_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_i := mi as MeshInstance3D
		if not mesh_i.mesh:
			continue
		var xf := root.global_transform.affine_inverse() * mesh_i.global_transform
		var box: AABB = xf * mesh_i.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
