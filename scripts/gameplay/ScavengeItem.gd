class_name ScavengeItem
extends Resource

## ScavengeItem — one collectible entry from assets/data/scavenge_catalog.json.
## Pure data; the SOP Stage-2 schema fields plus collection extension fields.
## Region assignments are draft until verified against #11 RegionCatalog.

@export var asset_id: String = ""
@export var display_name: String = ""
@export var category: String = "resource"
@export var role: String = "scavenge"
@export var region_id: int = 1
@export var tier: int = 1
@export var dimensions_m: Vector3 = Vector3.ONE
@export var model_path: String = ""
@export var icon_path: String = ""
@export var lore_text: String = ""
@export var quantity: int = 0
@export var first_found_ts: int = 0


func to_dict() -> Dictionary:
	var out := {}
	out["asset_id"] = asset_id
	out["display_name"] = display_name
	out["category"] = category
	out["role"] = role
	out["region_id"] = region_id
	out["tier"] = tier
	out["dimensions_m"] = [dimensions_m.x, dimensions_m.y, dimensions_m.z]
	out["model_path"] = model_path
	out["icon_path"] = icon_path
	out["lore_text"] = lore_text
	out["quantity"] = quantity
	out["first_found_ts"] = first_found_ts
	return out


static func from_dict(d: Dictionary) -> ScavengeItem:
	var item := ScavengeItem.new()
	item.asset_id = str(d.get("asset_id", ""))
	item.display_name = str(d.get("display_name", ""))
	item.category = str(d.get("category", "resource"))
	item.role = str(d.get("role", "scavenge"))
	item.region_id = int(d.get("region_id", 1))
	item.tier = int(d.get("tier", 1))
	var dim = d.get("dimensions_m", [1.0, 1.0, 1.0])
	if dim is Array and dim.size() >= 3:
		item.dimensions_m = Vector3(float(dim[0]), float(dim[1]), float(dim[2]))
	var exp = d.get("export_target", {})
	item.model_path = str(exp.get("model_path", ""))
	item.icon_path = str(d.get("icon_path", ""))
	item.lore_text = str(d.get("lore_text", ""))
	return item
