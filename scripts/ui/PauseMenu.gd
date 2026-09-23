## PauseMenu.gd — Pause Menu UI
## Attach to root Control of pause_menu scene

extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal menu_pressed

@onready var resume_btn = $Panel/VBox/ResumeBtn
@onready var restart_btn = $Panel/VBox/RestartBtn
@onready var settings_btn = $Panel/VBox/SettingsBtn
@onready var menu_btn = $Panel/VBox/MenuBtn

var is_visible: bool = false

func _ready() -> void:
	# Button signals are wired in pause_menu.tscn ([connection] entries) —
	# do not re-connect here or Godot logs "already connected" errors.

	# Start hidden
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		toggle_pause()


func toggle_pause() -> void:
	if is_visible:
		resume()
	else:
		pause()


func pause() -> void:
	is_visible = true
	show()
	get_tree().paused = true


func resume() -> void:
	is_visible = false
	hide()
	get_tree().paused = false


func _on_resume_pressed() -> void:
	Audio.play_click()
	resume()
	emit_signal("resume_pressed")


func _on_restart_pressed() -> void:
	Audio.play_click()
	resume()
	emit_signal("restart_pressed")


func _on_settings_pressed() -> void:
	Audio.play_click()
	resume()
	get_tree().change_scene_to_file("res://scenes/main/settings.tscn")
	emit_signal("settings_pressed")


func _on_menu_pressed() -> void:
	Audio.play_click()
	resume()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
	emit_signal("menu_pressed")
