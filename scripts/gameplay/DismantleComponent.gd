class_name DismantleComponent
extends Node
## Attachable, STATELESS dismantling driver (GDD §2 / §6 / §7).
##
## Hits gate on tool tier; depletion swaps to PRE-AUTHORED split-part meshes
## (joint disconnect, NOT real-time CSG / boolean / fracture), rolls loot via
## the existing LootTable, records the prop/entity into CollectionManager (the
## SOLE writer), and returns debris to DebrisPool on a pooled despawn timer.
##
## The art dependency (pre-authored split-part GLBs, #9.2) is OPTIONAL here:
## when split_parts_scene is null the intact mesh hides and part_detached still
## fires per joint marker, so the mechanic + state layer work without art.

signal hit(remaining_hp: float, tool_tier: int)
signal dismantled(prop_asset_id: String, loot: Array)
signal part_detached(part_id: String)
signal despawned()

# Identity (catalog-linked, NOT save state).
@export var prop_asset_id: String = ""
@export var bestiary_id: String = ""

# Hitpoints & tool gating (GDD §7).
@export var hitpoints: float = 100.0
@export var required_tool_tier: int = 1

# Joint-disconnect mesh swap (NOT real-time CSG).
@export var intact_mesh_path: NodePath = ^""
@export var split_parts_scene: PackedScene = null
@export var joint_markers: Array[NodePath] = []
@export var detach_impulse: float = 1.2

# Loot-table drops.
@export var loot_table_path: NodePath = ^""
@export var loot_table_id: String = ""

# Pooled despawn + debris cap (GDD §6).
@export var despawn_delay: float = 8.0
@export var max_debris_per_prop: int = 6

var _hp: float = 0.0
var _depleted: bool = false
var _despawn_timer: Timer = null
var _spawned_debris: Array[Node] = []
var _loot_descriptor: Array = []


func _ready() -> void:
	_hp = hitpoints
	_despawn_timer = Timer.new()
	_despawn_timer.one_shot = true
	_despawn_timer.timeout.connect(_on_despawn_timeout)
	add_child(_despawn_timer)


## Returns true if damage was applied. tool_tier < required_tool_tier is a no-op
## ("clink" only) — the GDD §2 tool-tier gate.
func apply_damage(amount: float, tool_tier: int) -> bool:
	if _depleted:
		return false
	if not can_dismantle(tool_tier):
		return false
	_hp = maxf(0.0, _hp - amount)
	hit.emit(_hp, tool_tier)
	if _hp <= 0.0:
		_on_depleted()
	return true


func can_dismantle(tool_tier: int) -> bool:
	return tool_tier >= required_tool_tier


func current_hp() -> float:
	return _hp


func is_depleted() -> bool:
	return _depleted


func loot_descriptor() -> Array:
	return _loot_descriptor.duplicate()


func spawned_debris_count() -> int:
	return _spawned_debris.size()


func _on_depleted() -> void:
	_depleted = true
	_swap_to_split_meshes()
	_loot_descriptor = _roll_and_spawn_loot()
	_record_registries()
	dismantled.emit(prop_asset_id, _loot_descriptor)
	_begin_despawn()


## Disable the intact root mesh and instance the pre-split scene at the joint
## markers. Pure visibility/instance swap — never boolean/CSG/fracture ops.
func _swap_to_split_meshes() -> void:
	var intact: MeshInstance3D = get_node_or_null(intact_mesh_path) as MeshInstance3D
	if intact != null:
		intact.visible = false
		intact.process_mode = Node.PROCESS_MODE_DISABLED
	for marker_path in joint_markers:
		var marker: Marker3D = get_node_or_null(marker_path) as Marker3D
		if marker != null:
			part_detached.emit(String(marker.name))
	if split_parts_scene == null:
		return
	var pool: Node = get_node_or_null("/root/DebrisPool")
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for marker_path in joint_markers:
		var marker: Marker3D = get_node_or_null(marker_path) as Marker3D
		if marker == null:
			continue
		if _spawned_debris.size() >= max_debris_per_prop:
			break
		var acquired: Variant = null
		if pool != null and pool.has_method("acquire"):
			acquired = pool.call("acquire", split_parts_scene, marker.global_position)
		else:
			push_warning("[DismantleComponent] DebrisPool unavailable — fallback debris self-despawns after %ss" % [str(despawn_delay)])
			var inst: Node = split_parts_scene.instantiate()
			parent_node.add_child(inst)
			if inst is Node3D:
				(inst as Node3D).global_position = marker.global_position
			if despawn_delay <= 0.0:
				inst.queue_free()
				acquired = null
			else:
				var t: Timer = Timer.new()
				t.one_shot = true
				t.wait_time = despawn_delay
				t.timeout.connect(_on_fallback_despawn.bind(inst))
				inst.add_child(t)
				t.start()
				acquired = inst
		if acquired is Node:
			_spawned_debris.append(acquired as Node)


func _roll_and_spawn_loot() -> Array:
	var record: Array = []
	var table: LootTable = get_node_or_null(loot_table_path) as LootTable
	var parent3d: Node3D = get_parent() as Node3D
	# Scavenge yield bonus from CollectionManager (capped at 0.5 by CollectionManager).
	var scavenge_bonus: float = 0.0
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm != null and cm.has_method("get_bonuses"):
		var bonuses: Dictionary = cm.call("get_bonuses")
		if bonuses.has("scavenge_yield_bonus"):
			scavenge_bonus = float(bonuses["scavenge_yield_bonus"])
	if table != null and parent3d != null:
		# Apply scavenge yield bonus by rolling extra drops.
		# Bonus is capped at 0.5 (50% extra), so max 1 extra drop per roll.
		var extra_rolls: int = int(scavenge_bonus * 2.0)  # 0.5 -> 1 extra roll
		table.spawn_drops(parent3d.global_position)
		for _roll_index in range(extra_rolls):
			table.spawn_drops(parent3d.global_position)
	# Deterministic descriptor from the asset-id-keyed dismantle table (NOT the
	# random world drops): what CollectionLog / Bestiary display.
	var entry: Dictionary = _table_entry()
	if not entry.is_empty():
		record.append(entry)
	return record


func _table_entry() -> Dictionary:
	if loot_table_id.is_empty():
		return {}
	var path: String = "res://assets/data/dismantle_tables.json"
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var tables: Variant = (parsed as Dictionary).get("tables", {})
	if not tables is Dictionary:
		return {}
	var entry: Variant = (tables as Dictionary).get(loot_table_id, {})
	var out: Dictionary = {}
	if entry is Dictionary:
		out = (entry as Dictionary).duplicate(true)
	out["asset_id"] = prop_asset_id
	out["loot_table_id"] = loot_table_id
	out["tool_tier"] = required_tool_tier
	return out


## The ONE integration point with persistence: never touches /root/Save and
## never owns registry dictionaries. CollectionManager is the sole writer.
func _record_registries() -> void:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null:
		return
	if not prop_asset_id.is_empty() and cm.has_method("record_dismantle"):
		cm.call("record_dismantle", prop_asset_id, required_tool_tier)
	if not bestiary_id.is_empty() and cm.has_method("record_defeat"):
		cm.call("record_defeat", bestiary_id)
	# Aggregate deterministic loot ids before passing them to the sole writer.
	var loot_counts: Dictionary = {}
	for entry in _loot_descriptor:
		if entry is Dictionary and entry.has("drops"):
			var drops: Array = entry["drops"]
			for drop in drops:
				var item_id: String = ""
				var count: int = 1
				if drop is Dictionary and drop.has("item_id"):
					item_id = String(drop["item_id"])
					if drop.has("count"):
						count = int(drop["count"])
				elif drop is String:
					item_id = String(drop)
				if not item_id.is_empty():
					loot_counts[item_id] = int(loot_counts.get(item_id, 0)) + count
	if cm.has_method("record_item"):
		for item_id in loot_counts:
			cm.call("record_item", String(item_id), int(loot_counts[item_id]))


func _begin_despawn() -> void:
	if despawn_delay <= 0.0:
		_on_despawn_timeout()
		return
	_despawn_timer.start(despawn_delay)


## Recycle, do NOT queue_free. DebrisPool.MAX_ACTIVE enforces the global cap.
func _on_despawn_timeout() -> void:
	var pool: Node = get_node_or_null("/root/DebrisPool")
	if pool != null and pool.has_method("recycle_all"):
		pool.call("recycle_all", _spawned_debris)
	_spawned_debris.clear()
	despawned.emit()


func _on_fallback_despawn(node: Node) -> void:
	"""Self-despawn for fallback debris when DebrisPool cannot recycle it."""
	if is_instance_valid(node):
		node.queue_free()


func recycle() -> void:
	_hp = hitpoints
	_depleted = false
	_loot_descriptor.clear()
	_spawned_debris.clear()
