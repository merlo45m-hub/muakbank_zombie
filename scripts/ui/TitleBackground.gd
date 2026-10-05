## TitleBackground.gd - Builds the cemetery backdrop.
##
## Uses real authored CC0 models now instead of primitives: KayKit Halloween Bits
## (dead trees, headstones, fences, crypt, lanterns, pumpkins, path tiles),
## Kenney's graveyard kit stones, CC0 animal GLBs, and a Poly Haven cobblestone
## floor. The .tscn keeps the static parts (floor, moon, glow, lights, vignette);
## its primitive Tombstones/Trees groups are hidden and superseded.
##
## Models are auto-scaled to a target height from their measured AABB, so a pack
## at a different unit scale still lands at the size the composition needs.

extends Node3D

## The four blocky animals flank the title screen; the character select turns
## them off so its five pedestals own the stage (matches the reference art).
@export var build_animals := true

const DevMode := preload("res://scripts/core/DevMode.gd")

const TITLE_CAM_FOV = 62.0
const TITLE_CAM_NEAR = 0.1
const TITLE_CAM_FAR = 120.0
const TITLE_CAM_POSITION = Vector3(-0.3, 1.5, 2.6)
const TITLE_CAM_TARGET = Vector3(-0.7, 0.95, -5.3)

const MODELS := "res://assets/models/cc0/"

# Four flankers frame the menu the way the cover art does. Spawn points sit
# inside the camera cone (x up to ~4.6 visible at z -2.4..-3.8). Animals face +Z
# with a slight inward yaw so they read as standing guard around the menu.
var _animal_spawns = [
	{"kind": "dog", "model": "animals/dog_pocket_borough.glb", "x": -4.0, "z": -3.4, "yaw": 0.35, "h": 0.9},
	{"kind": "cat", "model": "animals/cat_ginger_tabby.glb", "x": -2.4, "z": -2.2, "yaw": -0.30, "h": 0.85},
	{"kind": "bear", "model": "animals/bear_grizzly.glb", "x": 3.1, "z": -4.4, "yaw": 0.25, "h": 1.15},
	{"kind": "chicken", "model": "animals/chick.glb", "x": 4.2, "z": -3.6, "yaw": -0.40, "h": 0.6},
]


func _ready() -> void:
	_setup_camera()
	_hide_procedural()
	_dress_floor()
	_build_graveyard()
	_build_props()
	_build_mist()
	if build_animals:
		_build_animals()


func _setup_camera() -> void:
	# Eye level, horizon just above the middle, graves and trees as silhouettes
	# against the fog, sky and moon above them.
	var cam := get_node_or_null("Camera") as Camera3D
	if cam == null:
		printerr("[TitleBackground] no Camera child found - framing unchanged")
		return
	cam.fov = TITLE_CAM_FOV
	cam.near = TITLE_CAM_NEAR
	cam.far = TITLE_CAM_FAR
	cam.global_position = TITLE_CAM_POSITION
	cam.look_at(TITLE_CAM_TARGET, Vector3.UP)


func _hide_procedural() -> void:
	# Primitive stand-ins the .tscn shipped with. The authored models replace
	# them; hiding keeps the change reversible without editing the scene.
	for n in ["Tombstones", "Trees"]:
		var node := get_node_or_null(n)
		if node is Node3D:
			(node as Node3D).visible = false


func _dress_floor() -> void:
	# Poly Haven cobblestone (CC0) on the cemetery floor. Dimmed so the night
	# grade stays intact instead of washing out to mid grey.
	var fm := get_node_or_null("Floor/FloorMesh") as MeshInstance3D
	var tex := load("res://assets/textures/cobblestone.jpg")
	if fm == null or tex == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.62, 0.62, 0.68)
	mat.uv1_scale = Vector3(7, 7, 7)
	mat.roughness = 0.95
	fm.material_override = mat


# --- MODEL PLACEMENT ------------------------------------------------

func _load_model(rel: String) -> Node3D:
	var path := MODELS + rel
	if not ResourceLoader.exists(path):
		push_warning("[TitleBackground] missing model " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	if inst is Node3D:
		return inst as Node3D
	inst.queue_free()
	return null


func _aabb_of(node: Node3D) -> AABB:
	# Bounds of every mesh under the instance, in the instance's local space.
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var local: AABB = m.transform * m.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _place(rel: String, pos: Vector3, yaw: float, target_h: float, lift: float) -> Node3D:
	var inst := _load_model(rel)
	if inst == null:
		return null
	var box := _aabb_of(inst)
	var s := 1.0
	if target_h > 0.0 and box.size.y > 0.01:
		s = target_h / box.size.y
	inst.scale = Vector3(s, s, s)
	inst.position = Vector3(pos.x, pos.y - box.position.y * s + lift, pos.z)
	inst.rotation.y = yaw
	add_child(inst)
	if DevMode.is_active():
		print("[TitleBackground] placed ", rel, " size=", box.size, " scale=", s)
	return inst


func _place_fence(z: float) -> void:
	# A run of KayKit fence pieces across the back, spaced by their own width,
	# with a gap where the walkway enters.
	var probe := _load_model("kaykit/fence.gltf")
	if probe == null:
		return
	var box := _aabb_of(probe)
	probe.queue_free()
	var s := 1.15 / maxf(box.size.y, 0.01)
	var step := maxf(box.size.x * s, 0.4)
	var span := 12.0
	var n := int(span / step)
	for i in range(n):
		var x := -span * 0.5 + step * 0.5 + float(i) * step
		if absf(x) < 1.1:
			continue
		var inst := _load_model("kaykit/fence.gltf")
		if inst == null:
			continue
		inst.scale = Vector3(s, s, s)
		inst.position = Vector3(x, -box.position.y * s, z)
		add_child(inst)


func _build_graveyard() -> void:
	# Dead trees framing the shot (the cover art has no leaves anywhere).
	_place("kaykit/tree_dead_large.gltf", Vector3(-4.2, 0, -9.5), 0.4, 5.6, 0.0)
	_place("kaykit/tree_dead_large.gltf", Vector3(4.0, 0, -10.5), -0.6, 5.2, 0.0)
	_place("kaykit/tree_dead_medium.gltf", Vector3(-7.0, 0, -11.5), 0.8, 4.4, 0.0)
	_place("kaykit/tree_dead_small.gltf", Vector3(6.2, 0, -7.2), 0.2, 3.2, 0.0)
	_place("kaykit/tree_dead_small.gltf", Vector3(-6.0, 0, -6.8), -0.3, 3.0, 0.0)
	# Headstones, mixed shapes so the rows do not tile.
	var stones := [
		{"m": "kaykit/gravestone.gltf", "p": Vector3(-2.3, 0, -2.9), "h": 1.5, "y": 0.15},
		{"m": "kaykit/grave_A.gltf", "p": Vector3(2.4, 0, -3.2), "h": 1.2, "y": -0.2},
		{"m": "kenney/gravestone-cross.glb", "p": Vector3(-3.4, 0, -4.3), "h": 1.7, "y": 0.1},
		{"m": "kaykit/gravemarker_A.gltf", "p": Vector3(3.5, 0, -4.6), "h": 1.3, "y": 0.3},
		{"m": "kaykit/grave_B.gltf", "p": Vector3(-5.4, 0, -5.2), "h": 1.4, "y": -0.15},
		{"m": "kenney/gravestone-round.glb", "p": Vector3(5.6, 0, -5.6), "h": 1.5, "y": 0.25},
		{"m": "kaykit/gravemarker_B.gltf", "p": Vector3(-4.4, 0, -7.4), "h": 1.6, "y": 0.4},
		{"m": "kaykit/grave_A_destroyed.gltf", "p": Vector3(4.6, 0, -7.8), "h": 1.2, "y": -0.4},
		{"m": "kaykit/gravestone.gltf", "p": Vector3(-1.6, 0, -9.4), "h": 1.5, "y": 0.2},
		{"m": "kaykit/grave_A.gltf", "p": Vector3(1.4, 0, -10.2), "h": 1.4, "y": -0.1},
	]
	for s: Dictionary in stones:
		_place(str(s.m), s.p, float(s.y), float(s.h), 0.0)
	# Heavy silhouettes at the edges + the walkway furniture.
	_place("kaykit/crypt.gltf", Vector3(-8.6, 0, -9.8), 0.35, 3.4, 0.0)
	_place("kaykit/arch_gate.gltf", Vector3(7.2, 0, -10.4), -0.3, 3.6, 0.0)
	_place_fence(-6.2)
	# Lanterns flank the walkway and actually light it.
	_place("kaykit/lantern_standing.gltf", Vector3(-1.7, 0, -4.9), 0.0, 1.5, 0.0)
	_lantern_light(Vector3(-1.7, 1.3, -4.9))
	_place("kaykit/lantern_standing.gltf", Vector3(1.7, 0, -4.9), 0.0, 1.5, 0.0)
	_lantern_light(Vector3(1.7, 1.3, -4.9))


func _lantern_light(pos: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = Color(1.0, 0.72, 0.38)
	lamp.light_energy = 2.4
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	add_child(lamp)


func _build_props() -> void:
	_place("kaykit/pumpkin_orange.gltf", Vector3(-3.0, 0, -2.2), 0.4, 0.55, 0.0)
	_place("kaykit/pumpkin_orange_jackolantern.gltf", Vector3(3.2, 0, -2.4), -0.3, 0.6, 0.0)
	_place("kaykit/pumpkin_orange.gltf", Vector3(5.0, 0, -3.4), 0.9, 0.5, 0.0)
	_place("kaykit/pumpkin_orange_jackolantern.gltf", Vector3(-5.6, 0, -3.1), 0.2, 0.55, 0.0)
	_place("kaykit/skull.gltf", Vector3(-2.9, 0, -4.0), 0.7, 0.4, 0.0)
	_place("kaykit/bone_A.gltf", Vector3(2.6, 0, -5.4), 1.2, 0.3, 0.0)
	# Worn stone tiles lead the eye down the walkway.
	for i in range(4):
		var x := sin(float(i) * 1.7) * 0.35
		_place("kaykit/path_A.gltf", Vector3(x, 0.212, -0.9 - float(i) * 1.25), float(i) * 0.5, 0.07, 0.0)


func _build_animals() -> void:
	var holder := get_node_or_null("Zombies")
	if holder == null:
		holder = self
	for spawn in _animal_spawns:
		var rel: String = str(spawn.model)
		var inst := _load_model(rel)
		if inst == null:
			continue
		var box := _aabb_of(inst)
		var target_h := float(spawn.h)
		var s := target_h / maxf(box.size.y, 0.01)
		inst.scale = Vector3(s, s, s)
		inst.position = Vector3(float(spawn.x), -box.position.y * s + 0.2, float(spawn.z))
		inst.rotation.y = float(spawn.yaw)
		holder.add_child(inst)
		# contact shadow on the ground, not a child (it must not scale)
		var disc := _shadow_disc(0.55)
		disc.position = Vector3(float(spawn.x), 0.215, float(spawn.z))
		holder.add_child(disc)
		if DevMode.is_active():
			print("[TitleBackground] animal ", rel, " size=", box.size, " scale=", s)
	# the bear's guarded orb, kept from the cover art
	var orb := _sphere(0.16, Color(1, 0.62, 0.2), Vector3(2.55, 0.75, -2.35), 2.4)
	holder.add_child(orb)
	var orb_light := OmniLight3D.new()
	orb_light.position = Vector3(2.55, 0.85, -2.35)
	orb_light.light_color = Color(1.0, 0.6, 0.22)
	orb_light.light_energy = 2.2
	orb_light.omni_range = 4.0
	holder.add_child(orb_light)


func _build_mist() -> void:
	# Low ground mist: flattened translucent spheres drifting between the
	# graves. Unshaded so they read as haze in every renderer (environment
	# depth-fog alone was invisible on the phone).
	for m: Dictionary in [
		{"p": Vector3(-3.5, 0.8, -4.5), "s": Vector3(3.0, 0.55, 1.3)},
		{"p": Vector3(3.2, 0.7, -5.0), "s": Vector3(2.8, 0.5, 1.1)},
		{"p": Vector3(0.0, 0.9, -7.5), "s": Vector3(4.5, 0.7, 1.5)},
		{"p": Vector3(-5.5, 0.6, -2.0), "s": Vector3(1.8, 0.4, 1.0)},
		{"p": Vector3(5.8, 0.6, -1.5), "s": Vector3(1.8, 0.4, 1.0)},
		{"p": Vector3(-2.5, 0.7, -0.8), "s": Vector3(2.4, 0.45, 1.1)},
		{"p": Vector3(2.6, 0.6, -1.2), "s": Vector3(2.2, 0.4, 1.0)},
		{"p": Vector3(0.0, 1.2, -9.5), "s": Vector3(6.5, 0.9, 1.4)},
		{"p": Vector3(-4.0, 1.0, -8.5), "s": Vector3(3.5, 0.7, 1.2)},
		{"p": Vector3(-7.6, 0.7, -4.0), "s": Vector3(2.2, 0.5, 1.2)},
		{"p": Vector3(7.8, 0.7, -3.5), "s": Vector3(2.2, 0.5, 1.2)},
	]:
		var blob := _sphere(1.0, Color(0.62, 0.68, 0.80), m.p)
		blob.scale = m.s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.62, 0.68, 0.80, 0.20)
		blob.material_override = mat
		add_child(blob)


func _shadow_disc(r: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 16
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.01, 0.01, 0.02, 0.38)
	m.material_override = mat
	return m


# --- PRIMITIVE HELPERS ----------------------------------------------

func _sphere(r: float, color: Color, pos: Vector3, glow := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	m.material_override = mat
	m.position = pos
	return m
