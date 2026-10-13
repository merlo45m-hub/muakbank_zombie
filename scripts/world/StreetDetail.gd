## StreetDetail.gd — the real-asset street layer for level 1.
##
## Sits alongside LevelDetail (which owns the courtyard + the procedural road
## base). This pass dresses the town with ACTUAL CC0 model packs: Kenney City
## Kit buildings around the arena, parked vehicles along the road, traffic
## lights, dumpsters, construction barriers and road signs.
##
## Asset paths are committed explicitly because exported PCK/APK builds cannot
## enumerate res:// directories with DirAccess. Missing resources are skipped,
## and placement remains seeded and stable.
extends Node3D

const BUILDING_ASSETS: Array[String] = [
	"res://assets/models/cc0/city/commercial/Models/building-a.glb",
	"res://assets/models/cc0/city/commercial/Models/building-b.glb",
	"res://assets/models/cc0/city/commercial/Models/building-c.glb",
	"res://assets/models/cc0/city/commercial/Models/building-d.glb",
	"res://assets/models/cc0/city/commercial/Models/building-e.glb",
	"res://assets/models/cc0/city/commercial/Models/building-f.glb",
	"res://assets/models/cc0/city/commercial/Models/building-g.glb",
	"res://assets/models/cc0/city/commercial/Models/building-h.glb",
	"res://assets/models/cc0/city/commercial/Models/building-i.glb",
	"res://assets/models/cc0/city/commercial/Models/building-j.glb",
	"res://assets/models/cc0/city/commercial/Models/building-k.glb",
	"res://assets/models/cc0/city/commercial/Models/building-l.glb",
	"res://assets/models/cc0/city/commercial/Models/building-m.glb",
	"res://assets/models/cc0/city/commercial/Models/building-n.glb",
	"res://assets/models/cc0/city/commercial/Models/building-skyscraper-a.glb",
	"res://assets/models/cc0/city/commercial/Models/building-skyscraper-b.glb",
	"res://assets/models/cc0/city/commercial/Models/building-skyscraper-c.glb",
	"res://assets/models/cc0/city/commercial/Models/building-skyscraper-d.glb",
	"res://assets/models/cc0/city/commercial/Models/building-skyscraper-e.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-a.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-b.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-c.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-d.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-e.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-f.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-g.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-h.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-i.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-j.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-k.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-l.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-m.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-n.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-o.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-p.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-q.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-r.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-s.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-t.glb",
	"res://assets/models/cc0/city/suburban/Models/building-type-u.glb",
]
const ROAD_ASSETS: Array[String] = [
	"res://assets/models/cc0/city/roads/Models/bridge-pillar-wide.glb",
	"res://assets/models/cc0/city/roads/Models/bridge-pillar.glb",
	"res://assets/models/cc0/city/roads/Models/construction-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/construction-cone.glb",
	"res://assets/models/cc0/city/roads/Models/construction-fence.glb",
	"res://assets/models/cc0/city/roads/Models/construction-light.glb",
	"res://assets/models/cc0/city/roads/Models/dumpster.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-pole-single.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-pole-wide.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-pole.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-side-single.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-side-wide.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-side.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-wires-wide.glb",
	"res://assets/models/cc0/city/roads/Models/electricity-wires.glb",
	"res://assets/models/cc0/city/roads/Models/light-curved-cross.glb",
	"res://assets/models/cc0/city/roads/Models/light-curved-double.glb",
	"res://assets/models/cc0/city/roads/Models/light-curved.glb",
	"res://assets/models/cc0/city/roads/Models/light-square-cross.glb",
	"res://assets/models/cc0/city/roads/Models/light-square-double.glb",
	"res://assets/models/cc0/city/roads/Models/light-square.glb",
	"res://assets/models/cc0/city/roads/Models/road-bend-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-bend-sidewalk.glb",
	"res://assets/models/cc0/city/roads/Models/road-bend-square-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-bend-square.glb",
	"res://assets/models/cc0/city/roads/Models/road-bend.glb",
	"res://assets/models/cc0/city/roads/Models/road-bridge.glb",
	"res://assets/models/cc0/city/roads/Models/road-crossing.glb",
	"res://assets/models/cc0/city/roads/Models/road-crossroad-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-crossroad-line.glb",
	"res://assets/models/cc0/city/roads/Models/road-crossroad-path.glb",
	"res://assets/models/cc0/city/roads/Models/road-crossroad.glb",
	"res://assets/models/cc0/city/roads/Models/road-curve-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-curve-intersection-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-curve-intersection.glb",
	"res://assets/models/cc0/city/roads/Models/road-curve-pavement.glb",
	"res://assets/models/cc0/city/roads/Models/road-curve.glb",
	"res://assets/models/cc0/city/roads/Models/road-driveway-double-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-driveway-double.glb",
	"res://assets/models/cc0/city/roads/Models/road-driveway-single-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-driveway-single.glb",
	"res://assets/models/cc0/city/roads/Models/road-end-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-end-round-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-end-round.glb",
	"res://assets/models/cc0/city/roads/Models/road-end.glb",
	"res://assets/models/cc0/city/roads/Models/road-intersection-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-intersection-line.glb",
	"res://assets/models/cc0/city/roads/Models/road-intersection-path.glb",
	"res://assets/models/cc0/city/roads/Models/road-intersection.glb",
	"res://assets/models/cc0/city/roads/Models/road-roundabout-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-roundabout.glb",
	"res://assets/models/cc0/city/roads/Models/road-side-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-side-entry-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-side-entry.glb",
	"res://assets/models/cc0/city/roads/Models/road-side-exit-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-side-exit.glb",
	"res://assets/models/cc0/city/roads/Models/road-side.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-empty-hanging.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-empty.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-object-stop.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-object-street.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-object-warning.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-stop.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-street.glb",
	"res://assets/models/cc0/city/roads/Models/road-sign-warning.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-curve-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-curve.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-flat-curve.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-flat-high.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-flat.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-high-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant-high.glb",
	"res://assets/models/cc0/city/roads/Models/road-slant.glb",
	"res://assets/models/cc0/city/roads/Models/road-split-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-split.glb",
	"res://assets/models/cc0/city/roads/Models/road-square-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-square.glb",
	"res://assets/models/cc0/city/roads/Models/road-straight-barrier-end.glb",
	"res://assets/models/cc0/city/roads/Models/road-straight-barrier-half.glb",
	"res://assets/models/cc0/city/roads/Models/road-straight-barrier.glb",
	"res://assets/models/cc0/city/roads/Models/road-straight-half.glb",
	"res://assets/models/cc0/city/roads/Models/road-straight.glb",
	"res://assets/models/cc0/city/roads/Models/sign-highway-detailed.glb",
	"res://assets/models/cc0/city/roads/Models/sign-highway-wide.glb",
	"res://assets/models/cc0/city/roads/Models/sign-highway.glb",
	"res://assets/models/cc0/city/roads/Models/tile-high.glb",
	"res://assets/models/cc0/city/roads/Models/tile-low.glb",
	"res://assets/models/cc0/city/roads/Models/tile-slant.glb",
	"res://assets/models/cc0/city/roads/Models/tile-slantHigh.glb",
	"res://assets/models/cc0/city/roads/Models/traffic-light-hanging.glb",
	"res://assets/models/cc0/city/roads/Models/traffic-light-object-hanging.glb",
	"res://assets/models/cc0/city/roads/Models/traffic-light-object-horizontal.glb",
	"res://assets/models/cc0/city/roads/Models/traffic-light-object-vertical.glb",
	"res://assets/models/cc0/city/roads/Models/traffic-light.glb",
]
const CAR_ASSETS: Array[String] = [
	"res://assets/models/cc0/cars/Models/ambulance.glb",
	"res://assets/models/cc0/cars/Models/box.glb",
	"res://assets/models/cc0/cars/Models/cone-flat.glb",
	"res://assets/models/cc0/cars/Models/cone.glb",
	"res://assets/models/cc0/cars/Models/debris-bolt.glb",
	"res://assets/models/cc0/cars/Models/debris-bumper.glb",
	"res://assets/models/cc0/cars/Models/debris-door-window.glb",
	"res://assets/models/cc0/cars/Models/debris-door.glb",
	"res://assets/models/cc0/cars/Models/debris-drivetrain-axle.glb",
	"res://assets/models/cc0/cars/Models/debris-drivetrain.glb",
	"res://assets/models/cc0/cars/Models/debris-nut.glb",
	"res://assets/models/cc0/cars/Models/debris-plate-a.glb",
	"res://assets/models/cc0/cars/Models/debris-plate-b.glb",
	"res://assets/models/cc0/cars/Models/debris-plate-small-a.glb",
	"res://assets/models/cc0/cars/Models/debris-plate-small-b.glb",
	"res://assets/models/cc0/cars/Models/debris-spoiler-a.glb",
	"res://assets/models/cc0/cars/Models/debris-spoiler-b.glb",
	"res://assets/models/cc0/cars/Models/debris-tire.glb",
	"res://assets/models/cc0/cars/Models/delivery-flat.glb",
	"res://assets/models/cc0/cars/Models/delivery.glb",
	"res://assets/models/cc0/cars/Models/firetruck.glb",
	"res://assets/models/cc0/cars/Models/garbage-truck.glb",
	"res://assets/models/cc0/cars/Models/hatchback-sports.glb",
	"res://assets/models/cc0/cars/Models/kart-oobi.glb",
	"res://assets/models/cc0/cars/Models/kart-oodi.glb",
	"res://assets/models/cc0/cars/Models/kart-ooli.glb",
	"res://assets/models/cc0/cars/Models/kart-oopi.glb",
	"res://assets/models/cc0/cars/Models/kart-oozi.glb",
	"res://assets/models/cc0/cars/Models/police.glb",
	"res://assets/models/cc0/cars/Models/race-future.glb",
	"res://assets/models/cc0/cars/Models/race.glb",
	"res://assets/models/cc0/cars/Models/sedan-sports.glb",
	"res://assets/models/cc0/cars/Models/sedan.glb",
	"res://assets/models/cc0/cars/Models/suv-luxury.glb",
	"res://assets/models/cc0/cars/Models/suv.glb",
	"res://assets/models/cc0/cars/Models/taxi.glb",
	"res://assets/models/cc0/cars/Models/tractor-police.glb",
	"res://assets/models/cc0/cars/Models/tractor-shovel.glb",
	"res://assets/models/cc0/cars/Models/tractor.glb",
	"res://assets/models/cc0/cars/Models/truck-flat.glb",
	"res://assets/models/cc0/cars/Models/truck.glb",
	"res://assets/models/cc0/cars/Models/van.glb",
	"res://assets/models/cc0/cars/Models/wheel-dark.glb",
	"res://assets/models/cc0/cars/Models/wheel-default.glb",
	"res://assets/models/cc0/cars/Models/wheel-racing.glb",
	"res://assets/models/cc0/cars/Models/wheel-tractor-back.glb",
	"res://assets/models/cc0/cars/Models/wheel-tractor-dark-back.glb",
	"res://assets/models/cc0/cars/Models/wheel-tractor-dark-front.glb",
	"res://assets/models/cc0/cars/Models/wheel-tractor-front.glb",
	"res://assets/models/cc0/cars/Models/wheel-truck.glb",
]

# Backdrop skyline ring (distant horizon outside the expanded town): tall skyline, no colliders.
# Pushed outward to 60-85m with 28 buildings so the horizon looks full and dense
# around the enlarged ~200-220m floor instead of leaving a barren rim.
const RING_MIN_R := 60.0
const RING_MAX_R := 85.0
const RING_COUNT := 28
const RING_MIN_H := 3.2
const RING_MAX_H := 7.5

# Interior cover buildings: walkable-arena obstacles, WITH colliders.
# Spread across 25-70m with 10 buildings to populate the larger free-roam area,
# while keeping clear of player spawn and the 3 mini-game destinations.
const COVER_COUNT := 10
const COVER_R_MIN := 25.0
const COVER_R_MAX := 70.0
const COVER_HEIGHT := 2.8

# Exclusion zones for interior cover buildings:
# Keep cover buildings clear of ~12m radius around player spawn and the 3 mini-game hubs
# so routes and interaction stations are never obstructed.
const COVER_EXCLUSION_RADIUS := 12.0
const COVER_EXCLUSIONS: Array[Vector2] = [
	Vector2(-14.0, -14.0), # Player spawn point
	Vector2(-70.0, 70.0),  # Mini-game 1: SpoilAndSurvive
	Vector2(70.0, 60.0),   # Mini-game 2: KeepGeneratorFed (~(70,60))
	Vector2(72.0, 62.0),   # Mini-game 2: KeepGeneratorFed (~(72,62) exact)
	Vector2(75.0, -60.0),  # Mini-game 3: LastStandStation (~(75,-60))
	Vector2(78.0, -62.0),  # Mini-game 3: LastStandStation (~(78,-62) exact)
]

# Parked cars: ringed across the expanded town (15-70m).
# 30 vehicles dress the streets and routes connecting the distant mini-games.
const CAR_COUNT := 30
const CAR_R_MIN := 15.0
const CAR_R_MAX := 70.0
const CAR_HEIGHT := 1.5

# Street furniture (props & lamps): ringed across 15-75m.
# 24 roadside props and 24 lit street lamps ensure the entire expanded map is
# dressed and illuminated without dark dead zones.
const PROP_COUNT := 24
const PROP_R_MIN := 15.0
const PROP_R_MAX := 75.0
const PROP_HEIGHT := 0.9

const LIGHT_COUNT := 24
const LIGHT_R_MIN := 15.0
const LIGHT_R_MAX := 75.0
const LIGHT_ENERGY := 2.6
const LIGHT_RANGE := 14.0
const LIGHT_HEIGHT := 3.2

const GROUND_TOP := 0.0
var _rng := RandomNumberGenerator.new()
var _building_paths: Array[String] = []
var _road_paths: Array[String] = []
var _car_paths: Array[String] = []
var _placed := 0


func _ready() -> void:
	_rng.seed = 20261006
	_building_paths = _existing_paths(BUILDING_ASSETS)
	_road_paths = _existing_paths(ROAD_ASSETS)
	_car_paths = _existing_paths(CAR_ASSETS)
	if _building_paths.is_empty():
		push_warning("StreetDetail: no building models found - street dressing skipped")
	_building_ring()
	_cover_buildings()
	_parked_cars()
	_street_furniture()
	print("[StreetDetail] placed %d nodes (buildings=%d road_props=%d cars=%d)" % [
		_placed, _building_paths.size(), _road_paths.size(), _car_paths.size()])


## Packed APKs cannot enumerate res:// directories with DirAccess, so use
## committed asset paths and keep only resources present in this build.
func _existing_paths(paths: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for path in paths:
		if ResourceLoader.exists(path):
			out.append(path)
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
		# Lift so the model's bounding-box bottom sits exactly on pos.y, otherwise
		# models whose origin is at their centre (most car .glb) sink halfway into
		# the road and are invisible from the player's eye level.
		inst.position.y = pos.y - aabb.position.y * s
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


## Buildings inside the arena as hard cover, with collision.
## Kept clear of player spawn and the 3 mini-game locations.
func _cover_buildings() -> void:
	if _building_paths.is_empty():
		return
	for i in range(COVER_COUNT):
		var base_angle := TAU * float(i) / float(COVER_COUNT) + 0.7
		var pos := Vector3.ZERO
		var valid_pos := false
		for attempt in range(16):
			var a := base_angle + _rng.randf_range(-0.25, 0.25) * float(attempt + 1)
			var r := _rng.randf_range(COVER_R_MIN, COVER_R_MAX)
			var candidate := Vector3(cos(a) * r, GROUND_TOP, sin(a) * r)
			if _is_cover_pos_clear(Vector2(candidate.x, candidate.z)):
				pos = candidate
				valid_pos = true
				break
		if not valid_pos:
			continue
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


## Checks whether a 2D position (x, z) is clear of player spawn and mini-games.
func _is_cover_pos_clear(pos_2d: Vector2) -> bool:
	for excl in COVER_EXCLUSIONS:
		if pos_2d.distance_to(excl) < COVER_EXCLUSION_RADIUS:
			return false
	return true


## Vehicles scattered across the town, alternating sides, varied heading.
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
		# Scatter cars around the expanded town across CAR_R_MIN..CAR_R_MAX so
		# parked vehicles dress the routes between mini-game destinations.
		var a := TAU * float(i) / float(CAR_COUNT) + _rng.randf_range(-0.15, 0.15)
		var r := _rng.randf_range(CAR_R_MIN, CAR_R_MAX)
		var pos := Vector3(cos(a) * r, GROUND_TOP, sin(a) * r)
		var yaw := a + PI * 0.5
		_spawn(_pick(cars, i * 5 + 2), pos, yaw + _rng.randf_range(-0.08, 0.08),
			CAR_HEIGHT * _rng.randf_range(0.9, 1.35))


## Dumpsters, barriers, cones, signs, plus lit lamps scattered across the expanded town.
func _street_furniture() -> void:
	var pool: Array[String] = []
	for p in _road_paths:
		if _is_street_prop(p):
			pool.append(p)
	for i in range(PROP_COUNT):
		if pool.is_empty():
			break
		# Ring props across PROP_R_MIN..PROP_R_MAX so road dressing is distributed
		# across the expanded playable area instead of clustered at the center.
		var a := TAU * float(i) / float(PROP_COUNT) + _rng.randf_range(-0.15, 0.15)
		var r := _rng.randf_range(PROP_R_MIN, PROP_R_MAX)
		var pos := Vector3(cos(a) * r, GROUND_TOP, sin(a) * r)
		_spawn(_pick(pool, i * 4 + 1), pos, _rng.randf_range(0.0, TAU), PROP_HEIGHT)
	var lamps: Array[String] = []
	for p in _road_paths:
		var leaf := p.get_file()
		if leaf.begins_with("electricity-pole") or leaf.begins_with("light-"):
			lamps.append(p)
	for i in range(LIGHT_COUNT):
		if lamps.is_empty():
			break
		# Ring the lamps around the expanded town across LIGHT_R_MIN..LIGHT_R_MAX
		# so the whole playable area is lit and reads as a lived-in street.
		var a := TAU * float(i) / float(LIGHT_COUNT) + 0.4
		var r := _rng.randf_range(LIGHT_R_MIN, LIGHT_R_MAX)
		var pos := Vector3(cos(a) * r, GROUND_TOP, sin(a) * r)
		var node := _spawn(_pick(lamps, i * 2), pos, 0.0, LIGHT_HEIGHT)
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
