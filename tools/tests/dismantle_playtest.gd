## Reusable Issue #26 full-chain dismantling regression test (tool-tier gate ->
## joint disconnect -> loot -> sole-writer registries -> debris cap -> recycle).
extends SceneTree
## Issue #26 runtime verification — the full dismantling chain headless.
## Verified premises (from curated specs lane_code_dismantle.md / lane_claude_gdd26.md):
##  * DismantleComponent is a STATELESS world actor (no save ownership).
##  * CollectionManager is the SOLE writer; CollectionLog/Bestiary are read-only facades.
##  * No real-time CSG: joint disconnect = visibility/instance swap only.
##  * DebrisPool enforces a global MAX_ACTIVE cap.

var _detached_parts: Array = []
var _dismantled_signal: Array = []
var _despawned: bool = false


func _initialize() -> void:
	for _i in range(4):
		await process_frame

	var cm: Node = root.get_node_or_null("CollectionManager")
	var save: Node = root.get_node_or_null("Save")
	var pool: Node = root.get_node_or_null("DebrisPool")
	var clog: Node = root.get_node_or_null("CollectionLog")
	var best: Node = root.get_node_or_null("Bestiary")
	print("AUTOLOADS cm=", cm != null, " save=", save != null, " pool=", pool != null, " clog=", clog != null, " best=", best != null)

	# Build a runtime PackedScene for split parts (stands in for the pre-authored GLB).
	var part_root: Node3D = Node3D.new()
	part_root.name = "SplitPart"
	var ps: PackedScene = PackedScene.new()
	ps.pack(part_root)
	part_root.free()

	# Assemble a dismantlable prop.
	var prop: Node3D = Node3D.new()
	prop.name = "Prop"
	root.add_child(prop)
	var intact: MeshInstance3D = MeshInstance3D.new()
	intact.name = "Intact"
	prop.add_child(intact)
	var joint_a: Marker3D = Marker3D.new()
	joint_a.name = "JointA"
	prop.add_child(joint_a)
	var joint_b: Marker3D = Marker3D.new()
	joint_b.name = "JointB"
	prop.add_child(joint_b)
	var loot: LootTable = LootTable.new()
	loot.name = "LootTable"
	prop.add_child(loot)

	var dc: DismantleComponent = DismantleComponent.new()
	dc.name = "DismantleComponent"
	dc.prop_asset_id = "scav_gravestone_broken"
	dc.bestiary_id = "zombie_pig_butcher"
	dc.hitpoints = 20.0
	dc.required_tool_tier = 2
	dc.intact_mesh_path = ^"../Intact"
	var markers: Array[NodePath] = []
	markers.assign([^"../JointA", ^"../JointB"])
	dc.joint_markers = markers
	dc.split_parts_scene = ps
	dc.loot_table_path = ^"../LootTable"
	dc.loot_table_id = "grave_stone"
	dc.despawn_delay = 0.0
	dc.max_debris_per_prop = 6
	prop.add_child(dc)

	dc.part_detached.connect(_on_part_detached)
	dc.dismantled.connect(_on_dismantled)
	dc.despawned.connect(_on_despawned)
	await process_frame

	# 1) Tool-tier gate: tier 1 must be a no-op ("clink").
	var blocked: bool = dc.apply_damage(10.0, 1)
	var hp_at_gate: float = dc.current_hp()
	print("TIER_GATE_BLOCKED=", not blocked, " HP_UNCHANGED=", hp_at_gate == 20.0)

	# 2) Valid-tier hits deplete it.
	var h1: bool = dc.apply_damage(10.0, 2)
	var h2: bool = dc.apply_damage(10.0, 2)
	print("DEPLETED=", dc.is_depleted(), " HITS=", h1 and h2)

	# 3) Joint disconnect: intact mesh hidden (NO CSG), parts detached + spawned.
	print("INTACT_HIDDEN=", not intact.visible)
	print("PARTS_DETACHED=", _detached_parts.size())
	print("DEBRIS_SPAWNED=", dc.spawned_debris_count())

	# 4) Loot descriptor from dismantle_tables.json.
	var ld: Array = dc.loot_descriptor()
	print("LOOT_DESCRIPTOR=", ld.size(), " id=", ld[0].get("loot_table_id", "?") if ld.size() > 0 else "none")

	# 5) Signals fired.
	print("DISMANTLED_SIGNAL=", _dismantled_signal.size(), " despawned=", _despawned)

	# 6) CollectionManager SOLE WRITER recorded both registries, persisted to Save.
	var props: Dictionary = cm.get_dismantled_props()
	var bes: Dictionary = cm.get_bestiary()
	var saved_props: bool = save.save_data.has("dismantled_props")
	var saved_best: bool = save.save_data.has("bestiary")
	print("REGISTRY_PROP=", props.has("scav_gravestone_broken"), " REGISTRY_BESTIARY=", bes.has("zombie_pig_butcher"))
	print("SAVE_KEYS=", saved_props and saved_best)

	# 7) Read-only facades reflect the write; bonuses derived at read time.
	var union: Dictionary = clog.union()
	var b_kills: int = best.kills("zombie_pig_butcher")
	var bonuses: Dictionary = cm.get_bonuses()
	print("FACADE_UNION_HAS_PROP=", union.has("scav_gravestone_broken"), " BESTIARY_KILLS=", b_kills)
	print("FACADE_NO_WRITER=", not clog.has_method("record_item"))
	print("BONUSES_KEYS=", bonuses.keys())

	# 8) DebrisPool global cap — acquire more than MAX_ACTIVE.
	for _j in range(60):
		pool.acquire(ps, Vector3.ZERO)
	var capped: bool = pool.active_count() <= 48
	print("POOL_ACTIVE=", pool.active_count(), " CAPPED=", capped)
	pool.recycle_all([])

	# 9) Recycle resets the component (pooled reuse).
	var was_depleted: bool = dc.is_depleted()
	dc.recycle()
	print("RECYCLE_RESET=", not dc.is_depleted() and dc.current_hp() == 20.0)

	var ok: bool = (cm != null and save != null and pool != null and clog != null and best != null
	    and not blocked and hp_at_gate == 20.0 and h1 and h2 and was_depleted
		and not intact.visible and _detached_parts.size() == 2 and _dismantled_signal.size() == 1
		and _despawned and props.has("scav_gravestone_broken") and bes.has("zombie_pig_butcher")
		and saved_props and saved_best and union.has("scav_gravestone_broken") and b_kills == 1
		and capped)
	print("GDD26_PASS=", ok)
	quit(0 if ok else 1)


func _on_part_detached(part_id: String) -> void:
	_detached_parts.append(part_id)


func _on_dismantled(prop_asset_id: String, loot: Array) -> void:
	_dismantled_signal.append({"id": prop_asset_id, "loot": loot})


func _on_despawned() -> void:
	_despawned = true
