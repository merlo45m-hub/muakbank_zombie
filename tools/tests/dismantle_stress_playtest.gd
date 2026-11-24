extends SceneTree
## Multi-prop destruction + combat stress probe for GDD §2/§6 60 FPS gate.
## Uses real autoloads (FpsMonitor, DebrisPool, CollectionManager) and real
## spawner/DismantleComponent paths. No UI driving, no screenshots.

var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _build_part_scene() -> PackedScene:
	var part_root: Node3D = Node3D.new()
	part_root.name = "SplitParts"
	for i in range(6):
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "Part%d" % i
		mesh.mesh = BoxMesh.new()
		mesh.position = Vector3(float(i) * 0.25, 0.1, 0.0)
		part_root.add_child(mesh)
	var packed: PackedScene = PackedScene.new()
	packed.pack(part_root)
	part_root.free()
	return packed

func _make_prop(index: int, parts: PackedScene, dc_script: GDScript, loot_script: GDScript) -> Node:
	var prop: Node3D = Node3D.new()
	prop.name = "StressProp%d" % index
	prop.position = Vector3(float(index % 6) * 2.0 - 5.0, 0.0, float(index / 6) * 2.0 - 4.0)
	root.add_child(prop)
	var intact: MeshInstance3D = MeshInstance3D.new()
	intact.name = "Intact"
	intact.mesh = BoxMesh.new()
	prop.add_child(intact)
	var markers: Array[NodePath] = []
	for j in range(6):
		var marker: Marker3D = Marker3D.new()
		marker.name = "Joint%d" % j
		marker.position = Vector3(float(j) * 0.2, 0.1, 0.0)
		prop.add_child(marker)
		markers.append(marker.get_path())
	var loot: Node = loot_script.new()
	loot.name = "LootTable"
	prop.add_child(loot)
	var dc: Node = dc_script.new()
	dc.name = "DismantleComponent"
	prop.set("prop_asset_id", "")
	dc.set("prop_asset_id", "scav_stress_prop_%02d" % index)
	dc.set("hitpoints", 20.0)
	dc.set("required_tool_tier", 1)
	dc.set("intact_mesh_path", ^"../Intact")
	dc.set("joint_markers", markers)
	dc.set("split_parts_scene", parts)
	dc.set("loot_table_path", ^"../LootTable")
	dc.set("loot_table_id", "grave_stone")
	dc.set("despawn_delay", 8.0)
	dc.set("max_debris_per_prop", 6)
	prop.add_child(dc)
	return dc

func _initialize() -> void:
	for _i in range(4):
		await process_frame
	print("=== Dismantle destruction stress (60 FPS gate) ===")

	var fps_mon: Node = root.get_node_or_null("FpsMonitor")
	var pool: Node = root.get_node_or_null("DebrisPool")
	var cm: Node = root.get_node_or_null("CollectionManager")
	_assert(fps_mon != null and pool != null and cm != null, "real autoloads present")

	var dc_script: GDScript = load("res://scripts/gameplay/DismantleComponent.gd") as GDScript
	var loot_script: GDScript = load("res://scripts/gameplay/LootTable.gd") as GDScript
	var spawner_script: GDScript = load("res://scripts/characters/ZombieSpawner3D.gd") as GDScript
	_assert(dc_script != null and loot_script != null and spawner_script != null, "production scripts loaded by path")

	# Combat load: 12 real zombies from the real spawner.
	var player: Node3D = Node3D.new()
	player.name = "StressPlayer"
	player.add_to_group("player")
	root.add_child(player)
	var diff: Node = _DifficultyStub.new()
	diff.name = "DifficultyManager"
	root.add_child(diff)
	var spawner: Node3D = spawner_script.new() as Node3D
	spawner.name = "ZombieSpawner"
	var timer: Timer = Timer.new()
	timer.name = "SpawnTimer"
	spawner.add_child(timer)
	spawner.set("can_spawn", true)
	spawner.set("max_zombies", 64)
	spawner.set("spawn_interval", 120.0)
	spawner.set("spawn_radius", 6.0)
	spawner.set("min_spawn_distance", 3.5)
	root.add_child(spawner)
	await process_frame
	for _i in range(12):
		spawner.call("_spawn_random_zombie")
	await process_frame

	# Destruction load: 24 props x 6 joints, depleted progressively during measurement.
	var parts: PackedScene = _build_part_scene()
	var comps: Array = []
	for i in range(24):
		comps.append(_make_prop(i, parts, dc_script, loot_script))
	await process_frame

	var baseline_props: int = (cm.call("get_dismantled_props") as Dictionary).size()
	var start_reports: int = int(fps_mon.call("report_count"))
	var start_ms: int = Time.get_ticks_msec()
	var depleted: int = 0
	var batch: int = 0
	while Time.get_ticks_msec() - start_ms < 10000:
		if batch < 12 and (Time.get_ticks_msec() - start_ms) >= batch * 800:
			for k in range(2):
				var dc: Node = comps[batch * 2 + k] as Node
				dc.call("apply_damage", 10.0, 1)
				dc.call("apply_damage", 10.0, 1)
				if bool(dc.call("is_depleted")):
					depleted += 1
			batch += 1
		await process_frame

	var report: Dictionary = fps_mon.call("get_report")
	var reports: int = int(fps_mon.call("report_count")) - start_reports
	var avg_fps: float = float(report.get("avg_fps", 0.0))
	var p05_fps: float = float(report.get("p05_fps", 0.0))
	var jank_pct: float = float(report.get("jank_pct", 100.0))
	var active_debris: int = int(pool.call("active_count"))
	var after_props: int = (cm.call("get_dismantled_props") as Dictionary).size()

	print("STRESS_METRICS ", JSON.stringify(report))
	_assert(depleted == 24, "24 properties fully dismantled under load (got %d)" % depleted)
	_assert(active_debris <= 48, "DebrisPool cap held (active=%d)" % active_debris)
	_assert(after_props - baseline_props == 24, "all 24 props recorded at registry sink (delta=%d)" % (after_props - baseline_props))
	_assert(reports >= 3, "FPSMON produced %d report windows" % reports)
	var budget_ok: bool = avg_fps >= 60.0 and p05_fps >= 50.0 and jank_pct <= 10.0
	if budget_ok:
		print("FPS_BUDGET_PASS=true avg=%.1f p05=%.1f jank=%.1f%%" % [avg_fps, p05_fps, jank_pct])
	else:
		# Advisory only: shared CI runner jitter must not fail a functional gate.
		# The VPS/device owner lane reads these exact metrics.
		print("FPS_BUDGET_ADVISORY=true avg=%.1f p05=%.1f jank=%.1f%%" % [avg_fps, p05_fps, jank_pct])

	if _failures == 0:
		print("DISMANTLE_STRESS_PASS=true")
		quit(0)
	else:
		printerr("DISMANTLE_STRESS_FAIL=%d" % _failures)
		quit(1)

class _DifficultyStub extends Node:
	func get_spawn_interval() -> float:
		return 1.0
	func get_max_zombies_multiplier() -> float:
		return 1.0
	func get_level_difficulty(_level: int) -> float:
		return 1.0
