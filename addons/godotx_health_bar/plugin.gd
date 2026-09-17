@tool
extends EditorPlugin

func _enter_tree() -> void:
	var script_control = load("res://addons/godotx_health_bar/runtime/godotx_health_bar_control.gd") as Script
	var script_2d = load("res://addons/godotx_health_bar/runtime/godotx_health_bar_2d.gd") as Script
	if script_control == null or script_2d == null:
		push_error("GodotX Health Bar: Failed to load runtime scripts.")
		return
	var icon: Texture2D = null
	if FileAccess.file_exists("res://addons/godotx_health_bar/icon.svg"):
		icon = load("res://addons/godotx_health_bar/icon.svg") as Texture2D
	add_custom_type("GodotxHealthBarControl", "Control", script_control, icon)
	add_custom_type("GodotxHealthBar2D", "Node2D", script_2d, icon)

func _exit_tree() -> void:
	remove_custom_type("GodotxHealthBarControl")
	remove_custom_type("GodotxHealthBar2D")
