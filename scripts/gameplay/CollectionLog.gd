extends Node
## CollectionLog (autoload) — READ-ONLY facade over CollectionManager.
## Owns no state, never references /root/Save, never calls save_game().
## Mirrors ProgressTracker.gd. Sole writer is still CollectionManager.


func all_items() -> Dictionary:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_items"):
		return {}
	var d: Variant = cm.call("get_items")
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}


func dismantled_props() -> Dictionary:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_dismantled_props"):
		return {}
	var d: Variant = cm.call("get_dismantled_props")
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}


func regions() -> Dictionary:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_regions"):
		return {}
	var d: Variant = cm.call("get_regions")
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}


func seen() -> Array:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_seen"):
		return []
	var a: Variant = cm.call("get_seen")
	if a is Array:
		return (a as Array).duplicate()
	return []


func bonuses() -> Dictionary:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_bonuses"):
		return {}
	var d: Variant = cm.call("get_bonuses")
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}


## Union of collection_items (loot/tech) + dismantled_props (core props) +
## museum_seen, keyed by asset id (GDD §5 Collection Log / Bestiary Synergy).
func union() -> Dictionary:
	var out: Dictionary = {}
	for k in all_items().keys():
		out[k] = {"kind": "loot"}
	for k in dismantled_props().keys():
		out[k] = {"kind": "prop"}
	for a in seen():
		out[String(a)] = {"kind": "museum"}
	return out
