extends SceneTree
## GDD gap probe: volumetric fog must be OFF at the default (MOBILE, tier 0) quality tier.
## Measures: VinylLookController default tier, game.tscn VinylLook tier, tunable_baseline
## quality_tier, runtime Environment state after default apply_tier, and shipped
## scene/resource text for any volumetric_fog_enabled = true.

const VINYL_PATH: String = "res://scripts/world/VinylLookController.gd"
const GAME_SCENE: String = "res://scenes/main/game.tscn"
const BASELINE_PATH: String = "res://resources/world/tunable_baseline.json"
const SCAN_ROOTS: Array[String] = ["res://scenes", "res://resources"]
const EXTRA_FILES: Array[String] = ["res://default_env.tres"]
const WE_NAME: String = "FogProbeWE"


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out)
			elif entry.ends_with(".tscn") or entry.ends_with(".tres"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _fail(reason: String) -> void:
	push_error("FOG_PROBE FAIL: " + reason)
	print("FOG_DEFAULT_PROBE_PASS=false")
	quit(1)


func _initialize() -> void:
	print("--- BEGIN FOG DEFAULT-OFF PROBE ---")

	var vinyl_script: GDScript = load(VINYL_PATH) as GDScript
	if vinyl_script == null:
		_fail("cannot load " + VINYL_PATH)
		return

	# 1. Script default tier + enum value for MOBILE
	var consts: Dictionary = vinyl_script.get_script_constant_map()
	var tier_enum: Dictionary = consts.get("QualityTier", {}) as Dictionary
	var mobile_val: int = int(tier_enum.get("MOBILE", -1))
	var ctrl: Node = vinyl_script.new() as Node
	if ctrl == null:
		_fail("VinylLookController did not instantiate as Node")
		return
	var default_tier: int = int(ctrl.get("tier"))
	print("measured: script default tier=%d MOBILE enum=%d" % [default_tier, mobile_val])
	if mobile_val != 0 or default_tier != mobile_val:
		_fail("default tier %d != MOBILE(0) (enum=%d)" % [default_tier, mobile_val])
		return

	# 2. Shipped game.tscn VinylLook node tier (no instantiation)
	var packed: PackedScene = load(GAME_SCENE) as PackedScene
	if packed == null:
		_fail("cannot load " + GAME_SCENE)
		return
	var state: SceneState = packed.get_state()
	var scene_tier: int = -1
	for node_idx in range(state.get_node_count()):
		if state.get_node_name(node_idx) != "VinylLook":
			continue
		for prop_idx in range(state.get_node_property_count(node_idx)):
			if state.get_node_property_name(node_idx, prop_idx) == "tier":
				scene_tier = int(state.get_node_property_value(node_idx, prop_idx))
	print("measured: game.tscn VinylLook tier=%d" % scene_tier)
	if scene_tier != 0:
		_fail("game.tscn VinylLook tier=%d (expected 0)" % scene_tier)
		return

	# 3. tunable_baseline.json presentation.quality_tier
	var baseline_text: String = FileAccess.get_file_as_string(BASELINE_PATH)
	var parsed: Variant = JSON.parse_string(baseline_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("cannot parse " + BASELINE_PATH)
		return
	var sections: Dictionary = (parsed as Dictionary).get("sections", {}) as Dictionary
	var presentation: Dictionary = sections.get("presentation", {}) as Dictionary
	var baseline_tier: int = int(presentation.get("quality_tier", -1))
	print("measured: tunable_baseline quality_tier=%d" % baseline_tier)
	if baseline_tier != 0:
		_fail("tunable_baseline quality_tier=%d (expected 0)" % baseline_tier)
		return

	# 4. Runtime: start with volumetric fog forced ON, let the default tier apply, expect OFF
	var env: Environment = Environment.new()
	env.volumetric_fog_enabled = true
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = WE_NAME
	world_env.environment = env
	root.add_child(world_env)
	ctrl.set("environment_path", NodePath("/root/" + WE_NAME))
	root.add_child(ctrl)
	for _frame in range(3):
		await process_frame
	var fog_on: bool = env.volumetric_fog_enabled
	var fog_density: float = env.volumetric_fog_density
	var is_high: bool = bool(ctrl.call("is_high"))
	print("measured: after default apply volumetric_fog_enabled=%s density=%.4f is_high=%s" % [str(fog_on), fog_density, str(is_high)])
	if fog_on or is_high:
		_fail("default tier left volumetric fog enabled")
		return

	# 5. Gate is real: HIGH turns it on, back to MOBILE turns it off
	ctrl.call("apply_tier", 1)
	var high_on: bool = env.volumetric_fog_enabled
	ctrl.call("apply_tier", mobile_val)
	var back_off: bool = not env.volumetric_fog_enabled
	print("measured: HIGH enables=%s, MOBILE re-disables=%s" % [str(high_on), str(back_off)])
	if not high_on or not back_off:
		_fail("tier gate not symmetric (high_on=%s back_off=%s)" % [str(high_on), str(back_off)])
		return

	# 6. No shipped scene/resource enables volumetric fog or references the fog shader
	var files: Array[String] = []
	for scan_root in SCAN_ROOTS:
		_collect(scan_root, files)
	for extra in EXTRA_FILES:
		if FileAccess.file_exists(extra):
			files.append(extra)
	var enabled_hits: Array[String] = []
	var shader_hits: Array[String] = []
	for file_path in files:
		var text: String = FileAccess.get_file_as_string(file_path)
		if text.find("volumetric_fog_enabled = true") != -1:
			enabled_hits.append(file_path)
		if text.find("volumetric_fog.gdshader") != -1:
			shader_hits.append(file_path)
	print("measured: scanned=%d files, volumetric_fog_enabled=true in %d, volumetric_fog.gdshader refs in %d" % [files.size(), enabled_hits.size(), shader_hits.size()])
	if files.is_empty():
		_fail("scanned zero scene/resource files (fail closed)")
		return
	if not enabled_hits.is_empty():
		_fail("volumetric_fog_enabled = true in: " + ", ".join(enabled_hits))
		return
	if not shader_hits.is_empty():
		_fail("volumetric_fog.gdshader referenced by: " + ", ".join(shader_hits))
		return

	ctrl.queue_free()
	world_env.queue_free()
	print("tier=%d volumetric_fog_enabled=%s" % [default_tier, str(fog_on)])
	print("FOG_DEFAULT_PROBE_PASS=true")
	print("--- FOG DEFAULT-OFF PROBE COMPLETED ---")
	await _survivor_probe()


const CHARACTERS_JSON: String = "res://assets/data/rules/characters.json"
const SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const STATS_PATH_FMT: String = "res://assets/materials/stats_%s.tres"
const EXPECTED_SURVIVOR_IDS: Array[String] = ["gamer", "doctor", "nurse", "streamer", "hunter"]
const COLOR_TOLERANCE: float = 0.01
const STAT_TOLERANCE: float = 0.001


func _survivor_fail(reason: String) -> void:
	push_error("SURVIVOR_PROBE FAIL: " + reason)
	print("SURVIVOR_PEDESTAL_PROBE_PASS=false")
	quit(1)


func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOR_TOLERANCE and absf(a.g - b.g) <= COLOR_TOLERANCE and absf(a.b - b.b) <= COLOR_TOLERANCE


func _survivor_probe() -> void:
	print("--- BEGIN SURVIVOR PEDESTAL PROBE ---")
	var problems: Array[String] = []
	var stat_gaps: Array[String] = []

	# 1. characters.json: 5 ids / colors / scenes
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_JSON))
	if typeof(parsed) != TYPE_DICTIONARY:
		_survivor_fail("cannot parse " + CHARACTERS_JSON)
		return
	var entries: Array = (parsed as Dictionary).get("characters", []) as Array
	if entries.size() != 5:
		_survivor_fail("characters.json has %d entries (expected 5)" % entries.size())
		return
	var json_ids: Array[String] = []
	var json_colors: Array[Color] = []
	var json_scenes: Array[String] = []
	for entry_idx in range(entries.size()):
		var entry: Dictionary = entries[entry_idx] as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		var entry_color: Color = Color.html(str(entry.get("color", "")))
		var entry_scene: String = str(entry.get("scene", ""))
		json_ids.append(entry_id)
		json_colors.append(entry_color)
		json_scenes.append(entry_scene)
		if entry_id != EXPECTED_SURVIVOR_IDS[entry_idx]:
			problems.append("json id[%d]=%s expected %s" % [entry_idx, entry_id, EXPECTED_SURVIVOR_IDS[entry_idx]])
		if load(entry_scene) as PackedScene == null:
			problems.append("json scene for %s not loadable: %s" % [entry_id, entry_scene])
	print("measured: json ids=%s colors=%s" % [str(json_ids), str(json_colors)])

	# 2. Character select screen: survivors, models, pedestals
	var select_packed: PackedScene = load(SELECT_SCENE) as PackedScene
	if select_packed == null:
		_survivor_fail("cannot load " + SELECT_SCENE)
		return
	var select_screen: Control = select_packed.instantiate() as Control
	root.add_child(select_screen)
	for _frame in range(4):
		await process_frame

	var survivors: Array = select_screen.get("_survivors") as Array
	var models: Array = select_screen.get("_models") as Array
	var neon_mats: Array = select_screen.get("_pedestal_neon_mats") as Array
	var lights: Array = select_screen.get("_pedestal_lights") as Array
	print("measured: survivors=%d models=%d pedestal_mats=%d pedestal_lights=%d" % [survivors.size(), models.size(), neon_mats.size(), lights.size()])
	if survivors.size() != 5 or models.size() != 5 or neon_mats.size() != 5 or lights.size() != 5:
		_survivor_fail("expected 5 survivors/models/pedestal mats/lights")
		return
	for lane_idx in range(5):
		var survivor: RefCounted = survivors[lane_idx] as RefCounted
		if str(survivor.get("id")) != json_ids[lane_idx]:
			problems.append("select id[%d]=%s json=%s" % [lane_idx, str(survivor.get("id")), json_ids[lane_idx]])
		if str(survivor.get("scene_path")) != json_scenes[lane_idx]:
			problems.append("select scene[%d]=%s json=%s" % [lane_idx, str(survivor.get("scene_path")), json_scenes[lane_idx]])
		if not _color_close(survivor.get("color") as Color, json_colors[lane_idx]):
			problems.append("select color[%d]=%s json=%s" % [lane_idx, str(survivor.get("color")), str(json_colors[lane_idx])])
		var model: Node3D = models[lane_idx] as Node3D
		if model == null or not is_instance_valid(model) or not model.visible:
			problems.append("model[%d] missing or hidden" % lane_idx)
		var neon_mat: StandardMaterial3D = neon_mats[lane_idx] as StandardMaterial3D
		var pedestal_light: OmniLight3D = lights[lane_idx] as OmniLight3D
		if neon_mat == null or pedestal_light == null:
			problems.append("pedestal[%d] material/light missing" % lane_idx)
		elif not _color_close(neon_mat.emission, json_colors[lane_idx]):
			problems.append("pedestal[%d] emission %s != json %s" % [lane_idx, str(neon_mat.emission), str(json_colors[lane_idx])])

	# 3. Selecting each survivor: Save id + pedestal highlight + resolved player stats
	var save: Node = root.get_node_or_null("Save")
	if save == null:
		_survivor_fail("Save autoload missing")
		return
	var original_selection: String = str(save.get("selected_character"))
	for pick_idx in range(5):
		select_screen.call("_select_character", pick_idx, false, true)
		var pick_id: String = json_ids[pick_idx]
		if int(select_screen.get("selected_character")) != pick_idx:
			problems.append("select index %d not applied" % pick_idx)
		if str(save.get("selected_character")) != pick_id:
			problems.append("Save.selected_character=%s after picking %s" % [str(save.get("selected_character")), pick_id])
		for mat_idx in range(5):
			var highlighted: StandardMaterial3D = neon_mats[mat_idx] as StandardMaterial3D
			var is_boosted: bool = highlighted.emission_energy_multiplier >= 2.0
			if is_boosted != (mat_idx == pick_idx):
				problems.append("pedestal %d highlight=%s while %s selected" % [mat_idx, str(is_boosted), pick_id])

		# Player resolves stats_<id>.tres first (Player.gd _ready); json base_stats only feed the fallback.
		var entry_stats: Dictionary = (entries[pick_idx] as Dictionary).get("base_stats", {}) as Dictionary
		var want_health: int = int(entry_stats.get("health", -1))
		var want_speed: float = float(entry_stats.get("speed", -1.0))
		var want_damage: float = float(entry_stats.get("damage", -1.0))
		var stats_path: String = STATS_PATH_FMT % pick_id
		var stats_res: Resource = load(stats_path) as Resource if ResourceLoader.exists(stats_path) else null
		if stats_res == null:
			stat_gaps.append("%s: no %s; Player fallback reads max_health/move_speed keys absent from json (defaults 100/5.0)" % [pick_id, stats_path])
			continue
		var got_health: int = int(stats_res.get("max_health"))
		var got_speed: float = float(stats_res.get("move_speed"))
		var got_damage: float = float(stats_res.get("weapon_damage_multiplier"))
		print("measured: %s json(health=%d speed=%.2f damage=%.2f) player(max_health=%d move_speed=%.2f weapon_damage_multiplier=%.2f)" % [pick_id, want_health, want_speed, want_damage, got_health, got_speed, got_damage])
		if got_health != want_health or absf(got_speed - want_speed) > STAT_TOLERANCE or absf(got_damage - want_damage) > STAT_TOLERANCE:
			stat_gaps.append("%s: json health/speed/damage=%d/%.2f/%.2f vs player stats=%d/%.2f/%.2f" % [pick_id, want_health, want_speed, want_damage, got_health, got_speed, got_damage])

	save.call("set_selected_character", original_selection)
	select_screen.queue_free()

	for problem in problems:
		push_error("SURVIVOR_PROBE: " + problem)
	for gap in stat_gaps:
		push_error("SURVIVOR_STAT_GAP: " + gap)
	if problems.is_empty() and stat_gaps.is_empty():
		print("SURVIVOR_PEDESTAL_PROBE_PASS=true")
		print("--- SURVIVOR PEDESTAL PROBE COMPLETED ---")
		quit(0)
		return
	print("SURVIVOR_PEDESTAL_PROBE_PASS=false problems=%d stat_gaps=%d" % [problems.size(), stat_gaps.size()])
	quit(1)
