## CharacterSelect.gd — Character Selection Screen (5-Lane Lineup)
## Rebuilt to match Reference Photo #12: 5 distinct survivor lanes on glowing pedestals
## in a horizontal row across the cemetery backdrop, each displaying their canonical
## palette, props, and idle animation simultaneously.
## Supports direct 3D raycast / tap, unprojected 2D tap zones, touch swipe,
## bottom lane buttons, keyboard navigation, and skin customization.
extends Control

const WOOD_TEX := preload("res://assets/textures/wood_planks.jpg")

# Stage layout: 5 lanes evenly distributed across the cemetery backdrop
const PEDESTAL_X: Array[float] = [-3.4, -1.7, 0.0, 1.7, 3.4]
const PEDESTAL_Z: float = -1.6
const PEDESTAL_TOP: float = 0.50
const MODEL_ORIGIN_Y: float = PEDESTAL_TOP + 0.02
const SURVIVOR_HEIGHT: float = 1.75

class Survivor extends RefCounted:
	var id: String
	var display_name: String
	var description: String
	var color: Color
	var scene_path: String
	var pedestal_x: float = 0.0

# 5 Canonical Survivors in order (matching Reference Photo #12 left-to-right)
const SURVIVOR_CONFIGS: Array[Dictionary] = [
	{
		"id": "gamer",
		"name": "GAMER",
		"scene": "res://scenes/characters/character_gamer.tscn",
		"desc": "Speed and snacks on demand"
	},
	{
		"id": "doctor",
		"name": "DOCTOR",
		"scene": "res://scenes/characters/character_doctor.tscn",
		"desc": "Tanky frame, medkits go further"
	},
	{
		"id": "nurse",
		"name": "NURSE",
		"scene": "res://scenes/characters/character_nurse.tscn",
		"desc": "Fast healer, high agility"
	},
	{
		"id": "streamer",
		"name": "STREAMER",
		"scene": "res://scenes/characters/character_streamer.tscn",
		"desc": "Trades health for hype & damage"
	},
	{
		"id": "hunter",
		"name": "HUNTER",
		"scene": "res://scenes/characters/character_hunter.tscn",
		"desc": "Ranged specialist, steady aim"
	},
]

# Canonical 5-lane palette (DESIGN.md §2 / specs/claude_canonical_roster.md)
# Nurse = neon-cyan (#2de0ff), Doctor = clinical-blue (#6fa8ff)
const PEDESTAL_COLORS: Dictionary = {
	"gamer": Color(1.0, 0.176, 0.482),     # #ff2d7b
	"doctor": Color(0.435, 0.659, 1.0),    # #6fa8ff clinical-blue
	"nurse": Color(0.176, 0.878, 1.0),     # #2de0ff neon-cyan
	"streamer": Color(0.627, 0.361, 1.0),  # #a05cff
	"hunter": Color(1.0, 0.839, 0.039),    # #ffd60a
}

var selected_character: int = 1  # Doctor default or read from Save
var _survivors: Array[Survivor] = []
var _models: Array[Node3D] = []
var _anim_players: Array[AnimationPlayer] = []

# 5-Lane Stage references
var _pedestal_neon_mats: Array[StandardMaterial3D] = []
var _pedestal_inner_mats: Array[StandardMaterial3D] = []
var _pedestal_lights: Array[OmniLight3D] = []

# UI references
var _zone_buttons: Array[Button] = []
var _lane_buttons: Array[Button] = []
var _play_btn: Button = null
var _back_btn: Button = null
var _name_label: Label = null
var _desc_label: Label = null
var _skin_name_label: Label = null
var _skin_prev_btn: Button = null
var _skin_next_btn: Button = null
var _btn_font: Font = null
var _title_font: Font = null

# Touch / gesture state
var _touch_start := Vector2.ZERO
var _is_swiping := false

# Audio
var _chime_player: AudioStreamPlayer = null
var _t: float = 0.0


func _init() -> void:
	_init_survivors()


func _init_survivors() -> void:
	_survivors.clear()
	for i in range(SURVIVOR_CONFIGS.size()):
		var cfg: Dictionary = SURVIVOR_CONFIGS[i]
		var s := Survivor.new()
		s.id = cfg["id"]
		s.display_name = cfg["name"]
		s.description = cfg.get("desc", "")
		s.color = PEDESTAL_COLORS.get(s.id, Color.WHITE)
		s.scene_path = cfg["scene"]
		s.pedestal_x = PEDESTAL_X[i]
		_survivors.append(s)


func _ready() -> void:
	_soften_bloom()

	var f := "res://assets/fonts/SpecialElite-Regular.ttf"
	if ResourceLoader.exists(f):
		_btn_font = load(f) as Font
	var nf := "res://assets/fonts/Nosifer-Regular.ttf"
	if ResourceLoader.exists(nf):
		_title_font = load(nf) as Font

	# Read initial selection from SaveManager without clobbering
	if has_node("/root/Save"):
		var save_mgr: Node = get_node("/root/Save")
		var saved_id: String = String(save_mgr.get("selected_character"))
		for i in range(_survivors.size()):
			if _survivors[i].id == saved_id:
				selected_character = i
				break

	_build_stage()
	_build_ui()
	_select_character(selected_character, false, false)

	resized.connect(_update_tap_zones)
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.size_changed.connect(_update_tap_zones)
	_update_tap_zones.call_deferred()

	Audio.play_menu_music()


func _process(delta: float) -> void:
	_t += delta

	# Subtle idle vertical breathing bob for all 5 figures
	for i in range(_models.size()):
		var m: Node3D = _models[i]
		if is_instance_valid(m):
			var is_selected: bool = (i == selected_character)
			var amp: float = 0.025 if is_selected else 0.012
			var spd: float = 1.6 if is_selected else 1.2
			m.position.y = MODEL_ORIGIN_Y + sin(_t * spd + float(i) * 1.25) * amp

	# Gentle pulse on the PLAY CTA button
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.modulate = Color(1.0, 1.0, 1.0, 0.86 + 0.14 * (0.5 + 0.5 * sin(_t * 3.4)))


func _soften_bloom() -> void:
	var we := get_node_or_null("Background3D/WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env: Environment = we.environment.duplicate() as Environment
	env.glow_intensity = 0.60
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.95
	we.environment = env


func _get_camera() -> Camera3D:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		return cam
	return get_node_or_null("Background3D/Camera") as Camera3D


# ── INPUT HANDLING ─────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Arrow keys / A & D to cycle survivors
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

	# Touch swipe navigation
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
				_is_swiping = false


func _cycle_selection(delta: int) -> void:
	var next_idx: int = posmod(selected_character + delta, _survivors.size())
	_select_character(next_idx, true, true)


# ── 3D STAGE SETUP (5 LANES) ──────────────────────────────────

func _build_stage() -> void:
	var bg: Node3D = $Background3D as Node3D
	_build_pedestals(bg)
	_spawn_survivors(bg)


func _build_pedestals(bg: Node3D) -> void:
	_pedestal_neon_mats.clear()
	_pedestal_inner_mats.clear()
	_pedestal_lights.clear()

	var ped_root := Node3D.new()
	ped_root.name = "Pedestal_Stage"
	bg.add_child(ped_root)

	for i in range(PEDESTAL_X.size()):
		var x: float = PEDESTAL_X[i]
		var col: Color = _survivors[i].color

		var lane_node := Node3D.new()
		lane_node.name = "Lane_%s" % _survivors[i].id
		lane_node.position = Vector3(x, 0.0, PEDESTAL_Z)
		ped_root.add_child(lane_node)

		# Tier 1: Foundation stone plinth
		var base := MeshInstance3D.new()
		var base_cyl := CylinderMesh.new()
		base_cyl.top_radius = 0.64
		base_cyl.bottom_radius = 0.74
		base_cyl.height = 0.22
		base_cyl.radial_segments = 32
		base.mesh = base_cyl
		base.position = Vector3(0.0, 0.11, 0.0)
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.14, 0.14, 0.15)
		base_mat.roughness = 0.95
		base_mat.metallic = 0.0
		base.material_override = base_mat
		lane_node.add_child(base)

		# Tier 2: Sculpted stone dais
		var collar := MeshInstance3D.new()
		var col_cyl := CylinderMesh.new()
		col_cyl.top_radius = 0.54
		col_cyl.bottom_radius = 0.62
		col_cyl.height = 0.16
		col_cyl.radial_segments = 32
		collar.mesh = col_cyl
		collar.position = Vector3(0.0, 0.30, 0.0)
		var collar_mat := StandardMaterial3D.new()
		collar_mat.albedo_color = Color(0.16, 0.16, 0.17)
		collar_mat.roughness = 0.95
		collar.material_override = collar_mat
		lane_node.add_child(collar)

		# Tier 3: Top platform (standing surface, top at Y = 0.50)
		var top_disc := MeshInstance3D.new()
		var top_cyl := CylinderMesh.new()
		top_cyl.top_radius = 0.48
		top_cyl.bottom_radius = 0.52
		top_cyl.height = 0.12
		top_cyl.radial_segments = 32
		top_disc.mesh = top_cyl
		top_disc.position = Vector3(0.0, 0.44, 0.0)
		var top_mat := StandardMaterial3D.new()
		top_mat.albedo_color = Color(0.12, 0.12, 0.13)
		top_mat.roughness = 0.95
		top_disc.material_override = top_mat
		lane_node.add_child(top_disc)

		# Neon rim light ring on top platform perimeter
		var neon_ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.48
		torus.rings = 24
		torus.ring_segments = 12
		neon_ring.mesh = torus
		neon_ring.position = Vector3(0.0, 0.505, 0.0)
		var neon_mat := StandardMaterial3D.new()
		neon_mat.albedo_color = col.darkened(0.25)
		neon_mat.emission_enabled = true
		neon_mat.emission = col
		neon_mat.emission_energy_multiplier = 0.8
		neon_ring.material_override = neon_mat
		lane_node.add_child(neon_ring)
		_pedestal_neon_mats.append(neon_mat)

		# Inner glowing disc surface
		var inner_disc := MeshInstance3D.new()
		var inner_cyl := CylinderMesh.new()
		inner_cyl.top_radius = 0.42
		inner_cyl.bottom_radius = 0.42
		inner_cyl.height = 0.015
		inner_cyl.radial_segments = 24
		inner_disc.mesh = inner_cyl
		inner_disc.position = Vector3(0.0, 0.508, 0.0)
		var inner_mat := StandardMaterial3D.new()
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
		inner_mat.roughness = 0.2
		inner_mat.metallic = 0.1
		inner_disc.material_override = inner_mat
		lane_node.add_child(inner_disc)
		_pedestal_inner_mats.append(inner_mat)

		# Contact shadow below on ground plane
		var shadow := MeshInstance3D.new()
		var scyl := CylinderMesh.new()
		scyl.top_radius = 0.78
		scyl.bottom_radius = 0.78
		scyl.height = 0.01
		scyl.radial_segments = 24
		shadow.mesh = scyl
		shadow.position = Vector3(0.0, 0.01, 0.0)
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.01, 0.01, 0.02, 0.6)
		shadow.material_override = smat
		lane_node.add_child(shadow)

		# Recessed OmniLight casting colored glow upward onto survivor
		var light := OmniLight3D.new()
		light.position = Vector3(0.0, 0.68, 0.12)
		light.light_color = col
		light.light_energy = 0.5
		light.omni_range = 2.8
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		lane_node.add_child(light)
		_pedestal_lights.append(light)

		# 3D selection Area3D collider for direct raycast tap
		var area := Area3D.new()
		area.name = "Area_%s" % _survivors[i].id
		var cshape := CollisionShape3D.new()
		var cyl_col := CylinderShape3D.new()
		cyl_col.radius = 0.62
		cyl_col.height = 2.4
		cshape.shape = cyl_col
		cshape.position = Vector3(0.0, 1.2, 0.0)
		area.add_child(cshape)
		var lane_idx: int = i
		area.input_event.connect(func(_cam: Node, ev: InputEvent, _pos: Vector3, _n: Vector3, _s: int) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_character(lane_idx)
		)
		lane_node.add_child(area)


func _spawn_survivors(bg: Node3D) -> void:
	_models.clear()
	_anim_players.clear()

	for i in range(_survivors.size()):
		var s: Survivor = _survivors[i]
		var vis := Node3D.new()
		vis.name = "Survivor_%s" % s.id
		vis.position = Vector3(s.pedestal_x, MODEL_ORIGIN_Y, PEDESTAL_Z)
		vis.visible = true
		bg.add_child(vis)
		_models.append(vis)

		var saved_skin: int = _get_current_skin(s.id)
		var ap: AnimationPlayer = BlockyAnim.apply_body_variant(vis, s.id, saved_skin)
		_anim_players.append(ap)
		if ap != null:
			_play_active_idle(i)


# ── UI SETUP ───────────────────────────────────────────────────

func _build_ui() -> void:
	_build_top_bar()
	_build_stage_tap_zones()
	_build_bottom_bar()


func _build_top_bar() -> void:
	var ui: Control = $UI as Control

	# Clean Back Button in top-left
	var back := Button.new()
	back.text = "◀  BACK"
	back.custom_minimum_size = Vector2(130, 44)
	back.position = Vector2(24, 20)
	back.focus_mode = Control.FOCUS_NONE
	_style_nav_button(back)
	back.pressed.connect(_on_back_pressed)
	ui.add_child(back)
	_back_btn = back


func _build_stage_tap_zones() -> void:
	var zones: Control = $UI/StageZones as Control
	for child in zones.get_children():
		child.queue_free()
	_zone_buttons.clear()

	for i in range(_survivors.size()):
		var z := Button.new()
		z.flat = true
		z.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		z.add_theme_stylebox_override("normal", empty)
		z.add_theme_stylebox_override("hover", empty)
		z.add_theme_stylebox_override("pressed", empty)
		z.add_theme_stylebox_override("focus", empty)
		var lane_idx: int = i
		z.pressed.connect(func() -> void: _select_character(lane_idx))
		zones.add_child(z)
		_zone_buttons.append(z)


func _update_tap_zones() -> void:
	var cam: Camera3D = _get_camera()
	var vp_size: Vector2 = get_viewport_rect().size
	if cam == null or vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	for i in range(_zone_buttons.size()):
		if i >= _survivors.size():
			break
		var btn: Button = _zone_buttons[i]
		var world_pos := Vector3(_survivors[i].pedestal_x, MODEL_ORIGIN_Y + 0.85, PEDESTAL_Z)
		var screen_pt: Vector2 = cam.unproject_position(world_pos)
		var half_w: float = vp_size.x * 0.09
		btn.anchor_left = 0.0
		btn.anchor_right = 0.0
		btn.anchor_top = 0.0
		btn.anchor_bottom = 0.0
		btn.position = Vector2(screen_pt.x - half_w, vp_size.y * 0.12)
		btn.size = Vector2(half_w * 2.0, vp_size.y * 0.65)


func _build_bottom_bar() -> void:
	var bar: MarginContainer = $UI/BottomBar as MarginContainer
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24.0
	bar.offset_right = -24.0
	bar.offset_top = -160.0
	bar.offset_bottom = -16.0

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	bar.add_child(root_vbox)

	_build_lane_selector_row(root_vbox)
	_build_info_action_row(root_vbox)


func _build_lane_selector_row(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	parent.add_child(hbox)

	_lane_buttons.clear()
	for i in range(_survivors.size()):
		var s: Survivor = _survivors[i]
		var btn := Button.new()
		btn.text = s.display_name
		btn.custom_minimum_size = Vector2(140, 42)
		btn.focus_mode = Control.FOCUS_NONE
		if _btn_font != null:
			btn.add_theme_font_override("font", _btn_font)
		btn.add_theme_font_size_override("font_size", 18)
		var lane_idx: int = i
		btn.pressed.connect(func() -> void: _select_character(lane_idx))
		_style_lane_button(btn, s.color, i == selected_character)
		hbox.add_child(btn)
		_lane_buttons.append(btn)


func _build_info_action_row(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	parent.add_child(hbox)

	# Left/Center: Survivor description & role
	var info_box := VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.custom_minimum_size = Vector2(360, 60)
	hbox.add_child(info_box)

	var name_lbl := Label.new()
	name_lbl.text = "DOCTOR"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _title_font != null:
		name_lbl.add_theme_font_override("font", _title_font)
	elif _btn_font != null:
		name_lbl.add_theme_font_override("font", _btn_font)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("shadow_offset_x", 2)
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	info_box.add_child(name_lbl)
	_name_label = name_lbl

	var desc_lbl := Label.new()
	desc_lbl.text = "TANKY FRAME, MEDKITS GO FURTHER"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _btn_font != null:
		desc_lbl.add_theme_font_override("font", _btn_font)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	desc_lbl.add_theme_constant_override("shadow_offset_x", 1)
	desc_lbl.add_theme_constant_override("shadow_offset_y", 1)
	info_box.add_child(desc_lbl)
	_desc_label = desc_lbl

	# Center: Skin variant selector
	var skin_box := HBoxContainer.new()
	skin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	skin_box.add_theme_constant_override("separation", 6)
	hbox.add_child(skin_box)

	var skin_prev := Button.new()
	skin_prev.text = "◀"
	skin_prev.custom_minimum_size = Vector2(36, 40)
	skin_prev.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(skin_prev)
	skin_prev.pressed.connect(func() -> void: _cycle_skin(-1))
	skin_box.add_child(skin_prev)
	_skin_prev_btn = skin_prev

	var skin_lbl := Label.new()
	skin_lbl.text = "Default"
	skin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skin_lbl.custom_minimum_size = Vector2(140, 40)
	if _btn_font != null:
		skin_lbl.add_theme_font_override("font", _btn_font)
	skin_lbl.add_theme_font_size_override("font_size", 14)
	skin_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	skin_box.add_child(skin_lbl)
	_skin_name_label = skin_lbl

	var skin_next := Button.new()
	skin_next.text = "▶"
	skin_next.custom_minimum_size = Vector2(36, 40)
	skin_next.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(skin_next)
	skin_next.pressed.connect(func() -> void: _cycle_skin(1))
	skin_box.add_child(skin_next)
	_skin_next_btn = skin_next

	# Right: Prominent Pulsing Red PLAY Button
	var play := Button.new()
	play.text = "PLAY  ▶"
	play.custom_minimum_size = Vector2(240, 56)
	play.focus_mode = Control.FOCUS_NONE
	var cta := StyleBoxFlat.new()
	cta.bg_color = Color(0.68, 0.08, 0.12)
	cta.set_border_width_all(2)
	cta.border_color = Color(1.0, 0.82, 0.75, 0.6)
	cta.set_corner_radius_all(14)
	play.add_theme_stylebox_override("normal", cta)
	var cta_hover: StyleBoxFlat = cta.duplicate() as StyleBoxFlat
	cta_hover.bg_color = Color(0.85, 0.14, 0.16)
	play.add_theme_stylebox_override("hover", cta_hover)
	play.add_theme_stylebox_override("pressed", cta_hover)
	play.add_theme_color_override("font_color", Color(1.0, 0.97, 0.93))
	play.add_theme_color_override("font_outline_color", Color(0.1, 0.01, 0.01, 0.95))
	play.add_theme_constant_override("outline_size", 4)
	play.add_theme_font_size_override("font_size", 24)
	if _btn_font != null:
		play.add_theme_font_override("font", _btn_font)
	play.pressed.connect(_on_play_pressed)
	hbox.add_child(play)
	_play_btn = play


func _style_lane_button(b: Button, accent: Color, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.9)
		sb.set_border_width_all(2)
		sb.border_color = accent
	else:
		sb.bg_color = Color(0.12, 0.12, 0.14, 0.75)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.3, 0.3, 0.35, 0.5)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)

	var sb_hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 0.95)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb_hover)
	b.add_theme_color_override("font_color", accent if active else Color(0.85, 0.85, 0.90))


func _style_skin_arrow(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.28, 0.28, 0.35, 0.9)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))


func _style_nav_button(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.18, 0.85)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.4, 0.45, 0.6)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.25, 0.25, 0.30, 0.95)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	if _btn_font != null:
		b.add_theme_font_override("font", _btn_font)
	b.add_theme_font_size_override("font_size", 16)


# ── SELECTION & ANIMATION LOGIC ────────────────────────────────

func _select_character(index: int, play_sound: bool = true, persist: bool = true) -> void:
	selected_character = clampi(index, 0, _survivors.size() - 1)
	var s: Survivor = _survivors[selected_character]

	# 1. Update all 5 pedestal highlights
	for i in range(_pedestal_neon_mats.size()):
		var is_sel: bool = (i == selected_character)
		if i < _pedestal_neon_mats.size() and _pedestal_neon_mats[i] != null:
			_pedestal_neon_mats[i].emission_energy_multiplier = 2.6 if is_sel else 0.75
		if i < _pedestal_inner_mats.size() and _pedestal_inner_mats[i] != null:
			var c: Color = _survivors[i].color
			_pedestal_inner_mats[i].albedo_color = Color(c.r, c.g, c.b, 0.65 if is_sel else 0.25)
		if i < _pedestal_lights.size() and _pedestal_lights[i] != null:
			_pedestal_lights[i].light_energy = 1.8 if is_sel else 0.45
			_pedestal_lights[i].omni_range = 3.6 if is_sel else 2.6

	# 2. Update animations: active holding idle on selected, idle on others
	for i in range(_anim_players.size()):
		var ap: AnimationPlayer = _anim_players[i]
		if ap != null and is_instance_valid(ap):
			_play_active_idle(i)

	# 3. Update lane selector buttons
	for i in range(_lane_buttons.size()):
		var btn: Button = _lane_buttons[i]
		if btn != null and is_instance_valid(btn):
			_style_lane_button(btn, _survivors[i].color, i == selected_character)

	# 4. Update Header / Info / Skin selector
	if _name_label != null:
		_name_label.text = s.display_name
		_name_label.add_theme_color_override("font_color", s.color)

	if _desc_label != null:
		_desc_label.text = s.description.to_upper() if not s.description.is_empty() else ""

	var active_skin: int = _get_current_skin(s.id)
	_update_skin_ui(s, active_skin)

	# 5. Audio feedback
	if play_sound:
		_play_selection_audio(selected_character)

	# 6. Persistence
	if persist and has_node("/root/Save"):
		var save_mgr: Node = get_node("/root/Save")
		save_mgr.set_selected_character(s.id)


func _play_active_idle(char_idx: int) -> void:
	if char_idx < 0 or char_idx >= _anim_players.size() or char_idx >= _survivors.size():
		return
	var ap: AnimationPlayer = _anim_players[char_idx]
	if ap == null or not is_instance_valid(ap):
		return

	# Character holds their distinctive prop
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
			if ap.has_animation("holding-right"):
				ap.play("holding-right")
			elif ap.has_animation("idle"):
				ap.play("idle")
		"hunter":
			if ap.has_animation("holding-right"):
				ap.play("holding-right")
			elif ap.has_animation("idle"):
				ap.play("idle")
		_:
			if ap.has_animation("idle"):
				ap.play("idle")


# ── SKIN CUSTOMIZATION ─────────────────────────────────────────

func _update_skin_ui(s: Survivor, active_idx: int) -> void:
	if _skin_name_label == null:
		return
	var variants: Array = BlockyAnim.SKIN_VARIANTS.get(s.id, [])
	var variant_name: String = "Variant %d" % (active_idx + 1)
	if active_idx >= 0 and active_idx < variants.size():
		variant_name = String(variants[active_idx].get("name", variant_name))
	_skin_name_label.text = variant_name
	_skin_name_label.add_theme_color_override("font_color", s.color)


func _get_current_skin(char_id: String) -> int:
	if has_node("/root/Save"):
		var save_mgr: Node = get_node("/root/Save")
		if save_mgr.has_method("get_selected_skin"):
			return int(save_mgr.call("get_selected_skin", char_id))
		elif save_mgr.get("selected_skins") != null:
			var skins: Dictionary = save_mgr.get("selected_skins")
			return int(skins.get(char_id, 0))
	return 0


func _select_skin(variant_index: int, play_sound: bool = true, persist: bool = true) -> void:
	if selected_character < 0 or selected_character >= _survivors.size():
		return
	var s: Survivor = _survivors[selected_character]
	var variants: Array = BlockyAnim.SKIN_VARIANTS.get(s.id, [])
	if variants.is_empty():
		return
	var safe_idx: int = clampi(variant_index, 0, variants.size() - 1)

	if persist and has_node("/root/Save"):
		var save_mgr: Node = get_node("/root/Save")
		if save_mgr.has_method("set_selected_skin"):
			save_mgr.call("set_selected_skin", s.id, safe_idx)

	_update_skin_ui(s, safe_idx)

	# Apply new body variant on the 3D model
	if selected_character < _models.size() and is_instance_valid(_models[selected_character]):
		var vis: Node3D = _models[selected_character]
		var ap: AnimationPlayer = BlockyAnim.apply_body_variant(vis, s.id, safe_idx)
		if ap != null:
			_anim_players[selected_character] = ap
			_play_active_idle(selected_character)

	if play_sound:
		_play_skin_audio(safe_idx)


func _cycle_skin(delta: int) -> void:
	if selected_character < 0 or selected_character >= _survivors.size():
		return
	var s: Survivor = _survivors[selected_character]
	var variants: Array = BlockyAnim.SKIN_VARIANTS.get(s.id, [])
	if variants.is_empty():
		return
	var count: int = variants.size()
	var current: int = _get_current_skin(s.id)
	var next_idx: int = posmod(current + delta, count)
	_select_skin(next_idx, true, true)


func _play_skin_audio(variant_index: int) -> void:
	Audio.play_click()
	if _chime_player == null:
		_chime_player = AudioStreamPlayer.new()
		var sfx_bus: int = AudioServer.get_bus_index("SFX")
		_chime_player.bus = "SFX" if sfx_bus >= 0 else "Master"
		add_child(_chime_player)

	var skin_freqs: Array[float] = [587.33, 739.99, 880.00]
	var freq: float = skin_freqs[clampi(variant_index, 0, skin_freqs.size() - 1)]
	_chime_player.stream = _generate_chime_stream(freq)
	_chime_player.volume_db = -5.0
	_chime_player.play()


# ── AUDIO FEEDBACK ─────────────────────────────────────────────

func _play_selection_audio(index: int) -> void:
	Audio.play_click()
	if _chime_player == null:
		_chime_player = AudioStreamPlayer.new()
		var sfx_bus: int = AudioServer.get_bus_index("SFX")
		_chime_player.bus = "SFX" if sfx_bus >= 0 else "Master"
		add_child(_chime_player)

	# Frequencies for pentatonic chime: C5, D5, E5, G5, A5
	var freqs: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.00]
	var safe_idx: int = clampi(index, 0, freqs.size() - 1)
	_chime_player.stream = _generate_chime_stream(freqs[safe_idx])
	_chime_player.volume_db = -6.0
	_chime_player.play()


func _generate_chime_stream(freq: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.32
	var num_samples: int = int(sample_rate * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	for i in range(num_samples):
		var time_sec: float = float(i) / float(sample_rate)
		var env: float = exp(-time_sec * 12.0)
		var val: float = (
			sin(time_sec * freq * TAU) * 0.70
			+ sin(time_sec * freq * 2.0 * TAU) * 0.22
			+ sin(time_sec * freq * 3.0 * TAU) * 0.08
		) * env
		var s16: int = clampi(int(val * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream


# ── NAVIGATION BUTTONS ─────────────────────────────────────────

func _on_play_pressed() -> void:
	Audio.play_click()
	if has_node("/root/Save") and selected_character >= 0 and selected_character < _survivors.size():
		var save_mgr: Node = get_node("/root/Save")
		save_mgr.set_selected_character(_survivors[selected_character].id)
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_back_pressed() -> void:
	Audio.play_click()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
