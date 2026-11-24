extends Node
## Test stub for WorldProgression. No gameplay logic; only what triggers read.

var current_region: int = 1
var unlocked_regions: Array[int] = [1, 2, 3]
var reachable: Dictionary = {}

func is_secret_reachable(from_region: int, to_region: int) -> bool:
	return bool(reachable.get("%d->%d" % [from_region, to_region], false))

func set_reachable(from_region: int, to_region: int, value: bool) -> void:
	reachable["%d->%d" % [from_region, to_region]] = value
