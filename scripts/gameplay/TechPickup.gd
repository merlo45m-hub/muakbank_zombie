## TechPickup.gd — Issue #11 P1. Emitter only: reports scavenge tech to WorldProgression.
class_name TechPickup
extends Area3D

@export var tech_id: StringName = &"circuit"
@export var region_id: int = 1

func collect() -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp != null and wp.has_method("report_tech"):
		wp.report_tech(region_id, tech_id)
	queue_free()
