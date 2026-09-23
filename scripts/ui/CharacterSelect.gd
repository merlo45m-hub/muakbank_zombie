## CharacterSelect.gd — Character Selection Screen
## Horror theme: Nosifer headings, dark graveyard palette, blood-red accents

extends Control

# === CHARACTER DATA ===
@export var character_scenes: Array = [
	"res://scenes/characters/character_gamer.tscn",
	"res://scenes/characters/character_doctor.tscn",
	"res://scenes/characters/character_nurse.tscn",
	"res://scenes/characters/character_streamer.tscn",
	"res://scenes/characters/character_hunter.tscn",
]

@export var character_names: Array = ["GAMER", "DOCTOR", "NURSE", "STREAMER", "HUNTER"]

# === STATE ===
var selected_character: int = 0

# === NODE REFS ===
@onready var gamer_btn = $VBoxMain/CharactersContainer/GamerCard/GamerBtn
@onready var doctor_btn = $VBoxMain/CharactersContainer/DoctorCard/DoctorBtn
@onready var nurse_btn = $VBoxMain/CharactersContainer/NurseCard/NurseBtn
@onready var streamer_btn = $VBoxMain/CharactersContainer/StreamerCard/StreamerBtn
@onready var hunter_btn = $VBoxMain/CharactersContainer/HunterCard/HunterBtn
@onready var back_btn = $VBoxMain/BackBtn

@onready var gamer_viewport = $VBoxMain/CharactersContainer/GamerCard/GamerViewport
@onready var doctor_viewport = $VBoxMain/CharactersContainer/DoctorCard/DoctorViewport
@onready var nurse_viewport = $VBoxMain/CharactersContainer/NurseCard/NurseViewport
@onready var streamer_viewport = $VBoxMain/CharactersContainer/StreamerCard/StreamerViewport
@onready var hunter_viewport = $VBoxMain/CharactersContainer/HunterCard/HunterViewport

@onready var gamer_card = $VBoxMain/CharactersContainer/GamerCard
@onready var doctor_card = $VBoxMain/CharactersContainer/DoctorCard
@onready var nurse_card = $VBoxMain/CharactersContainer/NurseCard
@onready var streamer_card = $VBoxMain/CharactersContainer/StreamerCard
@onready var hunter_card = $VBoxMain/CharactersContainer/HunterCard

@onready var gamer_pedestal = $VBoxMain/CharactersContainer/GamerCard/GamerPedestal
@onready var doctor_pedestal = $VBoxMain/CharactersContainer/DoctorCard/DoctorPedestal
@onready var nurse_pedestal = $VBoxMain/CharactersContainer/NurseCard/NursePedestal
@onready var streamer_pedestal = $VBoxMain/CharactersContainer/StreamerCard/StreamerPedestal
@onready var hunter_pedestal = $VBoxMain/CharactersContainer/HunterCard/HunterPedestal

@onready var gamer_desc = $VBoxMain/CharactersContainer/GamerCard/GamerDesc
@onready var doctor_desc = $VBoxMain/CharactersContainer/DoctorCard/DoctorDesc
@onready var nurse_desc = $VBoxMain/CharactersContainer/NurseCard/NurseDesc
@onready var streamer_desc = $VBoxMain/CharactersContainer/StreamerCard/StreamerDesc
@onready var hunter_desc = $VBoxMain/CharactersContainer/HunterCard/HunterDesc

var card_panels: Array[Panel] = []
var pedestal_panels: Array[Panel] = []


func _ready() -> void:
	# Build card/pedestal reference arrays
	card_panels = [gamer_card, doctor_card, nurse_card, streamer_card, hunter_card]
	pedestal_panels = [gamer_pedestal, doctor_pedestal, nurse_pedestal, streamer_pedestal, hunter_pedestal]

	# Setup viewport previews with lighting
	_setup_viewports()

	# Default selection: doctor (player's saved default)
	_select_character(1, false)

	# Play menu music
	Audio.play_menu_music()


func _setup_viewports() -> void:
	# Instantiate each character into its SubViewport for preview
	var viewports = [gamer_viewport, doctor_viewport, nurse_viewport, streamer_viewport, hunter_viewport]

	for i in range(viewports.size()):
		if i < character_scenes.size():
			var scene = load(character_scenes[i])
			if scene:
				var instance = scene.instantiate()
				viewports[i].add_child(instance)
				instance.position = Vector3(0, 0, 0)

				# Add ambient light so models are visible
				var world_env = WorldEnvironment.new()
				var env = Environment.new()
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = Color(0.4, 0.4, 0.5, 1.0)
				env.ambient_light_energy = 0.8
				world_env.environment = env
				viewports[i].add_child(world_env)


# ── SELECTION HANDLERS ─────────────────────────────────────────

func _on_gamer_selected() -> void:
	_select_character(0)

func _on_doctor_selected() -> void:
	_select_character(1)

func _on_nurse_selected() -> void:
	_select_character(2)

func _on_streamer_selected() -> void:
	_select_character(3)

func _on_hunter_selected() -> void:
	_select_character(4)

func _select_character(index: int, play_sound: bool = true) -> void:
	selected_character = index

	# Update visual selection highlight
	for i in range(card_panels.size()):
		var is_selected = (i == index)
		var panel = card_panels[i]
		var pedestal = pedestal_panels[i]

		# Card background: darker when selected
		if is_selected:
			panel.set("theme_override_styles/panel", _get_selected_card_style())
			pedestal.set("theme_override_styles/panel", _get_selected_pedestal_style())
		else:
			panel.set("theme_override_styles/panel", _get_normal_card_style())
			pedestal.set("theme_override_styles/panel", _get_normal_pedestal_style())

	# Update description labels (emphasize selected)
	var desc_labels = [gamer_desc, doctor_desc, nurse_desc, streamer_desc, hunter_desc]
	var normal_color = Color(0.5, 0.5, 0.5, 1.0)
	var highlight_color = Color(0.75, 0.12, 0.08, 1.0)  # Blood red

	for i in range(desc_labels.size()):
		if i == index:
			desc_labels[i].set("theme_override_font_color", highlight_color)
		else:
			desc_labels[i].set("theme_override_font_color", normal_color)

	if play_sound:
		Audio.play_click()

	print("[CharacterSelect] Selected: ", character_names[index])

	# Save selection to be loaded in game
	Save.selected_character = character_names[index].to_lower()

	# Transition to game
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")

func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")


# === STYLE CREATION HELPERS ===

func _get_normal_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.08, 1.0)
	style.border_color = Color(0.2, 0.1, 0.15, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _get_selected_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.04, 0.1, 1.0)
	style.border_color = Color(0.6, 0.1, 0.15, 1.0)  # Blood red
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _get_normal_pedestal_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.12, 1.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_right = 999
	style.corner_radius_bottom_left = 999
	return style

func _get_selected_pedestal_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.04, 0.08, 1.0)
	style.border_color = Color(0.6, 0.1, 0.15, 1.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_right = 999
	style.corner_radius_bottom_left = 999
	return style
