## LevelManager.gd — Autoload Singleton
## Maps level numbers to environment scenes
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

var current_level: int = 1

# Maps level numbers to ambient sound names
var ambient_map = {
	1: "town",
	2: "cemetery",
	3: "hospital",
	4: "warehouse",
	5: "subway",
	6: "rooftop"
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
