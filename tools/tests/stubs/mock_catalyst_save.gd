## mock_catalyst_save.gd — Minimal Save double for issue #86 probe.
extends Node

func get_current_level() -> int:
	return 1

func get_unlocked_achievements() -> Array:
	return []

func set_unlocked_achievements(_ids: Array) -> void:
	pass

func get_world_bosses_defeated() -> Dictionary:
	return {}

func set_world_bosses_defeated(_data: Dictionary) -> void:
	pass

func is_post_cure() -> bool:
	return false

func set_post_cure(_val: bool) -> void:
	pass
