extends Node
class_name LootTable

## LootTable — Weighted random loot drops
## Attach to enemies or spawners. Drops items based on weighted probabilities.

@export var drop_chance: float = 0.35
@export var loot_items: Array[Dictionary] = []

func _ready() -> void:
	# Default loot: the common food pickups, weighted
	if loot_items.is_empty():
		# Issue #11 P4: each entry carries `tier` = the minimum loot tier needed
		# to roll it. LootTierGate caps every roll at the highest unlocked region
		# tier, so high-tier gear stays behind the progression barrier.
		loot_items = [
			{"item": preload("res://scenes/world/food_burger.tscn"), "weight": 3.0, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/food_pizza.tscn"), "weight": 2.5, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/food_soda.tscn"), "weight": 2.0, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/food_fries.tscn"), "weight": 2.0, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/food_coffee.tscn"), "weight": 1.5, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/food_medkit.tscn"), "weight": 0.5, "count": 1, "tier": 2},
			# Rare weapon drops
			{"item": preload("res://scenes/world/weapon_pickup_bat.tscn"), "weight": 0.6, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/weapon_pickup_knife.tscn"), "weight": 0.5, "count": 1, "tier": 1},
			{"item": preload("res://scenes/world/weapon_pickup_axe.tscn"), "weight": 0.3, "count": 1, "tier": 2},
			{"item": preload("res://scenes/world/weapon_pickup_lightsaber.tscn"), "weight": 0.15, "count": 1, "tier": 3},
			{"item": preload("res://scenes/world/weapon_pickup_firegun.tscn"), "weight": 0.1, "count": 1, "tier": 3},
		]

func roll_drops() -> Array:
	var drops: Array = []
	if randf() > drop_chance:
		return drops

	# Issue #11 P4: high-tier loot is locked behind world progression. The gate
	# reads WorldProgression.max_loot_tier (tier of the highest unlocked region),
	# NEVER the raw save. Entries without `tier` default to 1 (back-compat with
	# any scene that overrides loot_items).
	var cap: int = LootTierGate.cap()
	var pool: Array = []
	for entry in loot_items:
		if int(entry.get("tier", 1)) <= cap:
			pool.append(entry)

	var total_weight: float = 0.0
	for entry in pool:
		total_weight += entry.get("weight", 1.0)
	if total_weight <= 0.0:
		return drops

	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for entry in pool:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			var count = entry.get("count", 1)
			for i in range(count):
				drops.append(entry.get("item"))
			break

	return drops

func request_reward_drops(world_pos: Vector3, requested_tier: int) -> Dictionary:
	## Minigame-win reward path (audit #189-adjacent loot pass-through): unlike
	## kill drops there is NO drop_chance gate — a win always pays out exactly
	## one reward roll. The earned tier is requested from LootTierGate (which
	## clamps against max_loot_tier), so a Bio-Lab win can never pay tier 3 with
	## the region locked, and the requested tier is returned for the sink probe.
	# Static helpers only — roll_loot is an instance method and must not be
	# called through the class (Parse Error class, idiom preamble #3).
	var t: int = LootTierGate.clamp_tier(requested_tier)
	var capped: bool = t < requested_tier
	var pool: Array = []
	for entry in loot_items:
		if int(entry.get("tier", 1)) == t:
			pool.append(entry)
	if pool.is_empty():
		for entry in loot_items:
			if int(entry.get("tier", 1)) <= t:
				pool.append(entry)
	if pool.is_empty():
		return {"tier": t, "count": 0, "capped": capped}
	var total_weight: float = 0.0
	for entry in pool:
		total_weight += entry.get("weight", 1.0)
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	var chosen: Dictionary = pool[0]
	for entry in pool:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			chosen = entry
			break
	var count := 0
	for i in range(int(chosen.get("count", 1))):
		var node: Node = (chosen.get("item") as PackedScene).instantiate()
		get_parent().add_child(node)
		node.global_position = world_pos
		count += 1
	return {"tier": t, "count": count, "capped": capped}

func spawn_drops(world_pos: Vector3) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	for item in roll_drops():
		if item is PackedScene:
			var instance = item.instantiate()
			# Add to the tree BEFORE touching global_position — a Node3D's
			# global_position setter asserts is_inside_tree(), so setting it on a
			# freshly instantiated (detached) node throws every kill.
			scene.add_child(instance)
			instance.global_position = world_pos + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
