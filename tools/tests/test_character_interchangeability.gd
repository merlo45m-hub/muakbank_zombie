extends SceneTree
## Test harness for Character Interchangeability & Engine Reproducibility

const RequirementTypes = preload("res://scripts/core/rules/RequirementTypes.gd")
const RulesEngine = preload("res://scripts/core/rules/RulesEngine.gd")
const PlayerScript = preload("res://scripts/core/Player.gd")

func _initialize() -> void:
	print("--- BEGIN CHARACTER INTERCHANGEABILITY & REPRODUCIBILITY TEST ---")

	# Wait for Autoloads to boot
	for _i in range(3):
		await process_frame

	var rules: Node = root.get_node_or_null("Rules")
	if rules == null:
		push_error("FAIL: Rules autoload not found in root")
		quit(1)
		return
	print("PASS: Rules autoload active in scene tree")

	# 1. Test canonical characters availability
	var chars: Array = rules.call("get_characters")
	if chars.size() < 5:
		push_error("FAIL: Expected at least 5 default characters, got %d" % chars.size())
		quit(1)
		return
	print("PASS: Canonical characters loaded: %d characters" % chars.size())

	# 2. Test dynamic custom character registration
	var custom_char: Dictionary = {
		"id": "cyborg",
		"name": "CYBORG",
		"scene": "res://scenes/characters/character_gamer.tscn",
		"desc": "Heavy kinetic cybernetic warrior",
		"color": "#00ffcc",
		"base_stats": {
			"max_health": 175,
			"max_stamina": 120,
			"move_speed": 7.5,
			"sprint_speed": 11.0,
			"attack_damage": 35,
			"attack_speed": 0.9,
			"damage_reduction": 0.15,
			"special_ability": "kinetic_blast"
		},
		"unlock_rules": [
			{
				"type": RequirementTypes.Type.TOTAL_GAMES,
				"op": ">=",
				"value": 1
			}
		]
	}

	rules.call("register_character", custom_char)
	var retrieved: Dictionary = rules.call("get_character", "cyborg")
	if retrieved.is_empty() or str(retrieved.get("id")) != "cyborg":
		push_error("FAIL: Custom character 'cyborg' could not be retrieved")
		quit(1)
		return
	print("PASS: Custom reproducible character registered and verified")

	# 3. Test SaveManager character switching
	var save_mgr: Node = root.get_node_or_null("Save")
	if save_mgr != null and save_mgr.has_method("set_selected_character"):
		save_mgr.call("set_selected_character", "cyborg")
		var current_char: String = str(save_mgr.get("selected_character"))
		if current_char != "cyborg":
			push_error("FAIL: SaveManager selected_character should be cyborg, got %s" % current_char)
			quit(1)
			return
		print("PASS: SaveManager switched selected_character to cyborg")

	# 4. Test Player instantiation with custom character stats
	var player_node: CharacterBody3D = CharacterBody3D.new()
	player_node.set_script(PlayerScript)
	root.add_child(player_node)
	for _i in range(3):
		await process_frame

	var p_health: int = player_node.get("max_health")
	var p_speed: float = player_node.get("move_speed")
	print("Player instantiated with max_health: %d, move_speed: %.2f" % [p_health, p_speed])

	if p_health != 175:
		push_error("FAIL: Expected Player max_health=175 from custom character, got %d" % p_health)
		player_node.queue_free()
		quit(1)
		return

	if p_speed < 7.0:
		push_error("FAIL: Expected Player move_speed >= 7.0 from custom character, got %.2f" % p_speed)
		player_node.queue_free()
		quit(1)
		return
	print("PASS: Player dynamically loaded custom character base stats (100% interchangeable)")

	# 5. Test LiveOps run lifecycle hooks & stat tracking
	rules.call("record_run_started")
	rules.call("increment_stat", "ZombiesKilled", 12)
	rules.call("record_run_completed", 45.0)

	var kills: int = rules.call("get_stat", "ZombiesKilled", 0)
	var runs: int = rules.call("get_stat", "TotalRuns", 0)
	var games: int = rules.call("get_stat", "TotalGames", 0)
	var total_time: float = rules.call("get_stat", "TotalTimeInRuns", 0.0)

	if kills < 12:
		push_error("FAIL: Expected ZombiesKilled >= 12, got %d" % kills)
		player_node.queue_free()
		quit(1)
		return

	if runs < 1:
		push_error("FAIL: Expected TotalRuns >= 1, got %d" % runs)
		player_node.queue_free()
		quit(1)
		return

	if games < 1:
		push_error("FAIL: Expected TotalGames >= 1, got %d" % games)
		player_node.queue_free()
		quit(1)
		return
	print("PASS: Run lifecycle hooks and lifetime stats verified (Kills: %d, Runs: %d, Games: %d, Time: %.1fs)" % [kills, runs, games, total_time])

	# 6. Test Unlock rule evaluation with updated stats
	var is_unlocked: bool = bool(rules.call("is_character_unlocked", "cyborg"))
	if not is_unlocked:
		push_error("FAIL: Character cyborg should be unlocked after completing runs")
		player_node.queue_free()
		quit(1)
		return
	print("PASS: Dynamic unlock rule evaluation verified for custom character")

	player_node.queue_free()
	print("INTERCHANGEABILITY_PASS=true")
	print("--- CHARACTER INTERCHANGEABILITY & REPRODUCIBILITY TEST COMPLETED SUCCESSFULLY ---")
	quit(0)
