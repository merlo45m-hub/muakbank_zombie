extends Node3D

## Main Game Controller
## Attach to root Node3D of the main game scene

signal game_over(survived, score, kills)
signal health_changed(new_health, max_health)
signal stamina_changed(new_stamina, max_stamina)
signal score_changed(new_score)
signal kills_changed(new_kills)
signal timer_changed(seconds_left)
signal weapon_changed(weapon_name)
signal food_eaten(food_type, amount)

# === NODE REFS ===
@onready var player: CharacterBody3D = $Player
@onready var zombie_spawner: Node3D = $ZombieSpawner
@onready var food_spawner: Node3D = $FoodSpawner
@onready var hud: Control = $HUD
@onready var game_timer: Timer = $GameTimer
@onready var environment: Node3D = $Environment

# === GAME CONFIG ===
const GAME_DURATION: float = 600.0  # 10 minutes
const MAX_ZOMBIES: int = 12
const ZOMBIE_SPAWN_INTERVAL: float = 3.0
const FOOD_SPAWN_INTERVAL: float = 8.0
const SCORE_PER_KILL: int = 100

# === GAME STATE ===
var score: int = 0
var zombies_killed: int = 0
var game_active: bool = false
var time_remaining: float = GAME_DURATION
var zombies_to_kill: int = 5  # Kill quota to clear level

# === OPTIONAL SYSTEMS (auto-detected) ===
var wave_manager: Node = null
var combo_system: Node = null
var difficulty_manager: Node = null
var objective_manager: Node = null
var achievement_manager: Node = null
var camera_shake: Node = null

func _ready() -> void:
	print("[Game] Initializing Muak Bank Zombie...")
	# Auto-detect optional systems if present in scene
	wave_manager = get_node_or_null("WaveManager")
	combo_system = get_node_or_null("ComboSystem")
	difficulty_manager = get_node_or_null("DifficultyManager")
	objective_manager = get_node_or_null("ObjectiveManager")
	achievement_manager = get_node_or_null("AchievementManager")
	camera_shake = get_node_or_null("CameraShake")
	
	# Set up level objectives
	_setup_objectives()
	
	# Register achievements
	_setup_achievements()
	
	# Connect player signals for reactive HUD updates
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.stamina_changed.connect(_on_player_stamina_changed)
	
	# Connect wave/combo signals for reactive HUD updates
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
	if combo_system:
		if combo_system.has_signal("combo_changed"):
			combo_system.combo_changed.connect(_on_combo_changed)
	if objective_manager:
		if objective_manager.has_signal("objective_updated"):
			objective_manager.objective_updated.connect(_on_objective_updated)
	
	# Set environment based on current level
	_load_environment()
	start_game()

func _load_environment() -> void:
	var level = Save.get_current_level()
	var env_scene = Level.get_environment_scene(level)
	var env = load(env_scene).instantiate()
	add_child(env)
	print("[Game] Loaded environment: ", env_scene)
	
	# Play ambient layer for this environment
	Audio.play_ambient_for(Level.get_ambient_name(level))

func _setup_objectives() -> void:
	if not objective_manager or not objective_manager.has_method("add_objective"):
		return
	objective_manager.clear_objectives()
	# Core objectives for every level
	objective_manager.add_objective("kill_zombies", "Kill zombies", zombies_to_kill)
	objective_manager.add_objective("eat_food", "Eat to stay alive", 3)
	objective_manager.add_objective("survive", "Survive the shift", 1)

func _setup_achievements() -> void:
	var am = get_node_or_null("AchievementManager")
	if not am or not am.has_method("register_achievement"):
		return
	am.register_achievement("first_kill", "First Blood", "Kill your first zombie")
	am.register_achievement("combo_5", "Combo Master", "Reach a 5x kill combo")
	am.register_achievement("boss_slayer", "Boss Slayer", "Defeat a boss zombie")
	am.register_achievement("survivor", "Survivor", "Complete a level")
	am.register_achievement("well_fed", "Well Fed", "Eat 10 food items")
	am.register_achievement("untouchable", "Untouchable", "Complete a level without taking damage")

func start_game() -> void:
	game_active = true
	score = 0
	zombies_killed = 0
	time_remaining = GAME_DURATION
	
	# Reset player
	if player:
		player.position = Vector3(0, 0, 0)
		player.health = player.max_health
		player.stamina = player.max_stamina
	
	# Start spawners
	if zombie_spawner:
		zombie_spawner.start_spawning()
	if food_spawner:
		food_spawner.start_spawning()
	
	# Start optional systems
	if wave_manager and wave_manager.has_method("start_waves"):
		wave_manager.start_waves()
	if combo_system and combo_system.has_method("reset_combo"):
		combo_system.reset_combo()
	var powerup_manager = get_node_or_null("PowerUpManager")
	if powerup_manager and powerup_manager.has_method("start_spawning"):
		powerup_manager.start_spawning()
	
	# Start timer
	if game_timer:
		game_timer.start(1.0)  # Tick every second
	
	# Initial HUD update
	_update_hud()
	print("[Game] Started! Survive the zombie animal apocalypse!")

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Update timer
	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		end_game(true)  # Survived!
		return
	
	# Update HUD timer (cheap, only when second changes)
	if hud:
		hud.update_timer(int(time_remaining))

func _on_game_timer_timeout() -> void:
	"""Called every second — handle periodic game logic."""
	if not game_active:
		return
	# Periodic HUD refresh as fallback
	_update_hud()

func _update_hud() -> void:
	if not hud:
		return
	hud.update_score(score)
	hud.update_kills(zombies_killed)
	if player:
		hud.update_health(player.health, player.max_health)
		hud.update_stamina(player.stamina, player.max_stamina)
	# Objectives
	if objective_manager and objective_manager.has_method("get_all_objective_texts"):
		hud.update_objectives(objective_manager.get_all_objective_texts())
	# Combo
	if combo_system and combo_system.has_method("get_score_multiplier"):
		hud.update_combo(combo_system.combo_count, combo_system.get_score_multiplier())
	# Wave
	if wave_manager and hud.has_method("update_wave"):
		hud.update_wave(wave_manager.current_wave, wave_manager.waves_per_level)

# === SIGNAL HANDLERS (reactive HUD) ===

func _on_player_health_changed(new_health: int, max_health: int) -> void:
	if hud:
		hud.update_health(new_health, max_health)

func _on_player_stamina_changed(new_stamina: int, max_stamina: int) -> void:
	if hud:
		hud.update_stamina(new_stamina, max_stamina)

func _on_wave_started(wave_number: int, _count: int) -> void:
	if hud and hud.has_method("update_wave"):
		hud.update_wave(wave_number, wave_manager.waves_per_level if wave_manager else 5)

func _on_combo_changed(combo_count: int) -> void:
	if hud and hud.has_method("update_combo"):
		var mult = combo_system.get_score_multiplier() if combo_system else 1.0
		hud.update_combo(combo_count, mult)

func _on_objective_updated(_id: String, _progress: int, _target: int) -> void:
	if hud and objective_manager and objective_manager.has_method("get_all_objective_texts"):
		hud.update_objectives(objective_manager.get_all_objective_texts())

func end_game(survived: bool) -> void:
	if not game_active:
		return
	
	game_active = false
	
	# Stop spawners
	if zombie_spawner:
		zombie_spawner.stop_spawning()
	if food_spawner:
		food_spawner.stop_spawning()
	
	# Stop timer
	if game_timer:
		game_timer.stop()
	
	print("[Game] Game over! Survived: ", survived, " Score: ", score)
	emit_signal("game_over", survived, score, zombies_killed)
	
	# Save progress BEFORE scene change (race condition fix)
	Save.update_high_score(score)
	
	# Level progression: unlock next level on survival
	if survived:
		Save.add_shifts_completed(1)
		var next_level = Save.get_current_level() + 1
		if next_level <= Level.get_level_count():
			Save.unlock_level(next_level)
			print("[Game] Level ", next_level, " unlocked!")
		# Achievement: survivor
		if achievement_manager and achievement_manager.has_method("unlock"):
			achievement_manager.unlock("survivor")
	
	# Store results in Save singleton for the game over screen to retrieve
	# This avoids race condition with scene change + await
	Save.pending_results = {
		"survived": survived,
		"score": score,
		"kills": zombies_killed
	}
	
	Save.save_game()
	
	# Show game over screen
	get_tree().change_scene_to_file("res://scenes/main/game_over.tscn")

func on_zombie_killed(zombie_type: String) -> void:
	if not game_active:
		return
	
	zombies_killed += 1
	score += SCORE_PER_KILL
	
	# Apply combo multiplier if combo system present
	if combo_system and combo_system.has_method("register_kill"):
		combo_system.register_kill()
		score += int(SCORE_PER_KILL * (combo_system.get_score_multiplier() - 1.0))
	
	# Apply difficulty scaling
	if difficulty_manager and difficulty_manager.has_method("register_kill"):
		difficulty_manager.register_kill()
	
	emit_signal("kills_changed", zombies_killed)
	emit_signal("score_changed", score)
	
	# Update objectives
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress("kill_zombies", 1)
	
	# Achievements
	if achievement_manager:
		if zombies_killed == 1 and achievement_manager.has_method("unlock"):
			achievement_manager.unlock("first_kill")
		if combo_system and combo_system.combo_count >= 5:
			achievement_manager.unlock("combo_5")
	
	# Check for level completion
	if zombies_killed >= zombies_to_kill:
		# Level complete — survive the wave
		end_game(true)
		return
	
	print("[Game] Killed: ", zombie_type, " Total: ", zombies_killed)

func on_player_damaged(damage: int) -> void:
	if not game_active or not player:
		return
	
	player.take_damage(damage)
	emit_signal("health_changed", player.health, player.max_health)
	
	# Screen shake proportional to damage
	_shake(clampf(damage / 40.0, 0.1, 0.5))
	
	if difficulty_manager and difficulty_manager.has_method("register_damage_taken"):
		difficulty_manager.register_damage_taken()
	
	if player.health <= 0:
		end_game(false)

func _shake(strength: float) -> void:
	if camera_shake and camera_shake.has_method("shake"):
		camera_shake.shake(strength)

func on_food_eaten(food_type: String, health_amount: int) -> void:
	if not game_active or not player:
		return
	
	player.heal(health_amount)
	emit_signal("food_eaten", food_type, health_amount)
	emit_signal("health_changed", player.health, player.max_health)
	
	# Update objectives
	if objective_manager and objective_manager.has_method("update_progress"):
		objective_manager.update_progress("eat_food", 1)
	
	# Achievement: well fed
	if achievement_manager and achievement_manager.has_method("unlock"):
		if Save.get_total_zombies_fed() >= 10:
			achievement_manager.unlock("well_fed")
	
	print("[Game] Ate: ", food_type, " +", health_amount, " HP")

func consume_food(food_type: String) -> void:
	"""Consume a food item from player inventory (called by HUD food bar)."""
	if not game_active or not player:
		return
	var health_amount = 20  # Default heal
	match food_type:
		"medkit": health_amount = 50
		"coffee": health_amount = 10
		"sushi": health_amount = 30
		"burger": health_amount = 25
		"pizza": health_amount = 20
		"fries": health_amount = 15
		"soda": health_amount = 10
		"takis": health_amount = 15
	player.heal(health_amount)
	emit_signal("food_eaten", food_type, health_amount)
	emit_signal("health_changed", player.health, player.max_health)
	print("[Game] Consumed: ", food_type, " +", health_amount, " HP")

func on_pickup_weapon(weapon_name: String) -> void:
	if not game_active or not player:
		return
	
	player.equip_weapon(weapon_name)
	emit_signal("weapon_changed", weapon_name)
	print("[Game] Equipped: ", weapon_name)

func on_player_died() -> void:
	if not game_active:
		return
	end_game(false)

func on_powerup_collected(powerup_type: String) -> void:
	if not game_active or not player:
		return
	match powerup_type:
		"health":
			player.heal(50)
			Audio.play_pickup()
		"speed":
			player.move_speed *= 1.5
			player.sprint_speed *= 1.5
			Audio.play_powerup()
			await get_tree().create_timer(10.0).timeout
			if is_instance_valid(player):
				player.move_speed /= 1.5
				player.sprint_speed /= 1.5
		"damage":
			player.attack_damage *= 2
			Audio.play_powerup()
			await get_tree().create_timer(10.0).timeout
			if is_instance_valid(player):
				player.attack_damage /= 2
		"shield":
			player.is_shield_active = true
			Audio.play_powerup()
			await get_tree().create_timer(8.0).timeout
			if is_instance_valid(player):
				player.is_shield_active = false
		"frenzy":
			player.is_rage_active = true
			Audio.play_frenzy()
			await get_tree().create_timer(8.0).timeout
			if is_instance_valid(player):
				player.is_rage_active = false
	print("[Game] Power-up collected: ", powerup_type)
