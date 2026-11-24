extends Node

## CollectionManager (autoload) — sole owner/writer of the collection state.
## Reads and writes the game_collection_* / game_museum_* save keys via Save.
## Subscribes to #11 WorldProgression signals only when that autoload exists;
## until #11 Phase 1 lands, this holds whatever the save file contains and never
## invents a competing signal set (canonical contract: COLLECTION-MUSEUM-PROGRESS-SPEC.md §4).

var _items: Dictionary = {}
var _regions: Dictionary = {}
var _seen: Array = []
var _dismantled_props: Dictionary = {}
var _bestiary: Dictionary = {}


func _ready() -> void:
	_load()
	_wire_progression()


func _load() -> void:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return
	var raw_items = save.get_registry("collection_items")
	var raw_regions = save.get_registry("collection_regions")
	var raw_seen = save.get_registry("museum_seen")
	if raw_items is Dictionary:
		_items = raw_items.duplicate(true)
	if raw_regions is Dictionary:
		_regions = raw_regions.duplicate(true)
	if raw_seen is Array:
		_seen = raw_seen.duplicate()
	var raw_props = save.get_registry("dismantled_props")
	var raw_bestiary = save.get_registry("bestiary")
	if raw_props is Dictionary:
		_dismantled_props = (raw_props as Dictionary).duplicate(true)
	if raw_bestiary is Dictionary:
		_bestiary = (raw_bestiary as Dictionary).duplicate(true)
	# Seed the 3 known region ids (LevelManager.environments) on first run.
	for id in [1, 2, 3]:
		if not _regions.has(id):
			_regions[id] = RegionStat.from_dict({"region_id": id}).to_dict()

	# Backward-compat: if a save already has a world boss defeated but no catalyst item,
	# seed the catalyst once. No duplicate grants.
	var am := get_node_or_null("/root/AchievementManager")
	if am != null and am.has_method("is_boss_defeated"):
		for world_id in [1, 2, 3]:
			if am.is_boss_defeated(world_id):
				var cid = CureCatalysts.get_catalyst_id_for_world(world_id)
				if not _items.has(cid) or int(_items.get(cid, 0)) <= 0:
					_items[cid] = 1
					if not _seen.has(cid):
						_seen.append(cid)
		_persist()


func _persist() -> void:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return
	save.set_registry("collection_items", _items.duplicate(true))
	save.set_registry("collection_regions", _regions.duplicate(true))
	save.set_registry("museum_seen", _seen.duplicate())
	save.set_registry("museum_version", 2)
	save.set_registry("dismantled_props", _dismantled_props.duplicate(true))
	save.set_registry("bestiary", _bestiary.duplicate(true))
	save.save_game()


func record_item(asset_id: String, quantity: int = 1) -> void:
	if asset_id.is_empty():
		return
	_items[asset_id] = int(_items.get(asset_id, 0)) + quantity
	if not _seen.has(asset_id):
		_seen.append(asset_id)
	_persist()


func get_items() -> Dictionary:
	return _items.duplicate(true)


func get_regions() -> Dictionary:
	return _regions.duplicate(true)


func get_seen() -> Array:
	return _seen.duplicate()


func is_seen(asset_id: String) -> bool:
	return _seen.has(asset_id)


func _wire_progression() -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp == null:
		return
	if wp.has_signal("tech_collected") and not wp.tech_collected.is_connected(_on_tech_collected):
		wp.tech_collected.connect(_on_tech_collected)
	if wp.has_signal("milestone_reached") and not wp.milestone_reached.is_connected(_on_milestone_reached):
		wp.milestone_reached.connect(_on_milestone_reached)


func _on_tech_collected(region_id: int, tech_id: StringName, new_count: int, required: int) -> void:
	record_item(String(tech_id))


func _on_milestone_reached(region_id: int, milestone_id: StringName) -> void:
	var d = _regions.get(region_id, {})
	if d is Dictionary:
		var s := RegionStat.from_dict(d)
		s.milestones_done += 1
		_regions[region_id] = s.to_dict()
		_persist()


# ── GDD-2 (#26) registries — CollectionManager remains the SOLE writer ──────

func record_dismantle(prop_asset_id: String, tool_tier: int = 1) -> void:
	if prop_asset_id.is_empty():
		return
	var entry: Dictionary = {}
	var existing: Variant = _dismantled_props.get(prop_asset_id, {})
	if existing is Dictionary:
		entry = (existing as Dictionary).duplicate(true)
	entry["qty"] = int(entry.get("qty", 0)) + 1
	if not entry.has("first_tier"):
		entry["first_tier"] = tool_tier
	_dismantled_props[prop_asset_id] = entry
	_persist()


func record_defeat(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var entry: Dictionary = {}
	var existing: Variant = _bestiary.get(entity_id, {})
	if existing is Dictionary:
		entry = (existing as Dictionary).duplicate(true)
	entry["kills"] = int(entry.get("kills", 0)) + 1
	entry["first_seen"] = true
	if not entry.has("lore"):
		entry["lore"] = false
	_bestiary[entity_id] = entry
	_persist()


func consume_item(asset_id: String, qty: int = 1) -> bool:
	if asset_id.is_empty() or qty <= 0:
		return false
	var current: int = int(_items.get(asset_id, 0))
	if current < qty:
		return false
	_items[asset_id] = current - qty
	if _items[asset_id] <= 0:
		_items.erase(asset_id)
	_persist()
	return true


func get_dismantled_props() -> Dictionary:
	return _dismantled_props.duplicate(true)


func get_bestiary() -> Dictionary:
	return _bestiary.duplicate(true)


## Derived deterministically at read time — NEVER stored (no rival state cache).
func get_bonuses() -> Dictionary:
	var unique_props: int = _dismantled_props.size()
	var total_props: int = 0
	for key in _dismantled_props:
		var e: Variant = _dismantled_props.get(key)
		if e is Dictionary:
			total_props += int((e as Dictionary).get("qty", 0))
	var total_kills: int = 0
	for key2 in _bestiary:
		var e2: Variant = _bestiary.get(key2)
		if e2 is Dictionary:
			total_kills += int((e2 as Dictionary).get("kills", 0))
	return {
		"scavenge_yield_bonus": minf(0.5, float(unique_props) * 0.02),
		"bestiary_power_bonus": minf(0.5, float(total_kills) * 0.01),
		"total_props": total_props,
		"unique_props": unique_props,
		"total_kills": total_kills,
		"recipes_unlocked": unique_props >= 5,
	}
