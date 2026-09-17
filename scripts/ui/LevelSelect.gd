## LevelSelect.gd — Level Selection Screen
## Attach to root Control node

extends Control

signal level_selected(level)

@export var levels_per_page = 6

var current_page = 0
var buttons = []

@onready var grid = $VBoxMain/ScrollContainer/GridContainer
@onready var page_label = $VBoxMain/PaginationContainer/PageLabel
@onready var back_btn = $VBoxMain/ButtonContainer/BackBtn
@onready var prev_btn = $VBoxMain/PaginationContainer/PrevBtn
@onready var next_btn = $VBoxMain/PaginationContainer/NextBtn


func _ready():
	back_btn.pressed.connect(_on_back)
	prev_btn.pressed.connect(_on_prev)
	next_btn.pressed.connect(_on_next)
	_build_level_buttons()
	_update_page()


func _build_level_buttons():
	"""Create a button for each level."""
	for i in range(1, 31):  # 30 levels max
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(64, 64)
		btn.pressed.connect(_on_level_pressed.bind(i))

		# Lock if not unlocked
		if not Save.is_level_unlocked(i):
			btn.disabled = true
			btn.text = "🔒"

		# Highlight current level
		if i == Save.get_current_level():
			btn.add_theme_color_override("font_color", Color(1, 0.8, 0))

		buttons.append(btn)
		grid.add_child(btn)


func _update_page():
	"""Show only buttons for current page."""
	var start = current_page * levels_per_page
	var end = min(start + levels_per_page, buttons.size())

	for i in range(buttons.size()):
		buttons[i].visible = (i >= start and i < end)

	page_label.text = "Page %d" % (current_page + 1)
	prev_btn.disabled = (current_page == 0)
	next_btn.disabled = (end >= buttons.size())


func _on_level_pressed(level):
	"""Start selected level."""
	var _sfx = load("res://audio/sfx/click.wav")
	if _sfx:
		Audio.play_sfx(_sfx)
	Save.set_current_level(level)
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _on_back():
	var _sfx = load("res://audio/sfx/click.wav")
	if _sfx:
		Audio.play_sfx(_sfx)
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")


func _on_prev():
	if current_page > 0:
		current_page -= 1
		_update_page()


func _on_next():
	current_page += 1
	_update_page()
