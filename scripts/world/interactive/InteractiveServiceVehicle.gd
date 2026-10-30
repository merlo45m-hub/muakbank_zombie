extends InteractiveVehicle
class_name InteractiveServiceVehicle

## Interactable hospital service vehicle. The inherited controller registers it
## with Interactor and owns the open/closed service-access state.
signal service_access_toggled(is_open: bool)

func _ready() -> void:
	# Flatten the Blender GLB wrapper, then adapt its meshes and colliders to the
	# names and physics types expected by InteractiveVehicle.
	var imported_root := get_node_or_null("InteractiveServiceAmbulance") as Node3D
	if imported_root:
		for child in imported_root.get_children():
			_clear_scene_owners(child)
			child.reparent(self, true)
		imported_root.free()

	var body_visual := get_node_or_null("Body") as MeshInstance3D
	if body_visual:
		var body_rigid := body_visual.get_node_or_null("StaticBody3D") as StaticBody3D
		if body_rigid:
			_clear_scene_owners(body_visual)
			var rigid_transform := body_rigid.global_transform
			body_visual.remove_child(body_rigid)
			body_visual.name = "VehicleBodyVisual"
			body_rigid.name = "Body"
			body_visual.reparent(self, true)
			add_child(body_rigid)
			body_rigid.global_transform = rigid_transform
			body_visual.reparent(body_rigid, true)

	var imported_door := get_node_or_null("Door") as Node3D
	if imported_door and not imported_door is RigidBody3D:
		var door_mesh := imported_door.get_node_or_null("DoorMesh") as MeshInstance3D
		if door_mesh:
			_clear_scene_owners(imported_door)
			var imported_door_transform := imported_door.transform
			imported_door.name = "ImportedDoorVisual"
			var door := RigidBody3D.new()
			door.name = "Door"
			door.transform = imported_door_transform
			add_child(door)
			door_mesh.reparent(door, true)
			var door_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = door_mesh.get_aabb().size
			door_shape.shape = box
			door_shape.transform = door_mesh.transform
			door_shape.position += door_mesh.get_aabb().get_center()
			door.add_child(door_shape)
			remove_child(imported_door)
			imported_door.free()

	super._ready()

func _clear_scene_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_scene_owners(child)

func interact() -> void:
	if is_door_open:
		_reset_vehicle()
	else:
		open_door()
	service_access_toggled.emit(is_door_open)
