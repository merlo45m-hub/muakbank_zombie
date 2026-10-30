extends Node3D

const TANK := preload("res://assets/models/sand3-tank-col.glb")
const TANK_LARGE := preload("res://assets/models/sand3-tank-large-col.glb")
const CHIMNEY := preload("res://assets/models/sand3-chimney-basic-col.glb")
const CHIMNEY_LARGE := preload("res://assets/models/sand3-chimney-large-col.glb")
const SOLAR_LANDSCAPE := preload("res://assets/models/sand3-solar-landscape-col.glb")
const SOLAR_PORTRAIT := preload("res://assets/models/sand3-solar-portrait-col.glb")
const WINDMILL := preload("res://assets/models/sand3-windmill-low-col.glb")
const ANTENNA := preload("res://assets/models/sand3-rooftop-antenna-col.glb")

# The ring and cross rows keep the helipad and existing AC units accessible.
const ROOFTOP_PROPS := [
	{ "scene": TANK_LARGE, "x": -42.0, "z": -42.0 }, { "scene": CHIMNEY, "x": -30.0, "z": -42.0 }, { "scene": SOLAR_LANDSCAPE, "x": -18.0, "z": -42.0 }, { "scene": TANK, "x": -6.0, "z": -42.0 }, { "scene": CHIMNEY_LARGE, "x": 6.0, "z": -42.0 }, { "scene": SOLAR_PORTRAIT, "x": 18.0, "z": -42.0 }, { "scene": WINDMILL, "x": 30.0, "z": -42.0 }, { "scene": TANK, "x": 42.0, "z": -42.0 },
	{ "scene": SOLAR_PORTRAIT, "x": -42.0, "z": 42.0 }, { "scene": WINDMILL, "x": -30.0, "z": 42.0 }, { "scene": CHIMNEY_LARGE, "x": -18.0, "z": 42.0 }, { "scene": TANK, "x": -6.0, "z": 42.0 }, { "scene": SOLAR_LANDSCAPE, "x": 6.0, "z": 42.0 }, { "scene": CHIMNEY, "x": 18.0, "z": 42.0 }, { "scene": TANK_LARGE, "x": 30.0, "z": 42.0 }, { "scene": TANK, "x": 42.0, "z": 42.0 },
	{ "scene": TANK, "x": -42.0, "z": -30.0 }, { "scene": CHIMNEY_LARGE, "x": -42.0, "z": -18.0 }, { "scene": SOLAR_LANDSCAPE, "x": -42.0, "z": -6.0 }, { "scene": TANK_LARGE, "x": -42.0, "z": 6.0 }, { "scene": CHIMNEY, "x": -42.0, "z": 18.0 }, { "scene": SOLAR_PORTRAIT, "x": -42.0, "z": 30.0 },
	{ "scene": CHIMNEY, "x": 42.0, "z": -30.0 }, { "scene": TANK_LARGE, "x": 42.0, "z": -18.0 }, { "scene": SOLAR_PORTRAIT, "x": 42.0, "z": -6.0 }, { "scene": CHIMNEY_LARGE, "x": 42.0, "z": 6.0 }, { "scene": TANK, "x": 42.0, "z": 18.0 }, { "scene": SOLAR_LANDSCAPE, "x": 42.0, "z": 30.0 },
	{ "scene": WINDMILL, "x": 6.0, "z": 32.0 }, { "scene": TANK_LARGE, "x": 18.0, "z": 32.0 },
	{ "scene": ANTENNA, "x": -25.0, "z": -4.0 }, { "scene": ANTENNA, "x": 25.0, "z": 3.0 }, { "scene": ANTENNA, "x": -16.0, "z": 20.0 }, { "scene": ANTENNA, "x": 5.0, "z": -30.0 }
]

func _ready() -> void:
	for index in ROOFTOP_PROPS.size():
		var spec: Dictionary = ROOFTOP_PROPS[index]
		var prop: Node3D = (spec["scene"] as PackedScene).instantiate() as Node3D
		prop.name = "RooftopAsset%02d" % (index + 1)
		add_child(prop)
		prop.position = Vector3(spec["x"], 0.05, spec["z"])
		prop.rotation.y = deg_to_rad(float((index % 4) * 90))
