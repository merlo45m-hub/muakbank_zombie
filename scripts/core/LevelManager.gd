## LevelManager.gd — Autoload Singleton
## Maps level numbers to environment scenes, names, and difficulty
## Registered as "Level" in autoload

class_name LevelManager
extends Node

# Level → environment scene mapping
var environments = {
	1: "res://scenes/world/environment/old_town_enhanced.tscn",
	2: "res://scenes/world/environment/cemetery_enhanced.tscn",
	3: "res://scenes/world/environment/hospital_enhanced.tscn",
	4: "res://scenes/world/environment/warehouse_enhanced.tscn",
	5: "res://scenes/world/environment/subway_enhanced.tscn",
	6: "res://scenes/world/environment/rooftop_enhanced.tscn",
}

# Level → display name
var level_names = {
	1: "Old Town",
	2: "Pet Cemetery",
	3: "Animal Hospital",
	4: "Warehouse",
	5: "Subway",
	6: "Rooftop",
}

# Level → ambient sound name
var ambient_map = {
	1: "town",
	2: "cemetery",
	3: "hospital",
	4: "warehouse",
	5: "subway",
	6: "rooftop"
}

# Level → difficulty multiplier (enemy health/damage/speed)
var difficulty_map = {
	1: 1.0,
	2: 1.2,
	3: 1.4,
	4: 1.6,
	5: 1.8,
	6: 2.0,
}

# Level → enemy type pool (which zombies spawn)
var enemy_pool_map = {
	1: ["chicken", "rabbit"],
	2: ["dog", "cat", "chicken"],
	3: ["dog", "cat", "rabbit"],
	4: ["bear", "dog", "cat"],
	5: ["bear", "dog", "rabbit"],
	6: ["bear", "cat", "chicken"],
}

var current_level: int = 1

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
	return 1.0

func get_enemy_pool(level: int) -> Array:
	if enemy_pool_map.has(level):
		return enemy_pool_map[level]
	return ["chicken", "rabbit"]  # fallback
