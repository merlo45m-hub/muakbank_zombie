## CharacterSelect.gd — Character Selection Screen
## One continuous 3D stage: the five survivors stand on glowing pedestals in the graveyard.
## Tap zones projected from the real Camera3D allow direct stage tapping, mirrored
## by the bottom bar.
extends Control

const WOOD_TEX := preload("res://assets/textures/wood_planks.jpg")

const PEDESTAL_Z := -1.6
const PEDESTAL_TOP := 0.7
const MODEL_ORIGIN_Y := PEDESTAL_TOP + 0.06
const SURVIVOR_HEIGHT := 1.8

class Survivor extends RefCounted:
	var id: String
	var display_name: String
	var description: String
	var color: Color
	var scene_path: String
	var pedestal_x: float

const SURVIVOR_CONFIGS: Array[Dictionary] = [
	{"id": "gamer", "name": "GAMER", "x": -3.4, "scene": "res://scenes/characters/character_gamer.tscn"},
	{"id": "doctor", "name": "DOCTOR", "x": -1.7, "scene": "res://scenes/characters/character_doctor.tscn"},
	{"id": "nurse", "name": "NURSE", "x": 0.0, "scene": "res://scenes/characters/character_nurse.tscn"},
	{"id": "streamer", "name": "STREAMER", "x": 1.7, "scene": "res://scenes/characters/character_streamer.tscn"},
	{"id": "hunter", "name": "HUNTER", "x": 3.4, "scene": "res://scenes/characters/character_hunter.tscn"},
]

var selected_character: int = 1
var _survivors: Array[Survivor] = []
var _models: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _disc_mats: Array[StandardMaterial3D] = []
var _col_buttons: Array[Button] = []
var _zone_buttons: Array[Button] = []
var _play_btn: Button = null
var _hint_label: Label = null
var _name_label: Label = null
var _desc_label: Label = null
var _btn_font: Font = null
# UI scale: font sizes are authored for the 1600x900 design viewport; the game
# stretches that to the phone's real resolution, so scale text proportionally
# to the actual window height instead of shipping fixed pixel sizes.
const UI_DESIGN_HEIGHT := 900.0
var _ui_scale: float = 1.0


func _fs(px: float) -> int:
	return maxi(int(round(px * _ui_scale)), 8)
var _t := 0.0


func _init() -> void:
	_init_survivors()


func _init_survivors() -> void:
	_survivors.clear()
	for cfg in SURVIVOR_CONFIGS:
		var s := Survivor.new()
		s.id = cfg["id"]
		s.display_name = cfg["name"]
		s.pedestal_x = cfg["x"]
		s.scene_path = cfg["scene"]
		s.description = ""
		s.color = Color.WHITE

		# Single source of truth: read description and color from stats_*.tres
		var stats_path := "res://assets/materials/stats_%s.tres" % s.id
		if ResourceLoader.exists(stats_path):
			var res := load(stats_path) as CharacterStats
			if res != null:
				if not res.display_name.is_empty():
					s.display_name = res.display_name.to_upper()
				s.description = res.description
				s.color = res.character_color
		_survivors.append(s)


func _ready() -> void:
	_ui_scale = get_viewport().get_visible_rect().size.y / UI_DESIGN_HEIGHT
	_soften_bloom()
	var font_path := "res://assets/fonts/SpecialElite-Regular.ttf"
	if ResourceLoader.exists(font_path):
		_btn_font = load(font_path)

	# Scale the .tscn-authored title/subtitle labels to match the runtime scale
	# so they stay proportional on the stretched phone viewport.
	var title := get_node_or_null("UI/TitleLabel") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", _fs(52))
	var subtitle := get_node_or_null("UI/SubtitleLabel") as Label
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", _fs(22))

	_build_stage()
	_build_ui()

	# Restore saved character selection without overwriting it on disk
	var saved_id := ""
	if has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		if save_mgr.get("selected_character") != null:
			saved_id = String(save_mgr.get("selected_character")).to_lower()

	var initial_index := 1
	for i in range(_survivors.size()):
		if _survivors[i].id == saved_id:
			initial_index = i
			break

	_select_character(initial_index, false, false)

	resized.connect(_update_tap_zones)
	get_tree().root.size_changed.connect(_update_tap_zones)
	_update_tap_zones.call_deferred()

	Audio.play_menu_music()


func _process(delta: float) -> void:
	_t += delta
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.modulate = Color(1.0, 1.0, 1.0, 0.84 + 0.16 * (0.5 + 0.5 * sin(_t * 3.4)))


func _soften_bloom() -> void:
	var we := get_node_or_null("Background3D/WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment.duplicate() as Environment
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	we.environment = env


# ── STAGE SETUP ────────────────────────────────────────────────

func _build_stage() -> void:
	var bg: Node3D = $Background3D
	_build_pedestals(bg)
	_build_ring_light(bg)
	_spawn_survivors(bg)


func _build_pedestals(bg: Node3D) -> void:
	for i in range(_survivors.size()):
		var s := _survivors[i]
		var x: float = s.pedestal_x
		var col: Color = s.color

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
		stone.albedo_color = Color(0.22, 0.22, 0.25)
		stone.roughness = 0.95
		base.material_override = stone
		bg.add_child(base)

		# Neon ring on top of pedestal
		var disc := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.50
		torus.outer_radius = 0.60
		torus.rings = 32
		torus.ring_segments = 16
		disc.mesh = torus
		disc.position = Vector3(x, PEDESTAL_TOP + 0.02, PEDESTAL_Z)
		var dmat := StandardMaterial3D.new()
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dmat.albedo_color = col * 1.3
		dmat.emission_enabled = true
		dmat.emission = col
		dmat.emission_energy_multiplier = 1.3
		disc.material_override = dmat
		bg.add_child(disc)
		_disc_mats.append(dmat)

		# Glow light (positioned low and slightly forward for dramatic under-light)
		var light := OmniLight3D.new()
		light.position = Vector3(x, PEDESTAL_TOP + 0.25, PEDESTAL_Z + 0.22)
		light.light_color = col
		light.light_energy = 1.4
		light.omni_range = 7.0
		bg.add_child(light)
		_lights.append(light)

		# Contact shadow
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


func _build_ring_light(bg: Node3D) -> void:
	# Stage prop on the streamer's pedestal
	var ring_root := Node3D.new()
	ring_root.name = "StageRingLight"
	ring_root.position = Vector3(1.7 + 0.42, PEDESTAL_TOP, PEDESTAL_Z + 0.2)

	var stand := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.018
	pole.height = 1.45
	stand.mesh = pole
	stand.position = Vector3(0.0, 0.725, 0.0)
	var stand_mat := StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.12, 0.12, 0.14)
	stand_mat.roughness = 0.6
	stand_mat.metallic = 0.8
	stand.material_override = stand_mat
	ring_root.add_child(stand)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.19
	ring.mesh = torus
	ring.position = Vector3(0.0, 1.45, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.98, 0.92)
	ring.material_override = ring_mat
	ring_root.add_child(ring)

	bg.add_child(ring_root)


func _spawn_survivors(bg: Node3D) -> void:
	for i in range(_survivors.size()):
		var s := _survivors[i]
		var scene := load(s.scene_path) as PackedScene
		if scene == null:
			push_warning("CharacterSelect: missing scene " + s.scene_path)
			continue
		var full := scene.instantiate()
		var vis := full.get_node_or_null("PlayerVisuals") as Node3D
		if vis == null:
			vis = full
		else:
			full.remove_child(vis)
			full.free()

		vis.position = Vector3(s.pedestal_x, MODEL_ORIGIN_Y, PEDESTAL_Z)
		bg.add_child(vis)

		var sap := BlockyAnim.setup(vis, s.id)
		if sap != null:
			sap.play("idle")

		_models.append(vis)


# ── UI SETUP ───────────────────────────────────────────────────

func _build_ui() -> void:
	var bar: MarginContainer = $UI/BottomBar
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	bar.add_child(vbox)

	_build_name_buttons(vbox)
	_build_action_row(vbox)
	_build_step_hints(vbox)
	_build_tap_zones()


func _build_name_buttons(vbox: VBoxContainer) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	vbox.add_child(cols)

	for i in range(_survivors.size()):
		var b := Button.new()
		b.text = _survivors[i].display_name
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, 22)
		var idx := i
		b.pressed.connect(func() -> void: _select_character(idx, true, true))
		cols.add_child(b)
		_col_buttons.append(b)


func _build_action_row(vbox: VBoxContainer) -> void:
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
	_name_label.add_theme_font_size_override("font_size", _fs(26))
	mid.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", _fs(15))
	_desc_label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.68))
	mid.add_child(_desc_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", _fs(17))
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	mid.add_child(_hint_label)

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(300, 92)
	play.focus_mode = Control.FOCUS_NONE
	var cta := StyleBoxFlat.new()
	cta.bg_color = Color(0.62, 0.08, 0.08)
	cta.set_border_width_all(3)
	cta.border_color = Color(1.0, 0.85, 0.8, 0.5)
	cta.set_corner_radius_all(18)
	play.add_theme_stylebox_override("normal", cta)
	var cta_hover := cta.duplicate() as StyleBoxFlat
	cta_hover.bg_color = Color(0.78, 0.12, 0.10)
	play.add_theme_stylebox_override("hover", cta_hover)
	play.add_theme_stylebox_override("pressed", cta_hover)
	play.add_theme_color_override("font_color", Color(1.0, 0.97, 0.93))
	play.add_theme_color_override("font_outline_color", Color(0.1, 0.01, 0.01, 0.9))
	play.add_theme_constant_override("outline_size", 5)
	play.add_theme_font_size_override("font_size", _fs(34))
	if _btn_font != null:
		play.add_theme_font_override("font", _btn_font)
	play.pressed.connect(_on_play_pressed)
	actions.add_child(play)
	_play_btn = play


func _build_step_hints(vbox: VBoxContainer) -> void:
	var steps := Label.new()
	steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	steps.text = "1  Pick a survivor     2  PLAY     3  Choose a level"
	steps.add_theme_font_size_override("font_size", _fs(18))
	steps.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78))
	steps.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.04, 0.95))
	steps.add_theme_constant_override("outline_size", 5)
	if _btn_font != null:
		steps.add_theme_font_override("font", _btn_font)
	vbox.add_child(steps)


func _build_tap_zones() -> void:
	var zones: Control = $UI/StageZones
	for i in range(_survivors.size()):
		var z := Button.new()
		z.flat = true
		z.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		z.add_theme_stylebox_override("normal", empty)
		z.add_theme_stylebox_override("hover", empty)
		z.add_theme_stylebox_override("pressed", empty)
		z.add_theme_stylebox_override("focus", empty)
		var idx := i
		z.pressed.connect(func() -> void: _select_character(idx, true, true))
		zones.add_child(z)
		_zone_buttons.append(z)


func _update_tap_zones() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		cam = get_node_or_null("Background3D/Camera3D") as Camera3D
	if cam == null:
		return

	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	for i in range(_zone_buttons.size()):
		if i >= _survivors.size():
			break
		var z := _zone_buttons[i]
		var x: float = _survivors[i].pedestal_x
		var feet_pos := Vector3(x, MODEL_ORIGIN_Y, PEDESTAL_Z)
		var head_pos := Vector3(x, MODEL_ORIGIN_Y + SURVIVOR_HEIGHT, PEDESTAL_Z)

		var screen_feet := cam.unproject_position(feet_pos)
		var screen_head := cam.unproject_position(head_pos)

		var char_h := absf(screen_feet.y - screen_head.y)
		var half_w := maxf(char_h * 0.35, 44.0)

		var min_x := screen_feet.x - half_w
		var max_x := screen_feet.x + half_w
		var min_y := screen_head.y - char_h * 0.1
		var max_y := screen_feet.y + char_h * 0.1

		z.anchor_left = clampf(min_x / vp_size.x, 0.0, 1.0)
		z.anchor_right = clampf(max_x / vp_size.x, 0.0, 1.0)
		z.anchor_top = clampf(min_y / vp_size.y, 0.0, 1.0)
		z.anchor_bottom = clampf(max_y / vp_size.y, 0.0, 1.0)
		z.offset_left = 0
		z.offset_right = 0
		z.offset_top = 0
		z.offset_bottom = 0


func _style_button(b: Button, font_size: int) -> void:
	b.add_theme_stylebox_override("normal", _wood_style(Color(0.52, 0.4, 0.32)))
	b.add_theme_stylebox_override("hover", _wood_style(Color(0.66, 0.51, 0.4)))
	b.add_theme_stylebox_override("pressed", _wood_style(Color(0.4, 0.3, 0.25)))
	b.add_theme_stylebox_override("focus", _wood_style(Color(0.66, 0.51, 0.4)))
	b.add_theme_font_size_override("font_size", _fs(font_size))
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

func _select_character(index: int, play_sound: bool = true, persist: bool = true) -> void:
	selected_character = index
	var s: Survivor = _survivors[index]

	for i in range(_models.size()):
		var sel := (i == index)
		if i < _lights.size() and is_instance_valid(_lights[i]):
			_lights[i].light_energy = 2.8 if sel else 1.4
		if i < _disc_mats.size():
			var mult: float = 2.4 if sel else 1.3
			_disc_mats[i].albedo_color = _survivors[i].color * mult
			_disc_mats[i].emission_energy_multiplier = mult
		if i < _col_buttons.size() and is_instance_valid(_col_buttons[i]):
			_col_buttons[i].modulate = Color.WHITE if sel else Color(0.66, 0.66, 0.66)

	if _name_label != null:
		_name_label.text = s.display_name
		_name_label.add_theme_color_override("font_color", s.color)
	if _desc_label != null:
		_desc_label.text = s.description
	if _hint_label != null:
		_hint_label.text = s.display_name + " selected. Tap PLAY to continue"

	if play_sound:
		Audio.play_click()

	if persist and has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		save_mgr.set_selected_character(s.id)


func _on_play_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
