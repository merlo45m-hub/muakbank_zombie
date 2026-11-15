extends Node

## CollectionManager (autoload) — sole owner/writer of the collection state.
## Reads and writes the game_collection_* / game_museum_* save keys via Save.
## Subscribes to #11 WorldProgression signals only when that autoload exists;
## until #11 Phase 1 lands, this holds whatever the save file contains and never
## invents a competing signal set (canonical contract: COLLECTION-MUSEUM-PROGRESS-SPEC.md §4).

var _items: Dictionary = {}
var _regions: Dictionary = {}
var _seen: Array = []


func _ready() -> void:
	_load()
	_wire_progression()


func _load() -> void:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return
	var raw_items = save.save_data.get("collection_items", {})
	var raw_regions = save.save_data.get("collection_regions", {})
	var raw_seen = save.save_data.get("museum_seen", [])
	if raw_items is Dictionary:
		_items = raw_items.duplicate(true)
	if raw_regions is Dictionary:
		_regions = raw_regions.duplicate(true)
	if raw_seen is Array:
		_seen = raw_seen.duplicate()
	# Seed the 3 known region ids (LevelManager.environments) on first run.
	for id in [1, 2, 3]:
		if not _regions.has(id):
			_regions[id] = RegionStat.from_dict({"region_id": id}).to_dict()


func _persist() -> void:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return
	save.save_data["collection_items"] = _items.duplicate(true)
	save.save_data["collection_regions"] = _regions.duplicate(true)
	save.save_data["museum_seen"] = _seen.duplicate()
	save.save_data["museum_version"] = 2
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
