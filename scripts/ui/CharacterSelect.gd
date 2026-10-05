## CharacterSelect.gd — Character Selection Screen
## Horror theme: Nosifer headings, dark graveyard palette, blood-red accents

extends Control

# === THEME COLORS ===
const CARD_NORMAL_BG = Color(0.06, 0.03, 0.08, 1.0)
const CARD_SELECTED_BG = Color(0.14, 0.04, 0.1, 1.0)
const CARD_BORDER_DARK = Color(0.2, 0.1, 0.15, 1.0)
const PEDESTAL_NORMAL_BG = Color(0.1, 0.08, 0.12, 1.0)
const PEDESTAL_SELECTED_BG = Color(0.2, 0.04, 0.08, 1.0)
const BLOOD_RED = Color(0.6, 0.1, 0.15, 1.0)
const DESC_NORMAL = Color(0.5, 0.5, 0.5, 1.0)
const DESC_HIGHLIGHT = Color(0.75, 0.12, 0.08, 1.0)
const CARD_CORNER_RADIUS = 8
const PEDESTAL_CORNER_RADIUS = 999

# === PREVIEW RIG ===
# The preview must frame the display-only model without any gameplay nodes:
# camera dead ahead of the +Z-facing model, slightly above its mid point.
const PREVIEW_CAMERA_POS = Vector3(0, 0.8, 3.3)
const PREVIEW_CAMERA_TARGET = Vector3(0, 0.2, 0)
const PREVIEW_FOV = 45.0  # frames the full model with headroom (the ring-light hat is tall)
const TURNTABLE_SPEED = 0.45  # rad/s — slow spin so every card reads as "alive"

# === CHARACTER DATA ===
@export var character_scenes: Array = [
	"res://scenes/characters/character_gamer.tscn",
	"res://scenes/characters/character_doctor.tscn",
	"res://scenes/characters/character_nurse.tscn",
	"res://scenes/characters/character_streamer.tscn",
	"res://scenes/characters/character_hunter.tscn",
]

@export var character_names: Array = ["GAMER", "DOCTOR", "NURSE", "STREAMER", "HUNTER"]

# === STATE ===
var selected_character: int = 0
var preview_models: Array[Node3D] = []

# === NODE REFS ===
@onready var gamer_btn = $VBoxMain/CharactersContainer/GamerCard/CardLayout/GamerBtn
@onready var doctor_btn = $VBoxMain/CharactersContainer/DoctorCard/CardLayout/DoctorBtn
@onready var nurse_btn = $VBoxMain/CharactersContainer/NurseCard/CardLayout/NurseBtn
@onready var streamer_btn = $VBoxMain/CharactersContainer/StreamerCard/CardLayout/StreamerBtn
@onready var hunter_btn = $VBoxMain/CharactersContainer/HunterCard/CardLayout/HunterBtn
@onready var back_btn = $VBoxMain/BackBtn

@onready var gamer_viewport = $VBoxMain/CharactersContainer/GamerCard/CardLayout/GamerPreview/GamerViewport
@onready var doctor_viewport = $VBoxMain/CharactersContainer/DoctorCard/CardLayout/DoctorPreview/DoctorViewport
@onready var nurse_viewport = $VBoxMain/CharactersContainer/NurseCard/CardLayout/NursePreview/NurseViewport
@onready var streamer_viewport = $VBoxMain/CharactersContainer/StreamerCard/CardLayout/StreamerPreview/StreamerViewport
@onready var hunter_viewport = $VBoxMain/CharactersContainer/HunterCard/CardLayout/HunterPreview/HunterViewport

@onready var gamer_card = $VBoxMain/CharactersContainer/GamerCard
@onready var doctor_card = $VBoxMain/CharactersContainer/DoctorCard
@onready var nurse_card = $VBoxMain/CharactersContainer/NurseCard
@onready var streamer_card = $VBoxMain/CharactersContainer/StreamerCard
@onready var hunter_card = $VBoxMain/CharactersContainer/HunterCard

@onready var gamer_pedestal = $VBoxMain/CharactersContainer/GamerCard/CardLayout/GamerPedestal
@onready var doctor_pedestal = $VBoxMain/CharactersContainer/DoctorCard/CardLayout/DoctorPedestal
@onready var nurse_pedestal = $VBoxMain/CharactersContainer/NurseCard/CardLayout/NursePedestal
@onready var streamer_pedestal = $VBoxMain/CharactersContainer/StreamerCard/CardLayout/StreamerPedestal
@onready var hunter_pedestal = $VBoxMain/CharactersContainer/HunterCard/CardLayout/HunterPedestal

@onready var gamer_desc = $VBoxMain/CharactersContainer/GamerCard/CardLayout/GamerDesc
@onready var doctor_desc = $VBoxMain/CharactersContainer/DoctorCard/CardLayout/DoctorDesc
@onready var nurse_desc = $VBoxMain/CharactersContainer/NurseCard/CardLayout/NurseDesc
@onready var streamer_desc = $VBoxMain/CharactersContainer/StreamerCard/CardLayout/StreamerDesc
@onready var hunter_desc = $VBoxMain/CharactersContainer/HunterCard/CardLayout/HunterDesc

var card_panels: Array[Panel] = []
var pedestal_panels: Array[Panel] = []


func _ready() -> void:
	# Build card/pedestal reference arrays
	card_panels = [gamer_card, doctor_card, nurse_card, streamer_card, hunter_card]
	pedestal_panels = [gamer_pedestal, doctor_pedestal, nurse_pedestal, streamer_pedestal, hunter_pedestal]

	# Setup viewport previews with lighting
	_setup_viewports()

	# Default selection: doctor (player's saved default)
	_select_character(1, false)

	# Play menu music
	Audio.play_menu_music()


func _process(delta: float) -> void:
	# Turntable: a slow spin keeps each card's preview visibly alive.
	for model in preview_models:
		model.rotate_y(delta * TURNTABLE_SPEED)


func _setup_viewports() -> void:
	# Instantiate each character into its SubViewport for preview.
	# Use the PlayerVisuals subtree only — the full player scene carries a script,
	# physics, input and its own camera, none of which belong in a menu preview.
	var viewports = [gamer_viewport, doctor_viewport, nurse_viewport, streamer_viewport, hunter_viewport]
	var camera_names = ["GamerCamera", "DoctorCamera", "NurseCamera", "StreamerCamera", "HunterCamera"]

	for i in range(viewports.size()):
		# The turntable animates every frame; the default update mode only redraws
		# when the viewport believes something changed.
		viewports[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# Isolate the preview. By default a SubViewport SHARES the parent scene's
		# World3D: all five models would stack at the origin, sit inside the menu
		# background, and leak into the main view. Give each card its own world.
		# Create it explicitly — the engine does not materialize an own world on
		# the flag alone.
		viewports[i].world_3d = World3D.new()
		viewports[i].own_world_3d = true

		if i >= character_scenes.size():
			continue
		var scene: PackedScene = load(character_scenes[i]) as PackedScene
		if scene == null:
			push_warning("CharacterSelect: missing scene " + str(character_scenes[i]))
			continue

		var full = scene.instantiate()
		var vis: Node3D = full.get_node_or_null("PlayerVisuals") as Node3D
		if vis == null:
			# Fallback: an unusual character scene without PlayerVisuals —
			# ship the whole (still not-in-tree) instance rather than nothing.
			vis = full as Node3D
		else:
			full.remove_child(vis)
			full.free()

		vis.position = Vector3.ZERO
		viewports[i].add_child(vis)
		preview_models.append(vis)

		# Add ambient light so models are visible
		var world_env = WorldEnvironment.new()
		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.05, 0.035, 0.07, 1.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.4, 0.4, 0.5, 1.0)
		env.ambient_light_energy = 0.8
		world_env.environment = env
		viewports[i].add_child(world_env)

		# Key light: ambient alone flattens every shape into a silhouette.
		var key = DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-28, 40, 0)
		key.light_energy = 1.1
		key.shadow_enabled = false
		viewports[i].add_child(key)

		# Frame the model (the authored camera transform is not trustworthy).
		var cam: Camera3D = viewports[i].get_node_or_null(camera_names[i]) as Camera3D
		if cam != null:
			cam.look_at_from_position(PREVIEW_CAMERA_POS, PREVIEW_CAMERA_TARGET, Vector3.UP)
			cam.fov = PREVIEW_FOV


# ── SELECTION HANDLERS ─────────────────────────────────────────

func _on_gamer_selected() -> void:
	_select_character(0)

func _on_doctor_selected() -> void:
	_select_character(1)

func _on_nurse_selected() -> void:
	_select_character(2)

func _on_streamer_selected() -> void:
	_select_character(3)

func _on_hunter_selected() -> void:
	_select_character(4)

func _update_selection_visuals(index: int) -> void:
	# Update visual selection highlight
	for i in range(card_panels.size()):
		var is_selected = (i == index)
		var panel = card_panels[i]
		var pedestal = pedestal_panels[i]

		# Card background: darker when selected
		if is_selected:
			panel.set("theme_override_styles/panel", _get_selected_card_style())
			pedestal.set("theme_override_styles/panel", _get_selected_pedestal_style())
		else:
			panel.set("theme_override_styles/panel", _get_normal_card_style())
			pedestal.set("theme_override_styles/panel", _get_normal_pedestal_style())

	# Update description labels (emphasize selected)
	var desc_labels = [gamer_desc, doctor_desc, nurse_desc, streamer_desc, hunter_desc]
	var normal_color = DESC_NORMAL
	var highlight_color = DESC_HIGHLIGHT  # Blood red

	for i in range(desc_labels.size()):
		if i == index:
			desc_labels[i].set("theme_override_font_color", highlight_color)
		else:
			desc_labels[i].set("theme_override_font_color", normal_color)


func _confirm_selection(index: int, play_sound: bool) -> void:
	if play_sound:
		Audio.play_click()

	print("[CharacterSelect] Selected: ", character_names[index])

	# Persist immediately — the member var alone is lost if the app dies before the
	# next gameplay save.
	Save.set_selected_character(character_names[index].to_lower())


func _select_character(index: int, play_sound: bool = true) -> void:
	selected_character = index
	_update_selection_visuals(index)
	_confirm_selection(index, play_sound)

func _on_play_pressed() -> void:
	# This screen used to be a dead end — PLAY now routes to level selection.
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")


# === STYLE CREATION HELPERS ===

func make_style(bg_color: Color, border_color: Color = Color(0, 0, 0, 0), border_width: int = 0, corner_radius: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	if corner_radius > 0:
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
	return style

func _get_normal_card_style() -> StyleBoxFlat:
	return make_style(CARD_NORMAL_BG, CARD_BORDER_DARK, 2, CARD_CORNER_RADIUS)

func _get_selected_card_style() -> StyleBoxFlat:
	return make_style(CARD_SELECTED_BG, BLOOD_RED, 3, CARD_CORNER_RADIUS)

func _get_normal_pedestal_style() -> StyleBoxFlat:
	return make_style(PEDESTAL_NORMAL_BG, Color(0, 0, 0, 0), 0, PEDESTAL_CORNER_RADIUS)

func _get_selected_pedestal_style() -> StyleBoxFlat:
	return make_style(PEDESTAL_SELECTED_BG, BLOOD_RED, 0, PEDESTAL_CORNER_RADIUS)