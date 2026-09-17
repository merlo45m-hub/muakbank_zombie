extends Node
class_name LootTable

## LootTable — Weighted random loot drops
## Attach to enemies or spawners. Drops items based on weighted probabilities.

@export var drop_chance: float = 0.3
@export var loot_items: Array[Dictionary] = []  # [{item: PackedScene, weight: float, count: int}]

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
