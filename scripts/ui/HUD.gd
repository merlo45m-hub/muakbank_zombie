extends Control
class_name HUD

## HUD — Survival UI Controller with Food Bar + Center Banner
## Attach to CanvasLayer in main game scene

# Health bar & label — prominent indicator for player survival
@onready var health_bar: ProgressBar = $VBoxLeft/HealthContainer/HealthBar
@onready var health_label: Label = $VBoxLeft/HealthContainer/HealthLabel

# Secondary arcade meters (Hype / Overwhelm)
@onready var hype_bar = $VBoxLeft/HypeContainer/HypeBar
@onready var stamina_bar = $VBoxLeft/OverwhelmContainer/OverwhelmBar
@onready var score_label = $VBoxRight/LikesLabel
@onready var kills_label = $VBoxRight/KillsLabel
@onready var timer_label = $VBoxRight/TimerLabel
@onready var center_banner = $CenterBanner
@onready var banner_label = $CenterBanner/BannerLabel

# Health visual styling and hit feedback state
var _health_fill_style: StyleBoxFlat = null
var _last_health: int = -1

# Food bar — 6 slots
@onready var food_bar = $FoodBar
var food_slots: Array = []
var food_types: Array = ["burger", "pizza", "soda", "fries", "sushi", "takis"]
# Last rendered count per type, so an inventory change can tell a pickup (count went
# up -> pulse) from a consume (count went down -> just dim).
var _last_food_counts: Dictionary = {}

# Dynamically created labels
var wave_label: Label = null
var combo_label: Label = null
var objective_label: Label = null

# Wayfinding markers for the 3 mini-games
var waypoint_markers: Dictionary = {}
const WAYPOINT_POSITIONS: Dictionary = {
	"l1_spoil_and_survive": Vector3(-70, 0, 70),
	"l1_generator_fed":   Vector3(72, 0, 62),
	"l1_last_stand":      Vector3(78, 0, -62)
}  # Match scene instance transforms exactly so markers point to the right world positions

# Throttle waypoint updates to ~10Hz to avoid per-frame churn
var _waypoint_accumulator: float = 0.0
const WAYPOINT_UPDATE_INTERVAL: float = 0.1

# Banner state
var banner_tween: Tween = null

func _ready() -> void:
	_init_health_bar()
	_connect_player_signals()
	_build_extra_labels()
	_collect_food_slots()
	_connect_food_buttons()
	_connect_food_signals()
	print("[HUD] Ready")

# ── HEALTH BAR & SIGNALS ────────────────────────────────────────

func _init_health_bar() -> void:
	"""Set up dedicated stylebox for reactive health color transitions (green->yellow->red)."""
	if not health_bar:
		return
	var fill_sb = health_bar.get_theme_stylebox("fill")
	if fill_sb is StyleBoxFlat:
		_health_fill_style = fill_sb.duplicate() as StyleBoxFlat
	else:
		_health_fill_style = StyleBoxFlat.new()
		_health_fill_style.corner_radius_top_left = 4
		_health_fill_style.corner_radius_top_right = 4
		_health_fill_style.corner_radius_bottom_right = 4
		_health_fill_style.corner_radius_bottom_left = 4
	health_bar.add_theme_stylebox_override("fill", _health_fill_style)

func _connect_player_signals() -> void:
	"""Wire up player signals reactively as fallback or standalone init."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# Connect to player health_changed signal if not already connected by parent scene
	if player.has_signal("health_changed") and not player.health_changed.is_connected(update_health):
		player.health_changed.connect(update_health)
	# Connect damaged signal for immediate hit feedback flash
	if player.has_signal("damaged") and not player.damaged.is_connected(_on_player_damaged):
		player.damaged.connect(_on_player_damaged)
	# Seed initial values immediately if player already has state
	if "health" in player and "max_health" in player:
		update_health(player.health, player.max_health)

func _on_player_damaged(_amount: int) -> void:
	"""Player took damage — trigger immediate visual feedback."""
	_flash_health_bar()

func _flash_health_bar() -> void:
	"""Briefly flash the health bar to make damage immediately noticeable."""
	if not health_bar:
		return
	var tween = create_tween()
	tween.tween_property(health_bar, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.06)
	tween.tween_property(health_bar, "modulate", Color.WHITE, 0.12)

func _update_health_bar_visuals(current: int, maximum: int) -> void:
	"""Update health bar color (green -> yellow -> red) and label text/color."""
	var max_hp: float = float(max(1, maximum))
	var cur_hp: float = float(max(0, current))
	var pct: float = clampf(cur_hp / max_hp, 0.0, 1.0)

	# Smooth color progression from safe green through caution yellow to danger red
	var bar_color: Color
	if pct > 0.5:
		var t: float = (pct - 0.5) * 2.0
		bar_color = Color(1.0, 0.85, 0.2).lerp(Color(0.2, 0.85, 0.3), t)
	else:
		var t: float = pct * 2.0
		bar_color = Color(0.95, 0.15, 0.15).lerp(Color(1.0, 0.85, 0.2), t)

	if _health_fill_style:
		_health_fill_style.bg_color = bar_color

	if health_label:
		health_label.text = "HEALTH: %d / %d" % [max(0, current), maximum]
		health_label.add_theme_color_override("font_color", bar_color)


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

func _connect_food_signals() -> void:
	"""Connect to player food signals for reactive bar updates."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# Player.food_picked_up fires on BOTH pickup and consume (consume emits it after
	# decrementing), so this one connection covers the whole bar.
	# Deliberately NOT connecting Game.food_eaten: Game is the scene ROOT, so its
	# _ready() runs AFTER this node's, which means the "game" group is still empty
	# here and the lookup would silently return null — a dead connection that looks
	# live. The player signal is the one that actually works.
	player.food_picked_up.connect(_on_food_picked_up)
	_update_food_counts()

func _on_food_picked_up(food_type: String) -> void:
	"""Inventory changed — refresh the bar, pulse only when the count went UP."""
	var player = get_tree().get_first_node_in_group("player")
	var now: int = player.get_food_count(food_type) if player and player.has_method("get_food_count") else 0
	var slot_index: int = food_types.find(food_type)
	if slot_index >= 0 and now > int(_last_food_counts.get(food_type, 0)):
		pulse_food_slot(slot_index)
	_update_food_counts()

func _update_food_counts() -> void:
	"""Refresh every slot and remember the counts so the next event can compare."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	for i in range(food_types.size()):
		var food_type: String = food_types[i]
		# Ask the player for the count instead of re-deriving it here — a second
		# counting implementation is a second thing to keep in sync.
		var count: int = player.get_food_count(food_type) if player.has_method("get_food_count") else 0
		_last_food_counts[food_type] = count
		set_food_slot_count(i, count)

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

	# Waypoint markers (top-right, stacked vertically so they don't cover the joystick)
	_build_waypoint_markers()

func _build_waypoint_markers() -> void:
	"""Create a directional arrow + distance label for each mini-game.
	   Uses simple Control nodes (TextureRect with arrow glyph + Label) — lightweight and mobile-readable."""
	var start_y: float = 80.0
	var spacing: float = 48.0
	var idx: int = 0
	for obj_id in WAYPOINT_POSITIONS:
		# Container for this waypoint (arrow + distance)
		var container = HBoxContainer.new()
		container.anchor_right = 1.0
		container.anchor_top = 0.0
		container.offset_right = -16.0
		container.offset_top = start_y + idx * spacing
		container.offset_left = -160.0
		container.offset_bottom = start_y + idx * spacing + 36.0
		container.add_theme_constant_override("separation", 6)
		container.modulate = Color(1, 1, 1, 0.85)  # semi-transparent for readability
		add_child(container)

		# Arrow glyph using a Label with Unicode triangle — simple, no texture dependency
		var arrow = Label.new()
		arrow.text = "▶"  # right-pointing triangle; we'll rotate it via transform
		arrow.add_theme_font_size_override("font_size", 24)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.custom_minimum_size = Vector2(32, 32)
		arrow.modulate = Color(1, 0.9, 0.2)  # gold/yellow for visibility
		container.add_child(arrow)

		# Distance text
		var dist_label = Label.new()
		dist_label.add_theme_font_size_override("font_size", 16)
		dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dist_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dist_label.custom_minimum_size = Vector2(60, 28)
		dist_label.modulate = Color(1, 1, 1, 0.9)
		dist_label.text = "--m"
		container.add_child(dist_label)

		waypoint_markers[obj_id] = {
			"container": container,
			"arrow": arrow,
			"distance_label": dist_label,
			"target_pos": WAYPOINT_POSITIONS[obj_id]
		}
		idx += 1

# ── FOOD BAR ───────────────────────────────────────────────────

func _on_food_slot_pressed(slot_index: int) -> void:
	"""Player pressed a food slot — consume that food."""
	if slot_index < 0 or slot_index >= food_types.size():
		return
	var food_name = food_types[slot_index]
	# Find food in player inventory and eat it
	var game = get_tree().get_first_node_in_group("game")
	if game and game.has_method("consume_food"):
		var success = game.consume_food(food_name)
		if success:
			# Only play sound and show banner when eat actually happened
			Audio.play_eat()
			show_banner("Ate %s!" % food_name, 1.5, Color(0.2, 0.8, 0.2, 1.0))

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
		timer_label.text = "%02d:%02d" % [mins, secs]
		if seconds < 60:
			timer_label.modulate = Color(1, 0.3, 0.3)

func update_health(current: int, maximum: int) -> void:
	# Update dedicated health bar and prominent label
	if health_bar:
		health_bar.max_value = float(maximum)
		health_bar.value = float(current)
		_update_health_bar_visuals(current, maximum)

		# Trigger visual damage feedback if health decreased
		if _last_health != -1 and current < _last_health:
			_flash_health_bar()
		_last_health = current

	# Keep HypeBar synchronized alongside health so existing HUD mechanics remain intact
	if hype_bar and hype_bar.has_method("set_value"):
		hype_bar.max_value = float(maximum)
		hype_bar.set_value(float(current), true)

func update_hype(current: int, maximum: int) -> void:
	"""Update HypeBar specifically if driven by separate hype/audience mechanics."""
	if hype_bar and hype_bar.has_method("set_value"):
		hype_bar.max_value = float(maximum)
		hype_bar.set_value(float(current), true)

func update_stamina(current: int, maximum: int) -> void:
	if stamina_bar:
		stamina_bar.max_value = float(maximum)
		stamina_bar.set_value(float(current), true)

func update_score(score: int) -> void:
	if score_label:
		score_label.text = "SCORE %d" % score

func update_kills(kills: int) -> void:
	if kills_label:
		kills_label.text = "KILLS %d" % kills

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

func _process(delta: float) -> void:
	_waypoint_accumulator += delta
	if _waypoint_accumulator < WAYPOINT_UPDATE_INTERVAL:
		return
	_waypoint_accumulator = 0.0
	_update_waypoint_markers()

func _update_waypoint_markers() -> void:
	"""Update arrow rotation and distance for each active waypoint. Throttled to ~10Hz."""
	# Get player node (in "player" group) for "from" position — null-safe
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("get_global_position"):
		return
	var player_pos: Vector3 = player.global_position

	# Get ObjectiveManager autoload to check completion status — null-safe
	var obj_mgr = get_node_or_null("/root/ObjectiveManager")

	# Camera yaw for screen-space direction (project world dir onto camera horizontal plane)
	var camera = get_viewport().get_camera_3d()
	var cam_yaw: float = 0.0
	if camera:
		cam_yaw = camera.global_transform.basis.get_euler().y

	for obj_id in waypoint_markers:
		var marker = waypoint_markers[obj_id]
		var container: Control = marker["container"]
		var arrow: Label = marker["arrow"]
		var dist_label: Label = marker["distance_label"]
		var target_pos: Vector3 = marker["target_pos"]

		# Hide if objective completed (null-safe ObjectiveManager check)
		var completed: bool = false
		if obj_mgr and obj_mgr.has_method("is_objective_completed"):
			completed = obj_mgr.is_objective_completed(obj_id)
		container.visible = not completed
		if completed:
			continue

		# World direction from player to target (ignore Y for horizontal navigation)
		var to_target = target_pos - player_pos
		to_target.y = 0.0
		var distance: float = to_target.length()
		if distance < 0.1:
			continue

		# Angle between camera forward and target direction (screen-space rotation)
		var target_angle: float = atan2(to_target.x, to_target.z)
		var relative_angle: float = target_angle - cam_yaw
		# Rotate arrow label (Label doesn't have rotation, so use a TextureRect approach or rotate container)
		# Simpler: rotate the arrow Label via transform
		arrow.rotation = relative_angle

		# Update distance text
		dist_label.text = "%dm" % int(distance)
