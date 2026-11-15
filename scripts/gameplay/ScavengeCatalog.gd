class_name ScavengeCatalog
extends RefCounted

## ScavengeCatalog — loads assets/data/scavenge_catalog.json into ScavengeItem
## resources. Read-only loader; does not own state. Returns an empty array on any
## failure and pushes a warning so a missing catalog never hard-crashes a boot.

const CATALOG_PATH := "res://assets/data/scavenge_catalog.json"


static func load_items() -> Array:
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		push_warning("[ScavengeCatalog] cannot open " + CATALOG_PATH)
		return []
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("[ScavengeCatalog] catalog root is not an object")
		return []
	var raw = parsed.get("items", [])
	if not raw is Array:
		push_warning("[ScavengeCatalog] 'items' is not an array")
		return []
	var out := []
	for entry in raw:
		if entry is Dictionary:
			out.append(ScavengeItem.from_dict(entry))
	return out


static func item_count() -> int:
	return load_items().size()
