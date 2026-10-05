## TitleBackground.gd - Builds the cemetery backdrop's zombie animals.
## The .tscn has the static geometry (floor, tombstones, trees, fog, lights).
## The GLB "animals" turned out to be 64-vert blockout boxes (the same placeholder
## disease the player model had), so the four flankers are assembled from
## primitives instead: readable silhouettes with ears, snouts, tails and eyes,
## matching the cover art (dog + cat left, bear + chicken right).

extends Node3D

const DevMode := preload("res://scripts/core/DevMode.gd")

const TITLE_CAM_FOV = 62.0
const TITLE_CAM_NEAR = 0.1
const TITLE_CAM_FAR = 120.0
const TITLE_CAM_POSITION = Vector3(-0.3, 1.5, 2.6)
const TITLE_CAM_TARGET = Vector3(-0.7, 0.95, -5.3)

# Four flankers frame the menu the way the cover art does. Spawn points must sit
# INSIDE the camera's cone; the landscape viewport is wide, so x up to ~4.6 is
# visible at z -2.4..-3.8. All animals face +Z (toward the camera) with a slight
# inward yaw so they read as standing guard around the menu.
var _animal_spawns = [
	{"kind": "dog", "x": -4.4, "z": -3.4, "yaw": 0.35},
	{"kind": "cat", "x": -2.5, "z": -2.4, "yaw": -0.30},
	{"kind": "bear", "x": 2.1, "z": -2.8, "yaw": 0.20},
	{"kind": "chicken", "x": 4.4, "z": -3.6, "yaw": -0.40},
]


func _ready() -> void:
	_setup_camera()
	_build_animals()


func _setup_camera() -> void:
	# The scene file's camera sat at knee height looking 30 degrees down, so the frame
	# was mostly a flat grey slab of floor with the headstones cropped at the very top
	# edge - it read as a UI panel, not a cemetery. Frame it the way the cover art does:
	# eye level, horizon just above the middle, graves and trees as silhouettes against
	# the fog, sky and moon above them.
	var cam := get_node_or_null("Camera") as Camera3D
	if cam == null:
		printerr("[TitleBackground] no Camera child found - framing unchanged")
		return
	if DevMode.is_active():
		print("[TitleBackground] _setup_camera before: ", cam.global_position, " fov=", cam.fov)
	cam.fov = TITLE_CAM_FOV
	cam.near = TITLE_CAM_NEAR
	cam.far = TITLE_CAM_FAR
	cam.global_position = TITLE_CAM_POSITION
	cam.look_at(TITLE_CAM_TARGET, Vector3.UP)


func _build_animals() -> void:
	var holder = get_node_or_null("Zombies")
	if holder == null:
		holder = self
	for spawn in _animal_spawns:
		var animal := _make_animal(str(spawn.kind))
		animal.position = Vector3(float(spawn.x), 0.0, float(spawn.z))
		animal.rotation.y = float(spawn.yaw)
		holder.add_child(animal)
		var anim = preload("res://scripts/ui/TitleZombieAnim.gd").new()
		anim.shamble_speed = 0.3 + randf() * 0.2
		anim.shamble_amount = 0.05 + randf() * 0.03
		anim.bob_amount = 0.02 + randf() * 0.02
		animal.add_child(anim)


# --- PRIMITIVE HELPERS -------------------------------------------

func _box(size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(color, 0.0)
	m.position = pos
	m.rotation = rot
	return m


func _sphere(r: float, color: Color, pos: Vector3, glow := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	m.mesh = sm
	m.material_override = _mat(color, glow)
	m.position = pos
	return m


func _cone(r: float, h: float, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 4
	m.mesh = cm
	m.material_override = _mat(color, 0.0)
	m.position = pos
	m.rotation = rot
	return m


func _mat(color: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.0
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


func _make_animal(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	match kind:
		"dog":
			_build_dog(root)
		"cat":
			_build_cat(root)
		"bear":
			_build_bear(root)
		"chicken":
			_build_chicken(root)
	return root


# --- ANIMALS (all face +Z, standing on y=0) -----------------------

func _build_dog(root: Node3D) -> void:
	var coat := Color(0.55, 0.40, 0.26)
	var dark := Color(0.42, 0.30, 0.19)
	root.add_child(_box(Vector3(0.55, 0.42, 1.0), coat, Vector3(0, 0.62, 0)))
	root.add_child(_box(Vector3(0.5, 0.45, 0.3), coat, Vector3(0, 0.66, 0.5)))
	root.add_child(_box(Vector3(0.42, 0.4, 0.42), coat, Vector3(0, 0.95, 0.62)))
	root.add_child(_box(Vector3(0.24, 0.18, 0.3), dark, Vector3(0, 0.86, 0.86)))
	root.add_child(_box(Vector3(0.12, 0.24, 0.1), dark, Vector3(-0.14, 1.2, 0.58), Vector3(0, 0, 0.35)))
	root.add_child(_box(Vector3(0.12, 0.24, 0.1), dark, Vector3(0.14, 1.2, 0.58), Vector3(0, 0, -0.35)))
	root.add_child(_sphere(0.045, Color(1, 0.85, 0.4), Vector3(-0.11, 1.0, 0.84), 1.8))
	root.add_child(_sphere(0.045, Color(1, 0.85, 0.4), Vector3(0.11, 1.0, 0.84), 1.8))
	for sx: float in [-0.19, 0.19]:
		for sz: float in [-0.32, 0.38]:
			root.add_child(_box(Vector3(0.13, 0.42, 0.13), dark, Vector3(sx, 0.21, sz)))
	root.add_child(_box(Vector3(0.1, 0.1, 0.42), coat, Vector3(0, 0.78, -0.6), Vector3(-0.5, 0, 0)))


func _build_cat(root: Node3D) -> void:
	var coat := Color(0.62, 0.62, 0.68)
	var dark := Color(0.48, 0.48, 0.55)
	root.add_child(_box(Vector3(0.38, 0.34, 0.7), coat, Vector3(0, 0.5, 0)))
	root.add_child(_box(Vector3(0.34, 0.34, 0.34), coat, Vector3(0, 0.78, 0.42)))
	root.add_child(_cone(0.1, 0.16, dark, Vector3(-0.1, 1.0, 0.42), Vector3(0, 0, 0.2)))
	root.add_child(_cone(0.1, 0.16, dark, Vector3(0.1, 1.0, 0.42), Vector3(0, 0, -0.2)))
	root.add_child(_sphere(0.04, Color(0.4, 1, 0.35), Vector3(-0.09, 0.82, 0.6), 2.2))
	root.add_child(_sphere(0.04, Color(0.4, 1, 0.35), Vector3(0.09, 0.82, 0.6), 2.2))
	root.add_child(_box(Vector3(0.14, 0.1, 0.12), dark, Vector3(0, 0.74, 0.6)))
	for sx: float in [-0.13, 0.13]:
		for sz: float in [-0.22, 0.26]:
			root.add_child(_box(Vector3(0.1, 0.34, 0.1), dark, Vector3(sx, 0.17, sz)))
	root.add_child(_box(Vector3(0.08, 0.5, 0.08), coat, Vector3(0, 0.72, -0.4), Vector3(0.5, 0, 0)))
	root.add_child(_box(Vector3(0.07, 0.22, 0.07), dark, Vector3(0, 1.0, -0.55), Vector3(0.9, 0, 0)))


func _build_bear(root: Node3D) -> void:
	var coat := Color(0.52, 0.36, 0.23)
	var dark := Color(0.4, 0.27, 0.17)
	root.add_child(_box(Vector3(0.85, 0.75, 1.1), coat, Vector3(0, 0.85, 0)))
	root.add_child(_box(Vector3(0.6, 0.55, 0.55), coat, Vector3(0, 1.45, 0.45)))
	root.add_child(_box(Vector3(0.3, 0.22, 0.28), dark, Vector3(0, 1.35, 0.78)))
	root.add_child(_sphere(0.14, dark, Vector3(-0.2, 1.75, 0.42)))
	root.add_child(_sphere(0.14, dark, Vector3(0.2, 1.75, 0.42)))
	root.add_child(_sphere(0.05, Color(1, 0.8, 0.35), Vector3(-0.13, 1.5, 0.72), 1.6))
	root.add_child(_sphere(0.05, Color(1, 0.8, 0.35), Vector3(0.13, 1.5, 0.72), 1.6))
	for sx: float in [-0.28, 0.28]:
		for sz: float in [-0.38, 0.42]:
			root.add_child(_box(Vector3(0.22, 0.5, 0.22), dark, Vector3(sx, 0.25, sz)))
	# the glowing orb it guards, held at the front paws
	root.add_child(_sphere(0.16, Color(1, 0.62, 0.2), Vector3(0.28, 0.62, 0.62), 2.4))


func _build_chicken(root: Node3D) -> void:
	var coat := Color(0.90, 0.87, 0.80)
	var red := Color(0.75, 0.12, 0.10)
	root.add_child(_sphere(0.26, coat, Vector3(0, 0.55, 0)))
	root.add_child(_sphere(0.16, coat, Vector3(0, 0.92, 0.18)))
	root.add_child(_cone(0.07, 0.12, Color(0.95, 0.6, 0.15), Vector3(0, 0.9, 0.34), Vector3(1.2, 0, 0)))
	root.add_child(_box(Vector3(0.06, 0.12, 0.18), red, Vector3(0, 1.08, 0.16)))
	root.add_child(_sphere(0.035, Color(0.9, 0.9, 0.9), Vector3(-0.07, 0.95, 0.3), 0.8))
	root.add_child(_sphere(0.035, Color(0.9, 0.9, 0.9), Vector3(0.07, 0.95, 0.3), 0.8))
	root.add_child(_box(Vector3(0.05, 0.3, 0.05), Color(0.9, 0.6, 0.15), Vector3(-0.09, 0.15, 0.02)))
	root.add_child(_box(Vector3(0.05, 0.3, 0.05), Color(0.9, 0.6, 0.15), Vector3(0.09, 0.15, 0.02)))
	root.add_child(_box(Vector3(0.16, 0.2, 0.3), coat, Vector3(0, 0.62, -0.28), Vector3(0.6, 0, 0)))
