extends Control
class_name HUD

## HUD — Survival UI Controller
## Attach to CanvasLayer in main game scene

@onready var health_bar = $VBoxLeft/HypeContainer/HypeBar
@onready var stamina_bar = $VBoxLeft/OverwhelmContainer/OverwhelmBar
@onready var score_label = $VBoxRight/LikesLabel
@onready var kills_label = $VBoxRight/KillsLabel
@onready var timer_label = $VBoxRight/TimerLabel

func _ready() -> void:
	print("[HUD] Ready")

func update_timer(seconds: int) -> void:
	if timer_label:
		var mins = seconds / 60
		var secs = seconds % 60
		timer_label.text = "⏱ %02d:%02d" % [mins, secs]
		if seconds < 60:
			timer_label.modulate = Color(1, 0.3, 0.3)

func update_health(current: int, maximum: int) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		if current > 60:
			health_bar.tint_progress = Color(0.2, 0.8, 0.2)
		elif current > 30:
			health_bar.tint_progress = Color(0.9, 0.7, 0.2)
		else:
			health_bar.tint_progress = Color(0.9, 0.2, 0.2)

func update_stamina(current: int, maximum: int) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current

func update_score(score: int) -> void:
	if score_label:
		score_label.text = "🪙 %d" % score

func update_kills(kills: int) -> void:
	if kills_label:
		kills_label.text = "☠ %d" % kills
