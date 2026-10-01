## TitleScreen.gd — Main Menu (Muakbank Zombie)
## Attach to root Node3D of title screen scene
## Features: 3D cemetery background, animated buttons, save stats display

extends Node3D

const DevMenu = preload("res://scripts/ui/DevMenu.gd")

# === FOOD DECOR CONSTANTS (3D metric space) ===
const FOOD_ICON_START_X = -3.0
const FOOD_ICON_SPACING = 1.2
const FOOD_ICON_BASE_Y = 2.0
const FOOD_ICON_Z = -4.0
const FOOD_FLOAT_RANGE = 0.3
const FOOD_FLOAT_BASE_DURATION = 1.5
const FOOD_FLOAT_INTERVAL_INCREMENT = 0.2
const TITLE_FLOAT_DISTANCE = 5.0
const TITLE_FLOAT_DURATION = 1.5
const QUIT_DELAY = 0.2

# === NODE REFS ===
@onready var play_btn = $VBoxMain/ButtonContainer/PlayBtn
@onready var level_btn = $VBoxMain/ButtonContainer/LevelBtn
@onready var settings_btn = $VBoxMain/ButtonContainer/SettingsBtn
@onready var credits_btn = $VBoxMain/ButtonContainer/CreditsBtn
@onready var quit_btn = $VBoxMain/ButtonContainer/QuitBtn
@onready var high_score_label = $VBoxMain/StatsContainer/HighScoreLabel
@onready var total_fed_label = $VBoxMain/StatsContainer/TotalFedLabel

# === FOOD ICONS FOR DECORATION ===
var food_icons = ["burger", "noodles", "soda", "donut", "pizza", "takis"]

func _ready() -> void:
	# Connect buttons only if the scene did not already wire them.
	if play_btn and not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.pressed.connect(_on_play_pressed)
	if level_btn and not level_btn.pressed.is_connected(_on_levels_pressed):
		level_btn.pressed.connect(_on_levels_pressed)
	if settings_btn and not settings_btn.pressed.is_connected(_on_settings_pressed):
		settings_btn.pressed.connect(_on_settings_pressed)
	if credits_btn and not credits_btn.pressed.is_connected(_on_credits_pressed):
		credits_btn.pressed.connect(_on_credits_pressed)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)

	# Update stats display
	_update_stats()

	# Play menu music
	Audio.play_menu_music()
	
	# Animate title text
	_animate_title()

	# Animate food decoration icons
	_animate_food_decor()

	# Install dev menu if dev mode is active
	DevMenu.install_on(self)


func _update_stats():
	"""Show player's saved stats."""
	high_score_label.text = "HIGH SCORE: %d" % Save.get_high_score()
	total_fed_label.text = "FED: %d" % Save.get_total_zombies_fed()


func _animate_title():
	"""Subtle floating animation on the title."""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property($VBoxMain/TitleLabel, "position:y",
		$VBoxMain/TitleLabel.position.y - TITLE_FLOAT_DISTANCE, TITLE_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($VBoxMain/TitleLabel, "position:y",
		$VBoxMain/TitleLabel.position.y + TITLE_FLOAT_DISTANCE, TITLE_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_food_decor():
	"""Make food icons float around the background."""
	for i in range(food_icons.size()):
		var icon = load("res://assets/textures/%s.png" % food_icons[i])
		if not icon:
			continue
		var sprite = Sprite3D.new()
		sprite.texture = icon
		sprite.position = Vector3(FOOD_ICON_START_X + i * FOOD_ICON_SPACING, FOOD_ICON_BASE_Y, FOOD_ICON_Z)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sprite)

		# Float animation
		var tween = create_tween()
		var start_y = FOOD_ICON_BASE_Y
		var end_y = start_y - FOOD_FLOAT_RANGE
		var duration = FOOD_FLOAT_BASE_DURATION + i * FOOD_FLOAT_INTERVAL_INCREMENT

		tween.set_loops()
		tween.tween_property(sprite, "position:y", end_y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).from(start_y)
		tween.tween_property(sprite, "position:y", start_y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(duration)


# ── BUTTON HANDLERS ───────────────────────────────────────────

func _on_play_pressed():
	"""Go to character select first."""
	Audio.play_click()
	Audio.stop_music()
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func _on_levels_pressed():
	"""Open level select screen."""
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_settings_pressed():
	"""Open settings menu."""
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/settings.tscn")


func _on_credits_pressed():
	"""Show credits."""
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/credits.tscn")


func _on_quit_pressed():
	"""Quit game."""
	Audio.play_click()
	await get_tree().create_timer(QUIT_DELAY).timeout
	get_tree().quit()
