## LevelDetail.gd — authored detail pass for the gameplay arena.
## Attached to the Environment node. Builds once on _ready: ground texture,
## perimeter (fences / tree line), focal structures (arch gate, crypts, the
## Muakbank counter), booth seating, scattered graveyard props, pumpkins,
## lamps, bones, blood decals. Seeded RNG so the layout is stable.
##
## Collision is added ONLY to the large structures (crypts, arch, counter):
## the zombie spawner paths around the open arena, and dozens of small
## colliders would fight the VectorField navigation for no player benefit.
extends Node3D

const MODELS := "res://assets/models/cc0/"

var _rng := RandomNumberGenerator.new()
var _wood: StandardMaterial3D = null
var _wood_dark: StandardMaterial3D = null


func _ready() -> void:
	_rng.seed = 20261005
	_wood = _wood_mat("res://assets/textures/wood_planks.jpg", Color(0.55, 0.42, 0.3))
	_wood_dark = _wood_mat("res://assets/textures/wood_planks.jpg", Color(0.32, 0.24, 0.17))
	_ground_texture()
	_perimeter()
	_structures()
	_seating()
	_scatter_graveyard()
	_scatter_pumpkins()
	_scatter_small()
	_blood()
	_lamps()


# ── helpers ──────────────────────────────────────────────────────────────

func _wood_mat(tex_path: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex := load(tex_path) as Texture2D
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(1.5, 1.5, 1.5)
	m.albedo_color = tint
	m.roughness = 0.9
	return m


func _load_model(rel: String) -> Node3D:
	var path := MODELS + rel
	if not ResourceLoader.exists(path):
		push_warning("[LevelDetail] missing model " + path)
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


## target_h = desired world height (0 = keep native size); lift = extra y.
func _place(rel: String, pos: Vector3, yaw: float, target_h: float, lift: float = 0.0) -> Node3D:
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
	return inst


func _box(size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0, collide: bool = false) -> Node3D:
	var body: Node3D
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		body = sb
	else:
		body = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	return body


func _cyl(r: float, h: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r * 1.06
	mesh.height = h
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


# ── ground ───────────────────────────────────────────────────────────────

func _ground_texture() -> void:
	# Re-skin the flat brown ground with cobblestone (the texture already
	# ships with the project for the menu floor).
	var ground := get_node_or_null("Ground/GroundMesh") as MeshInstance3D
	if ground == null:
		return
	var m := ground.material_override
	if m is StandardMaterial3D:
		var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
		var tex := load("res://assets/textures/cobblestone.jpg") as Texture2D
		if tex:
			sm.albedo_texture = tex
			sm.uv1_scale = Vector3(14, 14, 14)
		sm.albedo_color = Color(0.42, 0.4, 0.42)
		sm.roughness = 0.95
		ground.material_override = sm


# ── perimeter ────────────────────────────────────────────────────────────

func _perimeter() -> void:
	# Front fence run (+Z) with a gap at the gate, a side run (-X).
	var probe := _load_model("kaykit/fence.gltf")
	if probe != null:
		var box := _aabb_of(probe)
		probe.queue_free()
		var s := 1.35 / maxf(box.size.y, 0.01)
		var step := maxf(box.size.x * s, 0.5)
		var half := 20.0
		var n := int((half * 2.0) / step)
		for i in range(n):
			var x := -half + step * 0.5 + float(i) * step
			if absf(x) < 2.2:
				continue  # gate gap
			_place("kaykit/fence.gltf", Vector3(x, 0.0, 22.0), 0.0, 1.35)
		for i in range(int((36.0) / step)):
			var z := -18.0 + step * 0.5 + float(i) * step
			if z > 18.0:
				break
			_place("kaykit/fence.gltf", Vector3(-22.0, 0.0, z), PI * 0.5, 1.35)
	# Broken sections sprinkled along the fence for wear.
	_place("kaykit/fence_broken.gltf", Vector3(-7.5, 0.0, 22.0), 0.0, 1.2)
	_place("kaykit/fence_broken.gltf", Vector3(9.5, 0.0, 22.0), 0.1, 1.2)
	_place("kaykit/fence_pillar.gltf", Vector3(2.6, 0.0, 22.0), 0.0, 1.7)
	_place("kaykit/fence_pillar.gltf", Vector3(-2.6, 0.0, 22.0), 0.0, 1.7)
	# Tree line + graves along the back and right side.
	var trees := [
		{"m": "kaykit/tree_dead_large.gltf", "p": Vector3(-14.0, 0, -20.0), "h": 5.4},
		{"m": "kaykit/tree_dead_large.gltf", "p": Vector3(10.0, 0, -21.0), "h": 5.0},
		{"m": "kaykit/tree_dead_medium.gltf", "p": Vector3(-4.0, 0, -21.5), "h": 4.4},
		{"m": "kaykit/tree_dead_medium.gltf", "p": Vector3(18.0, 0, -14.0), "h": 4.6},
		{"m": "kaykit/tree_dead_small.gltf", "p": Vector3(21.0, 0, 4.0), "h": 3.4},
		{"m": "kaykit/tree_dead_small.gltf", "p": Vector3(20.5, 0, -6.0), "h": 3.2},
	]
	for t in trees:
		_place(t["m"], t["p"], _rng.randf_range(-PI, PI), t["h"])


# ── structures ───────────────────────────────────────────────────────────

func _structures() -> void:
	# Arch gate at the entrance (focal point when you spawn and look around).
	var arch := _place("kaykit/arch_gate.gltf", Vector3(0.0, 0.0, 21.5), PI, 5.2)
	if arch:
		_add_collision_box(arch, Vector3(0.7, 5.2, 0.7), Vector3(0, 2.6, 0), 0.0)
	# Corner mausoleums.
	var crypt_a := _place("kaykit/crypt.gltf", Vector3(-16.5, 0.0, -16.5), 0.35, 3.6)
	if crypt_a:
		_add_collision_box(crypt_a, Vector3(4.6, 3.6, 3.4), Vector3(0, 1.8, 0), 0.35)
	var crypt_b := _place("kaykit/crypt.gltf", Vector3(16.5, 0.0, -16.5), -0.3, 3.6)
	if crypt_b:
		_add_collision_box(crypt_b, Vector3(4.6, 3.6, 3.4), Vector3(0, 1.8, 0), -0.3)
	# The Muakbank counter — the "bank" the horde wants to break into.
	var counter_pos := Vector3(0.0, 0.0, 12.0)
	_box(Vector3(5.4, 0.18, 1.05), counter_pos + Vector3(0, 1.02, 0), _wood, 0.0, true)
	_box(Vector3(0.22, 1.0, 1.05), counter_pos + Vector3(-2.6, 0.5, 0), _wood_dark)
	_box(Vector3(0.22, 1.0, 1.05), counter_pos + Vector3(2.6, 0.5, 0), _wood_dark)
	_box(Vector3(0.5, 0.5, 0.5), counter_pos + Vector3(-3.6, 0.25, 0.4), _wood_dark)
	_box(Vector3(0.5, 0.5, 0.5), counter_pos + Vector3(3.4, 0.25, -0.3), _wood_dark)
	# Two coffins as centrepiece props (one open angle, one closed).
	_place("kaykit/coffin.gltf", Vector3(-6.5, 0.0, 3.0), 0.5, 0.6)
	_place("kaykit/coffin.gltf", Vector3(7.2, 0.0, -2.5), -0.9, 0.6)


func _add_collision_box(_ref: Node3D, size: Vector3, offset: Vector3, yaw: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	sb.rotation.y = yaw
	sb.position = _ref.position
	add_child(sb)


# ── seating (restaurant feel around the counter) ────────────────────────

func _seating() -> void:
	var spots := [
		Vector3(-6.0, 0.0, 9.0), Vector3(6.0, 0.0, 9.0),
		Vector3(-8.5, 0.0, 13.5), Vector3(8.5, 0.0, 13.5),
	]
	for p in spots:
		# table: top + pedestal
		_box(Vector3(1.5, 0.1, 0.95), p + Vector3(0, 0.78, 0), _wood)
		_cyl(0.09, 0.76, p + Vector3(0, 0.38, 0), _wood_dark)
		# two benches
		_box(Vector3(1.6, 0.09, 0.42), p + Vector3(0, 0.48, -0.85), _wood)
		_box(Vector3(1.6, 0.09, 0.42), p + Vector3(0, 0.48, 0.85), _wood)
		_box(Vector3(0.09, 0.46, 0.4), p + Vector3(-0.7, 0.24, -0.85), _wood_dark)
		_box(Vector3(0.09, 0.46, 0.4), p + Vector3(0.7, 0.24, -0.85), _wood_dark)
		_box(Vector3(0.09, 0.46, 0.4), p + Vector3(-0.7, 0.24, 0.85), _wood_dark)
		_box(Vector3(0.09, 0.46, 0.4), p + Vector3(0.7, 0.24, 0.85), _wood_dark)


# ── scatter ──────────────────────────────────────────────────────────────

func _ring_pos(min_r: float, max_r: float) -> Vector3:
	var a := _rng.randf_range(0.0, TAU)
	var r := _rng.randf_range(min_r, max_r)
	return Vector3(cos(a) * r, 0.0, sin(a) * r)


func _scatter_graveyard() -> void:
	var kinds := [
		"kaykit/gravestone.gltf", "kaykit/grave_A.gltf", "kaykit/grave_B.gltf",
		"kaykit/gravemarker_A.gltf", "kaykit/gravemarker_B.gltf",
		"kenney/gravestone-cross.glb", "kenney/gravestone-round.glb",
	]
	for i in range(14):
		var p := _ring_pos(13.0, 20.5)
		# keep the gate approach clear
		if p.z > 16.0 and absf(p.x) < 3.0:
			continue
		_place(kinds[_rng.randi() % kinds.size()], p, _rng.randf_range(-PI, PI), _rng.randf_range(1.1, 1.8))
	for i in range(3):
		var p2 := _ring_pos(10.0, 17.0)
		_place("kaykit/grave_A_destroyed.gltf", p2, _rng.randf_range(-PI, PI), _rng.randf_range(0.9, 1.3))


func _scatter_pumpkins() -> void:
	for i in range(10):
		var p := _ring_pos(4.0, 19.0)
		var jack := (i % 3 == 0)
		var model := "kaykit/pumpkin_orange_jackolantern.gltf" if jack else "kaykit/pumpkin_orange.gltf"
		var inst := _place(model, p, _rng.randf_range(-PI, PI), 0.55)
		if jack and inst and i < 6:
			# The carved ones glow.
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.62, 0.2)
			l.light_energy = 0.55
			l.omni_range = 3.2
			l.position = Vector3(0, 0.6, 0)
			inst.add_child(l)


func _scatter_small() -> void:
	for i in range(8):
		var p := _ring_pos(3.0, 18.0)
		var m := "kaykit/skull.gltf" if i % 2 == 0 else "kaykit/bone_A.gltf"
		_place(m, p, _rng.randf_range(-PI, PI), 0.28)


func _blood() -> void:
	var tex := load("res://assets/textures/floor_blood.png") as Texture2D
	if tex == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.1, 0.08, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var spots := [
		Vector3(2.4, 0.102, 10.6), Vector3(-3.1, 0.102, 13.2),
		Vector3(5.5, 0.102, 6.0), Vector3(-7.0, 0.102, -1.0),
		Vector3(3.0, 0.102, -5.5), Vector3(-2.0, 0.102, 16.5),
	]
	for p in spots:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(_rng.randf_range(1.6, 2.6), _rng.randf_range(1.6, 2.6))
		mi.mesh = q
		mi.material_override = mat
		mi.position = p
		mi.rotation.x = -PI * 0.5
		mi.rotation.z = _rng.randf_range(0.0, TAU)
		add_child(mi)


func _lamps() -> void:
	var spots := [Vector3(-5.5, 0, -5.0), Vector3(6.0, 0, -4.0), Vector3(-4.5, 0, 14.5), Vector3(5.5, 0, 15.5)]
	for p in spots:
		var inst := _place("kaykit/lantern_standing.gltf", p, 0.0, 1.5)
		if inst:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.42)
			l.light_energy = 1.25
			l.omni_range = 7.0
			l.position = Vector3(0, 1.7, 0)
			inst.add_child(l)
	_place("kaykit/post_lantern.gltf", Vector3(2.9, 0.0, 13.0), 0.0, 2.2)
	_place("kaykit/post_lantern.gltf", Vector3(-2.9, 0.0, 13.0), 0.0, 2.2)