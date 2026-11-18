extends SceneTree
## Test harness for RulesEngine & Reproducible Character Registry

const RequirementTypes = preload("res://scripts/core/rules/RequirementTypes.gd")
const RulesEngine = preload("res://scripts/core/rules/RulesEngine.gd")

func _initialize() -> void:
	print("--- BEGIN RULES ENGINE & CHARACTER REGISTRY TEST ---")

	# Test 1: Verify all 158 parameters defined
	var total_params: int = RequirementTypes.TOTAL_PARAMETERS
	print("Checking total parameters: ", total_params)
	if total_params != 158:
		push_error("FAIL: Expected 158 parameters, got %d" % total_params)
		quit(1)
		return

	var defs: Dictionary = RequirementTypes.get_parameter_definitions()
	if defs.size() < 158:
		push_error("FAIL: Parameter definitions size %d is less than 158" % defs.size())
		quit(1)
		return
	print("PASS: All 158 RequirementTypes defined and registered")

	# Test 2: RulesEngine instantiation and config loading
	var rules: Node = load("res://scripts/core/rules/RulesEngine.gd").new()
	root.add_child(rules)
	for _i in range(3):
		await process_frame

	if not rules.get("rules_engine_enabled"):
		push_error("FAIL: rules_engine_enabled should be true by default")
		quit(1)
		return
	print("PASS: RulesEngine initialized successfully")

	# Test 3: UserStatTracker functionality
	rules.call("set_stat", "TotalGames", 4)
	rules.call("increment_stat", "TotalGames", 1)
	var games: int = int(rules.call("get_stat", "TotalGames", 0))
	if games != 5:
		push_error("FAIL: Expected TotalGames=5, got %d" % games)
		quit(1)
		return
	print("PASS: UserStatTracker increment and get_stat verified")

	# Test 4: Requirement Evaluation
	# Evaluate TotalGames >= 5 -> true
	var eval_true: bool = bool(rules.call("evaluate_requirement", RequirementTypes.Type.TOTAL_GAMES, ">=", 5))
	if not eval_true:
		push_error("FAIL: TotalGames >= 5 should be true")
		quit(1)
		return

	# Evaluate TotalGames >= 10 -> false
	var eval_false: bool = bool(rules.call("evaluate_requirement", RequirementTypes.Type.TOTAL_GAMES, ">=", 10))
	if eval_false:
		push_error("FAIL: TotalGames >= 10 should be false")
		quit(1)
		return
	print("PASS: Requirement comparison evaluation verified")

	# Test 5: Parameter and Category Toggling
	# Disable TotalGames parameter specifically
	rules.call("set_parameter_enabled", RequirementTypes.Type.TOTAL_GAMES, false)
	if bool(rules.call("is_parameter_enabled", RequirementTypes.Type.TOTAL_GAMES)):
		push_error("FAIL: Parameter TotalGames should report disabled")
		quit(1)
		return

	# Re-enable TotalGames parameter
	rules.call("set_parameter_enabled", RequirementTypes.Type.TOTAL_GAMES, true)
	if not bool(rules.call("is_parameter_enabled", RequirementTypes.Type.TOTAL_GAMES)):
		push_error("FAIL: Parameter TotalGames should report enabled")
		quit(1)
		return

	# Disable Monetization category
	rules.call("set_category_enabled", RequirementTypes.CAT_MONETIZATION, false)
	if bool(rules.call("is_parameter_enabled", RequirementTypes.Type.IS_PAYEE)):
		push_error("FAIL: IS_PAYEE should be disabled when Monetization category is disabled")
		quit(1)
		return
	print("PASS: Individual parameter and category toggles verified")

	# Test 6: Reproducible Character Registry
	var all_chars: Array = rules.call("get_characters")
	if all_chars.size() < 5:
		push_error("FAIL: Expected at least 5 default characters, got %d" % all_chars.size())
		quit(1)
		return
	print("PASS: Default characters registered from config: %d characters" % all_chars.size())

	# Register a new custom reproducible character dynamically
	var custom_char: Dictionary = {
		"id": "cyborg_scout",
		"name": "CYBORG SCOUT",
		"scene": "res://scenes/characters/character_cyborg.tscn",
		"color": "#00ffcc",
		"desc": "High-tech recon unit with plasma dash",
		"base_stats": {"health": 110, "speed": 7.2, "damage": 1.4},
		"unlock_rules": [
			{"type": RequirementTypes.Type.TOTAL_GAMES, "comparison": ">=", "value": 10}
		]
	}
	rules.call("register_custom_character", custom_char)

	# TotalGames is 5, required is 10 -> should be locked
	var unlocked_at_5: bool = bool(rules.call("is_character_unlocked", "cyborg_scout"))
	if unlocked_at_5:
		push_error("FAIL: Custom character should be locked when TotalGames < 10")
		quit(1)
		return

	# Now set TotalGames to 12 -> should be unlocked
	rules.call("set_stat", "TotalGames", 12)
	var unlocked_at_12: bool = bool(rules.call("is_character_unlocked", "cyborg_scout"))
	if not unlocked_at_12:
		push_error("FAIL: Custom character should unlock when TotalGames >= 10")
		quit(1)
		return
	print("PASS: Reproducible custom character registration and dynamic unlock rules verified")

	print("RULES_ENGINE_PASS=true")
	print("--- RULES ENGINE & CHARACTER REGISTRY TEST COMPLETED SUCCESSFULLY ---")
	quit(0)
