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

# === GAME STATE ===
var score: int = 0
var zombies_killed: int = 0
var game_active: bool = false
var time_remaining: float = GAME_DURATION
var zombies_to_kill: int = 5  # Kill quota to clear level

func _ready() -> void:
	print("[Game] Initializing Muak Bank Zombie...")
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

func start_game() -> void:
	game_active = true
	score = 0
	zombies_killed = 0
	time_remaining = GAME_DURATION
	
	# Reset player
	if player:
		player.position = Vector3(0, 0, 0)
		player.health = player.max_health
	
	# Start spawners
	if zombie_spawner:
		zombie_spawner.start_spawning()
	if food_spawner:
		food_spawner.start_spawning()
	
	# Start timer
	if game_timer:
		game_timer.start(1.0)  # Tick every second
	
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
	
	# Update HUD every frame
	if hud:
		hud.update_timer(int(time_remaining))
		hud.update_score(score)
		hud.update_kills(zombies_killed)
		if player:
			hud.update_health(player.health, player.max_health)
			hud.update_stamina(player.stamina, player.max_stamina)

func _on_game_timer_timeout() -> void:
	"""Called every second — handle periodic game logic."""
	if not game_active:
		return
	
	# Could add wave logic here
	pass

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
	score += 100
	emit_signal("kills_changed", zombies_killed)
	emit_signal("score_changed", score)
	
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
	
	if player.health <= 0:
		end_game(false)

func on_food_eaten(food_type: String, health_amount: int) -> void:
	if not game_active or not player:
		return
	
	player.heal(health_amount)
	emit_signal("food_eaten", food_type, health_amount)
	emit_signal("health_changed", player.health, player.max_health)
	
	print("[Game] Ate: ", food_type, " +", health_amount, " HP")

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

