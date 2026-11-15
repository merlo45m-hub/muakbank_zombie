## Settings.gd — Settings Menu
## Attach to root Control node

extends Control

@onready var master_slider = $PanelContainer/VBoxMain/AudioSection/MasterContainer/MasterSlider
@onready var music_slider = $PanelContainer/VBoxMain/AudioSection/MusicContainer/MusicSlider
@onready var sfx_slider = $PanelContainer/VBoxMain/AudioSection/SfxContainer/SfxSlider
@onready var difficulty_btn = $PanelContainer/VBoxMain/GameplaySection/DifficultyContainer/DifficultyOption
@onready var haptics_toggle = $PanelContainer/VBoxMain/GameplaySection/HapticsContainer/HapticsToggle
@onready var reset_btn = $PanelContainer/VBoxMain/DataSection/ResetBtn
@onready var back_btn = $PanelContainer/VBoxMain/BackBtn


func _ready() -> void:
	# Load values
	master_slider.value = Audio.master_volume
	music_slider.value = Audio.music_volume
	sfx_slider.value = Audio.sfx_volume
	haptics_toggle.button_pressed = Save.is_haptics_enabled()
	_update_difficulty_label()

	# Connect
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	difficulty_btn.item_selected.connect(_on_difficulty_selected)
	reset_btn.pressed.connect(_on_reset_pressed)
	back_btn.pressed.connect(_on_back)


func _play_click() -> void:
	Audio.play_click()


func _on_master_changed(val: float) -> void:
	Audio.master_volume = val


func _on_music_changed(val: float) -> void:
	Audio.music_volume = val


func _on_sfx_changed(val: float) -> void:
	Audio.sfx_volume = val
	_play_click()


func _on_haptics_toggled(enabled: bool) -> void:
	Save.set_haptics_enabled(enabled)
	if enabled:
		Audio.haptic_light()


func _on_difficulty_selected(idx: int) -> void:
	Save.set_difficulty(idx)
	_update_difficulty_label()
	_play_click()


func _update_difficulty_label() -> void:
	var labels = ["Easy", "Normal", "Hard"]
	difficulty_btn.clear()
	for i in range(labels.size()):
		difficulty_btn.add_item(labels[i])
	difficulty_btn.selected = Save.get_difficulty()


func _on_reset_pressed() -> void:
	Save.reset_progress()
	_update_difficulty_label()
	_play_click()


func _on_back() -> void:
	_play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
