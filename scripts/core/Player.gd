extends CharacterBody3D
class_name Player

## Player Character — Third Person Survival (Fixed)
## Attach to CharacterBody3D root with child nodes

signal health_changed(new_health, max_health)
signal stamina_changed(new_stamina, max_stamina)
signal died
signal ate_food(food_type, amount)
signal picked_up_weapon(weapon_name)

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

# === NODE REFS ===
@onready var mesh: Node3D = $PlayerVisuals/Body
@onready var camera_arm: SpringArm3D = $Camera
@onready var camera: Camera3D = $Camera/Camera3D
@onready var collision: CollisionShape3D = $PlayerCollision

# === CAMERA STATE ===
var camrot_h: float = 0.0
var camrot_v: float = 0.0
var h_sensitivity: float = 0.015
var v_sensitivity: float = 0.012

@onready var weapon_system = $WeaponSystem
@onready var mobile_controls = $MobileControls

# === MOBILE STATE ===
var mobile_move_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Load character stats if assigned
	if character_stats:
		_apply_character_stats()
	
	health = max_health
	stamina = max_stamina
	add_to_group("player")
	
	# Setup weapon system
	if has_node("WeaponSystem"):
		weapon_system = $WeaponSystem
		weapon_system.equip_weapon("bat")
	
	# Setup mobile controls
	if has_node("MobileControls"):
		mobile_controls = $MobileControls
		mobile_controls.move_vector_changed.connect(_on_mobile_move)
		mobile_controls.attack_pressed.connect(_on_mobile_attack)


func _apply_character_stats() -> void:
	max_health = character_stats.max_health
	max_stamina = character_stats.max_stamina
	move_speed = character_stats.move_speed
	sprint_speed = character_stats.sprint_speed
	attack_damage = character_stats.attack_damage
	stamina_regen = character_stats.stamina_regen

func _process(delta: float) -> void:
	if is_dead:
		return
	
	# Regenerate stamina slowly
	if stamina < max_stamina:
		stamina = min(max_stamina, stamina + delta * 15)
		emit_signal("stamina_changed", stamina, max_stamina)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle input
	_handle_movement(delta)
	_handle_jump()
	_handle_attack(delta)
	
	# Apply movement
	move_and_slide()

func _input(event: InputEvent) -> void:
	if is_dead:
		return
	
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camrot_h -= event.relative.x * h_sensitivity
		camrot_v -= event.relative.y * v_sensitivity
		camrot_v = clamp(camrot_v, deg_to_rad(-75), deg_to_rad(60))

func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	
	# Mobile input
	if OS.has_feature("android") or OS.has_feature("ios"):
		input_dir = mobile_move_vector
	else:
		# Keyboard input
		input_dir = Vector2(
			Input.get_action_strength("right") - Input.get_action_strength("left"),
			Input.get_action_strength("forward") - Input.get_action_strength("backward")
		).normalized()
	
	# Camera-relative direction
	var cam_basis = camera.global_transform.basis
	var direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0
	
	# Sprint check
	var sprinting = Input.is_action_pressed("sprint") and stamina > 10 and input_dir != Vector2.ZERO
	var speed = sprint_speed if sprinting else move_speed
	
	if sprinting:
		stamina = max(0, stamina - delta * 30)
		emit_signal("stamina_changed", stamina, max_stamina)
	
	# Apply velocity
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Rotate player to face movement direction
		if mesh:
			var target_rot = atan2(direction.x, direction.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rot, 10 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)

func _on_mobile_move(vector: Vector2) -> void:
	mobile_move_vector = vector

func _on_mobile_attack() -> void:
	_perform_attack()

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_dead:
		velocity.y = jump_velocity
		stamina -= 10

func _handle_attack(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta
	
	if Input.is_action_just_pressed("attack") and not is_attacking and attack_timer <= 0:
		_perform_attack()

func _perform_attack() -> void:
	is_attacking = true
	
	# Apply character attack speed
	var speed_mult = character_stats.attack_speed if character_stats else 1.0
	attack_timer = attack_cooldown * speed_mult
	
	Audio.play_click()
	
	# Swing animation
	if mesh:
		weapon_tween = create_tween()
		weapon_tween.tween_property(mesh, "rotation:x", mesh.rotation.x - deg_to_rad(45), weapon_swing_duration / 2)
		weapon_tween.tween_property(mesh, "rotation:x", mesh.rotation.x, weapon_swing_duration / 2)
	
	# Check for enemies in range
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.is_in_group("enemies") and not enemy.is_dead:
			var dist = global_transform.origin.distance_to(enemy.global_transform.origin)
			var hit_range = attack_range * (character_stats.attack_range / 2.0 if character_stats else 1.0)
			if dist < hit_range:
				if enemy.has_method("take_damage"):
					var damage = attack_damage
					
					# Apply weapon multiplier
					if character_stats:
						damage = int(damage * character_stats.weapon_damage_multiplier)
					
					# Rage mode: double damage
					if is_rage_active:
						damage *= 2
					
					# Critical hit check
					if character_stats and randf() < character_stats.critical_chance:
						damage = int(damage * character_stats.critical_multiplier)
						print("[CRITICAL HIT!]")
					
					# Emit hit particles
					if has_node("HitFeedback") and $HitFeedback.has_method("emit_hit"):
						$HitFeedback.emit_hit(enemy.global_transform.origin, enemy.get_class())
					
					enemy.take_damage(damage)
	
	await get_tree().create_timer(weapon_swing_duration).timeout
	is_attacking = false

func use_special_ability() -> void:
	if special_timer > 0 or not character_stats:
		return
	
	var ability = character_stats.special_ability
	
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
			# Heal over time
			special_timer = character_stats.special_cooldown
			for i in range(5):
				health = min(max_health, health + 10)
				await get_tree().create_timer(1.0).timeout
			print("[SPECIAL] Heal Aura ended.")

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
	emit_signal("picked_up_weapon", weapon_name)
	print("[Player] Equipped: ", weapon_name)

func _flash_red() -> void:
	if not mesh:
		return
	# Use material_override (not surface override) - fix for finding 6.4
	var mat = mesh.material_override
	if not mat:
		# Try surface override as fallback
		mat = mesh.get_surface_override_material(0)
	if not mat:
		return
	mat.emissive_color = Color(1, 0.2, 0.2)
	await get_tree().create_timer(0.15).timeout
	mat.emissive_color = Color(0, 0, 0)

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
