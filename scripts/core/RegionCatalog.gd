## RegionCatalog.gd — lookup table of RegionDef resources (Issue #11).
class_name RegionCatalog
extends Resource

@export var regions: Array[RegionDef] = []

func get_def(region_id: int) -> RegionDef:
	for def in regions:
		if def != null and def.id == region_id:
			return def
	return null

func ids() -> Array[int]:
	var out: Array[int] = []
	for def in regions:
		if def != null:
			out.append(def.id)
	return out
