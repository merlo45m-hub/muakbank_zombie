## StreetDetail.gd — the real-asset street layer for level 1.
##
## Sits alongside LevelDetail (which owns the courtyard + the procedural road
## base). This pass dresses the town with ACTUAL CC0 model packs: Kenney City
## Kit buildings around the arena, parked vehicles along the road, traffic
## lights, dumpsters, construction barriers and road signs.
##
## Every pool is built by SCANNING the staged asset dirs at runtime, so the
## layer degrades gracefully: a missing dir or a missing pack simply removes
## that category instead of erroring. Placement is seeded and stable.
extends Node3D

const COMMERCIAL_DIR := "res://assets/models/cc0/city/commercial/Models/"
const SUBURBAN_DIR := "res://assets/models/cc0/city/suburban/Models/"
const ROADS_DIR := "res://assets/models/cc0/city/roads/Models/"
const CARS_DIR := "res://assets/models/cc0/cars/Models/"

# Backdrop ring (outside the courtyard fence): tall skyline, no colliders.
const RING_MIN_R := 21.0
const RING_MAX_R := 27.0
const RING_COUNT := 16
const RING_MIN_H := 3.2
const RING_MAX_H := 7.5
# Interior cover buildings: walkable-arena obstacles, WITH colliders.
const COVER_COUNT := 4
const COVER_R_MIN := 6.0
const COVER_R_MAX := 13.0
const COVER_HEIGHT := 2.8
# Parked cars along the main road (LevelDetail puts it at z = -4, width 3.4).
const CAR_ROAD_Z := -4.0
const CAR_LANE_OFFSET := 1.6
const CAR_COUNT := 7
const CAR_HEIGHT := 1.5
# Street furniture.
const PROP_COUNT := 10
const LIGHT_COUNT := 6
const LIGHT_ENERGY := 1.6
const LIGHT_RANGE := 7.0

const GROUND_TOP := 0.0
var _rng := RandomNumberGenerator.new()
var _building_paths: Array[String] = []
var _road_paths: Array[String] = []
var _car_paths: Array[String] = []
var _placed := 0


func _ready() -> void:
	_rng.seed = 20261006
	_building_paths = _scan(COMMERCIAL_DIR, "building") + _scan(SUBURBAN_DIR, "building")
	_road_paths = _scan(ROADS_DIR, "")
	_car_paths = _scan(CARS_DIR, "")
	if _building_paths.is_empty():
		push_warning("StreetDetail: no building models found - street dressing skipped")
	_building_ring()
	_cover_buildings()
	_parked_cars()
	_street_furniture()
	print("[StreetDetail] placed %d nodes (buildings=%d road_props=%d cars=%d)" % [
		_placed, _building_paths.size(), _road_paths.size(), _car_paths.size()])


## Recursively collect .glb paths under a dir whose filename starts with prefix
## (empty prefix = everything). Returns absolute res:// paths.
func _scan(dir_path: String, prefix: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir() and not name.begins_with("."):
			out.append_array(_scan(dir_path.path_join(name), prefix))
		elif name.ends_with(".glb") and (prefix == "" or name.begins_with(prefix)):
			out.append(dir_path.path_join(name))
		name = d.get_next()
	d.list_dir_end()
	return out


## Instantiate a model and scale it so its height matches target_h.
## Returns null when the model cannot be loaded (never errors).
func _spawn(path: String, pos: Vector3, yaw: float, target_h: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return null
	add_child(inst)
	inst.position = pos
	inst.rotation.y = yaw
	var aabb := _aabb_of(inst)
	if aabb.size.y > 0.001 and target_h > 0.0:
		var s := target_h / aabb.size.y
		inst.scale = Vector3(s, s, s)
	_placed += 1
	return inst


func _aabb_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var b: AABB = m.transform * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _pick(pool: Array[String], i: int) -> String:
	if pool.is_empty():
		return ""
	return pool[i % pool.size()]


## Yaw that turns a model's +Z toward a point (Godot forward is -Z, so add PI).
func _face(pos: Vector3, target: Vector3) -> float:
	var d := target - pos
	return atan2(d.x, d.z) + PI


## Skyline ring: buildings shoulder to shoulder outside the courtyard fence.
func _building_ring() -> void:
	if _building_paths.is_empty():
		return
	for i in range(RING_COUNT):
		var a := TAU * float(i) / float(RING_COUNT) + _rng.randf_range(-0.06, 0.06)
		var r := _rng.randf_range(RING_MIN_R, RING_MAX_R)
		var pos := Vector3(cos(a) * r, GROUND_TOP, sin(a) * r)
		var h := _rng.randf_range(RING_MIN_H, RING_MAX_H)
		var model := _pick(_building_paths, i * 7 + int(r))
		_spawn(model, pos, _face(pos, Vector3.ZERO), h)


## A few buildings INSIDE the arena as hard cover, with collision.
func _cover_buildings() -> void:
	if _building_paths.is_empty():
		return
	for i in range(COVER_COUNT):
		var a := TAU * float(i) / float(COVER_COUNT) + 0.7
		var r := _rng.randf_range(COVER_R_MIN, COVER_R_MAX)
		var pos := Vector3(cos(a) * r, GROUND_TOP, sin(a) * r)
		var node := _spawn(_pick(_building_paths, i * 3 + 1), pos, _face(pos, Vector3.ZERO),
			COVER_HEIGHT * _rng.randf_range(0.9, 1.15))
		if node == null:
			continue
		var aabb := _aabb_of(node)
		var body := StaticBody3D.new()
		body.name = "CoverBody%d" % i
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(aabb.size.x * 0.85, max(aabb.size.y, 2.0), aabb.size.z * 0.85)
		shape.shape = box
		shape.position = Vector3(0, box.size.y * 0.5, 0)
		body.add_child(shape)
		node.add_child(body)


## Vehicles parked along the main road, alternating sides, varied heading.
func _parked_cars() -> void:
	if _car_paths.is_empty():
		return
	var cars: Array[String] = []
	for p in _car_paths:
		if _is_vehicle(p):
			cars.append(p)
	if cars.is_empty():
		return
	for i in range(CAR_COUNT):
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := -12.0 + float(i) * 4.2 + _rng.randf_range(-0.5, 0.5)
		var pos := Vector3(x, GROUND_TOP, CAR_ROAD_Z + side * CAR_LANE_OFFSET)
		var yaw := PI * 0.5 if i % 2 == 0 else -PI * 0.5
		_spawn(_pick(cars, i * 5 + 2), pos, yaw + _rng.randf_range(-0.08, 0.08),
			CAR_HEIGHT * _rng.randf_range(0.9, 1.35))


## Dumpsters, barriers, cones, signs along the roadside, plus lit lamps.
func _street_furniture() -> void:
	var pool: Array[String] = []
	for p in _road_paths:
		if _is_street_prop(p):
			pool.append(p)
	for i in range(PROP_COUNT):
		if pool.is_empty():
			break
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := -13.0 + float(i) * 2.9 + _rng.randf_range(-0.4, 0.4)
		var pos := Vector3(x, GROUND_TOP, CAR_ROAD_Z + side * _rng.randf_range(2.6, 3.4))
		_spawn(_pick(pool, i * 4 + 1), pos, _rng.randf_range(0.0, TAU), 0.9)
	var lamps: Array[String] = []
	for p in _road_paths:
		var leaf := p.get_file()
		if leaf.begins_with("electricity-pole") or leaf.begins_with("light-"):
			lamps.append(p)
	for i in range(LIGHT_COUNT):
		if lamps.is_empty():
			break
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := -10.0 + float(i) * 6.6
		var pos := Vector3(x, GROUND_TOP, CAR_ROAD_Z + side * 2.9)
		var node := _spawn(_pick(lamps, i * 2), pos, 0.0, 3.2)
		if node == null:
			continue
		var lamp := OmniLight3D.new()
		lamp.light_energy = LIGHT_ENERGY
		lamp.omni_range = LIGHT_RANGE
		lamp.light_color = Color(1.0, 0.86, 0.66)
		lamp.position = Vector3(0, 3.0, 0)
		node.add_child(lamp)

## Vehicle models only: the car kit also ships loose debris/wheel/cone parts.
func _is_vehicle(path: String) -> bool:
	var leaf := path.get_file()
	for bad in ["debris", "cone", "box", "wheel", "tire"]:
		if leaf.begins_with(bad):
			return false
	return true


## Roadside dressing: dumpsters, barriers, signs, cones, bins, benches.
func _is_street_prop(path: String) -> bool:
	var leaf := path.get_file()
	for good in ["dumpster", "construction", "sign", "road-cone", "hydrant", "bench", "bin", "traffic"]:
		if leaf.begins_with(good):
			return true
	return false
