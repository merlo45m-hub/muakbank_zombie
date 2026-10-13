## CharacterSelect.gd — Character Selection Screen
## Single hero 3D stage: one centered survivor on glowing pedestal in the graveyard.
## Direct 3D raycast / tap, touch swipe left/right, on-screen ◀ ▶ arrows, keyboard navigation,
## skin variant selector, dynamic pedestal neon lighting, and high-detail hero camera framing.
extends Control

const WOOD_TEX := preload("res://assets/textures/wood_planks.jpg")

const PEDESTAL_Z := -1.6
const PEDESTAL_TOP := 0.44
const MODEL_ORIGIN_Y := PEDESTAL_TOP + 0.01
const SURVIVOR_HEIGHT := 1.75

class Survivor extends RefCounted:
	var id: String
	var display_name: String
	var description: String
	var color: Color
	var scene_path: String
	var mini_model_path: String
	var pedestal_x: float = 0.0

const SURVIVOR_CONFIGS: Array[Dictionary] = [
	{"id": "gamer", "name": "GAMER", "scene": "res://scenes/characters/character_gamer.tscn"},
	{"id": "doctor", "name": "DOCTOR", "scene": "res://scenes/characters/character_doctor.tscn"},
	{"id": "nurse", "name": "NURSE", "scene": "res://scenes/characters/character_nurse.tscn"},
	{"id": "streamer", "name": "STREAMER", "scene": "res://scenes/characters/character_streamer.tscn"},
	{"id": "hunter", "name": "HUNTER", "scene": "res://scenes/characters/character_hunter.tscn"},
]

const PEDESTAL_COLORS: Dictionary = {
	"gamer": Color(1.0, 0.08, 0.60),      # Magenta
	"doctor": Color(0.08, 0.85, 1.0),     # Cyan
	"nurse": Color(0.18, 0.96, 0.65),     # Mint Green
	"streamer": Color(0.76, 0.22, 1.0),   # Violet
	"hunter": Color(1.0, 0.82, 0.18),     # Warm Gold
}

var selected_character: int = 2
var _survivors: Array[Survivor] = []
var _models: Array[Node3D] = []
var _anim_players: Array[AnimationPlayer] = []

# Single pedestal stage references
var _pedestal_light: OmniLight3D = null
var _pedestal_neon_mat: StandardMaterial3D = null
var _pedestal_inner_mat: StandardMaterial3D = null
var _pedestal_area: Area3D = null

# UI references
var _play_btn: Button = null
var _name_label: Label = null
var _desc_label: Label = null
var _pips_container: HBoxContainer = null
var _pip_labels: Array[Label] = []
var _stage_tap_btn: Button = null
var _btn_font: Font = null
var _btn_font_bold: Font = null

# On-screen floating cycle arrows
var _char_prev_btn: Button = null
var _char_next_btn: Button = null

# Skin variant selector
var _skin_buttons: Array[Button] = []
var _skin_prev_btn: Button = null
var _skin_next_btn: Button = null

# Camera tween state
var _cam_tween: Tween = null
var _is_camera_tweening: bool = false

# Touch / gesture state
var _touch_start := Vector2.ZERO
var _is_swiping := false

# Procedural audio chime player
var _chime_player: AudioStreamPlayer = null

# UI scale
const UI_DESIGN_HEIGHT := 900.0
var _ui_scale: float = 1.0
var _t := 0.0


func _fs(px: float) -> int:
	return maxi(int(round(px * _ui_scale)), 8)


func _fit_label_font(label: Label, base_px: float, width_frac: float) -> void:
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


func _init() -> void:
	_init_survivors()


func _init_survivors() -> void:
	_survivors.clear()
	for cfg in SURVIVOR_CONFIGS:
		var s := Survivor.new()
		s.id = cfg["id"]
		s.display_name = cfg["name"]
		s.pedestal_x = 0.0
		s.scene_path = cfg["scene"]
		s.mini_model_path = cfg.get("mini", "")
		s.description = ""
		s.color = PEDESTAL_COLORS.get(s.id, Color.WHITE)

		var stats_path := "res://assets/materials/stats_%s.tres" % s.id
		if ResourceLoader.exists(stats_path):
			var res := load(stats_path) as CharacterStats
			if res != null:
				if not res.display_name.is_empty():
					s.display_name = res.display_name.to_upper()
				s.description = res.description
		_survivors.append(s)


func _ready() -> void:
	_ui_scale = get_viewport().get_visible_rect().size.y / UI_DESIGN_HEIGHT
	_soften_bloom()
	var font_path := "res://assets/fonts/SpecialElite-Regular.ttf"
	if ResourceLoader.exists(font_path):
		_btn_font = load(font_path)
	var bold_path := "res://assets/fonts/LilitaOne-Regular.ttf"
	if not ResourceLoader.exists(bold_path):
		bold_path = "res://assets/fonts/Poppins-Bold.ttf"
	if ResourceLoader.exists(bold_path):
		_btn_font_bold = load(bold_path)

	call_deferred("_fit_title")

	_build_stage()
	_build_ui()

	# Snap camera immediately to hero position
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = get_node_or_null("Background3D/Camera") as Camera3D
	if cam != null:
		cam.fov = 74.0
		var initial_pos := Vector3(0.0, 1.25, 1.10)
		var initial_look := Vector3(0.0, 1.12, -1.60)
		cam.global_position = initial_pos
		cam.look_at(initial_look, Vector3.UP)

	# Default state: central character (Nurse, index 2) selected on load, or restore saved choice
	var initial_index := 2
	if OS.has_environment("DIAG_SURVIVOR"):
		initial_index = int(OS.get_environment("DIAG_SURVIVOR"))
	elif has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		var saved_id: String = String(save_mgr.get("selected_character"))
		for i in range(_survivors.size()):
			if _survivors[i].id == saved_id:
				initial_index = i
				break
	_select_character(initial_index, false, false)

	if OS.has_environment("DIAG_SKIN"):
		var diag_skin := int(OS.get_environment("DIAG_SKIN"))
		_select_skin(diag_skin, false, false)

	resized.connect(_update_tap_zones)
	get_tree().root.size_changed.connect(_update_tap_zones)
	_update_tap_zones.call_deferred()

	Audio.play_menu_music()


func _fit_title() -> void:
	var title := get_node_or_null("UI/TitleLabel") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", _fs(44))
		_fit_label_font(title, 44, 0.94)
	var subtitle := get_node_or_null("UI/SubtitleLabel") as Label
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", _fs(18))


func _process(delta: float) -> void:
	_t += delta
	if _play_btn != null and is_instance_valid(_play_btn) and not _is_camera_tweening:
		_play_btn.modulate = Color(1.0, 1.0, 1.0, 0.86 + 0.14 * (0.5 + 0.5 * sin(_t * 3.4)))


func _soften_bloom() -> void:
	var we := get_node_or_null("Background3D/WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment.duplicate() as Environment
	env.glow_intensity = 0.65
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.95
	we.environment = env


# ── INPUT HANDLING ─────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Secondary nav: A/D or Left/Right arrow keys cycle survivors
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_cycle_selection(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_cycle_selection(1)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			_cycle_skin(1)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_cycle_skin(-1)
			get_viewport().set_input_as_handled()
			return

	# Secondary nav: touch swipe left/right
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_is_swiping = true
		else:
			if _is_swiping:
				var delta_x: float = event.position.x - _touch_start.x
				var delta_y: float = absf(event.position.y - _touch_start.y)
				if absf(delta_x) > 65.0 and absf(delta_x) > delta_y * 1.4:
					if delta_x < 0.0:
						_cycle_selection(1)
					else:
						_cycle_selection(-1)
					get_viewport().set_input_as_handled()
				else:
					_handle_3d_tap(event.position)
				_is_swiping = false
		return

	# 3D raycast direct click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_3d_tap(event.position)


func _cycle_selection(delta: int) -> void:
	var next_idx := posmod(selected_character + delta, _survivors.size())
	_select_character(next_idx, true, true)


func _handle_3d_tap(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = get_node_or_null("Background3D/Camera") as Camera3D
	if cam == null:
		return

	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 60.0
	var space := get_viewport().find_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var result := space.intersect_ray(query)

	if result.has("collider"):
		var col: Object = result["collider"]
		if col == _pedestal_area:
			_cycle_selection(1)
			get_viewport().set_input_as_handled()
			return


# ── STAGE SETUP ────────────────────────────────────────────────

func _build_stage() -> void:
	var bg: Node3D = $Background3D
	_build_pedestals(bg)
	_spawn_survivors(bg)


func _build_pedestals(bg: Node3D) -> void:
	var ped_root := Node3D.new()
	ped_root.name = "Pedestal_Stage"
	bg.add_child(ped_root)

	# Tier 1: Base Plinth (Bottom Bevel, 48 segments for smooth circular curvature)
	var base := MeshInstance3D.new()
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 0.82
	base_cyl.bottom_radius = 0.90
	base_cyl.height = 0.12
	base_cyl.radial_segments = 48
	base.mesh = base_cyl
	base.position = Vector3(0.0, 0.20 + 0.06, PEDESTAL_Z)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.14, 0.15, 0.18)
	base_mat.roughness = 0.35
	base_mat.metallic = 0.45
	base.material_override = base_mat
	ped_root.add_child(base)

	# Tier 2: Bevel Collar (Recessed middle step)
	var collar := MeshInstance3D.new()
	var col_cyl := CylinderMesh.new()
	col_cyl.top_radius = 0.72
	col_cyl.bottom_radius = 0.80
	col_cyl.height = 0.08
	col_cyl.radial_segments = 48
	collar.mesh = col_cyl
	collar.position = Vector3(0.0, 0.20 + 0.12 + 0.04, PEDESTAL_Z)
	var collar_mat := StandardMaterial3D.new()
	collar_mat.albedo_color = Color(0.18, 0.20, 0.24)
	collar_mat.roughness = 0.30
	collar_mat.metallic = 0.35
	collar.material_override = collar_mat
	ped_root.add_child(collar)

	# Tier 3: Top Standing Platform (Charcoal matte platform, top at Y = 0.44)
	var top_disc := MeshInstance3D.new()
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = 0.62
	top_cyl.bottom_radius = 0.65
	top_cyl.height = 0.04
	top_cyl.radial_segments = 48
	top_disc.mesh = top_cyl
	top_disc.position = Vector3(0.0, 0.20 + 0.12 + 0.08 + 0.02, PEDESTAL_Z)
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.10, 0.11, 0.14)
	top_mat.roughness = 0.55
	top_mat.metallic = 0.15
	top_disc.material_override = top_mat
	ped_root.add_child(top_disc)

	# Recessed circular neon light strip (nestled in the bevel trench at Y = 0.405)
	var neon_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.63
	torus.outer_radius = 0.70
	torus.rings = 48
	torus.ring_segments = 16
	neon_ring.mesh = torus
	neon_ring.position = Vector3(0.0, 0.405, PEDESTAL_Z)
	var nmat := StandardMaterial3D.new()
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nmat.albedo_color = Color.WHITE * 2.2
	nmat.emission_enabled = true
	nmat.emission = Color.WHITE
	nmat.emission_energy_multiplier = 3.6
	neon_ring.material_override = nmat
	ped_root.add_child(neon_ring)
	_pedestal_neon_mat = nmat

	# Inner subtle glow disc on top platform surface
	var inner_glow := MeshInstance3D.new()
	var inner_cm := CylinderMesh.new()
	inner_cm.top_radius = 0.58
	inner_cm.bottom_radius = 0.58
	inner_cm.height = 0.005
	inner_cm.radial_segments = 36
	inner_glow.mesh = inner_cm
	inner_glow.position = Vector3(0.0, 0.443, PEDESTAL_Z)
	var inner_mat := StandardMaterial3D.new()
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	inner_glow.material_override = inner_mat
	ped_root.add_child(inner_glow)
	_pedestal_inner_mat = inner_mat

	# Contact shadow on pavement plane
	var shadow := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.95
	scyl.bottom_radius = 0.95
	scyl.height = 0.01
	scyl.radial_segments = 32
	shadow.mesh = scyl
	shadow.position = Vector3(0.0, 0.205, PEDESTAL_Z)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.01, 0.01, 0.02, 0.6)
	shadow.material_override = smat
	ped_root.add_child(shadow)

	# Recessed OmniLight casting colored glow upward onto survivor + floor
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.44 + 0.18, PEDESTAL_Z + 0.15)
	light.light_color = Color.WHITE
	light.light_energy = 1.2
	light.omni_range = 4.2
	ped_root.add_child(light)
	_pedestal_light = light

	# 3D selection Area3D collider for direct raycast tap
	var area := Area3D.new()
	area.name = "StageArea3D"
	var cshape := CollisionShape3D.new()
	var cyl_col := CylinderShape3D.new()
	cyl_col.radius = 0.88
	cyl_col.height = 2.6
	cshape.shape = cyl_col
	cshape.position = Vector3(0.0, 0.44 + 1.1, PEDESTAL_Z)
	area.add_child(cshape)
	area.input_event.connect(func(_cam: Node, ev: InputEvent, _pos: Vector3, _n: Vector3, _s: int) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_cycle_selection(1)
	)
	ped_root.add_child(area)
	_pedestal_area = area


func _spawn_survivors(bg: Node3D) -> void:
	_models.clear()
	_anim_players.clear()

	for i in range(_survivors.size()):
		var s := _survivors[i]
		var vis := Node3D.new()
		vis.name = "Survivor_%s" % s.id
		vis.position = Vector3(0.0, MODEL_ORIGIN_Y, PEDESTAL_Z)
		vis.visible = false
		bg.add_child(vis)
		_models.append(vis)

		var saved_skin := _get_current_skin(s.id)
		var ap := BlockyAnim.apply_body_variant(vis, s.id, saved_skin)
		_anim_players.append(ap)


# ── UI SETUP ───────────────────────────────────────────────────

func _build_ui() -> void:
	_build_side_nav_arrows()

	var bar: MarginContainer = $UI/BottomBar
	# Center the bottom UI as a tidy column instead of stretching edge-to-edge,
	# so the header strip + action row read as proportioned boxes.
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -560.0
	bar.offset_right = 560.0
	bar.offset_top = -188.0
	bar.offset_bottom = -16.0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	bar.add_child(vbox)

	_build_survivor_header(vbox)
	_build_action_row(vbox)
	_build_stage_tap_zone()


func _build_side_nav_arrows() -> void:
	var ui: Control = $UI

	# Left on-screen arrow button
	var left_btn := Button.new()
	left_btn.text = "◀"
	left_btn.custom_minimum_size = Vector2(62, 70)
	left_btn.anchor_left = 0.0
	left_btn.anchor_top = 0.48
	left_btn.anchor_right = 0.0
	left_btn.anchor_bottom = 0.48
	left_btn.offset_left = 36.0
	left_btn.offset_top = -35.0
	left_btn.offset_right = 98.0
	left_btn.offset_bottom = 35.0
	left_btn.focus_mode = Control.FOCUS_NONE
	_style_nav_arrow(left_btn)
	left_btn.pressed.connect(func() -> void: _cycle_selection(-1))
	ui.add_child(left_btn)
	_char_prev_btn = left_btn

	# Right on-screen arrow button
	var right_btn := Button.new()
	right_btn.text = "▶"
	right_btn.custom_minimum_size = Vector2(62, 70)
	right_btn.anchor_left = 1.0
	right_btn.anchor_top = 0.48
	right_btn.anchor_right = 1.0
	right_btn.anchor_bottom = 0.48
	right_btn.offset_left = -98.0
	right_btn.offset_top = -35.0
	right_btn.offset_right = -36.0
	right_btn.offset_bottom = 35.0
	right_btn.focus_mode = Control.FOCUS_NONE
	_style_nav_arrow(right_btn)
	right_btn.pressed.connect(func() -> void: _cycle_selection(1))
	ui.add_child(right_btn)
	_char_next_btn = right_btn


func _style_nav_arrow(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.72)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)

	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.20, 0.28, 0.90)
	hover.border_color = Color(1, 1, 1, 0.85)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_font_size_override("font_size", _fs(30))
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	if _btn_font_bold != null:
		b.add_theme_font_override("font", _btn_font_bold)


func _build_survivor_header(vbox: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.07, 0.10, 0.75)
	psb.set_corner_radius_all(16)
	psb.border_color = Color(1, 1, 1, 0.14)
	psb.set_border_width_all(2)
	psb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", psb)
	vbox.add_child(panel)

	var htop := HBoxContainer.new()
	htop.alignment = BoxContainer.ALIGNMENT_CENTER
	htop.add_theme_constant_override("separation", 16)
	panel.add_child(htop)

	# Left switcher button
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(40, 36)
	prev.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(prev)
	prev.pressed.connect(func() -> void: _cycle_selection(-1))
	htop.add_child(prev)

	# Middle column: Name, Description, Indicator Pips
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	htop.add_child(mid)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", _fs(42))
	_name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 0.95))
	_name_label.add_theme_constant_override("outline_size", _fs(8))
	if _btn_font_bold != null:
		_name_label.add_theme_font_override("font", _btn_font_bold)
	mid.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", _fs(20))
	_desc_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.99, 0.95))
	_desc_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 0.9))
	_desc_label.add_theme_constant_override("outline_size", _fs(5))
	if _btn_font_bold != null:
		_desc_label.add_theme_font_override("font", _btn_font_bold)
	mid.add_child(_desc_label)

	# Indicator pips row
	_pips_container = HBoxContainer.new()
	_pips_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips_container.add_theme_constant_override("separation", 10)
	mid.add_child(_pips_container)

	_pip_labels.clear()
	for i in range(_survivors.size()):
		var pip := Label.new()
		pip.text = "○"
		pip.add_theme_font_size_override("font_size", _fs(16))
		pip.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		_pips_container.add_child(pip)
		_pip_labels.append(pip)

	# Right switcher button
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(40, 36)
	next.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(next)
	next.pressed.connect(func() -> void: _cycle_selection(1))
	htop.add_child(next)


func _build_action_row(vbox: VBoxContainer) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)

	# Left container to match PLAY button width (240px) so the skin selector is centered
	var back_container := BoxContainer.new()
	back_container.custom_minimum_size = Vector2(240, 56)
	back_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	actions.add_child(back_container)

	# BACK
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(130, 52)
	back.focus_mode = Control.FOCUS_NONE
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.1, 0.11, 0.14, 0.65)
	back_sb.set_corner_radius_all(26)
	back_sb.border_color = Color(1, 1, 1, 0.22)
	back_sb.set_border_width_all(2)
	back.add_theme_stylebox_override("normal", back_sb)
	var back_hover := back_sb.duplicate() as StyleBoxFlat
	back_hover.bg_color = Color(0.18, 0.20, 0.26, 0.85)
	back.add_theme_stylebox_override("hover", back_hover)
	back.add_theme_stylebox_override("pressed", back_hover)
	back.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	back.add_theme_font_size_override("font_size", _fs(22))
	if _btn_font_bold != null:
		back.add_theme_font_override("font", _btn_font_bold)
	back.pressed.connect(_on_back_pressed)
	back_container.add_child(back)

	# Center: Skin selector
	var skin_mid := VBoxContainer.new()
	skin_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(skin_mid)
	_build_skin_selector(skin_mid)

	# PLAY
	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(240, 56)
	play.focus_mode = Control.FOCUS_NONE
	var cta := StyleBoxFlat.new()
	cta.bg_color = Color(0.85, 0.12, 0.16)
	cta.set_corner_radius_all(28)
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
	play.add_theme_font_size_override("font_size", _fs(30))
	if _btn_font_bold != null:
		play.add_theme_font_override("font", _btn_font_bold)
	play.pressed.connect(_on_play_pressed)
	actions.add_child(play)
	_play_btn = play


func _build_skin_selector(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Previous skin arrow
	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(44, 44)
	prev_btn.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(prev_btn)
	prev_btn.pressed.connect(func() -> void: _cycle_skin(-1))
	row.add_child(prev_btn)
	_skin_prev_btn = prev_btn

	# 3 Swatch / Variant buttons
	_skin_buttons.clear()
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 44)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func() -> void: _select_skin(idx, true, true))
		row.add_child(b)
		_skin_buttons.append(b)

	# Next skin arrow
	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(44, 44)
	next_btn.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(next_btn)
	next_btn.pressed.connect(func() -> void: _cycle_skin(1))
	row.add_child(next_btn)
	_skin_next_btn = next_btn


func _style_skin_arrow(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.15, 0.70)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.22, 0.30, 0.90)
	hover.border_color = Color(1, 1, 1, 0.40)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_font_size_override("font_size", _fs(18))
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	if _btn_font_bold != null:
		b.add_theme_font_override("font", _btn_font_bold)


func _style_skin_button(b: Button, accent: Color, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.20, 0.90) if active else Color(0.06, 0.08, 0.11, 0.55)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(4)
	if active:
		sb.border_color = accent
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = accent if active else Color(1, 1, 1, 0.35)
	hover.bg_color = Color(0.16, 0.18, 0.26, 0.92)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_font_size_override("font_size", _fs(15))
	b.add_theme_color_override("font_color", Color(1, 1, 1) if active else Color(0.72, 0.75, 0.80))
	if _btn_font_bold != null:
		b.add_theme_font_override("font", _btn_font_bold if active else _btn_font)


func _update_skin_ui(s: Survivor, active_idx: int) -> void:
	var variants: Array = BlockyAnim.get_skin_variants(s.id)
	for i in range(_skin_buttons.size()):
		var b := _skin_buttons[i]
		if i < variants.size():
			b.visible = true
			var vname: String = variants[i].get("name", "Skin %d" % (i + 1))
			b.text = vname
			var is_active := (i == active_idx)
			_style_skin_button(b, s.color, is_active)
		else:
			b.visible = false


func _get_current_skin(char_id: String) -> int:
	if has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		if save_mgr.has_method("get_selected_skin"):
			return save_mgr.get_selected_skin(char_id)
	return 0


func _select_skin(variant_index: int, play_sound: bool = true, persist: bool = true) -> void:
	if selected_character < 0 or selected_character >= _survivors.size():
		return
	var s: Survivor = _survivors[selected_character]
	var count: int = BlockyAnim.get_variant_count(s.id)
	if count <= 0:
		return
	var idx := clampi(variant_index, 0, count - 1)

	# 1. Live-update on-screen 3D model
	if selected_character < _models.size() and is_instance_valid(_models[selected_character]):
		var new_ap := BlockyAnim.apply_body_variant(_models[selected_character], s.id, idx)
		if selected_character < _anim_players.size():
			_anim_players[selected_character] = new_ap
		_play_active_idle(selected_character)

	# 2. Update skin UI
	_update_skin_ui(s, idx)

	# 3. Audio chime
	if play_sound:
		_play_skin_audio(idx)

	# 4. Persist to SaveManager
	if persist and has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		if save_mgr.has_method("set_selected_skin"):
			save_mgr.set_selected_skin(idx, s.id)


func _cycle_skin(delta: int) -> void:
	if selected_character < 0 or selected_character >= _survivors.size():
		return
	var s: Survivor = _survivors[selected_character]
	var count: int = BlockyAnim.get_variant_count(s.id)
	if count <= 0:
		return
	var current := _get_current_skin(s.id)
	var next_idx := posmod(current + delta, count)
	_select_skin(next_idx, true, true)


func _play_skin_audio(variant_index: int) -> void:
	Audio.play_click()
	if _chime_player == null:
		_chime_player = AudioStreamPlayer.new()
		var sfx_bus := AudioServer.get_bus_index("SFX")
		_chime_player.bus = "SFX" if sfx_bus >= 0 else "Master"
		add_child(_chime_player)

	var skin_freqs := [587.33, 739.99, 880.00]
	var freq: float = skin_freqs[clampi(variant_index, 0, skin_freqs.size() - 1)]
	_chime_player.stream = _generate_chime_stream(freq)
	_chime_player.volume_db = -5.0
	_chime_player.play()


func _build_stage_tap_zone() -> void:
	var zones: Control = $UI/StageZones
	var z := Button.new()
	z.flat = true
	z.focus_mode = Control.FOCUS_NONE
	z.anchor_left = 0.20
	z.anchor_right = 0.80
	z.anchor_top = 0.15
	z.anchor_bottom = 0.78
	var empty := StyleBoxEmpty.new()
	z.add_theme_stylebox_override("normal", empty)
	z.add_theme_stylebox_override("hover", empty)
	z.add_theme_stylebox_override("pressed", empty)
	z.add_theme_stylebox_override("focus", empty)
	z.pressed.connect(func() -> void: _cycle_selection(1))
	zones.add_child(z)
	_stage_tap_btn = z


func _update_tap_zones() -> void:
	# Center stage tap zone remains anchored relative to viewport
	pass


func _play_active_idle(char_idx: int) -> void:
	if char_idx < 0 or char_idx >= _anim_players.size() or char_idx >= _survivors.size():
		return
	var ap: AnimationPlayer = _anim_players[char_idx]
	if ap == null or not is_instance_valid(ap):
		return
	match _survivors[char_idx].id:
		"gamer":
			if ap.has_animation("holding-both"):
				ap.play("holding-both")
			elif ap.has_animation("idle"):
				ap.play("idle")
		"doctor":
			if ap.has_animation("holding-left"):
				ap.play("holding-left")
			elif ap.has_animation("idle"):
				ap.play("idle")
		"nurse":
			if ap.has_animation("holding-right"):
				ap.play("holding-right")
			elif ap.has_animation("idle"):
				ap.play("idle")
		"streamer":
			if ap.has_animation("interact-right"):
				ap.play("interact-right")
			elif ap.has_animation("holding-both"):
				ap.play("holding-both")
			elif ap.has_animation("idle"):
				ap.play("idle")
		"hunter":
			if ap.has_animation("holding-right"):
				ap.play("holding-right")
			elif ap.has_animation("attack-melee-right"):
				ap.play("attack-melee-right")
			elif ap.has_animation("idle"):
				ap.play("idle")
		_:
			if ap.has_animation("idle"):
				ap.play("idle")


# ── SELECTION & FEEDBACK ───────────────────────────────────────

func _select_character(index: int, play_sound: bool = true, persist: bool = true) -> void:
	selected_character = posmod(index, _survivors.size())
	var s: Survivor = _survivors[selected_character]

	# 1. Update single Pedestal lighting and neon materials
	if _pedestal_light != null and is_instance_valid(_pedestal_light):
		_pedestal_light.light_color = s.color
		_pedestal_light.light_energy = 1.2

	if _pedestal_neon_mat != null:
		_pedestal_neon_mat.albedo_color = s.color * 2.4
		_pedestal_neon_mat.emission = s.color
		_pedestal_neon_mat.emission_energy_multiplier = 3.6

	if _pedestal_inner_mat != null:
		_pedestal_inner_mat.albedo_color = Color(s.color.r, s.color.g, s.color.b, 0.42)

	# 2. Show only the selected survivor model, hide others
	for i in range(_models.size()):
		var is_active := (i == selected_character)
		if is_instance_valid(_models[i]):
			_models[i].visible = is_active
		if i < _anim_players.size() and is_instance_valid(_anim_players[i]):
			if is_active:
				_play_active_idle(i)
			else:
				if _anim_players[i].has_animation("idle"):
					_anim_players[i].play("idle")

	# 3. Update UI: Name, Description, Indicator Pips
	if _name_label != null:
		_name_label.text = s.display_name
		_name_label.add_theme_color_override("font_color", s.color)

	if _desc_label != null:
		_desc_label.text = s.description.to_upper() if not s.description.is_empty() else ""

	for i in range(_pip_labels.size()):
		var is_active := (i == selected_character)
		_pip_labels[i].add_theme_color_override("font_color", s.color if is_active else Color(1, 1, 1, 0.35))
		_pip_labels[i].text = "●" if is_active else "○"

	# 4. Update skin selector UI
	var active_skin := _get_current_skin(s.id)
	_update_skin_ui(s, active_skin)

	# 5. Camera framing
	_tween_camera_to_survivor(selected_character)

	# 6. Audio: clean selection chime + click
	if play_sound:
		_play_selection_audio(selected_character)

	# 7. Persist selection to SaveManager
	if persist and has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		save_mgr.set_selected_character(s.id)


func _tween_camera_to_survivor(_index: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = get_node_or_null("Background3D/Camera") as Camera3D
	if cam == null:
		return

	# Single hero character framing: pulled in close, centered at x=0
	var target_cam_pos := Vector3(0.0, 1.25, 1.10)
	var target_look := Vector3(0.0, 1.12, -1.60)

	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()

	_is_camera_tweening = true
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.disabled = true

	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(cam, "global_position", target_cam_pos, 0.35)

	# Smooth camera angle slerp
	var start_rot := cam.quaternion
	var dummy := Transform3D(Basis(), target_cam_pos)
	dummy = dummy.looking_at(target_look, Vector3.UP)
	var end_rot := dummy.basis.get_rotation_quaternion()

	_cam_tween.tween_method(func(w: float) -> void:
		if cam != null and is_instance_valid(cam):
			cam.quaternion = start_rot.slerp(end_rot, w)
	, 0.0, 1.0, 0.35)

	_cam_tween.chain().tween_callback(func() -> void:
		_is_camera_tweening = false
		if _play_btn != null and is_instance_valid(_play_btn):
			_play_btn.disabled = false
	)


func _play_selection_audio(index: int) -> void:
	Audio.play_click()
	if _chime_player == null:
		_chime_player = AudioStreamPlayer.new()
		var sfx_bus := AudioServer.get_bus_index("SFX")
		_chime_player.bus = "SFX" if sfx_bus >= 0 else "Master"
		add_child(_chime_player)

	# Clean pentatonic chime tones (C5, D5, E5, G5, A5) with whoosh sweep
	var freqs := [523.25, 587.33, 659.25, 783.99, 880.00]
	var freq: float = freqs[clampi(index, 0, freqs.size() - 1)]
	_chime_player.stream = _generate_chime_stream(freq)
	_chime_player.volume_db = -4.0
	_chime_player.play()


func _generate_chime_stream(freq: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	var duration := 0.28
	var sample_count := int(44100.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / 44100.0
		var chime_decay := exp(-t * 9.0)
		var whoosh_env := sin(clampf(t / duration, 0.0, 1.0) * PI) * 0.2
		var s := (sin(t * freq * TAU) * 0.65 + sin(t * freq * 2.0 * TAU) * 0.25) * chime_decay + whoosh_env * (randf() * 0.1 - 0.05)
		var int_s := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = int_s & 0xFF
		data[i * 2 + 1] = (int_s >> 8) & 0xFF

	stream.data = data
	return stream


func _on_play_pressed() -> void:
	if _is_camera_tweening:
		return
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
