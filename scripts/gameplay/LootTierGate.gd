## LootTierGate.gd — Issue #11 P1/P4. Caps every loot roll at the unlocked tier.
class_name LootTierGate
extends Node

static func _wp() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/WorldProgression")
	return null

static func cap() -> int:
	"""Current loot tier cap = WorldProgression.max_loot_tier (1 when absent)."""
	var wp := _wp()
	if wp != null and wp.has_method("get_loot_tier_cap"):
		return int(wp.get_loot_tier_cap())
	return 1


static func clamp_tier(requested_tier: int) -> int:
	return mini(requested_tier, LootTierGate.cap())

func roll_loot(requested_tier: int) -> Dictionary:
	var tier := LootTierGate.clamp_tier(requested_tier)
	return {"tier": tier, "requested_tier": requested_tier, "capped": tier < requested_tier}
