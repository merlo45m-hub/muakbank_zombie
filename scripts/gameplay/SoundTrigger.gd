extends Node3D
class_name SoundTrigger

## Sound Trigger — Attached to game objects for contextual audio
## Automatically plays sounds on events (pickup, hit, death, etc.)

@export var pickup_sound: bool = false
@export var hit_sound: bool = false
@export var death_sound: bool = false
@export var ambient_sound: bool = false

@export var player_only: bool = false
var triggered: bool = false

func _ready() -> void:
	if ambient_sound:
		_play_ambient()

func _on_area_entered(area: Area3D) -> void:
	if triggered:
		return
	
	if player_only and not area.is_in_group("player"):
		return
	
	if pickup_sound:
		_play_pickup()
	elif hit_sound:
		_play_hit()
	
	triggered = true

func _on_body_entered(body: Node3D) -> void:
	if triggered:
		return
	
	if player_only and not body.is_in_group("player"):
		return
	
	if hit_sound:
		_play_hit()
	elif death_sound:
		_play_death()
	
	triggered = true

func _play_pickup() -> void:
	Audio.play_pickup()

func _play_hit() -> void:
	Audio.play_hurt()

func _play_death() -> void:
	Audio.play_zombie_die()

func _play_ambient() -> void:
	var dir = "res://audio/ambient/"
	if ResourceLoader.exists(dir + "wind.wav"):
		var stream = load(dir + "wind.wav")
		Audio.play_ambient(stream)
