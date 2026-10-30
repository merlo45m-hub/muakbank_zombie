## LevelManager.gd — Autoload Singleton
## Maps level numbers to environment scenes, names, and difficulty
## Registered as "Level" in autoload

extends Node

# Level → environment scene mapping (exactly 3 open-world sandboxes)
var environments = {
	1: "res://scenes/world/environment/old_town_enhanced.tscn",
	2: "res://scenes/world/environment/industrial_district.tscn",
	3: "res://scenes/world/environment/endgame_heights.tscn",
}

# Level → display name
var level_names = {
	1: "Old Town",
	2: "Industrial District",
	3: "Endgame Heights",
}

# Level → ambient sound name
var ambient_map = {
	1: "town",
	2: "warehouse",
	3: "rooftop",
}

# Level → difficulty multiplier (enemy health/damage/speed)
var difficulty_map = {
	1: 1.0,
	2: 1.6,
	3: 2.5,
}

# Level → enemy type pool (which zombies spawn)
var enemy_pool_map = {
	1: ["chicken", "rabbit"],
	2: ["dog", "cat", "chicken", "runner", "bear"],
	3: ["bear", "runner", "spitter", "dog", "cat"],
}



func get_ambient_name(level: int) -> String:
	if ambient_map.has(level):
		return ambient_map[level]
	return "town"  # fallback

func get_environment_scene(level: int) -> String:
	if environments.has(level):
		return environments[level]
	return environments[1]  # fallback to level 1

func get_level_count() -> int:
	return environments.size()

func get_level_name(level: int) -> String:
	if level_names.has(level):
		return level_names[level]
	return "Level %d" % level

func get_difficulty(level: int) -> float:
	if difficulty_map.has(level):
		return difficulty_map[level]
	return 2.5 + (level - 3) * 0.3

func get_enemy_pool(level: int) -> Array:
	if enemy_pool_map.has(level):
		return enemy_pool_map[level]
	return ["chicken", "rabbit"]  # fallback
