## TitleScreen.gd - Main Menu (Muakbank Zombie)
## 3D cemetery backdrop (moon, fog, flanking zombie animals) with wooden-plank
## buttons on top. The old floating food icons and the bobbing title are gone;
## the backdrop and the blood-drip wordmark carry the motion now.

extends Node3D

const DevMenu = preload("res://scripts/ui/DevMenu.gd")
const QUIT_DELAY = 0.2

# === CAMERA OVERRIDE FOR TITLE SCREEN ===
# Zooms in closer with wider FOV so the cemetery backdrop, flanking animals,
# and moon fill the frame with rich detail, without affecting CharacterSelect.
const TITLE_CAM_FOV = 52.0
const TITLE_CAM_POS = Vector3(0.0, 1.35, 1.20)
const TITLE_CAM_TARGET = Vector3(0.0, 1.05, -2.60)

# === NODE REFS ===
@onready var play_btn = $UI/ButtonsBox/PlayBtn
@onready var level_btn = $UI/ButtonsBox/LevelBtn
@onready var settings_btn = $UI/ButtonsBox/SettingsBtn
@onready var credits_btn = $UI/ButtonsBox/CreditsBtn
@onready var quit_btn = $UI/ButtonsBox/QuitBtn
@onready var high_score_label = $UI/StatsContainer/HighScoreLabel
@onready var total_fed_label = $UI/StatsContainer/TotalFedLabel


func _ready() -> void:
	_setup_title_camera()

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


func _setup_title_camera() -> void:
	var cam := get_node_or_null("Background/Camera") as Camera3D
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam != null:
		cam.fov = TITLE_CAM_FOV
		cam.global_position = TITLE_CAM_POS
		cam.look_at(TITLE_CAM_TARGET, Vector3.UP)
	_add_title_lighting_polish()


func _add_title_lighting_polish() -> void:
	var bg := get_node_or_null("Background")
	if bg == null:
		return
	# Accent warm glow for jack-o'-lanterns and flanking animals to bring out rich textures
	var jack_light1 := OmniLight3D.new()
	jack_light1.position = Vector3(3.2, 0.50, -2.35)
	jack_light1.light_color = Color(1.0, 0.62, 0.22)
	jack_light1.light_energy = 1.8
	jack_light1.omni_range = 3.6
	jack_light1.shadow_enabled = false
	bg.add_child(jack_light1)

	var jack_light2 := OmniLight3D.new()
	jack_light2.position = Vector3(-3.0, 0.50, -2.15)
	jack_light2.light_color = Color(1.0, 0.65, 0.25)
	jack_light2.light_energy = 1.6
	jack_light2.omni_range = 3.4
	jack_light2.shadow_enabled = false
	bg.add_child(jack_light2)


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
