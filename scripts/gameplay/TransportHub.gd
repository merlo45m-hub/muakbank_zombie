## TransportHub.gd — Issue #11 P1/P2. Emitter only; world-map UI is a listener.
class_name TransportHub
extends StaticBody3D

signal interacted(region_id: int)

@export var region_id: int = 1

func repair(_parts: int) -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp != null and wp.has_method("report_transport_repaired"):
		wp.report_transport_repaired(region_id)

func open_world_map() -> void:
	interacted.emit(region_id)
