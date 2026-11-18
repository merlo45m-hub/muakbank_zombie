class_name CharacterRegistry
extends RefCounted

## CharacterRegistry — Data-driven character catalog for reproducible characters
## Loads from characters.json and supports registering new custom survivors dynamically.
## Evaluates character unlock rules against the RulesEngine.

var _characters: Dictionary = {}
var _character_order: Array[String] = []


func _init() -> void:
	pass


func load_from_config(config_dict: Dictionary) -> void:
	_characters.clear()
	_character_order.clear()

	var chars_list: Array = config_dict.get("characters", [])
	for item in chars_list:
		if item is Dictionary:
			register_character(item as Dictionary)


func register_character(data: Dictionary) -> void:
	var id: String = String(data.get("id", "")).strip_edges().to_lower()
	if id.is_empty():
		return

	var char_record: Dictionary = {
		"id": id,
		"name": String(data.get("name", id.to_upper())),
		"scene": String(data.get("scene", "res://scenes/characters/character_%s.tscn" % id)),
		"color": Color.from_string(String(data.get("color", "#ffffff")), Color.WHITE),
		"desc": String(data.get("desc", "")),
		"base_stats": data.get("base_stats", {"health": 100, "speed": 6.0, "damage": 1.0}),
		"unlock_rules": data.get("unlock_rules", []),
		"skin_variants": data.get("skin_variants", [])
	}

	if not _characters.has(id):
		_character_order.append(id)
	_characters[id] = char_record


func get_character(id: String) -> Dictionary:
	var key: String = id.strip_edges().to_lower()
	if _characters.has(key):
		return _characters[key] as Dictionary
	return {}


func has_character(id: String) -> bool:
	return _characters.has(id.strip_edges().to_lower())


func get_all_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _character_order:
		if _characters.has(id):
			result.append(_characters[id] as Dictionary)
	return result


func is_character_unlocked(id: String, rules_evaluator: Callable) -> bool:
	var char_data: Dictionary = get_character(id)
	if char_data.is_empty():
		return false

	var rules: Array = char_data.get("unlock_rules", [])
	if rules.is_empty():
		return true

	if not rules_evaluator.is_valid():
		return true

	return bool(rules_evaluator.call(rules))
