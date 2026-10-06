## CharacterSelect.gd — Character Selection Screen (rebuilt, no card grid)
## One continuous stage: the five survivors stand on glowing pedestals IN the
## graveyard backdrop. Tapping a character on the stage selects it; the bottom
## bar mirrors the selection. The old per-card SubViewports swallowed taps and
## hid the cemetery behind five boxes — both are gone.
extends Control

const WOOD_TEX := preload("res://assets/textures/wood_planks.jpg")

const CHARACTER_SCENES: Array[String] = [
	"res://scenes/characters/character_gamer.tscn",
	"res://scenes/characters/character_doctor.tscn",
	"res://scenes/characters/character_nurse.tscn",
	"res://scenes/characters/character_streamer.tscn",
	"res://scenes/characters/character_hunter.tscn",
]
const CHARACTER_NAMES: Array[String] = ["GAMER", "DOCTOR", "NURSE", "STREAMER", "HUNTER"]
const CHARACTER_COLORS: Array[Color] = [
	Color(1.0, 0.32, 0.72),   # gamer — neon pink
	Color(0.25, 0.45, 1.0),   # doctor — neon blue
	Color(0.15, 0.95, 1.0),   # nurse — neon cyan
	Color(0.72, 0.38, 1.0),   # streamer — neon purple
	Color(0.95, 0.85, 0.25),  # hunter — neon yellow
]
const CHARACTER_DESCS: Array[String] = [
	"Speed and snacks on demand",
	"Tanky frame, medkits go further",
	"Fast healer, fragile",
	"Trades health for damage",
	"Ranged specialist, steady aim",
]

# Stage layout (world units, matches the shared backdrop camera framing).
const PEDESTAL_X: Array[float] = [-3.4, -1.7, 0.0, 1.7, 3.4]
const PEDESTAL_Z := -1.6
const PEDESTAL_TOP := 0.7
const MODEL_ORIGIN_Y := PEDESTAL_TOP + 0.06  # rigged models carry feet at local 0 -> disc top (0.76)
const BOB_AMPLITUDE := 0.03
const BOB_SPEED := 1.2
# Screen-space fraction of a pedestal's column on the shared camera: the stage
# is 10.92 world units wide at the pedestal depth, so frac = 0.5 + x / 10.92.
const STAGE_WORLD_WIDTH := 10.92

var selected_character: int = 1  # doctor default, matches the old screen
var _models: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _disc_mats: Array[StandardMaterial3D] = []
var _col_buttons: Array[Button] = []
var _zone_buttons: Array[Button] = []
var _play_btn: Button = null
var _hint_label: Label = null
var _name_label: Label
var _desc_label: Label
var _btn_font: Font = null
var _t := 0.0


func _dim_model_materials(vis: Node3D) -> void:
	# The survivor models import with KHR_materials_unlit: their albedo renders
	# at full brightness no matter the scene light, so white outfits (doctor,
	# nurse) read as featureless white against the dark graveyard. Dim a
	# per-instance material copy; the source scenes keep their own values.
	for mi in vis.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var src: Material = m.get_active_material(0)
		if src is StandardMaterial3D:
			var dim := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			dim.albedo_color = Color(dim.albedo_color.r * 0.78, dim.albedo_color.g * 0.78, dim.albedo_color.b * 0.84, dim.albedo_color.a)
			m.material_override = dim


func _soften_bloom() -> void:
	# The survivor models import unlit (full-bright albedo). The title screen's
	# bloom, tuned for the moon, blows the white outfits to featureless white.
	# Soften a per-instance copy here so the title keeps its look.
	var we := get_node_or_null("Background3D/WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment.duplicate() as Environment
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	we.environment = env


func _ready() -> void:
	_soften_bloom()
	var f := "res://assets/fonts/SpecialElite-Regular.ttf"
	if ResourceLoader.exists(f):
		_btn_font = load(f)
	_build_stage()
	_build_ui()
	_select_character(1, false)
	print("[CharacterSelect] zones=", _zone_buttons.size(), " cols=", _col_buttons.size(), " models=", _models.size())
	Audio.play_menu_music()


func _process(delta: float) -> void:
	_t += delta
	for i in range(_models.size()):
		var m := _models[i]
		if is_instance_valid(m):
			m.position.y = MODEL_ORIGIN_Y + sin(_t * BOB_SPEED + float(i) * 1.3) * BOB_AMPLITUDE
	if _play_btn != null and is_instance_valid(_play_btn):
		# The way forward should be the loudest thing on the screen.
		_play_btn.modulate = Color(1, 1, 1, 0.84 + 0.16 * (0.5 + 0.5 * sin(_t * 3.4)))


# ── STAGE (3D) ─────────────────────────────────────────────────

func _build_stage() -> void:
	var bg: Node3D = $Background3D
	for i in range(PEDESTAL_X.size()):
		var x: float = PEDESTAL_X[i]
		var col: Color = CHARACTER_COLORS[i]

		# Stone plinth
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.64
		cyl.bottom_radius = 0.74
		cyl.height = 0.5
		cyl.radial_segments = 14
		base.mesh = cyl
		base.position = Vector3(x, 0.45, PEDESTAL_Z)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.3, 0.29, 0.33)
		stone.roughness = 0.9
		base.material_override = stone
		bg.add_child(base)

		# Neon top disc
		var disc := MeshInstance3D.new()
		var dcyl := CylinderMesh.new()
		dcyl.top_radius = 0.62
		dcyl.bottom_radius = 0.62
		dcyl.height = 0.06
		dcyl.radial_segments = 14
		disc.mesh = dcyl
		disc.position = Vector3(x, PEDESTAL_TOP + 0.03, PEDESTAL_Z)
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = col.darkened(0.4)
		dmat.emission_enabled = true
		dmat.emission = col
		dmat.emission_energy_multiplier = 0.9
		disc.material_override = dmat
		bg.add_child(disc)
		_disc_mats.append(dmat)

		# Glow light (dims/brightens with selection)
		var light := OmniLight3D.new()
		light.position = Vector3(x, PEDESTAL_TOP + 0.5, PEDESTAL_Z + 0.3)
		light.light_color = col
		light.light_energy = 0.12
		light.omni_range = 4.5
		bg.add_child(light)
		_lights.append(light)

		# Contact shadow so the plinth sits in the scene instead of floating.
		var shadow := MeshInstance3D.new()
		var scyl := CylinderMesh.new()
		scyl.top_radius = 0.78
		scyl.bottom_radius = 0.78
		scyl.height = 0.01
		scyl.radial_segments = 18
		shadow.mesh = scyl
		shadow.position = Vector3(x, 0.212, PEDESTAL_Z)
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.02, 0.02, 0.025, 0.65)
		shadow.material_override = smat
		bg.add_child(shadow)

		# The survivor — display-only PlayerVisuals subtree, facing the camera.
		var scene: PackedScene = load(CHARACTER_SCENES[i]) as PackedScene
		if scene == null:
			push_warning("CharacterSelect: missing scene " + CHARACTER_SCENES[i])
			continue
		var full := scene.instantiate()
		var vis: Node3D = full.get_node_or_null("PlayerVisuals") as Node3D
		if vis == null:
			vis = full
		else:
			full.remove_child(vis)
			full.free()
		vis.position = Vector3(x, MODEL_ORIGIN_Y, PEDESTAL_Z)
		bg.add_child(vis)
		_dim_model_materials(vis)
		var cid := String(CHARACTER_SCENES[i]).get_file().trim_prefix("character_").trim_suffix(".tscn")
		var sap := CharacterAnim.setup(vis, cid)
		if sap != null:
			sap.play("idle")
		_models.append(vis)


# ── UI ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bar: MarginContainer = $UI/BottomBar
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	bar.add_child(vbox)

	# Character name buttons (also select, mirroring the stage zones)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	vbox.add_child(cols)
	for i in range(CHARACTER_NAMES.size()):
		var b := Button.new()
		b.text = CHARACTER_NAMES[i]
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, 22)
		var idx := i
		b.pressed.connect(func() -> void: _select_character(idx))
		cols.add_child(b)
		_col_buttons.append(b)

	# Action row: BACK | selected name + desc | PLAY
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	vbox.add_child(actions)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(150, 58)
	back.focus_mode = Control.FOCUS_NONE
	_style_button(back, 22)
	back.pressed.connect(_on_back_pressed)
	actions.add_child(back)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	actions.add_child(mid)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 26)
	mid.add_child(_name_label)
	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.68))
	mid.add_child(_desc_label)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 17)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	mid.add_child(_hint_label)

	var play := Button.new()
	play.text = "PLAY  \u25b6"  # right-pointing triangle: obvious way forward
	play.custom_minimum_size = Vector2(300, 92)
	play.focus_mode = Control.FOCUS_NONE
	var cta := StyleBoxFlat.new()
	cta.bg_color = Color(0.62, 0.08, 0.08)
	cta.set_border_width_all(3)
	cta.border_color = Color(1, 0.85, 0.8, 0.5)
	cta.set_corner_radius_all(18)
	play.add_theme_stylebox_override("normal", cta)
	var cta_hover := cta.duplicate() as StyleBoxFlat
	cta_hover.bg_color = Color(0.78, 0.12, 0.10)
	play.add_theme_stylebox_override("hover", cta_hover)
	play.add_theme_stylebox_override("pressed", cta_hover)
	play.add_theme_color_override("font_color", Color(1, 0.97, 0.93))
	play.add_theme_color_override("font_outline_color", Color(0.1, 0.01, 0.01, 0.9))
	play.add_theme_constant_override("outline_size", 5)
	play.add_theme_font_size_override("font_size", 34)
	if _btn_font != null:
		play.add_theme_font_override("font", _btn_font)
	play.pressed.connect(_on_play_pressed)
	actions.add_child(play)
	_play_btn = play

	# Step hint so the flow is never a dead end: what this screen is, and the
	# exact next move. The user tapped a character and saw no direction forward.
	var steps := Label.new()
	steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	steps.text = "1  Pick a survivor     2  PLAY     3  Choose a level"
	steps.add_theme_font_size_override("font_size", 18)
	steps.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78))
	steps.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.04, 0.95))
	steps.add_theme_constant_override("outline_size", 5)
	if _btn_font != null:
		steps.add_theme_font_override("font", _btn_font)
	vbox.add_child(steps)

	# Invisible tap zones over each pedestal: tapping the character itself
	# selects it. The old screen only responded on the tiny SELECT buttons —
	# this is the fix for "tapping a character does nothing".
	var zones: Control = $UI/StageZones
	for i in range(PEDESTAL_X.size()):
		var z := Button.new()
		var frac := 0.5 + PEDESTAL_X[i] / STAGE_WORLD_WIDTH
		z.anchor_left = frac - 0.075
		z.anchor_right = frac + 0.075
		z.anchor_top = 0.10
		z.anchor_bottom = 0.76
		z.flat = true
		z.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		z.add_theme_stylebox_override("normal", empty)
		z.add_theme_stylebox_override("hover", empty)
		z.add_theme_stylebox_override("pressed", empty)
		z.add_theme_stylebox_override("focus", empty)
		var idx2 := i
		z.pressed.connect(func() -> void: _select_character(idx2))
		zones.add_child(z)
		_zone_buttons.append(z)


func _style_button(b: Button, font_size: int) -> void:
	b.add_theme_stylebox_override("normal", _wood_style(Color(0.52, 0.4, 0.32)))
	b.add_theme_stylebox_override("hover", _wood_style(Color(0.66, 0.51, 0.4)))
	b.add_theme_stylebox_override("pressed", _wood_style(Color(0.4, 0.3, 0.25)))
	b.add_theme_stylebox_override("focus", _wood_style(Color(0.66, 0.51, 0.4)))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.93, 0.88, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.88))
	b.add_theme_color_override("font_pressed_color", Color(0.85, 0.8, 0.72))
	if _btn_font != null:
		b.add_theme_font_override("font", _btn_font)


func _wood_style(mod: Color) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = WOOD_TEX
	s.texture_margin_left = 14.0
	s.texture_margin_top = 14.0
	s.texture_margin_right = 14.0
	s.texture_margin_bottom = 14.0
	s.modulate_color = mod
	s.content_margin_left = 16.0
	s.content_margin_right = 16.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


# ── SELECTION ──────────────────────────────────────────────────

func _select_character(index: int, play_sound: bool = true) -> void:
	selected_character = index
	for i in range(_models.size()):
		var sel := (i == index)
		if i < _lights.size() and is_instance_valid(_lights[i]):
			_lights[i].light_energy = 1.1 if sel else 0.12
		if i < _disc_mats.size():
			_disc_mats[i].emission_energy_multiplier = 2.0 if sel else 0.9
		if i < _col_buttons.size() and is_instance_valid(_col_buttons[i]):
			_col_buttons[i].modulate = Color(1, 1, 1) if sel else Color(0.66, 0.66, 0.66)
	if _name_label != null:
		_name_label.text = CHARACTER_NAMES[index]
		_name_label.add_theme_color_override("font_color", CHARACTER_COLORS[index])
	if _desc_label != null:
		_desc_label.text = CHARACTER_DESCS[index]
	if _hint_label != null:
		# Explicit next move; tapping the survivor should never be a dead end.
		_hint_label.text = CHARACTER_NAMES[index] + " selected. Tap PLAY to continue"
	_confirm_selection(index, play_sound)


func _confirm_selection(index: int, play_sound: bool) -> void:
	if play_sound:
		Audio.play_click()
	print("[CharacterSelect] Selected: ", CHARACTER_NAMES[index])
	# Persist immediately — the member var alone is lost if the app dies before
	# the next gameplay save.
	Save.set_selected_character(CHARACTER_NAMES[index].to_lower())


func _on_play_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
