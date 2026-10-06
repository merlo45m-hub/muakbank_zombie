## LevelSelect.gd — Level Selection Screen
## Attach to root Control node

extends Control

signal level_selected(level)

@export var levels_per_page = 6

var current_page = 0
var buttons = []

@onready var grid = $VBoxMain/ScrollContainer/GridContainer
@onready var page_label = $VBoxMain/PaginationContainer/PageLabel
@onready var prev_btn = $VBoxMain/PaginationContainer/PrevBtn
@onready var next_btn = $VBoxMain/PaginationContainer/NextBtn


func _ready():
	# Button signals are wired in the scene file; connecting them again here
	# printed "already connected" errors on every scene load.
	_build_level_buttons()
	_update_page()

	# Direction: say what this screen wants. Tapping a tile starts the run.
	var hint := Label.new()
	hint.text = "Tap a level and it starts right away"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	var vbox := $VBoxMain as VBoxContainer
	vbox.add_child(hint)
	vbox.move_child(hint, 1)
	prev_btn.add_theme_font_size_override("font_size", 22)
	next_btn.add_theme_font_size_override("font_size", 22)
	page_label.add_theme_font_size_override("font_size", 22)


func _play_click():
	Audio.play_click()


func _build_level_buttons():
	"""Create a button for each level."""
	for i in range(1, Level.get_level_count() + 1):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(130, 130)
		btn.add_theme_font_size_override("font_size", 34)
		btn.pressed.connect(_on_level_pressed.bind(i))

		# Lock if not unlocked
		if not Save.is_level_unlocked(i):
			btn.disabled = true
			btn.text = "LOCKED"

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
	_play_click()
	Save.set_current_level(level)
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _on_back():
	_play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")


func _on_prev():
	if current_page > 0:
		current_page -= 1
		_update_page()


func _on_next():
	current_page += 1
	_update_page()
