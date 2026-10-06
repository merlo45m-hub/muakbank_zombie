## LevelSelect.gd — Level Selection Screen
## Rebuilt: vector-art backdrop (LevelBackdrop), themed level cards with clear
## status lines, big "tap to play" direction. Tapping a card starts the run.
extends Control

signal level_selected(level)

const CREEP := preload("res://assets/fonts/Creepster-Regular.ttf")
const ELITE := preload("res://assets/fonts/SpecialElite-Regular.ttf")

const CARD_SIZE := Vector2(292, 262)
const CARD_BG := Color(0.11, 0.095, 0.14, 0.94)
const CARD_BORDER := Color(0.85, 0.8, 0.72, 0.30)
const CARD_BORDER_HOT := Color(1.0, 0.84, 0.45, 0.95)
const NUM_COL := Color(0.94, 0.9, 0.82)
const NUM_COL_LOCKED := Color(0.45, 0.43, 0.5)
const GOLD := Color(1.0, 0.76, 0.28)
const PALE := Color(0.82, 0.78, 0.7)
const GREEN := Color(0.62, 0.85, 0.55)

@export var levels_per_page = 6

var current_page = 0
var buttons: Array[Button] = []
var _pulse_labels: Array[Label] = []
var _cta: Label = null
var _t := 0.0

@onready var grid = $VBoxMain/ScrollContainer/Center/GridContainer
@onready var page_label = $VBoxMain/PaginationContainer/PageLabel
@onready var prev_btn = $VBoxMain/PaginationContainer/PrevBtn
@onready var next_btn = $VBoxMain/PaginationContainer/NextBtn


func _ready():
	_cta = $VBoxMain/CtaLabel
	_build_level_buttons()
	_update_page()


func _process(delta: float) -> void:
	_t += delta
	if _cta != null:
		_cta.modulate = Color(1, 1, 1, 0.78 + 0.22 * (0.5 + 0.5 * sin(_t * 2.6)))
	for lb in _pulse_labels:
		if is_instance_valid(lb):
			lb.modulate = Color(1, 1, 1, 0.72 + 0.28 * (0.5 + 0.5 * sin(_t * 3.2)))


func _play_click():
	Audio.play_click()


func _card_style(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _build_level_buttons():
	"""One themed card per level: number, status line, hover glow."""
	for i in range(1, Level.get_level_count() + 1):
		var btn := Button.new()
		btn.custom_minimum_size = CARD_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", _card_style(CARD_BG, CARD_BORDER))
		btn.add_theme_stylebox_override("hover", _card_style(Color(0.16, 0.14, 0.2, 0.96), CARD_BORDER_HOT, 3))
		btn.add_theme_stylebox_override("pressed", _card_style(Color(0.08, 0.07, 0.1, 0.98), CARD_BORDER_HOT, 3))
		btn.add_theme_stylebox_override("disabled", _card_style(Color(0.075, 0.07, 0.09, 0.9), Color(0.3, 0.29, 0.33, 0.35)))

		var unlocked: bool = Save.is_level_unlocked(i)
		var is_current: bool = (i == Save.get_current_level())

		# status line
		var status := ""
		var status_col := PALE
		if not unlocked:
			status = "LOCKED"
			status_col = Color(0.5, 0.48, 0.52)
		elif is_current:
			status = "PLAY NOW"
			status_col = GOLD
		elif i < Save.get_current_level():
			status = "REPLAY"
			status_col = GREEN
		else:
			status = "TAP TO PLAY"
			status_col = PALE

		# card border: gold for the current level
		if is_current and unlocked:
			btn.add_theme_stylebox_override("normal", _card_style(CARD_BG, CARD_BORDER_HOT, 3))

		# interior: LEVEL n / big number / status
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 12
		box.offset_top = 14
		box.offset_right = -12
		box.offset_bottom = -14
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 2)

		var lvl := Label.new()
		lvl.text = "LEVEL %d" % i
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl.add_theme_font_override("font", ELITE)
		lvl.add_theme_font_size_override("font_size", 19)
		lvl.add_theme_color_override("font_color", PALE)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lvl)

		var num := Label.new()
		num.text = str(i)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_font_override("font", CREEP)
		num.add_theme_font_size_override("font_size", 84)
		num.add_theme_color_override("font_color", NUM_COL if unlocked else NUM_COL_LOCKED)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(num)

		var st := Label.new()
		st.text = status
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_theme_font_override("font", ELITE)
		st.add_theme_font_size_override("font_size", 20)
		st.add_theme_color_override("font_color", status_col)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(st)

		if is_current and unlocked:
			_pulse_labels.append(st)

		btn.add_child(box)

		if not unlocked:
			btn.disabled = true

		btn.pressed.connect(_on_level_pressed.bind(i))
		buttons.append(btn)
		grid.add_child(btn)


func _update_page():
	"""Show only buttons for current page."""
	var start = current_page * levels_per_page
	var end = min(start + levels_per_page, buttons.size())

	for i in range(buttons.size()):
		buttons[i].visible = (i >= start and i < end)

	page_label.text = "Page %d / %d" % [current_page + 1, maxi(1, ceili(float(buttons.size()) / float(levels_per_page)))]
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