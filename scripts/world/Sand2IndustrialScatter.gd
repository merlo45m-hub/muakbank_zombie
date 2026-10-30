extends Node3D

const MACHINE := preload("res://assets/models/sand2-machine-col.glb")
const FORTIFIED := preload("res://assets/models/sand2-machine-fortified-col.glb")
const HOPPER := preload("res://assets/models/sand2-hopper-round-col.glb")
const PISTON := preload("res://assets/models/sand2-piston-square-col.glb")
const PIPE_LONG := preload("res://assets/models/sand2-pipe-long-col.glb")
const PIPE_BEND := preload("res://assets/models/sand2-pipe-bend-col.glb")
const PIPE_CROSS := preload("res://assets/models/sand2-pipe-cross-col.glb")
const PIPE_VALVE := preload("res://assets/models/sand2-pipe-valve-col.glb")
const CONVEYOR := preload("res://assets/models/sand2-conveyor-col.glb")
const CRANE := preload("res://assets/models/sand2-crane-col.glb")
const SERVICE_VEHICLE := preload("res://assets/models/sand3-service-ambulance-col.glb")
const VEHICLE_SCRIPT := preload("res://scripts/world/interactive/InteractiveServiceVehicle.gd")

# Four rows of yard dressing span the open industrial apron at 8–12 m spacing.
const INDUSTRIAL_PROPS := [
	{ "scene": MACHINE, "x": -42.0, "z": -22.0 }, { "scene": PIPE_LONG, "x": -30.0, "z": -22.0 }, { "scene": HOPPER, "x": -18.0, "z": -22.0 }, { "scene": PIPE_BEND, "x": -6.0, "z": -22.0 }, { "scene": FORTIFIED, "x": 6.0, "z": -22.0 }, { "scene": PIPE_CROSS, "x": 18.0, "z": -22.0 }, { "scene": CRANE, "x": 30.0, "z": -22.0 },
	{ "scene": CONVEYOR, "x": -42.0, "z": -8.0 }, { "scene": PIPE_VALVE, "x": -30.0, "z": -8.0 }, { "scene": MACHINE, "x": -18.0, "z": -8.0 }, { "scene": PIPE_LONG, "x": -6.0, "z": -8.0 }, { "scene": PISTON, "x": 6.0, "z": -8.0 }, { "scene": HOPPER, "x": 18.0, "z": -8.0 }, { "scene": PIPE_BEND, "x": 30.0, "z": -8.0 },
	{ "scene": FORTIFIED, "x": -42.0, "z": 10.0 }, { "scene": PIPE_CROSS, "x": -30.0, "z": 10.0 }, { "scene": CONVEYOR, "x": -18.0, "z": 10.0 }, { "scene": PIPE_VALVE, "x": -6.0, "z": 10.0 }, { "scene": MACHINE, "x": 6.0, "z": 10.0 }, { "scene": PIPE_LONG, "x": 18.0, "z": 10.0 }, { "scene": HOPPER, "x": 30.0, "z": 10.0 },
	{ "scene": PISTON, "x": -42.0, "z": 24.0 }, { "scene": PIPE_BEND, "x": -30.0, "z": 24.0 }, { "scene": CRANE, "x": -18.0, "z": 24.0 }, { "scene": FORTIFIED, "x": -6.0, "z": 24.0 }, { "scene": PIPE_CROSS, "x": 6.0, "z": 24.0 }, { "scene": CONVEYOR, "x": 18.0, "z": 24.0 }, { "scene": MACHINE, "x": 30.0, "z": 24.0 }
]

func _ready() -> void:
	for index in INDUSTRIAL_PROPS.size():
		var spec: Dictionary = INDUSTRIAL_PROPS[index]
		var prop: Node3D = (spec["scene"] as PackedScene).instantiate() as Node3D
		prop.name = "IndustrialAsset%02d" % (index + 1)
		add_child(prop)
		prop.position = Vector3(spec["x"], 0.05, spec["z"])
		prop.rotation.y = deg_to_rad(float((index % 4) * 90))

	var vehicle := SERVICE_VEHICLE.instantiate() as Node3D
	vehicle.name = "InteractiveServiceAmbulance"
	vehicle.set_script(VEHICLE_SCRIPT)
	add_child(vehicle)
	vehicle.position = Vector3(38.0, 0.05, 0.0)
	vehicle.rotation.y = PI / 2.0
