## Credits.gd — Credits Screen
## Attach to root Control node

extends Control

@onready var back_btn = $VBoxMain/BackBtn


func _ready():
	back_btn.pressed.connect(_on_back)


func _on_back():
	Audio.play_sfx(load("res://audio/sfx/click.wav"))
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
