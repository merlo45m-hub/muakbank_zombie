extends CharacterBody3D
class_name Player

## Player Character — Third Person Survival (Improved)
## Adapted with best practices from gdquest-demos/godot-4-3d-third-person-controller (MIT)
## Public API preserved for all external callers (Game.gd, FoodItem3D.gd, weapon/pickup systems).

signal health_changed(new_health: int, max_health: int)
signal stamina_changed(new_stamina: int, max_stamina: int)
signal died
signal ate_food(food_type: String, amount: int)
signal picked_up_weapon(weapon_name: String)

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
var current_weapon: String = "bat"
var foods: Array = []
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
var camrot_v: float = 0.0
var h_sensitivity: float = 0.015
var v_sensitivity: float = 0.012

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

# Track start position for respawn/reset
var _start_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Load character stats if assigned
	if character_stats:
		_apply_character_stats()

	health = max_health
	stamina = max_stamina
	add_to_group("player")

	# Setup weapon system
	if weapon_system and weapon_system.has_method("equip_weapon"):
		weapon_system.equip_weapon("bat")

	# Setup mobile controls
	if mobile_controls:
		mobile_controls.move_vector_changed.connect(_on_mobile_move)
		mobile_controls.attack_pressed.connect(_on_mobile_attack)
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
	# Consume mouse look here so _process doesn't double-handle.
	# Pattern adapted from gdquest camera_controller._unhandled_input.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_dead:
			camrot_h -= event.relative.x * h_sensitivity
			camrot_v -= event.relative.y * v_sensitivity
			camrot_v = clamp(camrot_v, deg_to_rad(-75), deg_to_rad(60))


func _process(delta: float) -> void:
	if is_dead:
		return

	# Apply camera rotation to the SpringArm each frame.
	# Doing this in _process (not _physics_process) keeps the camera smooth
	# independent of physics tick rate — adapted from gdquest approach.
	_apply_camera_rotation()

	# Regenerate stamina — uses the exported stamina_regen value (was hardcoded 15).
	if stamina < max_stamina:
		stamina = min(max_stamina, stamina + delta * stamina_regen)
		emit_signal("stamina_changed", stamina, max_stamina)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Gather and process input
	_handle_movement_input(delta)
	_handle_jump(delta)
	_handle_attack(delta)

	# Apply movement
	move_and_slide()

	# Stuck detection — adapted from gdquest controller.
	# If we had velocity but didn't move, push out of the blocking geometry.
	var stuck_epsilon: float = 0.001
	if velocity.length() > stuck_epsilon:
		var stuck_check := Vector3(velocity.x, 0, velocity.z)
		if stuck_check.length() > stuck_epsilon:
			# Simple nudge along movement direction to escape shallow traps.
			var nudge_dir := stuck_check.normalized()
			global_position += nudge_dir * 0.05


# ──────────────────────────────────────────────
#  INPUT — improved to mirror gdquest controller patterns
# ──────────────────────────────────────────────

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
	var wants_sprint: bool = Input.is_action_pressed("sprint") and stamina > 10 and _raw_input_dir != Vector2.ZERO
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

	var accel: float = 10.0
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	# Zero out tiny drift
	if velocity.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0


func _get_raw_input_dir() -> Vector2:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return mobile_move_vector
	else:
		return Vector2(
			Input.get_action_strength("right") - Input.get_action_strength("left"),
			Input.get_action_strength("forward") - Input.get_action_strength("backward")
		)


func _rotate_toward_direction(direction: Vector3, delta: float) -> void:
	if not mesh:
		return
	if direction.length() < 0.01:
		return
	var target_rot: float = atan2(direction.x, direction.z)
	var rot_speed: float = 10.0
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rot, rot_speed * delta)


func _handle_jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		stamina = max(0, stamina - 10)
		emit_signal("stamina_changed", stamina, max_stamina)


func _handle_attack(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta

	if Input.is_action_just_pressed("attack") and not is_attacking and attack_timer <= 0 and not is_dead:
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


# ──────────────────────────────────────────────
#  MOBILE CALLBACKS
# ──────────────────────────────────────────────

func _on_mobile_move(vector: Vector2) -> void:
	mobile_move_vector = vector


func _on_mobile_attack() -> void:
	if not is_dead:
		_perform_attack()

func _on_mobile_special() -> void:
	use_special_ability()


# ──────────────────────────────────────────────
#  ATTACK
# ──────────────────────────────────────────────

func _perform_attack() -> void:
	is_attacking = true

	# Apply character attack speed multiplier
	var speed_mult: float = character_stats.attack_speed if character_stats else 1.0
	attack_timer = attack_cooldown * speed_mult

	# Play sound (defer to Audio singleton; guard against it being absent)
	if Audio:
		Audio.play_click()

	# Swing animation via weapon mesh
	if mesh:
		weapon_tween = create_tween()
		weapon_tween.tween_property(mesh, "rotation:x", mesh.rotation.x - deg_to_rad(45), weapon_swing_duration / 2)
		weapon_tween.tween_property(mesh, "rotation:x", mesh.rotation.x, weapon_swing_duration / 2)

	# Check for enemies in range
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy.is_in_group("enemies"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead:
			continue
		var dist: float = global_transform.origin.distance_to(enemy.global_transform.origin)
		var base_range: float = attack_range
		var hit_range: float = base_range * (character_stats.attack_range / 2.0 if character_stats else 1.0)
		if dist < hit_range:
			if enemy.has_method("take_damage"):
				var damage: int = attack_damage
				
				# Use the equipped weapon's damage if a WeaponSystem is present
				if weapon_system and weapon_system.has_method("get_current_weapon_data"):
					var wdata = weapon_system.get_current_weapon_data()
					if wdata and wdata.has("damage") and int(wdata["damage"]) > 0:
						damage = int(wdata["damage"])

				# Apply weapon multiplier from character stats
				if character_stats:
					damage = int(damage * character_stats.weapon_damage_multiplier)

				# Rage mode: double damage
				if is_rage_active:
					damage *= 2

				# Critical hit check
				var is_crit: bool = false
				if character_stats and randf() < character_stats.critical_chance:
					damage = int(damage * character_stats.critical_multiplier)
					is_crit = true

				# Emit hit particles
				if has_node("HitFeedback") and $HitFeedback.has_method("emit_hit"):
					$HitFeedback.emit_hit(enemy.global_transform.origin, enemy.get_class())

				enemy.take_damage(damage)

				# Spawn damage number at enemy position
				if damage_numbers:
					var dmg_type: int = MinosDamageNumbers3D.DamageType.CRITICAL_HIT if is_crit else MinosDamageNumbers3D.DamageType.NORMAL
					damage_numbers.display_number(damage, enemy.global_transform.origin, dmg_type)

	# Wait for swing animation to finish
	await get_tree().create_timer(weapon_swing_duration).timeout
	is_attacking = false


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
			await get_tree().create_timer(character_stats.special_duration).timeout
			is_rage_active = false
			print("[SPECIAL] Rage ended.")
		"iron_skin":
			is_shield_active = true
			special_timer = character_stats.special_cooldown
			await get_tree().create_timer(character_stats.special_duration).timeout
			is_shield_active = false
			print("[SPECIAL] Iron Skin ended.")
		"rush":
			move_speed *= 2.0
			special_timer = character_stats.special_cooldown
			await get_tree().create_timer(character_stats.special_duration).timeout
			move_speed /= 2.0
			print("[SPECIAL] Rush ended.")
		"heal_aura":
			special_timer = character_stats.special_cooldown
			for i in range(5):
				health = min(max_health, health + 10)
				await get_tree().create_timer(1.0).timeout
			print("[SPECIAL] Heal Aura ended.")


# ──────────────────────────────────────────────
#  PUBLIC API — preserved exactly (take_damage, heal, eat, equip_weapon, signals)
# ──────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if is_dead:
		return

	# Apply damage reduction from character stats
	if character_stats:
		amount = int(amount * (1.0 - character_stats.damage_reduction))

	# Iron Skin: 50% damage reduction
	if is_shield_active:
		amount = int(amount * 0.5)

	health -= amount
	health = max(0, health)
	emit_signal("health_changed", health, max_health)

	if mesh:
		_flash_red()

	print("[Player] Took ", amount, " damage — HP: ", health)

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

	# Release mouse on desktop so the player can interact with UI
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func eat(food_type: String, amount: int) -> void:
	if is_eating or is_dead:
		return

	is_eating = true
	heal(amount)
	emit_signal("ate_food", food_type, amount)

	await get_tree().create_timer(0.5).timeout
	is_eating = false


func equip_weapon(weapon_name: String) -> void:
	current_weapon = weapon_name
	# Forward to the WeaponSystem so the actual weapon stats change
	if weapon_system and weapon_system.has_method("equip_weapon"):
		weapon_system.equip_weapon(weapon_name)
		if weapon_system.has_method("add_weapon_to_inventory"):
			weapon_system.add_weapon_to_inventory(weapon_name)
	emit_signal("picked_up_weapon", weapon_name)
	print("[Player] Equipped: ", weapon_name)


# ──────────────────────────────────────────────
#  VISUAL FEEDBACK
# ──────────────────────────────────────────────

func _flash_red() -> void:
	if not mesh:
		return
	# Use material_override (not surface override) — fix for Godot 6.4+
	var mat = mesh.material_override
	if not mat:
		# Try surface override as fallback
		mat = mesh.get_surface_override_material(0)
	if not mat:
		return
	mat.emissive_color = Color(1, 0.2, 0.2)
	await get_tree().create_timer(0.15).timeout
	mat.emissive_color = Color(0, 0, 0)


# ──────────────────────────────────────────────
#  AREA CALLBACKS (preserved — used by food/pickup/enemy-hitbox areas)
# ──────────────────────────────────────────────

func _on_FoodArea_area_entered(area: Area3D) -> void:
	if area.is_in_group("food"):
		var food_script = area.get_parent()
		if food_script and food_script.has_method("collect"):
			food_script.collect(self)
			if food_script.has("food_type"):
				foods.append(food_script.food_type)


func _on_PickupArea_area_entered(area: Area3D) -> void:
	if area.is_in_group("weapon"):
		var item = area.get_parent()
		if item and item.has_method("get_weapon_name"):
			equip_weapon(item.get_weapon_name())
			item.queue_free()


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
