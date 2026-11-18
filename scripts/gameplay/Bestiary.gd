extends Node
## Bestiary (autoload) — READ-ONLY facade over CollectionManager.bestiary.
## Owns no state, never references /root/Save. Mirrors ProgressTracker.gd.


func registry() -> Dictionary:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_bestiary"):
		return {}
	var d: Variant = cm.call("get_bestiary")
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}


func kills(entity_id: String) -> int:
	var reg: Dictionary = registry()
	var e: Variant = reg.get(entity_id, {})
	if e is Dictionary:
		return int((e as Dictionary).get("kills", 0))
	return 0


func is_seen(entity_id: String) -> bool:
	return registry().has(entity_id)


func total_kills() -> int:
	var total: int = 0
	for k in registry().keys():
		total += kills(String(k))
	return total


func bonuses() -> Dictionary:
	var cm: Node = get_node_or_null("/root/CollectionManager")
	if cm == null or not cm.has_method("get_bonuses"):
		return {}
	var d: Variant = cm.call("get_bonuses")
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}
