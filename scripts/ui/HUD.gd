extends Control
class_name HUD

## HUD — Survival UI Controller
## Attach to CanvasLayer in main game scene

@onready var health_bar = $VBoxLeft/HypeContainer/HypeBar
@onready var stamina_bar = $VBoxLeft/OverwhelmContainer/OverwhelmBar
@onready var score_label = $VBoxRight/LikesLabel
@onready var kills_label = $VBoxRight/KillsLabel
@onready var timer_label = $VBoxRight/TimerLabel

# Dynamically created labels (kept in code so the scene stays simple)
var wave_label: Label = null
var combo_label: Label = null
var objective_label: Label = null

func _ready() -> void:
	_build_extra_labels()
	print("[HUD] Ready")

func _build_extra_labels() -> void:
	# Wave label (top-center)
	wave_label = Label.new()
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.offset_left = -150.0
	wave_label.offset_right = 150.0
	wave_label.offset_top = 8.0
	wave_label.offset_bottom = 40.0
	wave_label.text = ""
	add_child(wave_label)
	
	# Combo label (below wave)
	combo_label = Label.new()
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 18)
	combo_label.anchor_left = 0.5
	combo_label.anchor_right = 0.5
	combo_label.offset_left = -150.0
	combo_label.offset_right = 150.0
	combo_label.offset_top = 44.0
	combo_label.offset_bottom = 70.0
	combo_label.modulate = Color(1, 0.85, 0.2)
	combo_label.text = ""
	add_child(combo_label)
	
	# Objective label (bottom-left)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.anchor_top = 1.0
	objective_label.anchor_bottom = 1.0
	objective_label.offset_left = 16.0
	objective_label.offset_top = -90.0
	objective_label.offset_right = 320.0
	objective_label.offset_bottom = -16.0
	objective_label.text = ""
	add_child(objective_label)

func update_timer(seconds: int) -> void:
	if timer_label:
		var mins = seconds / 60
		var secs = seconds % 60
		timer_label.text = "⏱ %02d:%02d" % [mins, secs]
		if seconds < 60:
			timer_label.modulate = Color(1, 0.3, 0.3)

func update_health(current: int, maximum: int) -> void:
	if health_bar:
		health_bar.max_value = float(maximum)
		health_bar.set_value(float(current), true)

func update_stamina(current: int, maximum: int) -> void:
	if stamina_bar:
		stamina_bar.max_value = float(maximum)
		stamina_bar.set_value(float(current), true)

func update_score(score: int) -> void:
	if score_label:
		score_label.text = "❤ %d" % score

func update_kills(kills: int) -> void:
	if kills_label:
		kills_label.text = "☠ %d" % kills

func update_wave(wave: int, total: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d / %d" % [wave, total]

func update_combo(combo: int, multiplier: float) -> void:
	if combo_label:
		if combo > 1:
			combo_label.text = "COMBO x%d  (%.1fx)" % [combo, multiplier]
		else:
			combo_label.text = ""

func update_objectives(texts: Array) -> void:
	if objective_label:
		objective_label.text = "\n".join(texts)
