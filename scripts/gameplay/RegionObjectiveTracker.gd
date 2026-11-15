## RegionObjectiveTracker.gd — Issue #11 P1. Emitter only.
class_name RegionObjectiveTracker
extends Node

@export var region_id: int = 1

func complete_milestone(milestone_id: StringName) -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp != null and wp.has_method("report_milestone"):
		wp.report_milestone(region_id, milestone_id)
