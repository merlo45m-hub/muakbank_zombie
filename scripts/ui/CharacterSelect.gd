## CharacterSelect.gd — Character Selection Screen
## Attach to root Control node of character_select scene
## Displays 5 playable characters with SubViewport previews

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


func _ready() -> void:
	# Connect buttons
	gamer_btn.pressed.connect(_on_gamer_selected)
	doctor_btn.pressed.connect(_on_doctor_selected)
	nurse_btn.pressed.connect(_on_nurse_selected)
	streamer_btn.pressed.connect(_on_streamer_selected)
	hunter_btn.pressed.connect(_on_hunter_selected)
	back_btn.pressed.connect(_on_back_pressed)

	# Setup viewport previews
	_setup_viewports()

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
				# Position camera for preview
				instance.position = Vector3(0, 0, 0)


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

func _select_character(index: int) -> void:
	selected_character = index
	Audio.play_click()
	print("[CharacterSelect] Selected: ", character_names[index])
	
	# Save selection to be loaded in game
	Save.selected_character = character_names[index]
	
	# Load character stats
	var stats_path = "res://assets/materials/stats_%s.tres" % character_names[index].to_lower()
	var stats = load(stats_path)
	
	# Transition to game
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")

func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
