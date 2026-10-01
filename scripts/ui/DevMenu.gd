extends Node

const DevMode := preload("res://scripts/core/DevMode.gd")

var dev_btn: Button
var footer_label: Label
var is_pressing: bool = false
var press_time: float = 0.0

static func install_on(title_screen: Node3D) -> void:
	var instance = preload("res://scripts/ui/DevMenu.gd").new()
	title_screen.add_child(instance)

func _ready() -> void:
	var parent = get_parent()
	if not is_instance_valid(parent):
		return

	var vbox = parent.get_node_or_null("VBoxMain")
	if not is_instance_valid(vbox):
		return
		
	var btn_container = vbox.get_node_or_null("ButtonContainer")
	if is_instance_valid(btn_container):
		dev_btn = Button.new()
		dev_btn.text = "DEV ROOM"
		dev_btn.custom_minimum_size = Vector2(200, 50)
		dev_btn.add_theme_font_size_override("font_size", 18)
		dev_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.4, 0.4)
		dev_btn.add_theme_stylebox_override("normal", style)
		
		btn_container.add_child(dev_btn)
		dev_btn.pressed.connect(_on_dev_btn_pressed)
		
	footer_label = vbox.get_node_or_null("FooterLabel")
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
