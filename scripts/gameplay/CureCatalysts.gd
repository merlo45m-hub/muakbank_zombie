class_name CureCatalysts

## CureCatalysts — centralized world-to-catalyst mapping and deterministic helpers.
## No autoload; instantiated or used as static utility.

const WORLD_1_CATALYST_ID: String = "catalyst_suburban"
const WORLD_2_CATALYST_ID: String = "catalyst_industrial"
const WORLD_3_CATALYST_ID: String = "catalyst_biolab"

const CATALYST_IDS: Array[String] = [WORLD_1_CATALYST_ID, WORLD_2_CATALYST_ID, WORLD_3_CATALYST_ID]

static func get_catalyst_id_for_world(world_id: int) -> String:
	match world_id:
		1:
			return WORLD_1_CATALYST_ID
		2:
			return WORLD_2_CATALYST_ID
		3:
			return WORLD_3_CATALYST_ID
		_:
			return ""

static func get_world_for_catalyst_id(catalyst_id: String) -> int:
	if catalyst_id == WORLD_1_CATALYST_ID:
		return 1
	if catalyst_id == WORLD_2_CATALYST_ID:
		return 2
	if catalyst_id == WORLD_3_CATALYST_ID:
		return 3
	return 0

static func get_all_catalyst_ids() -> Array[String]:
	return CATALYST_IDS.duplicate()

static func has_all_catalysts(collection_manager: Node) -> bool:
	if collection_manager == null or not collection_manager.has_method("get_items"):
		return false
	var items: Dictionary = collection_manager.get_items()
	for cid in CATALYST_IDS:
		var qty: int = int(items.get(cid, 0))
		if qty <= 0:
			return false
	return true

static func get_missing_catalysts(collection_manager: Node) -> Array[String]:
	var missing: Array[String] = []
	if collection_manager == null or not collection_manager.has_method("get_items"):
		return CATALYST_IDS.duplicate()
	var items: Dictionary = collection_manager.get_items()
	for cid in CATALYST_IDS:
		var qty: int = int(items.get(cid, 0))
		if qty <= 0:
			missing.append(cid)
	return missing