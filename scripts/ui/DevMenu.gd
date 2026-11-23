extends Node

const DevMode := preload("res://scripts/core/DevMode.gd")

var dev_btn: Button
var footer_label: Label
var is_pressing: bool = false
var press_time: float = 0.0

static func install_on(title_screen: Node3D) -> void:
	var instance = preload("res://scripts/ui/DevMenu.gd").new()
	title_screen.add_child(instance)

func _wood_style(modulate: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.content_margin_left = 56.0
	style.content_margin_top = 14.0
	style.content_margin_right = 56.0
	style.content_margin_bottom = 14.0
	var texture: Texture2D = load("res://assets/textures/wood_planks.jpg") as Texture2D
	if texture != null:
		style.texture = texture
	style.modulate_color = modulate
	return style

func _ready() -> void:
	var parent = get_parent()
	if not is_instance_valid(parent):
		return

	# The title screen was rebuilt: buttons live in UI/ButtonsBox, footer at
	# UI/FooterLabel. (The old VBoxMain/ButtonContainer path is gone.)
	var btn_container = parent.get_node_or_null("UI/ButtonsBox")
	if is_instance_valid(btn_container):
		dev_btn = Button.new()
		dev_btn.text = "DEV ROOM"
		dev_btn.custom_minimum_size = Vector2(400, 64)
		var secondary_font: Font = load("res://assets/fonts/SpecialElite-Regular.ttf") as Font
		if secondary_font != null:
			dev_btn.add_theme_font_override("font", secondary_font)
		dev_btn.add_theme_font_size_override("font_size", 30)
		dev_btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.89, 1))
		dev_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.9, 1))
		dev_btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.86, 0.8, 1))
		dev_btn.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 0.9))
		dev_btn.add_theme_constant_override("outline_size", 5)
		dev_btn.add_theme_stylebox_override("normal", _wood_style(Color(0.72, 0.68, 0.62, 1)))
		dev_btn.add_theme_stylebox_override("hover", _wood_style(Color(0.98, 0.93, 0.86, 1)))
		dev_btn.add_theme_stylebox_override("pressed", _wood_style(Color(0.6, 0.56, 0.52, 1)))
		dev_btn.add_theme_stylebox_override("focus", _wood_style(Color(0.98, 0.93, 0.86, 1)))

		btn_container.add_child(dev_btn)
		dev_btn.pressed.connect(_on_dev_btn_pressed)
		
	footer_label = parent.get_node_or_null("UI/FooterLabel")
	if is_instance_valid(footer_label):
		footer_label.mouse_filter = Control.MOUSE_FILTER_PASS
		footer_label.gui_input.connect(_on_footer_gui_input)
		
	_refresh_visibility()

func _on_dev_btn_pressed() -> void:
	if DevMode.is_active():
		get_tree().change_scene_to_file("res://scenes/dev/dev_room.tscn")

func _on_footer_gui_input(event: InputEvent) -> void:
	var pressed = false
	var released = false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed = true
		else:
			released = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			pressed = true
		else:
			released = true
			
	if pressed:
		is_pressing = true
		press_time = 0.0
	elif released:
		is_pressing = false

func _process(delta: float) -> void:
	if is_pressing:
		press_time += delta
		if press_time >= 1.0:
			is_pressing = false
			DevMode.toggle()
			_refresh_visibility()

func _refresh_visibility() -> void:
	if is_instance_valid(dev_btn):
		var active = DevMode.is_active()
		dev_btn.visible = active
		if active:
			dev_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			dev_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
