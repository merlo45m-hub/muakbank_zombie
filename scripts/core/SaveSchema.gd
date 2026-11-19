## SaveSchema.gd — Static class, no autoload
## Single source of truth for save field definitions, serialization, and deserialization.
## All conversion logic lives here; game state code never sees raw JSON variants.

class_name SaveSchema


## === SCHEMA VERSION (bump when field table changes incompatibly) ===
const SCHEMA_VERSION: int = 1

## === SAVE VERSION MAPPING ===
## Maps SaveManager.SAVE_VERSION to the schema version that produced it.
## Used for forward-compat decisions if we ever need multi-schema support.
const SAVE_VERSION_TO_SCHEMA: Dictionary = {
	6: 1,
	7: 1
}


## === TYPE ENUM ===
enum FieldType {
	TYPE_INT,
	TYPE_BOOL,
	TYPE_STRING,
	TYPE_ARRAY_STRING,      # Array[String]
	TYPE_ARRAY_INT,         # Array[int]
	TYPE_ARRAY_UNTYPED,     # Array (untyped elements)
	TYPE_DICT_UNTYPED,      # Dictionary (untyped keys/values)
	TYPE_DICT_STR_INT,      # Dictionary[String, int]
	TYPE_DICT_INT_BOOL,     # Dictionary[int, bool]
	TYPE_DICT_INT_KEYS      # Dictionary[int-keyed, any value]: region/tech maps
}


## === FIELD DEFINITION ===
## Each field: {key, type, default, element_type (for containers), key_type (for dicts)}
## Field order matches _default_save_data() declaration order for readability.
const FIELDS: Array[Dictionary] = [
	{"key": "version", "type": FieldType.TYPE_INT, "default": 7},
	{"key": "high_score", "type": FieldType.TYPE_INT, "default": 0},
	{"key": "total_zombies_fed", "type": FieldType.TYPE_INT, "default": 0},
	{"key": "total_shifts_completed", "type": FieldType.TYPE_INT, "default": 0},
	{"key": "total_likes_earned", "type": FieldType.TYPE_INT, "default": 0},
	{"key": "unlocked_foods", "type": FieldType.TYPE_ARRAY_STRING, "default": ["burger", "noodles", "soda", "donut", "pizza", "taco"]},
	{"key": "unlocked_levels", "type": FieldType.TYPE_ARRAY_INT, "default": [1]},
	{"key": "unlocked_achievements", "type": FieldType.TYPE_ARRAY_UNTYPED, "default": []},
	{"key": "current_level", "type": FieldType.TYPE_INT, "default": 1},
	{"key": "difficulty", "type": FieldType.TYPE_INT, "default": 0},
	{"key": "selected_character", "type": FieldType.TYPE_STRING, "default": "nurse"},
	{"key": "selected_skin", "type": FieldType.TYPE_INT, "default": 0},
	{"key": "selected_skins", "type": FieldType.TYPE_DICT_STR_INT, "default": {"gamer": 0, "doctor": 0, "nurse": 0, "streamer": 0, "hunter": 0}},
	{"key": "tutorial_completed", "type": FieldType.TYPE_BOOL, "default": false},
	{"key": "haptics_enabled", "type": FieldType.TYPE_BOOL, "default": true},
	{"key": "collection_items", "type": FieldType.TYPE_DICT_UNTYPED, "default": {}},
	{"key": "collection_regions", "type": FieldType.TYPE_DICT_INT_KEYS, "default": {}},
	{"key": "dismantled_props", "type": FieldType.TYPE_DICT_UNTYPED, "default": {}},
	{"key": "bestiary", "type": FieldType.TYPE_DICT_UNTYPED, "default": {}},
	{"key": "museum_seen", "type": FieldType.TYPE_ARRAY_UNTYPED, "default": []},
	{"key": "museum_version", "type": FieldType.TYPE_INT, "default": 2},
	{"key": "world_current_region", "type": FieldType.TYPE_INT, "default": 1},
	{"key": "world_unlocked_regions", "type": FieldType.TYPE_ARRAY_INT, "default": [1]},
	{"key": "world_tech", "type": FieldType.TYPE_DICT_INT_KEYS, "default": {}},
	{"key": "world_transport_repaired", "type": FieldType.TYPE_DICT_INT_KEYS, "default": {}},
	{"key": "world_milestones", "type": FieldType.TYPE_DICT_INT_KEYS, "default": {}},
	{"key": "world_max_loot_tier", "type": FieldType.TYPE_INT, "default": 1},
	{"key": "world_visited_regions", "type": FieldType.TYPE_ARRAY_INT, "default": [1]},
	{"key": "world_region_state", "type": FieldType.TYPE_DICT_INT_KEYS, "default": {}},
	{"key": "world_transient_snapshots", "type": FieldType.TYPE_DICT_INT_KEYS, "default": {}},
	{"key": "post_cure", "type": FieldType.TYPE_BOOL, "default": false},
	{"key": "world_bosses_defeated", "type": FieldType.TYPE_DICT_INT_BOOL, "default": {1: false, 2: false, 3: false}},
	{"key": "cure_synthesized_at", "type": FieldType.TYPE_STRING, "default": ""}
]


## === PUBLIC API ===

static func get_defaults() -> Dictionary:
	"""Return a Dictionary of all field keys to their default values."""
	var out: Dictionary = {}
	for field in FIELDS:
		out[field.key] = _clone_default(field.default)
	return out


static func get_field_def(key: String) -> Dictionary:
	"""Return the field definition for a given key, or empty dict if unknown."""
	for field in FIELDS:
		if field.key == key:
			return field.duplicate(true)
	return {}


static func get_all_keys() -> Array[String]:
	"""Return all known field keys."""
	var out: Array[String] = []
	for field in FIELDS:
		out.append(field.key)
	return out


static func _clone_default(v: Variant) -> Variant:
	"""Type-safe default clone: containers are deep-copied, scalars returned as-is."""
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v


## === DESERIALIZATION (load boundary) ===
## Input: raw Dictionary from JSON (string keys, floats for ints, etc.)
## Output: typed Dictionary matching field declarations exactly.
## Unknown keys are dropped. All conversion is deterministic.

static func deserialize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var defaults := get_defaults()

	for field in FIELDS:
		var key: String = String(field.key)
		var ftype: int = int(field.type)
		var default: Variant = defaults[key]

		if not raw.has(key):
			out[key] = _clone_default(default)
			continue

		var value: Variant = raw[key]
		out[key] = _deserialize_field(ftype, value, default)

	return out


static func _deserialize_field(ftype: int, value: Variant, default: Variant) -> Variant:
	match ftype:
		FieldType.TYPE_INT:
			if value == null:
				return default
			return int(value)

		FieldType.TYPE_BOOL:
			if value == null:
				return default
			return bool(value)

		FieldType.TYPE_STRING:
			if value == null:
				return default
			return str(value)

		FieldType.TYPE_ARRAY_STRING:
			if value == null or not value is Array:
				return _clone_default(default)
			var arr: Array[String] = []
			for elem in value:
				arr.append(str(elem))
			return arr

		FieldType.TYPE_ARRAY_INT:
			if value == null or not value is Array:
				return _clone_default(default)
			var arr: Array[int] = []
			for elem in value:
				arr.append(int(elem))
			return arr

		FieldType.TYPE_ARRAY_UNTYPED:
			if value == null or not value is Array:
				return _clone_default(default)
			return value.duplicate(true)

		FieldType.TYPE_DICT_UNTYPED:
			if value == null or not value is Dictionary:
				return _clone_default(default)
			return value.duplicate(true)

		FieldType.TYPE_DICT_STR_INT:
			if value == null or not value is Dictionary:
				return _clone_default(default)
			var out: Dictionary = {}
			for k in value:
				var nk := str(k)
				var nv := int(value[k])
				out[nk] = nv
			return out

		FieldType.TYPE_DICT_INT_BOOL:
			if value == null or not value is Dictionary:
				return _clone_default(default)
			var out: Dictionary = {}
			for k in value:
				var nk := int(k)
				var nv := bool(value[k])
				out[nk] = nv
			return out

		FieldType.TYPE_DICT_INT_KEYS:
			if value == null or not value is Dictionary:
				return _clone_default(default)
			return _normalize_int_keyed(value, 0)

		_:
			return value


static func _normalize_int_keyed(v: Variant, depth: int) -> Variant:
	"""Serializer-owned normalization for int-keyed maps: int-like string keys
	become ints, whole-number floats become ints, recursed deterministically to
	depth 3. Same rules on every platform - this is the schema, not a fallback."""
	if depth >= 3:
		return v
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			var nk: Variant = k
			if typeof(nk) == TYPE_STRING and String(nk).is_valid_int():
				nk = int(nk)
			out[nk] = _normalize_int_keyed(v[k], depth + 1)
		return out
	if v is Array:
		var arr: Array = []
		for item in v:
			arr.append(_normalize_int_keyed(item, depth + 1))
		return arr
	if v is float and floorf(v) == v:
		return int(v)
	return v


## === SERIALIZATION (store boundary) ===
## Input: typed Dictionary from game state (ints as ints, etc.)
## Output: Dictionary ready for JSON.stringify (ints stay ints, same key names).
## This is the identity transform for our types — kept for symmetry and future-proofing.

static func serialize(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for field in FIELDS:
		var key: String = String(field.key)
		if data.has(key):
			out[key] = data[key]
		else:
			out[key] = _clone_default(field.default)

	return out