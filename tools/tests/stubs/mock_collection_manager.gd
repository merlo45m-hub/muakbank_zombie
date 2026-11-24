## mock_collection_manager.gd — Test double for CollectionManager (issue #84).
## Mirrors CollectionManager.get_bonuses() determinism without /root/Save or
## WorldProgression wiring, so a headless SceneTree probe can control
## registrations directly and observe the bonus effect sink.
extends Node

var _dismantled: Dictionary = {}
var _bestiary: Dictionary = {}

func record_dismantle(prop_asset_id: String, tool_tier: int = 1) -> void:
	if prop_asset_id.is_empty():
		return
	var entry: Variant = _dismantled.get(prop_asset_id, {})
	if not entry is Dictionary:
		entry = {}
	entry["qty"] = int(entry.get("qty", 0)) + 1
	if not entry.has("first_tier"):
		entry["first_tier"] = tool_tier
	_dismantled[prop_asset_id] = entry

func record_defeat(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var entry: Variant = _bestiary.get(entity_id, {})
	if not entry is Dictionary:
		entry = {}
	entry["kills"] = int(entry.get("kills", 0)) + 1
	entry["first_seen"] = true
	_bestiary[entity_id] = entry

func clear() -> void:
	_dismantled.clear()
	_bestiary.clear()

## Deterministic bonus sink (mirrors CollectionManager.get_bonuses):
## scavenge_yield_bonus gates dismantle loot yield; bestiary_power_bonus
## gates player damage. Never stored; derived from registrations at read time.
func get_bonuses() -> Dictionary:
	var unique_props: int = _dismantled.size()
	var total_kills: int = 0
	for key in _bestiary:
		var entry: Variant = _bestiary.get(key)
		if entry is Dictionary:
			total_kills += int((entry as Dictionary).get("kills", 0))
	return {
		"scavenge_yield_bonus": clampf(float(unique_props) * 0.02, 0.0, 0.5),
		"bestiary_power_bonus": clampf(float(total_kills) * 0.01, 0.0, 0.5),
		"total_props": unique_props,
		"total_kills": total_kills,
		"recipes_unlocked": unique_props >= 5,
	}
