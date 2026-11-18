extends SceneTree
## tools/gen_regions.gd — regenerates res://resources/world/regions.tres.
## Run: godot --headless --path . --script tools/gen_regions.gd

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://resources/world")
	var catalog := RegionCatalog.new()
	var rows := [
		# spawn_point mirrors Game.gd SPAWN_HINTS (level-local, ground-probed).
		# ZERO would drop the player at the world origin INSIDE level geometry —
		# the exact catastrophe documented in Game.gd's SPAWN_HINTS comment.
		[1, "Suburban", "res://scenes/world/environment/old_town_enhanced.tscn", 1, 0, 0, [], 0, Vector3(-14.0, 0.15, -14.0)],
		[2, "Industrial", "res://scenes/world/environment/industrial_district.tscn", 2, 3, 2, [StringName("first_shift"), StringName("boss_defeated")], 1, Vector3(0.0, 0.15, 0.0)],
		[3, "Bio-Lab", "res://scenes/world/environment/endgame_heights.tscn", 3, 5, 3, [StringName("survivors_saved"), StringName("extraction_ready")], 2, Vector3(0.0, 0.15, 0.0)],
	]
	for row in rows:
		var def := RegionDef.new()
		def.id = int(row[0]); def.display_name = String(row[1]); def.scene_path = String(row[2])
		def.loot_tier = int(row[3]); def.tech_required = int(row[4])
		def.transport_parts_required = int(row[5])
		var ms: Array[StringName] = []
		ms.assign(row[6]); def.milestones_required = ms
		def.prerequisite_region = int(row[7]); def.spawn_point = row[8]
		catalog.regions.append(def)
	var err := ResourceSaver.save(catalog, "res://resources/world/regions.tres")
	print("GEN_REGIONS_ERR=", err)
	# read back
	var loaded := load("res://resources/world/regions.tres") as RegionCatalog
	if loaded == null:
		print("READBACK_FAIL"); quit(1); return
	print("READBACK_IDS=", loaded.ids())
	for i in loaded.ids():
		var d := loaded.get_def(i)
		print("DEF ", d.id, " ", d.display_name, " tier=", d.loot_tier, " tech=", d.tech_required, " prereq=", d.prerequisite_region, " ms=", d.milestones_required.size())
	quit(0)
