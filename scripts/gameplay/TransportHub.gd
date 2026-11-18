## TransportHub.gd — Issue #11 P1/P2. Emitter only; world-map UI is a listener.
class_name TransportHub
extends StaticBody3D

signal interacted(region_id: int)

const WORLD_MAP_SCENE: String = "res://scenes/ui/world_map.tscn"

@export var region_id: int = 1

func repair(_parts: int) -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp != null and wp.has_method("report_transport_repaired"):
		wp.report_transport_repaired(region_id)

func open_world_map() -> void:
	# Emit for any listener, then instantiate the world-map UI if the scene exists.
	# Idempotent: never stack two maps.
	interacted.emit(region_id)
	var tree := get_tree()
	if tree == null:
		return
	var existing := tree.root.get_node_or_null("WorldMapOverlay")
	if existing != null and is_instance_valid(existing):
		return
	if not ResourceLoader.exists(WORLD_MAP_SCENE):
		push_warning("[TransportHub] world_map.tscn missing — map not opened")
		return
	var packed := load(WORLD_MAP_SCENE) as PackedScene
	if packed == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "WorldMapOverlay"
	layer.layer = 90
	tree.root.add_child(layer)
	var map := packed.instantiate()
	layer.add_child(map)
