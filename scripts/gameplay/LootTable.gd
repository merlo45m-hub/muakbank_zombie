extends Node
class_name LootTable

## LootTable — Weighted random loot drops
## Attach to enemies or spawners. Drops items based on weighted probabilities.

@export var drop_chance: float = 0.35
@export var loot_items: Array[Dictionary] = []

func _ready() -> void:
	# Default loot: the common food pickups, weighted
	if loot_items.is_empty():
		loot_items = [
			{"item": preload("res://scenes/world/food_burger.tscn"), "weight": 3.0, "count": 1},
			{"item": preload("res://scenes/world/food_pizza.tscn"), "weight": 2.5, "count": 1},
			{"item": preload("res://scenes/world/food_soda.tscn"), "weight": 2.0, "count": 1},
			{"item": preload("res://scenes/world/food_fries.tscn"), "weight": 2.0, "count": 1},
			{"item": preload("res://scenes/world/food_coffee.tscn"), "weight": 1.5, "count": 1},
			{"item": preload("res://scenes/world/food_medkit.tscn"), "weight": 0.5, "count": 1},
		]

func roll_drops() -> Array:
	var drops: Array = []
	if randf() > drop_chance:
		return drops
	
	var total_weight: float = 0.0
	for entry in loot_items:
		total_weight += entry.get("weight", 1.0)
	
	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for entry in loot_items:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			var count = entry.get("count", 1)
			for i in range(count):
				drops.append(entry.get("item"))
			break
	
	return drops

func spawn_drops(world_pos: Vector3) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	for item in roll_drops():
		if item is PackedScene:
			var instance = item.instantiate()
			instance.global_position = world_pos + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
			scene.add_child(instance)
