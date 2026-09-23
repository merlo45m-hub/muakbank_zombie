extends Control
class_name HUD

## HUD — Survival UI Controller with Food Bar + Center Banner
## Attach to CanvasLayer in main game scene

@onready var health_bar = $VBoxLeft/HypeContainer/HypeBar
@onready var stamina_bar = $VBoxLeft/OverwhelmContainer/OverwhelmBar
@onready var score_label = $VBoxRight/LikesLabel
@onready var kills_label = $VBoxRight/KillsLabel
@onready var timer_label = $VBoxRight/TimerLabel
@onready var center_banner = $CenterBanner
@onready var banner_label = $CenterBanner/BannerLabel

# Food bar — 6 slots
@onready var food_bar = $FoodBar
var food_slots: Array = []
var food_types: Array = ["burger", "pizza", "soda", "fries", "sushi", "takis"]

# Dynamically created labels
var wave_label: Label = null
var combo_label: Label = null
var objective_label: Label = null

# Banner state
var banner_tween: Tween = null

func _ready() -> void:
	_build_extra_labels()
	_collect_food_slots()
	_connect_food_buttons()
	print("[HUD] Ready")

func _collect_food_slots() -> void:
	"""Collect food slot buttons for later state updates."""
	food_slots.clear()
	for child in food_bar.get_children():
		if child is TextureButton:
			food_slots.append(child)

func _connect_food_buttons() -> void:
	"""Wire up food bar button presses."""
	for i in range(food_slots.size()):
		var slot = food_slots[i]
		slot.pressed.connect(_on_food_slot_pressed.bind(i))

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

# ── FOOD BAR ───────────────────────────────────────────────────

func _on_food_slot_pressed(slot_index: int) -> void:
	"""Player pressed a food slot — consume that food."""
	if slot_index < 0 or slot_index >= food_types.size():
		return
	var food_name = food_types[slot_index]
	# Find food in player inventory and eat it
	var game = get_tree().get_first_node_in_group("game")
	if game and game.has_method("consume_food"):
		game.consume_food(food_name)
	Audio.play_eat()

func set_food_slot_count(slot_index: int, count: int) -> void:
	"""Update food slot display with count badge. count=0 means empty/dimmed."""
	if slot_index < 0 or slot_index >= food_slots.size():
		return
	var slot = food_slots[slot_index]
	if count > 0:
		slot.modulate = Color(1, 1, 1, 1)
	else:
		slot.modulate = Color(0.4, 0.4, 0.4, 0.6)

func pulse_food_slot(slot_index: int) -> void:
	"""Pulse animation on a food slot to draw attention."""
	if slot_index < 0 or slot_index >= food_slots.size():
		return
	var slot = food_slots[slot_index]
	var tween = create_tween()
	tween.tween_property(slot, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)

# ── CENTER BANNER ──────────────────────────────────────────────

func show_banner(message: String, duration: float = 2.0, color: Color = Color(0.9, 0.15, 0.1, 1.0)) -> void:
	"""Show a centered message banner with animated fade-in."""
	if not center_banner or not banner_label:
		return
	
	banner_label.text = message
	banner_label.add_theme_color_override("font_color", color)
	center_banner.visible = true
	center_banner.modulate = Color(1, 1, 1, 0)
	
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_property(center_banner, "modulate", Color(1, 1, 1, 1), 0.3)
	banner_tween.tween_interval(duration)
	banner_tween.tween_property(center_banner, "modulate", Color(1, 1, 1, 0), 0.3)
	banner_tween.tween_callback(func(): center_banner.visible = false)

func hide_banner() -> void:
	if center_banner:
		center_banner.visible = false

# ── HUD UPDATE METHODS (existing) ──────────────────────────────

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
