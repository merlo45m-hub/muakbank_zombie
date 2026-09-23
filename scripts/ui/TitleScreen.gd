## TitleScreen.gd — Main Menu (Muakbank Zombie)
## Attach to root Node3D of title screen scene
## Features: 3D cemetery background, animated buttons, save stats display

extends Node3D

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


func _update_stats():
	"""Show player's saved stats."""
	high_score_label.text = "HIGH SCORE: %d" % Save.get_high_score()
	total_fed_label.text = "FED: %d" % Save.get_total_zombies_fed()


func _animate_title():
	"""Subtle floating animation on the title."""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property($VBoxMain/TitleLabel, "position:y", 
		$VBoxMain/TitleLabel.position.y - 5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($VBoxMain/TitleLabel, "position:y", 
		$VBoxMain/TitleLabel.position.y + 5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_food_decor():
	"""Make food icons float around the background."""
	for i in range(food_icons.size()):
		var icon = load("res://assets/textures/%s.png" % food_icons[i])
		if not icon:
			continue
		var sprite = Sprite2D.new()
		sprite.texture = icon
		sprite.position = Vector2(80 + i * 90, 420)
		add_child(sprite)

		# Float animation
		var tween = create_tween()
		var start_y = 420
		var end_y = start_y - 20
		var duration = 1.5 + i * 0.2

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
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
