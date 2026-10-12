## CharacterSelect.gd — Character Selection Screen
## One continuous 3D stage: the five survivors stand on glowing pedestals in the graveyard.
## Tap zones projected from the real Camera3D allow direct stage tapping, mirrored
## by the bottom bar.
extends Control

const WOOD_TEX := preload("res://assets/textures/wood_planks.jpg")

const PEDESTAL_Z := -1.6
const PEDESTAL_TOP := 0.34
const MODEL_ORIGIN_Y := PEDESTAL_TOP + 0.02
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
var _btn_font_bold: Font = null
# UI scale: font sizes are authored for the 1600x900 design viewport; the game
# stretches that to the phone's real resolution, so scale text proportionally
# to the actual window height instead of shipping fixed pixel sizes.
const UI_DESIGN_HEIGHT := 900.0
var _ui_scale: float = 1.0


func _fs(px: float) -> int:
	return maxi(int(round(px * _ui_scale)), 8)


func _fit_label_font(label: Label, base_px: float, width_frac: float) -> void:
	# Shrink the font until the rendered text fits within width_frac of the
	# label's own width. Deterministic and aspect-proof: the stretched phone
	# viewport crops differently than the 1600x900 design area, so a fixed
	# size clips; measuring the real text width and stepping down cannot.
	var target_w: float = label.size.x * width_frac
	if target_w <= 0.0:
		label.add_theme_font_size_override("font_size", _fs(base_px))
		return
	var font := label.get_theme_font("font")
	var px := _fs(base_px)
	while px > 10:
		var line_w: float = font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if line_w <= target_w:
			break
		px -= 1
	label.add_theme_font_size_override("font_size", px)
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
	# Clean bold sans for the buttons + selected name (matches the modern UI).
	var bold_path := "res://assets/fonts/LilitaOne-Regular.ttf"
	if not ResourceLoader.exists(bold_path):
		bold_path = "res://assets/fonts/Poppins-Bold.ttf"
	if ResourceLoader.exists(bold_path):
		_btn_font_bold = load(bold_path)

	# Scale the .tscn-authored title/subtitle to the runtime viewport.
	call_deferred("_fit_title")

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


func _fit_title() -> void:
	# Deferred until after layout so label.size is valid. Scale the title to the
	# runtime viewport and shrink it to fit its width; scale the subtitle too.
	var title := get_node_or_null("UI/TitleLabel") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", _fs(46))
		_fit_label_font(title, 46, 0.94)
	var subtitle := get_node_or_null("UI/SubtitleLabel") as Label
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", _fs(20))


func _process(delta: float) -> void:
	_t += delta
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.modulate = Color(1.0, 1.0, 1.0, 0.84 + 0.16 * (0.5 + 0.5 * sin(_t * 3.4)))


func _soften_bloom() -> void:
	var we := get_node_or_null("Background3D/WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment.duplicate() as Environment
	env.glow_intensity = 0.65
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.95
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

		# Sleek beveled plinth (matches reference's low circular platform)
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.70
		cyl.bottom_radius = 0.74
		cyl.height = 0.14
		cyl.radial_segments = 24
		base.mesh = cyl
		base.position = Vector3(x, 0.20 + 0.07, PEDESTAL_Z)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.40, 0.42, 0.48)
		stone.roughness = 0.35
		stone.metallic = 0.35
		base.material_override = stone
		bg.add_child(base)

		# Inner subtle glow disc inside the neon ring
		var inner_disc := MeshInstance3D.new()
		var inner_cm := CylinderMesh.new()
		inner_cm.top_radius = 0.52
		inner_cm.bottom_radius = 0.52
		inner_cm.height = 0.005
		inner_cm.radial_segments = 24
		inner_disc.mesh = inner_cm
		inner_disc.position = Vector3(x, PEDESTAL_TOP + 0.008, PEDESTAL_Z)
		var inner_mat := StandardMaterial3D.new()
		inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.albedo_color = Color(col.r, col.g, col.b, 0.32)
		inner_disc.material_override = inner_mat
		bg.add_child(inner_disc)

		# Glowing neon ring on top of pedestal
		var disc := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.50
		torus.outer_radius = 0.62
		torus.rings = 32
		torus.ring_segments = 16
		disc.mesh = torus
		disc.position = Vector3(x, PEDESTAL_TOP + 0.012, PEDESTAL_Z)
		var dmat := StandardMaterial3D.new()
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dmat.albedo_color = col * 1.6
		dmat.emission_enabled = true
		dmat.emission = col
		dmat.emission_energy_multiplier = 1.8
		disc.material_override = dmat
		bg.add_child(disc)
		_disc_mats.append(dmat)

		# Glow light (low, tight range so it rims the pedestal + feet without
		# washing out a white coat from below)
		var light := OmniLight3D.new()
		light.position = Vector3(x, PEDESTAL_TOP + 0.10, PEDESTAL_Z + 0.20)
		light.light_color = col
		light.light_energy = 0.9
		light.omni_range = 3.2
		bg.add_child(light)
		_lights.append(light)

		# Contact shadow
		var shadow := MeshInstance3D.new()
		var scyl := CylinderMesh.new()
		scyl.top_radius = 0.82
		scyl.bottom_radius = 0.82
		scyl.height = 0.01
		scyl.radial_segments = 20
		shadow.mesh = scyl
		shadow.position = Vector3(x, 0.205, PEDESTAL_Z)
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.01, 0.01, 0.02, 0.45)
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

		# Per-character material tweak for the select screen only: the doctor's
		# coat reads pure-white/blown-out under the stage lights, so tint its
		# (already-duplicated) material off-white. Does not touch the shared rig.
		if s.id == "doctor":
			for mi in vis.find_children("*", "MeshInstance3D", true, false):
				var m := mi.get_active_material(0) as StandardMaterial3D
				if m != null:
					m.albedo_color = Color(0.82, 0.82, 0.84)

		_models.append(vis)


# ── UI SETUP ───────────────────────────────────────────────────

func _build_ui() -> void:
	var bar: MarginContainer = $UI/BottomBar
	bar.offset_top = -150.0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	bar.add_child(vbox)

	_build_name_buttons(vbox)
	_build_action_row(vbox)
	_build_tap_zones()


func _card_style(accent: Color, active: bool) -> StyleBoxFlat:
	# Semi-transparent dark rounded card; active gets a neon accent border that
	# matches the character's podium glow.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.72 if active else 0.5)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	if active:
		sb.border_color = accent
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(1, 1, 1, 0.10)
		sb.set_border_width_all(2)
	return sb


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
		_style_card(b, _survivors[i].color, false)
		var idx := i
		b.pressed.connect(func() -> void: _select_character(idx, true, true))
		cols.add_child(b)
		_col_buttons.append(b)


func _style_card(b: Button, accent: Color, active: bool) -> void:
	b.add_theme_stylebox_override("normal", _card_style(accent, active))
	b.add_theme_stylebox_override("hover", _card_style(accent, true))
	b.add_theme_stylebox_override("pressed", _card_style(accent, true))
	b.add_theme_stylebox_override("focus", _card_style(accent, active))
	b.add_theme_font_size_override("font_size", _fs(26))
	b.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.92, 0.96))
	if _btn_font_bold != null:
		b.add_theme_font_override("font", _btn_font_bold)


func _build_action_row(vbox: VBoxContainer) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)

	# BACK — subtle muted secondary pill, kept small to minimise clutter.
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120, 50)
	back.focus_mode = Control.FOCUS_NONE
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.1, 0.11, 0.14, 0.55)
	back_sb.set_corner_radius_all(25)
	back_sb.border_color = Color(1, 1, 1, 0.18)
	back_sb.set_border_width_all(2)
	back.add_theme_stylebox_override("normal", back_sb)
	var back_hover := back_sb.duplicate() as StyleBoxFlat
	back_hover.bg_color = Color(0.16, 0.17, 0.21, 0.7)
	back.add_theme_stylebox_override("hover", back_hover)
	back.add_theme_stylebox_override("pressed", back_hover)
	back.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	back.add_theme_font_size_override("font_size", _fs(22))
	if _btn_font_bold != null:
		back.add_theme_font_override("font", _btn_font_bold)
	back.pressed.connect(_on_back_pressed)
	actions.add_child(back)

	# Selected character name — big bold, coloured, between the two buttons.
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(mid)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", _fs(40))
	_name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 0.95))
	_name_label.add_theme_constant_override("outline_size", _fs(10))
	if _btn_font_bold != null:
		_name_label.add_theme_font_override("font", _btn_font_bold)
	mid.add_child(_name_label)

	# PLAY — prominent gradient pill (crimson -> bright), with press feedback.
	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(240, 62)
	play.focus_mode = Control.FOCUS_NONE
	var cta := StyleBoxFlat.new()
	cta.bg_color = Color(0.85, 0.12, 0.16)
	cta.set_corner_radius_all(31)
	cta.border_color = Color(1.0, 0.6, 0.6, 0.6)
	cta.set_border_width_all(2)
	play.add_theme_stylebox_override("normal", cta)
	var cta_hover := cta.duplicate() as StyleBoxFlat
	cta_hover.bg_color = Color(0.35, 0.85, 0.4)
	play.add_theme_stylebox_override("hover", cta_hover)
	var cta_pressed := cta.duplicate() as StyleBoxFlat
	cta_pressed.bg_color = Color(0.28, 0.7, 0.33)
	play.add_theme_stylebox_override("pressed", cta_pressed)
	play.add_theme_color_override("font_color", Color(1, 1, 1))
	play.add_theme_color_override("font_hover_color", Color(0.05, 0.1, 0.05))
	play.add_theme_color_override("font_outline_color", Color(0.1, 0.01, 0.01, 0.6))
	play.add_theme_constant_override("outline_size", 4)
	play.add_theme_font_size_override("font_size", _fs(32))
	if _btn_font_bold != null:
		play.add_theme_font_override("font", _btn_font_bold)
	play.pressed.connect(_on_play_pressed)
	actions.add_child(play)
	_play_btn = play


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


func _style_button(b: Button, font_size: int, bold: bool = false) -> void:
	b.add_theme_stylebox_override("normal", _wood_style(Color(0.52, 0.4, 0.32)))
	b.add_theme_stylebox_override("hover", _wood_style(Color(0.66, 0.51, 0.4)))
	b.add_theme_stylebox_override("pressed", _wood_style(Color(0.4, 0.3, 0.25)))
	b.add_theme_stylebox_override("focus", _wood_style(Color(0.66, 0.51, 0.4)))
	b.add_theme_font_size_override("font_size", _fs(font_size))
	b.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92))
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.86, 0.78))
	var f := _btn_font_bold if bold and _btn_font_bold != null else _btn_font
	if f != null:
		b.add_theme_font_override("font", f)


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
			_lights[i].light_energy = 1.8 if sel else 0.9
		if i < _disc_mats.size():
			var mult: float = 2.6 if sel else 1.5
			_disc_mats[i].albedo_color = _survivors[i].color * mult
			_disc_mats[i].emission_energy_multiplier = mult
		if i < _col_buttons.size() and is_instance_valid(_col_buttons[i]):
			_style_card(_col_buttons[i], _survivors[i].color, sel)

	if _name_label != null:
		_name_label.text = s.display_name
		_name_label.add_theme_color_override("font_color", s.color)
		_name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 0.95))
		_name_label.add_theme_constant_override("outline_size", _fs(10))

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
