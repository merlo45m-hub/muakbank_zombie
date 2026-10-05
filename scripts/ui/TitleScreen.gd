## TitleScreen.gd - Main Menu (Muakbank Zombie)
## 3D cemetery backdrop (moon, fog, flanking zombie animals) with wooden-plank
## buttons on top. The old floating food icons and the bobbing title are gone;
## the backdrop and the blood-drip wordmark carry the motion now.

extends Node3D

const DevMenu = preload("res://scripts/ui/DevMenu.gd")
const QUIT_DELAY = 0.2

# === NODE REFS ===
@onready var play_btn = $UI/ButtonsBox/PlayBtn
@onready var level_btn = $UI/ButtonsBox/LevelBtn
@onready var settings_btn = $UI/ButtonsBox/SettingsBtn
@onready var credits_btn = $UI/ButtonsBox/CreditsBtn
@onready var quit_btn = $UI/ButtonsBox/QuitBtn
@onready var high_score_label = $UI/StatsContainer/HighScoreLabel
@onready var total_fed_label = $UI/StatsContainer/TotalFedLabel


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

	_update_stats()
	Audio.play_menu_music()

	# Install dev menu if dev mode is active
	DevMenu.install_on(self)


func _update_stats() -> void:
	high_score_label.text = "HIGH SCORE: %d" % Save.get_high_score()
	total_fed_label.text = "FED: %d" % Save.get_total_zombies_fed()


# -- BUTTON HANDLERS -------------------------------------------

func _on_play_pressed() -> void:
	"""Go to character select first."""
	Audio.play_click()
	Audio.stop_music()
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func _on_levels_pressed() -> void:
	"""Open level select screen."""
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_settings_pressed() -> void:
	"""Open settings menu."""
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/settings.tscn")


func _on_credits_pressed() -> void:
	"""Show credits."""
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/credits.tscn")


func _on_quit_pressed() -> void:
	"""Quit game."""
	Audio.play_click()
	await get_tree().create_timer(QUIT_DELAY).timeout
	get_tree().quit()
