## WorldProgressListeners.gd — Issue #11 P2, autoload.
## Connects WorldProgression's canonical signals to the rest of the game.
## Pure listener: never writes progression state. Everything is null-guarded so
## a partial stack (Audio/Achievement missing in a headless probe) can't break boot.
extends Node

const ACH_REGION_PREFIX: String = "region_"
const ACH_MILESTONE_PREFIX: String = "milestone_"

func _ready() -> void:
	# Autoloads may still be initializing during _ready; defer the wiring.
	call_deferred("_connect_all")


func _connect_all() -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp == null:
		push_warning("[WorldProgressListeners] WorldProgression missing — listeners off")
		return
	var connected := 0
	for sig in ["region_unlocked", "milestone_reached", "hop_completed",
			"hop_failed", "tech_collected", "transport_repaired"]:
		if not wp.has_signal(sig):
			continue
		var cb: String = "_on_" + sig
		if not wp.is_connected(sig, Callable(self, cb)):
			wp.connect(sig, Callable(self, cb))
			connected += 1
	print("[WorldProgressListeners] connected ", connected, " signals")


func _achievement() -> Node:
	var am := get_node_or_null("/root/AchievementManager")
	if am != null:
		return am
	var scene := get_tree().current_scene
	if scene != null:
		return scene.get_node_or_null("AchievementManager")
	return null


func _register_and_unlock(id: String, title: String, desc: String) -> void:
	var am := _achievement()
	if am == null or not am.has_method("register_achievement"):
		return
	if not am.achievements.has(id):
		am.register_achievement(id, title, desc)
	if am.has_method("unlock"):
		am.unlock(id)


func _on_region_unlocked(region_id: int, loot_tier: int) -> void:
	_register_and_unlock(
		ACH_REGION_PREFIX + str(region_id),
		"Region %d Unlocked" % region_id,
		"Reached loot tier %d" % loot_tier)


func _on_milestone_reached(region_id: int, milestone_id: StringName) -> void:
	_register_and_unlock(
		ACH_MILESTONE_PREFIX + str(region_id) + "_" + String(milestone_id),
		"Milestone: %s" % milestone_id,
		"Completed in region %d" % region_id)


func _on_hop_completed(region_id: int) -> void:
	var audio := get_node_or_null("/root/Audio")
	var level := get_node_or_null("/root/Level")
	if audio != null and audio.has_method("play_ambient_for") and level != null \
			and level.has_method("get_ambient_name"):
		audio.play_ambient_for(level.get_ambient_name(region_id))


func _on_hop_failed(reason: StringName) -> void:
	push_warning("[WorldProgressListeners] hop failed: " + String(reason))


func _on_tech_collected(_region_id: int, _tech_id: StringName, _new_count: int, _required: int) -> void:
	pass  # UI (WorldMap) is the subscriber that needs this; audio/achievements do not.


func _on_transport_repaired(_region_id: int) -> void:
	pass
