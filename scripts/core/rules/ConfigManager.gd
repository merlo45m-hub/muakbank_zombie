class_name ConfigManager
extends RefCounted

## ConfigManager — Loads, manages, and merges game rules JSON configurations
## Supports local bundled defaults with remote/liveops override layer.

const RULES_FLAGS_PATH: String = "res://assets/data/rules/rules_flags.json"
const CHARACTERS_CONFIG_PATH: String = "res://assets/data/rules/characters.json"
const PRODUCTS_CONFIG_PATH: String = "res://assets/data/rules/products.json"
const SPAWN_CHANCES_PATH: String = "res://assets/data/rules/spawnchances.json"
const RUN_CONFIG_PATH: String = "res://assets/data/rules/runconfiguration.json"
const PROMOTIONS_PATH: String = "res://assets/data/rules/promotions.json"
const AD_PLACEMENTS_PATH: String = "res://assets/data/rules/adplacements.json"

var _configs: Dictionary = {}


func _init() -> void:
	load_all_configs()


func load_all_configs() -> void:
	_configs["flags"] = _load_json_file(RULES_FLAGS_PATH, _get_default_flags())
	_configs["characters"] = _load_json_file(CHARACTERS_CONFIG_PATH, _get_default_characters())
	_configs["products"] = _load_json_file(PRODUCTS_CONFIG_PATH, _get_default_products())
	_configs["spawnchances"] = _load_json_file(SPAWN_CHANCES_PATH, _get_default_spawnchances())
	_configs["runconfiguration"] = _load_json_file(RUN_CONFIG_PATH, _get_default_runconfiguration())
	_configs["promotions"] = _load_json_file(PROMOTIONS_PATH, _get_default_promotions())
	_configs["adplacements"] = _load_json_file(AD_PLACEMENTS_PATH, _get_default_adplacements())


func get_config(config_name: String) -> Dictionary:
	if _configs.has(config_name):
		return _configs[config_name] as Dictionary
	return {}


func set_config_override(config_name: String, override_data: Dictionary) -> void:
	if _configs.has(config_name):
		var base: Dictionary = _configs[config_name] as Dictionary
		for k in override_data.keys():
			base[k] = override_data[k]
	else:
		_configs[config_name] = override_data


func _load_json_file(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback

	var json_str: String = file.get_as_text()
	file.close()

	var test_json: JSON = JSON.new()
	var error: Error = test_json.parse(json_str)
	if error != OK:
		push_warning("[ConfigManager] JSON parse error in %s: %s" % [path, test_json.get_error_message()])
		return fallback

	if test_json.data is Dictionary:
		return test_json.data as Dictionary
	return fallback


func _get_default_flags() -> Dictionary:
	return {
		"rules_engine_enabled": true,
		"subsystem_flags": {
			"stat_tracking": true,
			"ab_testing": false,
			"telemetry": false,
			"remote_config": false,
			"iap_rules": false,
			"ad_rules": false,
			"dynamic_spawns": true,
			"dynamic_run_config": true,
			"character_rules": true
		},
		"category_toggles": {
			"General": true,
			"UserStats": true,
			"Monetization": false,
			"Platform": true,
			"LiveOps": false,
			"Rewards": true,
			"Challenges": true,
			"Device": true,
			"Gameplay": true,
			"Extended": true
		},
		"parameter_toggles": {}
	}


func _get_default_characters() -> Dictionary:
	return {
		"characters": [
			{
				"id": "gamer",
				"name": "GAMER",
				"scene": "res://scenes/characters/character_gamer.tscn",
				"color": "#ff2d7b",
				"desc": "Speed and snacks on demand",
				"base_stats": {"health": 90, "speed": 6.8, "damage": 1.1},
				"unlock_rules": []
			},
			{
				"id": "doctor",
				"name": "DOCTOR",
				"scene": "res://scenes/characters/character_doctor.tscn",
				"color": "#6fa8ff",
				"desc": "Tanky frame, medkits go further",
				"base_stats": {"health": 120, "speed": 5.5, "damage": 1.0},
				"unlock_rules": []
			},
			{
				"id": "nurse",
				"name": "NURSE",
				"scene": "res://scenes/characters/character_nurse.tscn",
				"color": "#2de0ff",
				"desc": "Fast healer, high agility",
				"base_stats": {"health": 80, "speed": 6.5, "damage": 0.9},
				"unlock_rules": []
			},
			{
				"id": "streamer",
				"name": "STREAMER",
				"scene": "res://scenes/characters/character_streamer.tscn",
				"color": "#a05cff",
				"desc": "Trades health for hype & damage",
				"base_stats": {"health": 85, "speed": 6.0, "damage": 1.3},
				"unlock_rules": []
			},
			{
				"id": "hunter",
				"name": "HUNTER",
				"scene": "res://scenes/characters/character_hunter.tscn",
				"color": "#ffd60a",
				"desc": "Ranged specialist, steady aim",
				"base_stats": {"health": 100, "speed": 5.8, "damage": 1.25},
				"unlock_rules": []
			}
		]
	}


func _get_default_products() -> Dictionary:
	return {
		"products": {
			"starter_pack": {"cost_cents": 199, "coins": 5000, "gem_bonus": 50},
			"coin_pack_small": {"cost_cents": 99, "coins": 1000},
			"revive_single": {"coins": 250, "ad_alternative": true}
		}
	}


func _get_default_spawnchances() -> Dictionary:
	return {
		"zombie_runner_chance": 0.20,
		"zombie_spitter_chance": 0.15,
		"snack_drop_chance": 0.35,
		"ammo_drop_chance": 0.25
	}


func _get_default_runconfiguration() -> Dictionary:
	return {
		"base_run_speed": 6.0,
		"wave_difficulty_multiplier": 1.15,
		"snack_heal_amount": 25
	}


func _get_default_promotions() -> Dictionary:
	return {
		"promotions": []
	}


func _get_default_adplacements() -> Dictionary:
	return {
		"interstitial_cooldown_seconds": 180,
		"grace_period_days": 1,
		"interstitial_on_game_over": true
	}
