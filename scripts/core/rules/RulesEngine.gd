extends Node
## RulesEngine — Central Autoload for Rules, Stats, LiveOps, and Character Registry
## Supports 158 conditional parameters with individual enable/disable toggles.

const RequirementTypes = preload("res://scripts/core/rules/RequirementTypes.gd")
const UserStatTracker = preload("res://scripts/core/rules/UserStatTracker.gd")
const ConfigManager = preload("res://scripts/core/rules/ConfigManager.gd")
const CharacterRegistry = preload("res://scripts/core/rules/CharacterRegistry.gd")

signal stat_changed(stat_name: String, new_value: Variant)
signal rule_evaluated(requirement_type: int, result: bool)

var rules_engine_enabled: bool = true

var stat_tracking_enabled: bool = true
var ab_testing_enabled: bool = false
var telemetry_enabled: bool = false
var remote_config_enabled: bool = false
var iap_rules_enabled: bool = false
var ad_rules_enabled: bool = false
var dynamic_spawns_enabled: bool = true
var dynamic_run_config_enabled: bool = true
var character_rules_enabled: bool = true

var category_toggles: Dictionary = {}
var parameter_toggles: Dictionary = {}

var stats: UserStatTracker = null
var configs: ConfigManager = null
var characters: CharacterRegistry = null


func _init() -> void:
	stats = UserStatTracker.new()
	configs = ConfigManager.new()
	characters = CharacterRegistry.new()


func _ready() -> void:
	_apply_config_flags()
	characters.load_from_config(configs.get_config("characters"))

	# Load saved stats if Save autoload is available
	if has_node("/root/Save"):
		var save_mgr: Node = get_node("/root/Save")
		var saved_dict: Dictionary = {}
		if save_mgr.get("save_data") is Dictionary:
			var sdata: Dictionary = save_mgr.get("save_data") as Dictionary
			if sdata.has("user_stats") and sdata["user_stats"] is Dictionary:
				saved_dict = sdata["user_stats"] as Dictionary
		stats.initialize_from_save(saved_dict)


func _process(delta: float) -> void:
	if rules_engine_enabled and stat_tracking_enabled and stats != null:
		stats.add_app_runtime(delta)


func _apply_config_flags() -> void:
	var flags: Dictionary = configs.get_config("flags")
	if flags.is_empty():
		return

	rules_engine_enabled = bool(flags.get("rules_engine_enabled", true))

	var sub_flags: Dictionary = flags.get("subsystem_flags", {})
	stat_tracking_enabled = bool(sub_flags.get("stat_tracking", true))
	ab_testing_enabled = bool(sub_flags.get("ab_testing", false))
	telemetry_enabled = bool(sub_flags.get("telemetry", false))
	remote_config_enabled = bool(sub_flags.get("remote_config", false))
	iap_rules_enabled = bool(sub_flags.get("iap_rules", false))
	ad_rules_enabled = bool(sub_flags.get("ad_rules", false))
	dynamic_spawns_enabled = bool(sub_flags.get("dynamic_spawns", true))
	dynamic_run_config_enabled = bool(sub_flags.get("dynamic_run_config", true))
	character_rules_enabled = bool(sub_flags.get("character_rules", true))

	category_toggles = flags.get("category_toggles", {})
	parameter_toggles = flags.get("parameter_toggles", {})


# ── PARAMETER TOGGLE API ───────────────────────────────────────

func is_parameter_enabled(type_id: int) -> bool:
	if not rules_engine_enabled:
		return false

	var def: Dictionary = RequirementTypes.get_def(type_id)
	var cat: String = String(def.get("category", RequirementTypes.CAT_GENERAL))

	# 1. Check subsystem level
	match cat:
		RequirementTypes.CAT_MONETIZATION:
			if not iap_rules_enabled and not ad_rules_enabled:
				return false
		RequirementTypes.CAT_USER_STATS:
			if not stat_tracking_enabled:
				return false
		RequirementTypes.CAT_LIVEOPS:
			if not remote_config_enabled and not ab_testing_enabled:
				return false

	# 2. Check category level
	if category_toggles.has(cat) and not bool(category_toggles[cat]):
		return false

	# 3. Check individual parameter level
	var key_str: String = str(type_id)
	if parameter_toggles.has(key_str):
		return bool(parameter_toggles[key_str])
	if parameter_toggles.has(type_id):
		return bool(parameter_toggles[type_id])

	# Default enabled
	return true


func set_parameter_enabled(type_id: int, enabled: bool) -> void:
	parameter_toggles[str(type_id)] = enabled


func set_category_enabled(category: String, enabled: bool) -> void:
	category_toggles[category] = enabled


# ── REQUIREMENT EVALUATION ─────────────────────────────────────

func evaluate_requirement(req_type: int, comparison: String = "==", target_val: Variant = null) -> bool:
	var def: Dictionary = RequirementTypes.get_def(req_type)
	var default_val: Variant = def.get("default", false)

	# If entire engine or specific parameter is disabled, return default safe value
	if not is_parameter_enabled(req_type):
		if target_val == null:
			return bool(default_val)
		return _compare(default_val, comparison, target_val)

	var current_val: Variant = _resolve_current_value(req_type, default_val)

	var result: bool = true
	if target_val == null:
		if current_val is bool:
			result = bool(current_val)
		elif current_val is int or current_val is float:
			result = (float(current_val) > 0.0)
		elif current_val is String:
			result = not String(current_val).is_empty()
	else:
		result = _compare(current_val, comparison, target_val)

	rule_evaluated.emit(req_type, result)
	return result


func evaluate_rule_set(rules: Array) -> bool:
	if not rules_engine_enabled or rules.is_empty():
		return true

	for item in rules:
		if not item is Dictionary:
			continue
		var rule: Dictionary = item as Dictionary
		var r_type: int = int(rule.get("type", RequirementTypes.Type.NONE))
		var comp: String = String(rule.get("comp", rule.get("comparison", "==")))
		var target: Variant = rule.get("value", rule.get("target", null))

		if not evaluate_requirement(r_type, comp, target):
			return false

	return true


func _resolve_current_value(type_id: int, fallback: Variant) -> Variant:
	match type_id:
		RequirementTypes.Type.NONE:
			return true
		RequirementTypes.Type.IS_NON_PAYEE:
			return (int(stats.get_stat("TotalIAPs", 0)) == 0)
		RequirementTypes.Type.IS_PAYEE:
			return (int(stats.get_stat("TotalIAPs", 0)) > 0)
		RequirementTypes.Type.TOTAL_GAMES:
			return stats.get_stat("TotalGames", fallback)
		RequirementTypes.Type.NUM_SESSIONS, RequirementTypes.Type.NUM_SESSIONS_PARAM:
			return stats.get_stat("NumSessions", fallback)
		RequirementTypes.Type.DAYS_PLAYED, RequirementTypes.Type.DAYS_PLAYED_PARAM:
			return stats.get_stat("DaysPlayed", fallback)
		RequirementTypes.Type.DAYS_SINCE_LAST_PLAYED:
			return stats.get_stat("DaysSinceLastPlayed", fallback)
		RequirementTypes.Type.CURRENT_LOGIN_STREAK:
			return stats.get_stat("CurrentLoginStreak", fallback)
		RequirementTypes.Type.TOTAL_TIME_IN_RUNS:
			return stats.get_stat("TotalTimeInRuns", fallback)
		RequirementTypes.Type.TOTAL_RUNS:
			return stats.get_stat("TotalRuns", fallback)
		RequirementTypes.Type.SECONDS_IN_RUN:
			return stats.get_stat("SecondsInRun", fallback)
		RequirementTypes.Type.TOTAL_IAPS:
			return stats.get_stat("TotalIAPs", fallback)
		RequirementTypes.Type.TOTAL_IAP_CURRENCY_SPENT:
			return stats.get_stat("TotalIAPCurrencySpent", fallback)
		RequirementTypes.Type.CUMULATIVE_IAP_SPENT:
			return stats.get_stat("CumulativeIAPSpent", fallback)
		RequirementTypes.Type.LAST_IAP_TIER:
			return stats.get_stat("LastIAPTier", fallback)
		RequirementTypes.Type.HOURS_SINCE_LAST_IAP:
			return stats.get_stat("HoursSinceLastIAP", fallback)
		RequirementTypes.Type.HOURS_SINCE_LAST_AD_WATCH:
			return stats.get_stat("HoursSinceLastAdWatch", fallback)
		RequirementTypes.Type.PLATFORM_ANDROID:
			return (OS.get_name() == "Android")
		RequirementTypes.Type.PLATFORM_IOS:
			return (OS.get_name() == "iOS")
		RequirementTypes.Type.PLATFORM_ANDROID_OR_IOS:
			return (OS.get_name() == "Android" or OS.get_name() == "iOS")
		RequirementTypes.Type.IS_DESKTOP_BUILD:
			return (OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "macOS", "Windows"])
		RequirementTypes.Type.IS_HEADLESS_BUILD:
			return DisplayServer.get_name() == "headless"
		RequirementTypes.Type.PLATFORM:
			return OS.get_name()
		RequirementTypes.Type.RANDOM_CHANCE:
			return randf()
		_:
			var def: Dictionary = RequirementTypes.get_def(type_id)
			var param_name: String = String(def.get("name", ""))
			if stats.stats.has(param_name):
				return stats.get_stat(param_name, fallback)
			return fallback


func _compare(current: Variant, op: String, target: Variant) -> bool:
	match op:
		"==":
			return (current == target)
		"!=":
			return (current != target)
		">=":
			return (float(current) >= float(target))
		"<=":
			return (float(current) <= float(target))
		">":
			return (float(current) > float(target))
		"<":
			return (float(current) < float(target))
		"contains":
			if current is String and target is String:
				return (String(current).find(String(target)) >= 0)
			if current is Array:
				return (target in (current as Array))
			return false
		_:
			return (current == target)


# ── PUBLIC HELPER API ──────────────────────────────────────────

func get_stat(stat_name: String, default_val: Variant = null) -> Variant:
	if stats != null:
		return stats.get_stat(stat_name, default_val)
	return default_val


func set_stat(stat_name: String, val: Variant) -> void:
	if stats != null:
		stats.set_stat(stat_name, val)
		stat_changed.emit(stat_name, val)


func increment_stat(stat_name: String, amount: float = 1.0) -> void:
	if stats != null:
		stats.increment_stat(stat_name, amount)
		stat_changed.emit(stat_name, stats.get_stat(stat_name))


func get_config(config_name: String) -> Dictionary:
	if configs != null:
		return configs.get_config(config_name)
	return {}


func is_character_unlocked(char_id: String) -> bool:
	if not character_rules_enabled or not rules_engine_enabled:
		return true
	if characters != null:
		return characters.is_character_unlocked(char_id, Callable(self, "evaluate_rule_set"))
	return true


func get_characters() -> Array[Dictionary]:
	if characters != null:
		return characters.get_all_characters()
	return []


func get_character(char_id: String) -> Dictionary:
	if characters != null:
		return characters.get_character(char_id)
	return {}


func register_character(data: Dictionary) -> void:
	register_custom_character(data)


func record_run_started() -> void:
	if not stat_tracking_enabled or stats == null:
		return
	stats.on_run_started()


func record_run_completed(duration_sec: float = 0.0) -> void:
	if not stat_tracking_enabled or stats == null:
		return
	stats.record_run_completed(duration_sec)


func get_run_config_float(key: String, default_val: float = 1.0) -> float:
	if not dynamic_run_config_enabled or configs == null:
		return default_val
	var run_cfg: Dictionary = configs.get_config("runconfiguration")
	return float(run_cfg.get(key, default_val))


func get_spawn_chance(entity_id: String, default_val: float = 0.5) -> float:
	if not dynamic_spawns_enabled or configs == null:
		return default_val
	var spawns: Dictionary = configs.get_config("spawnchances")
	return float(spawns.get(entity_id, default_val))


func register_custom_character(data: Dictionary) -> void:
	if characters != null:
		characters.register_character(data)


func save_user_stats(target_save_dict: Dictionary) -> void:
	if stats != null and target_save_dict != null:
		target_save_dict["user_stats"] = stats.serialize_for_save()
