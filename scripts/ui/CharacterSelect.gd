## CharacterSelect.gd — Character Selection Screen
## One continuous 3D stage: five survivors stand on glowing pedestals in the graveyard.
## Direct 3D raycast / tap on podiums and survivors, horizontal cards, swipe / arrow navigation,
## dynamic camera focus, active idle animations, and atmospheric neon lighting.
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
	var pedestal_x: float

const SURVIVOR_CONFIGS: Array[Dictionary] = [
	{"id": "gamer", "name": "GAMER", "x": -3.4, "scene": "res://scenes/characters/character_gamer.tscn"},
	{"id": "doctor", "name": "DOCTOR", "x": -1.7, "scene": "res://scenes/characters/character_doctor.tscn"},
	{"id": "nurse", "name": "NURSE", "x": 0.0, "scene": "res://scenes/characters/character_nurse.tscn"},
	{"id": "streamer", "name": "STREAMER", "x": 1.7, "scene": "res://scenes/characters/character_streamer.tscn"},
	{"id": "hunter", "name": "HUNTER", "x": 3.4, "scene": "res://scenes/characters/character_hunter.tscn"},
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
var _lights: Array[OmniLight3D] = []
var _disc_mats: Array[StandardMaterial3D] = []
var _inner_mats: Array[StandardMaterial3D] = []
var _prop_lights: Array[OmniLight3D] = []
var _survivor_areas: Array[Area3D] = []
var _col_buttons: Array[Button] = []
var _zone_buttons: Array[Button] = []
var _play_btn: Button = null
var _name_label: Label = null
var _btn_font: Font = null
var _btn_font_bold: Font = null
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
		s.pedestal_x = cfg["x"]
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
		title.add_theme_font_size_override("font_size", _fs(46))
		_fit_label_font(title, 46, 0.94)
	var subtitle := get_node_or_null("UI/SubtitleLabel") as Label
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", _fs(20))


func _process(delta: float) -> void:
	_t += delta
	if _play_btn != null and is_instance_valid(_play_btn) and not _is_camera_tweening:
		_play_btn.modulate = Color(1.0, 1.0, 1.0, 0.84 + 0.16 * (0.5 + 0.5 * sin(_t * 3.4)))


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
		for i in range(_survivor_areas.size()):
			if _survivor_areas[i] == col:
				_select_character(i, true, true)
				get_viewport().set_input_as_handled()
				return


# ── STAGE SETUP ────────────────────────────────────────────────

func _build_stage() -> void:
	var bg: Node3D = $Background3D
	_build_pedestals(bg)
	_spawn_survivors(bg)


func _build_pedestals(bg: Node3D) -> void:
	_lights.clear()
	_disc_mats.clear()
	_inner_mats.clear()
	_survivor_areas.clear()

	for i in range(_survivors.size()):
		var s := _survivors[i]
		var x: float = s.pedestal_x
		var col: Color = s.color

		var ped_root := Node3D.new()
		ped_root.name = "Pedestal_%s" % s.id
		bg.add_child(ped_root)

		# Tier 1: Base Plinth (Bottom Bevel, 48 segments for smooth circular curvature)
		var base := MeshInstance3D.new()
		var base_cyl := CylinderMesh.new()
		base_cyl.top_radius = 0.74
		base_cyl.bottom_radius = 0.80
		base_cyl.height = 0.12
		base_cyl.radial_segments = 48
		base.mesh = base_cyl
		base.position = Vector3(x, 0.20 + 0.06, PEDESTAL_Z)
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.15, 0.16, 0.19)
		base_mat.roughness = 0.35
		base_mat.metallic = 0.4
		base.material_override = base_mat
		ped_root.add_child(base)

		# Tier 2: Bevel Collar (Recessed middle step)
		var collar := MeshInstance3D.new()
		var col_cyl := CylinderMesh.new()
		col_cyl.top_radius = 0.65
		col_cyl.bottom_radius = 0.72
		col_cyl.height = 0.08
		col_cyl.radial_segments = 48
		collar.mesh = col_cyl
		collar.position = Vector3(x, 0.20 + 0.12 + 0.04, PEDESTAL_Z)
		var collar_mat := StandardMaterial3D.new()
		collar_mat.albedo_color = Color(0.18, 0.20, 0.24)
		collar_mat.roughness = 0.25
		collar_mat.metallic = 0.3
		collar.material_override = collar_mat
		ped_root.add_child(collar)

		# Tier 3: Top Standing Platform (Charcoal matte platform, top at Y = 0.44)
		var top_disc := MeshInstance3D.new()
		var top_cyl := CylinderMesh.new()
		top_cyl.top_radius = 0.55
		top_cyl.bottom_radius = 0.57
		top_cyl.height = 0.04
		top_cyl.radial_segments = 48
		top_disc.mesh = top_cyl
		top_disc.position = Vector3(x, 0.20 + 0.12 + 0.08 + 0.02, PEDESTAL_Z)
		var top_mat := StandardMaterial3D.new()
		top_mat.albedo_color = Color(0.11, 0.12, 0.15)
		top_mat.roughness = 0.6
		top_mat.metallic = 0.1
		top_disc.material_override = top_mat
		ped_root.add_child(top_disc)

		# Recessed circular neon light strip (nestled in the bevel trench at Y = 0.405)
		var neon_ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.56
		torus.outer_radius = 0.63
		torus.rings = 48
		torus.ring_segments = 16
		neon_ring.mesh = torus
		neon_ring.position = Vector3(x, 0.405, PEDESTAL_Z)
		var nmat := StandardMaterial3D.new()
		nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nmat.albedo_color = col * 2.2
		nmat.emission_enabled = true
		nmat.emission = col
		nmat.emission_energy_multiplier = 3.2
		neon_ring.material_override = nmat
		ped_root.add_child(neon_ring)
		_disc_mats.append(nmat)

		# Inner subtle glow disc on top platform surface
		var inner_glow := MeshInstance3D.new()
		var inner_cm := CylinderMesh.new()
		inner_cm.top_radius = 0.52
		inner_cm.bottom_radius = 0.52
		inner_cm.height = 0.005
		inner_cm.radial_segments = 36
		inner_glow.mesh = inner_cm
		inner_glow.position = Vector3(x, 0.443, PEDESTAL_Z)
		var inner_mat := StandardMaterial3D.new()
		inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.albedo_color = Color(col.r, col.g, col.b, 0.32)
		inner_glow.material_override = inner_mat
		ped_root.add_child(inner_glow)
		_inner_mats.append(inner_mat)

		# Contact shadow on pavement plane
		var shadow := MeshInstance3D.new()
		var scyl := CylinderMesh.new()
		scyl.top_radius = 0.86
		scyl.bottom_radius = 0.86
		scyl.height = 0.01
		scyl.radial_segments = 32
		shadow.mesh = scyl
		shadow.position = Vector3(x, 0.205, PEDESTAL_Z)
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.01, 0.01, 0.02, 0.5)
		shadow.material_override = smat
		ped_root.add_child(shadow)

		# Recessed OmniLight casting colored glow upward onto survivor + floor
		var light := OmniLight3D.new()
		light.position = Vector3(x, 0.44 + 0.15, PEDESTAL_Z + 0.15)
		light.light_color = col
		light.light_energy = 2.4
		light.omni_range = 3.4
		ped_root.add_child(light)
		_lights.append(light)

		# 3D selection Area3D collider for direct raycast tap
		var area := Area3D.new()
		area.name = "Area3D"
		var cshape := CollisionShape3D.new()
		var cyl_col := CylinderShape3D.new()
		cyl_col.radius = 0.78
		cyl_col.height = 2.4
		cshape.shape = cyl_col
		cshape.position = Vector3(x, 0.44 + 1.1, PEDESTAL_Z)
		area.add_child(cshape)
		var idx := i
		area.input_event.connect(func(_cam: Node, ev: InputEvent, _pos: Vector3, _n: Vector3, _s: int) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_character(idx, true, true)
		)
		ped_root.add_child(area)
		_survivor_areas.append(area)


func _spawn_survivors(bg: Node3D) -> void:
	_models.clear()
	_anim_players.clear()
	_prop_lights.clear()

	for i in range(_survivors.size()):
		var s := _survivors[i]
		var vis := Node3D.new()
		vis.name = "Survivor_%s" % s.id
		vis.position = Vector3(s.pedestal_x, MODEL_ORIGIN_Y, PEDESTAL_Z)
		bg.add_child(vis)
		_models.append(vis)

		var saved_skin := _get_current_skin(s.id)
		var ap := BlockyAnim.apply_body_variant(vis, s.id, saved_skin)
		_anim_players.append(ap)

		if ap != null and ap.has_animation("idle"):
			ap.play("idle")


func _setup_character_props(vis: Node3D, char_id: String, _x: float, _bg: Node3D) -> void:
	match char_id:
		"gamer":
			# Purple hoodie + RGB headphones + glowing controller
			var head_node := vis.find_child("head", true, false) as Node3D
			if head_node != null:
				var hp := Node3D.new()
				hp.name = "RGBHeadphones"
				# Headband arc over top of mini head
				var arc := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.24
				tm.outer_radius = 0.27
				tm.rings = 24
				tm.ring_segments = 12
				arc.mesh = tm
				arc.rotation_degrees = Vector3(90, 0, 0)
				arc.position = Vector3(0, 0.26, 0)
				var arc_mat := StandardMaterial3D.new()
				arc_mat.albedo_color = Color(0.12, 0.12, 0.15)
				arc_mat.metallic = 0.8
				arc.material_override = arc_mat
				hp.add_child(arc)
				# Left cup with cyan glowing ring
				var left_cup := _create_earcup(Color(0.1, 0.9, 1.0))
				left_cup.position = Vector3(-0.25, 0.18, 0)
				hp.add_child(left_cup)
				# Right cup with magenta glowing ring
				var right_cup := _create_earcup(Color(1.0, 0.1, 0.7))
				right_cup.position = Vector3(0.25, 0.18, 0)
				hp.add_child(right_cup)

				# Modeled purple hoodie cowl around neck/head base
				var cowl := MeshInstance3D.new()
				var ctor := TorusMesh.new()
				ctor.inner_radius = 0.20
				ctor.outer_radius = 0.28
				ctor.rings = 24
				ctor.ring_segments = 12
				cowl.mesh = ctor
				cowl.position = Vector3(0, 0.04, 0)
				cowl.rotation_degrees = Vector3(90, 0, 0)
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = Color(0.55, 0.18, 0.85)
				cmat.roughness = 0.8
				cowl.material_override = cmat
				hp.add_child(cowl)

				# Draped hood mesh on back of head
				var dhood := MeshInstance3D.new()
				var dbox := BoxMesh.new()
				dbox.size = Vector3(0.38, 0.32, 0.16)
				dhood.mesh = dbox
				dhood.position = Vector3(0, 0.14, -0.16)
				dhood.material_override = cmat
				hp.add_child(dhood)

				head_node.add_child(hp)

			# Glowing Game Controller held in right arm
			var arm_r := vis.find_child("arm-right", true, false) as Node3D
			if arm_r != null:
				var ctrl := Node3D.new()
				ctrl.name = "ControllerProp"
				var cbody := MeshInstance3D.new()
				var bmesh := BoxMesh.new()
				bmesh.size = Vector3(0.24, 0.08, 0.14)
				cbody.mesh = bmesh
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = Color(0.10, 0.10, 0.12)
				cmat.roughness = 0.35
				cbody.material_override = cmat
				ctrl.add_child(cbody)

				# Left & right grip handles
				for sx in [-0.10, 0.10]:
					var grip := MeshInstance3D.new()
					var gcyl := CylinderMesh.new()
					gcyl.top_radius = 0.035
					gcyl.bottom_radius = 0.04
					gcyl.height = 0.12
					grip.mesh = gcyl
					grip.position = Vector3(sx, -0.06, 0.02)
					grip.rotation_degrees = Vector3(-20, 0, 15 if sx < 0 else -15)
					grip.material_override = cmat
					ctrl.add_child(grip)

				# LED glowing strip on top edge
				var led := MeshInstance3D.new()
				var lmesh := BoxMesh.new()
				lmesh.size = Vector3(0.16, 0.015, 0.03)
				led.mesh = lmesh
				led.position = Vector3(0, 0.042, -0.055)
				var lmat := StandardMaterial3D.new()
				lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				lmat.albedo_color = Color(1.0, 0.1, 0.8) * 3.5
				led.material_override = lmat
				ctrl.add_child(led)

				# Glowing cyan and magenta thumbsticks
				for side in [-1.0, 1.0]:
					var stick := MeshInstance3D.new()
					var scyl := CylinderMesh.new()
					scyl.top_radius = 0.022
					scyl.bottom_radius = 0.018
					scyl.height = 0.025
					stick.mesh = scyl
					stick.position = Vector3(side * 0.06, 0.045, 0.01)
					var smat := StandardMaterial3D.new()
					smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					smat.albedo_color = (Color(0.1, 0.9, 1.0) if side < 0 else Color(1.0, 0.15, 0.8)) * 3.0
					stick.material_override = smat
					ctrl.add_child(stick)

				# Controller Point Light
				var clight := OmniLight3D.new()
				clight.name = "PropOmniLight_gamer"
				clight.light_color = Color(1.0, 0.15, 0.8)
				clight.light_energy = 2.2
				clight.omni_range = 1.8
				ctrl.add_child(clight)
				_prop_lights.append(clight)

				ctrl.position = Vector3(0.04, -0.28, 0.16)
				ctrl.rotation_degrees = Vector3(45, -10, 0)
				arm_r.add_child(ctrl)

		"doctor":
			# White lab coat over blue scrubs + modeled stethoscope
			var torso := vis.find_child("torso", true, false) as Node3D
			if torso != null:
				var coat := Node3D.new()
				coat.name = "LabCoat"
				var coat_mat := StandardMaterial3D.new()
				coat_mat.albedo_color = Color(0.96, 0.97, 1.0)
				coat_mat.roughness = 0.45

				# Left lapel
				var lapel_l := MeshInstance3D.new()
				var ll_box := BoxMesh.new()
				ll_box.size = Vector3(0.14, 0.36, 0.08)
				lapel_l.mesh = ll_box
				lapel_l.position = Vector3(-0.16, 0.02, 0.14)
				lapel_l.material_override = coat_mat
				coat.add_child(lapel_l)

				# Right lapel
				var lapel_r := MeshInstance3D.new()
				var lr_box := BoxMesh.new()
				lr_box.size = Vector3(0.14, 0.36, 0.08)
				lapel_r.mesh = lr_box
				lapel_r.position = Vector3(0.16, 0.02, 0.14)
				lapel_r.material_override = coat_mat
				coat.add_child(lapel_r)

				# Back of coat
				var coat_back := MeshInstance3D.new()
				var cb_box := BoxMesh.new()
				cb_box.size = Vector3(0.48, 0.40, 0.08)
				coat_back.mesh = cb_box
				coat_back.position = Vector3(0, 0.0, -0.14)
				coat_back.material_override = coat_mat
				coat.add_child(coat_back)

				# Lower coat skirt flaps
				var skirt := MeshInstance3D.new()
				var s_box := BoxMesh.new()
				s_box.size = Vector3(0.50, 0.22, 0.36)
				skirt.mesh = s_box
				skirt.position = Vector3(0, -0.24, 0)
				skirt.material_override = coat_mat
				coat.add_child(skirt)

				# Stethoscope
				var steth := Node3D.new()
				steth.name = "Stethoscope"
				var disc := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.055
				cm.bottom_radius = 0.055
				cm.height = 0.02
				cm.radial_segments = 20
				disc.mesh = cm
				disc.rotation_degrees = Vector3(85, 0, 0)
				disc.position = Vector3(0.04, 0.06, 0.20)
				var dmat := StandardMaterial3D.new()
				dmat.albedo_color = Color(0.92, 0.94, 0.98)
				dmat.metallic = 0.95
				dmat.roughness = 0.15
				disc.material_override = dmat
				steth.add_child(disc)

				# Tubing around neck
				var tube := MeshInstance3D.new()
				var tor := TorusMesh.new()
				tor.inner_radius = 0.11
				tor.outer_radius = 0.14
				tube.mesh = tor
				tube.position = Vector3(0, 0.17, 0.04)
				var tmat := StandardMaterial3D.new()
				tmat.albedo_color = Color(0.18, 0.22, 0.28)
				tmat.roughness = 0.5
				tube.material_override = tmat
				steth.add_child(tube)

				coat.add_child(steth)
				torso.add_child(coat)

			# Doctor glasses accessory
			var head_d := vis.find_child("head", true, false) as Node3D
			if head_d != null and ResourceLoader.exists("res://assets/models/cc0/minis/aid-glasses.glb"):
				var gl_ps := load("res://assets/models/cc0/minis/aid-glasses.glb") as PackedScene
				if gl_ps != null:
					var gl := gl_ps.instantiate() as Node3D
					gl.scale = Vector3(1.2, 1.2, 1.2)
					gl.position = Vector3(0, 0.14, 0.19)
					head_d.add_child(gl)

		"nurse":
			# Teal scrubs + face mask + scrub cap + glowing pink syringe
			var head_n := vis.find_child("head", true, false) as Node3D
			if head_n != null:
				# Surgical face mask
				if ResourceLoader.exists("res://assets/models/cc0/minis/aid-mask.glb"):
					var mask_ps := load("res://assets/models/cc0/minis/aid-mask.glb") as PackedScene
					if mask_ps != null:
						var mask := mask_ps.instantiate() as Node3D
						mask.scale = Vector3(1.2, 1.2, 1.2)
						mask.position = Vector3(0, 0.08, 0.19)
						head_n.add_child(mask)

				# Modeled scrub cap in mint teal
				var cap := MeshInstance3D.new()
				var ccyl := CylinderMesh.new()
				ccyl.top_radius = 0.26
				ccyl.bottom_radius = 0.28
				ccyl.height = 0.22
				cap.mesh = ccyl
				cap.position = Vector3(0, 0.30, 0.0)
				var cap_mat := StandardMaterial3D.new()
				cap_mat.albedo_color = Color(0.15, 0.78, 0.68)
				cap_mat.roughness = 0.7
				cap.material_override = cap_mat
				head_n.add_child(cap)

				# Scrub cap rim/brim
				var brim := MeshInstance3D.new()
				var btor := TorusMesh.new()
				btor.inner_radius = 0.26
				btor.outer_radius = 0.29
				brim.mesh = btor
				brim.position = Vector3(0, 0.20, 0.0)
				brim.rotation_degrees = Vector3(90, 0, 0)
				var brim_mat := StandardMaterial3D.new()
				brim_mat.albedo_color = Color(0.12, 0.68, 0.60)
				brim_mat.roughness = 0.75
				brim.material_override = brim_mat
				head_n.add_child(brim)

			# Glowing pink syringe in right hand
			var arm_nr := vis.find_child("arm-right", true, false) as Node3D
			if arm_nr != null:
				var syr := Node3D.new()
				syr.name = "GlowingSyringe"
				# Clear glass/plastic barrel
				var barrel := MeshInstance3D.new()
				var bcyl := CylinderMesh.new()
				bcyl.top_radius = 0.05
				bcyl.bottom_radius = 0.05
				bcyl.height = 0.30
				barrel.mesh = bcyl
				var bmat := StandardMaterial3D.new()
				bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bmat.albedo_color = Color(0.85, 0.95, 1.0, 0.5)
				barrel.material_override = bmat
				syr.add_child(barrel)

				# Glowing pink medicine core
				var core := MeshInstance3D.new()
				var ccyl := CylinderMesh.new()
				ccyl.top_radius = 0.04
				ccyl.bottom_radius = 0.04
				ccyl.height = 0.22
				core.mesh = ccyl
				core.position = Vector3(0, -0.02, 0)
				var cormat := StandardMaterial3D.new()
				cormat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				cormat.albedo_color = Color(1.0, 0.12, 0.72) * 4.0
				core.material_override = cormat
				syr.add_child(core)

				# Plunger & top finger flange
				var flange := MeshInstance3D.new()
				var fcyl := CylinderMesh.new()
				fcyl.top_radius = 0.065
				fcyl.bottom_radius = 0.065
				fcyl.height = 0.02
				flange.mesh = fcyl
				flange.position = Vector3(0, 0.15, 0)
				var fmat := StandardMaterial3D.new()
				fmat.albedo_color = Color(0.9, 0.9, 0.95)
				fmat.metallic = 0.8
				flange.material_override = fmat
				syr.add_child(flange)

				# Chrome needle
				var needle := MeshInstance3D.new()
				var ncyl := CylinderMesh.new()
				ncyl.top_radius = 0.006
				ncyl.bottom_radius = 0.003
				ncyl.height = 0.16
				needle.mesh = ncyl
				needle.position = Vector3(0, -0.23, 0)
				var nmat := StandardMaterial3D.new()
				nmat.albedo_color = Color(0.95, 0.95, 0.98)
				nmat.metallic = 0.95
				needle.material_override = nmat
				syr.add_child(needle)

				# Syringe Point Light
				var slight := OmniLight3D.new()
				slight.name = "PropOmniLight_nurse"
				slight.light_color = Color(1.0, 0.15, 0.72)
				slight.light_energy = 2.6
				slight.omni_range = 1.8
				syr.add_child(slight)
				_prop_lights.append(slight)

				syr.position = Vector3(0.04, -0.28, 0.18)
				syr.rotation_degrees = Vector3(-55, 10, 10)
				arm_nr.add_child(syr)

		"streamer":
			# Black hoodie hood-up + beard + phone on glowing magenta ring light
			var head_s := vis.find_child("head", true, false) as Node3D
			if head_s != null:
				var hood := Node3D.new()
				hood.name = "HoodUp"
				var hmat := StandardMaterial3D.new()
				hmat.albedo_color = Color(0.08, 0.08, 0.09)
				hmat.roughness = 0.85

				# Back of hood
				var h_back := MeshInstance3D.new()
				var hb_box := BoxMesh.new()
				hb_box.size = Vector3(0.52, 0.52, 0.16)
				h_back.mesh = hb_box
				h_back.position = Vector3(0, 0.24, -0.16)
				h_back.material_override = hmat
				hood.add_child(h_back)

				# Top of hood
				var h_top := MeshInstance3D.new()
				var ht_box := BoxMesh.new()
				ht_box.size = Vector3(0.52, 0.14, 0.44)
				h_top.mesh = ht_box
				h_top.position = Vector3(0, 0.46, 0.02)
				h_top.material_override = hmat
				hood.add_child(h_top)

				# Left side flap
				var h_left := MeshInstance3D.new()
				var hl_box := BoxMesh.new()
				hl_box.size = Vector3(0.12, 0.46, 0.42)
				h_left.mesh = hl_box
				h_left.position = Vector3(-0.25, 0.24, 0.02)
				h_left.material_override = hmat
				hood.add_child(h_left)

				# Right side flap
				var h_right := MeshInstance3D.new()
				var hr_box := BoxMesh.new()
				hr_box.size = Vector3(0.12, 0.46, 0.42)
				h_right.mesh = hr_box
				h_right.position = Vector3(0.25, 0.24, 0.02)
				h_right.material_override = hmat
				hood.add_child(h_right)

				# Hood collar around neck
				var collar := MeshInstance3D.new()
				var ctor := TorusMesh.new()
				ctor.inner_radius = 0.22
				ctor.outer_radius = 0.28
				collar.mesh = ctor
				collar.position = Vector3(0, 0.02, 0.0)
				collar.rotation_degrees = Vector3(90, 0, 0)
				collar.material_override = hmat
				hood.add_child(collar)

				head_s.add_child(hood)

			# Handheld vlogging stick with phone on glowing magenta ring light
			var arm_sr := vis.find_child("arm-right", true, false) as Node3D
			if arm_sr != null:
				var ring_prop := Node3D.new()
				ring_prop.name = "StreamerRingLightProp"

				# Handle stick
				var stick := MeshInstance3D.new()
				var smesh := CylinderMesh.new()
				smesh.top_radius = 0.02
				smesh.bottom_radius = 0.02
				smesh.height = 0.35
				stick.mesh = smesh
				stick.position = Vector3(0, 0.05, 0)
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.15, 0.15, 0.18)
				smat.roughness = 0.5
				stick.material_override = smat
				ring_prop.add_child(stick)

				# Ring light torus
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.15
				torus.outer_radius = 0.21
				torus.rings = 36
				torus.ring_segments = 16
				ring.mesh = torus
				ring.position = Vector3(0.0, 0.26, 0.02)
				ring.rotation_degrees = Vector3(85.0, 0.0, 0.0)
				var ring_mat := StandardMaterial3D.new()
				ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				ring_mat.albedo_color = Color(1.0, 0.12, 0.95) * 4.5
				ring.material_override = ring_mat
				ring_prop.add_child(ring)

				# Smartphone mounted inside ring light
				var phone := MeshInstance3D.new()
				var pbox := BoxMesh.new()
				pbox.size = Vector3(0.10, 0.18, 0.015)
				phone.mesh = pbox
				phone.position = Vector3(0.0, 0.26, 0.02)
				var phonemat := StandardMaterial3D.new()
				phonemat.albedo_color = Color(0.06, 0.06, 0.08)
				phonemat.roughness = 0.2
				phone.material_override = phonemat
				ring_prop.add_child(phone)

				# Phone screen glowing display
				var screen := MeshInstance3D.new()
				var sbox := BoxMesh.new()
				sbox.size = Vector3(0.085, 0.16, 0.005)
				screen.mesh = sbox
				screen.position = Vector3(0.0, 0.26, 0.01)
				var screenmat := StandardMaterial3D.new()
				screenmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				screenmat.albedo_color = Color(0.9, 0.95, 1.0) * 2.0
				screen.material_override = screenmat
				ring_prop.add_child(screen)

				# Ring Light OmniLight casting magenta glow onto streamer
				var rlight := OmniLight3D.new()
				rlight.name = "PropOmniLight_streamer"
				rlight.position = Vector3(0.0, 0.26, 0.08)
				rlight.light_color = Color(1.0, 0.15, 0.95)
				rlight.light_energy = 2.8
				rlight.omni_range = 2.0
				ring_prop.add_child(rlight)
				_prop_lights.append(rlight)

				ring_prop.position = Vector3(0.06, -0.28, 0.20)
				ring_prop.rotation_degrees = Vector3(25, -20, 15)
				arm_sr.add_child(ring_prop)

		"hunter":
			# Quilted brown vest + green shirt + knee pads + boots + wooden bat
			var torso_h := vis.find_child("torso", true, false) as Node3D
			if torso_h != null:
				var vest := Node3D.new()
				vest.name = "QuiltedVest"
				var vmat := StandardMaterial3D.new()
				vmat.albedo_color = Color(0.42, 0.26, 0.14)
				vmat.roughness = 0.65

				# Left vest panel
				var vl := MeshInstance3D.new()
				var vl_box := BoxMesh.new()
				vl_box.size = Vector3(0.20, 0.38, 0.06)
				vl.mesh = vl_box
				vl.position = Vector3(-0.13, 0.0, 0.16)
				vl.material_override = vmat
				vest.add_child(vl)

				# Right vest panel
				var vr := MeshInstance3D.new()
				var vr_box := BoxMesh.new()
				vr_box.size = Vector3(0.20, 0.38, 0.06)
				vr.mesh = vr_box
				vr.position = Vector3(0.13, 0.0, 0.16)
				vr.material_override = vmat
				vest.add_child(vr)

				# Back vest panel
				var vb := MeshInstance3D.new()
				var vb_box := BoxMesh.new()
				vb_box.size = Vector3(0.48, 0.38, 0.06)
				vb.mesh = vb_box
				vb.position = Vector3(0, 0.0, -0.15)
				vb.material_override = vmat
				vest.add_child(vb)

				# Waist belt
				var belt := MeshInstance3D.new()
				var b_box := BoxMesh.new()
				b_box.size = Vector3(0.50, 0.08, 0.36)
				belt.mesh = b_box
				belt.position = Vector3(0, -0.18, 0)
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.22, 0.14, 0.08)
				bmat.roughness = 0.5
				belt.material_override = bmat
				vest.add_child(belt)

				torso_h.add_child(vest)

			# Knee pads and boots on legs
			var leg_l := vis.find_child("leg-left", true, false) as Node3D
			if leg_l != null:
				var kpad_l := _create_kneepad()
				kpad_l.position = Vector3(0, -0.16, 0.08)
				leg_l.add_child(kpad_l)
				var boot_l := _create_boot()
				boot_l.position = Vector3(0, -0.34, 0.02)
				leg_l.add_child(boot_l)

			var leg_r := vis.find_child("leg-right", true, false) as Node3D
			if leg_r != null:
				var kpad_r := _create_kneepad()
				kpad_r.position = Vector3(0, -0.16, 0.08)
				leg_r.add_child(kpad_r)
				var boot_r := _create_boot()
				boot_r.position = Vector3(0, -0.34, 0.02)
				leg_r.add_child(boot_r)

			# Wooden baseball bat held in right hand and resting over shoulder
			var arm_hr := vis.find_child("arm-right", true, false) as Node3D
			if arm_hr != null:
				var bat := Node3D.new()
				bat.name = "WoodenBatProp"

				# Bat barrel
				var bmesh_inst := MeshInstance3D.new()
				var bmesh := CylinderMesh.new()
				bmesh.top_radius = 0.06
				bmesh.bottom_radius = 0.025
				bmesh.height = 0.75
				bmesh.radial_segments = 16
				bmesh_inst.mesh = bmesh
				var bat_mat := StandardMaterial3D.new()
				bat_mat.albedo_color = Color(0.74, 0.56, 0.36)
				bat_mat.roughness = 0.6
				bat_mat.metallic = 0.05
				bmesh_inst.material_override = bat_mat
				bat.add_child(bmesh_inst)

				# Grip tape
				var grip := MeshInstance3D.new()
				var gmesh := CylinderMesh.new()
				gmesh.top_radius = 0.026
				gmesh.bottom_radius = 0.026
				gmesh.height = 0.22
				grip.mesh = gmesh
				grip.position = Vector3(0, -0.24, 0)
				var gmat := StandardMaterial3D.new()
				gmat.albedo_color = Color(0.92, 0.90, 0.86)
				gmat.roughness = 0.8
				grip.material_override = gmat
				bat.add_child(grip)

				bat.position = Vector3(0.06, -0.22, 0.10)
				bat.rotation_degrees = Vector3(-50, 15, 30)
				arm_hr.add_child(bat)


func _create_earcup(glow_col: Color) -> Node3D:
	var cup_root := Node3D.new()
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = 0.05
	cm.radial_segments = 16
	cup.mesh = cm
	cup.rotation_degrees = Vector3(0, 0, 90)
	var cup_mat := StandardMaterial3D.new()
	cup_mat.albedo_color = Color(0.12, 0.12, 0.15)
	cup.material_override = cup_mat
	cup_root.add_child(cup)

	var ring := MeshInstance3D.new()
	var rtor := TorusMesh.new()
	rtor.inner_radius = 0.065
	rtor.outer_radius = 0.082
	ring.mesh = rtor
	ring.rotation_degrees = Vector3(0, 0, 90)
	ring.position = Vector3(0.026, 0, 0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = glow_col * 3.5
	ring.material_override = rmat
	cup_root.add_child(ring)
	return cup_root


func _create_kneepad() -> MeshInstance3D:
	var kp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.12, 0.06)
	kp.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.14, 0.13)
	mat.roughness = 0.65
	kp.material_override = mat
	return kp


func _create_boot() -> MeshInstance3D:
	var boot := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.14, 0.20)
	boot.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.14, 0.08)
	mat.roughness = 0.7
	boot.material_override = mat
	return boot


# ── UI SETUP ───────────────────────────────────────────────────

func _build_ui() -> void:
	var bar: MarginContainer = $UI/BottomBar
	bar.offset_top = -162.0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	bar.add_child(vbox)

	_build_name_buttons(vbox)
	_build_action_row(vbox)
	_build_tap_zones()


func _card_style(accent: Color, active: bool) -> StyleBoxFlat:
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

	# BACK
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

	# Selected character name
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(mid)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", _fs(34))
	_name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 0.95))
	_name_label.add_theme_constant_override("outline_size", _fs(8))
	if _btn_font_bold != null:
		_name_label.add_theme_font_override("font", _btn_font_bold)
	mid.add_child(_name_label)

	_build_skin_selector(mid)

	# PLAY
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


func _build_skin_selector(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	# Previous skin arrow
	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(34, 28)
	prev_btn.focus_mode = Control.FOCUS_NONE
	_style_skin_arrow(prev_btn)
	prev_btn.pressed.connect(func() -> void: _cycle_skin(-1))
	row.add_child(prev_btn)
	_skin_prev_btn = prev_btn

	# 3 Swatch / Variant buttons
	_skin_buttons.clear()
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(125, 28)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func() -> void: _select_skin(idx, true, true))
		row.add_child(b)
		_skin_buttons.append(b)

	# Next skin arrow
	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(34, 28)
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
	b.add_theme_font_size_override("font_size", _fs(15))
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	if _btn_font_bold != null:
		b.add_theme_font_override("font", _btn_font_bold)


func _style_skin_button(b: Button, accent: Color, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.20, 0.90) if active else Color(0.06, 0.08, 0.11, 0.55)
	sb.set_corner_radius_all(14)
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
	b.add_theme_font_size_override("font_size", _fs(14))
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
		cam = get_node_or_null("Background3D/Camera") as Camera3D
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
	selected_character = index
	var s: Survivor = _survivors[index]

	# 1. Update Pedestal lights, neon ring emission, and inner glow discs
	for i in range(_survivors.size()):
		var sel := (i == index)
		if i < _lights.size() and is_instance_valid(_lights[i]):
			_lights[i].light_energy = 2.4 if sel else 0.5
		if i < _disc_mats.size():
			var mult: float = 3.4 if sel else 0.85
			_disc_mats[i].albedo_color = _survivors[i].color * (2.4 if sel else 1.2)
			_disc_mats[i].emission_energy_multiplier = mult
		if i < _inner_mats.size():
			_inner_mats[i].albedo_color = Color(
				_survivors[i].color.r,
				_survivors[i].color.g,
				_survivors[i].color.b,
				0.38 if sel else 0.10
			)
		if i < _col_buttons.size() and is_instance_valid(_col_buttons[i]):
			_style_card(_col_buttons[i], _survivors[i].color, sel)

	# 2. Boost active prop lights (controller, syringe, ring light)
	for pl in _prop_lights:
		if is_instance_valid(pl):
			var active_prop := pl.name.ends_with(s.id)
			pl.light_energy = 2.2 if active_prop else 0.5

	# 3. Idle animations: selected survivor gets unique active idle, unselected stay in neutral idle
	for i in range(_anim_players.size()):
		var ap: AnimationPlayer = _anim_players[i]
		if ap == null or not is_instance_valid(ap):
			continue
		if i == index:
			_play_active_idle(i)
		else:
			if ap.has_animation("idle"):
				ap.play("idle")

	# 4. Update UI label and skin selector
	if _name_label != null:
		_name_label.text = s.display_name
		_name_label.add_theme_color_override("font_color", s.color)
		_name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 0.95))
		_name_label.add_theme_constant_override("outline_size", _fs(8))

	var active_skin := _get_current_skin(s.id)
	_update_skin_ui(s, active_skin)
	if index < _models.size() and is_instance_valid(_models[index]):
		BlockyAnim.apply_skin_variant(_models[index], s.id, active_skin)

	# 5. Dynamic Camera Tween: adjust angle/focal distance toward selected survivor smoothly
	_tween_camera_to_survivor(index)

	# 6. Audio: clean selection chime + click
	if play_sound:
		_play_selection_audio(index)

	# 7. Persist selection to SaveManager
	if persist and has_node("/root/Save"):
		var save_mgr = get_node("/root/Save")
		save_mgr.set_selected_character(s.id)


func _tween_camera_to_survivor(index: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = get_node_or_null("Background3D/Camera") as Camera3D
	if cam == null:
		return

	var s: Survivor = _survivors[index]
	# Keep the camera centered on the whole 5-character group — no horizontal
	# drift toward the selected survivor, or the row looks off-center. Only a
	# whisper of depth change for focus.
	var target_cam_pos := Vector3(0.0, 1.40, 2.05)
	var target_look := Vector3(0.0, 0.92, -2.2)

	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()

	_is_camera_tweening = true
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.disabled = true

	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(cam, "global_position", target_cam_pos, 0.42)

	# Smooth camera angle slerp
	var start_rot := cam.quaternion
	var dummy := Transform3D(Basis(), target_cam_pos)
	dummy = dummy.looking_at(target_look, Vector3.UP)
	var end_rot := dummy.basis.get_rotation_quaternion()

	_cam_tween.tween_method(func(w: float) -> void:
		if cam != null and is_instance_valid(cam):
			cam.quaternion = start_rot.slerp(end_rot, w)
	, 0.0, 1.0, 0.42)

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
