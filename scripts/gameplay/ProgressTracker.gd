extends Node

## ProgressTracker (autoload) — read-only projection over collection regions.
## Owns no state; everything comes from CollectionManager + Save.


func get_region(region_id: int) -> RegionStat:
	var cm := get_node_or_null("/root/CollectionManager")
	if cm == null:
		return RegionStat.from_dict({"region_id": region_id})
	var d = cm.get_regions().get(region_id, {})
	if d is Dictionary:
		return RegionStat.from_dict(d)
	return RegionStat.from_dict({"region_id": region_id})


func region_stat(region_id: int) -> Dictionary:
	return get_region(region_id).to_dict()


func all_regions() -> Dictionary:
	var cm := get_node_or_null("/root/CollectionManager")
	if cm == null:
		return {}
	return cm.get_regions()
