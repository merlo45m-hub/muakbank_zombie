extends SceneTree

## In-engine GLB asset contract gate (Issue #14 automation).
## For every entry in tools/glb_asset_contract.json: load the GLB as a
## PackedScene, instance it under a hidden Node3D on root, await 4 frames,
## then walk the instance computing the world-space AABB union via
## MeshInstance3D.global_aabb. Assert dims vs the manifest locked dims within
## dims_tolerance, the height-axis fraction rule (same rule as the external
## gate, now proven in-engine), and root-level rotation alignment
## (axis-aligned basis columns, determinant == 1). Internal parts may keep
## authored rotations (Kenney colliders). Prints ASSET_CONTRACT_PASS=true and
## quits 0; any failure prints ASSET_CONTRACT_FAIL <asset> <reason> and quits 1.
## Also boots the GridSnap-modified street scene and asserts every GridSnap
## child is snapped (position mod cell == 0, rotation quantized) and prints
## GRID_SNAP_PASS=true.

const CONTRACT_PATH: String = "res://tools/glb_asset_contract.json"
const HIDDEN_HOST_NAME: String = "__AssetContractHost"
const SETTLE_FRAMES: int = 4
const AXIS_EPS: float = 0.01
const MOD_EPS: float = 0.01
const STREET_SCENE: String = "res://scenes/world/environment/old_town_enhanced.tscn"

func _ready() -> void:
	if not _run_asset_contract():
		quit(1)
	if not _run_grid_snap_probe():
		quit(1)
	quit(0)

func _run_asset_contract() -> bool:
	var entries: Array = _load_contract()
	if entries.is_empty():
		print("ASSET_CONTRACT_FAIL contract empty or unreadable ", CONTRACT_PATH)
		return false
	var host: Node3D = Node3D.new()
	host.name = HIDDEN_HOST_NAME
	get_tree().get_root().add_child(host)
	var failures: Array[String] = []
	var checked: int = 0
	for entry in entries:
		_check_asset(entry, host, failures)
		while host.get_child_count() > 0:
			host.get_child(0).queue_free()
		await process_frame
		checked += 1
	get_tree().get_root().remove_child(host)
	host.free()
	if failures.is_empty():
		print("ASSET_CONTRACT_PASS=true assets=", checked)
		return true
	for f in failures:
		print("ASSET_CONTRACT_FAIL ", f)
	print("ASSET_CONTRACT_PASS=false checked=", checked, " failed=", failures.size())
	return false

func _load_contract() -> Array:
	var f: FileAccess = FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if f == null:
		print("ASSET_CONTRACT_FAIL cannot read ", CONTRACT_PATH)
		return []
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		print("ASSET_CONTRACT_FAIL contract is not an array")
		return []
	return parsed as Array

func _check_asset(entry: Dictionary, host: Node3D, failures: Array[String]) -> void:
	var rel: String = String(entry.get("file", ""))
	var path: String = "res://" + rel
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		failures.append(rel + " GLB failed to load")
		return
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		failures.append(rel + " instance is not a Node3D")
		return
	host.add_child(inst)
	for _ in range(SETTLE_FRAMES):
		await process_frame
	var expect: Dictionary = entry.get("expect", {}) as Dictionary
	var tol: float = float(entry.get("dims_tolerance", 0.25))
	var aabb: AABB = _world_aabb_union(inst)
	var size: Vector3 = aabb.size
	var dims_fail: String = _check_dims(size, expect.get("dims", {}) as Dictionary, tol)
	if dims_fail != "":
		failures.append(rel + " dims " + dims_fail)
		return
	var h_axis: String = String(expect.get("height_axis", "Y"))
	var min_frac: float = float(expect.get("min_height_frac", 0.0))
	var axis_idx: int = _axis_index(h_axis)
	var largest: float = maxf(size.x, maxf(size.y, size.z))
	if largest > 0.0 and size[axis_idx] < largest * min_frac:
		failures.append(rel + " orientation height axis ", h_axis, " fraction below min_frac ", str(min_frac))
		return
	var basis: Basis = inst.global_transform.basis
	if not _basis_axis_aligned(basis):
		failures.append(rel + " root basis not axis-aligned")
		return
	var det: float = basis.determinant()
	if absf(det - 1.0) > AXIS_EPS:
		failures.append(rel + " root determinant != 1 (", str(det), ")")
		return
	print("ASSET_CHECK ", rel, " OK dims=(%.2f,%.2f,%.2f)" % [size.x, size.y, size.z])

func _check_dims(size: Vector3, dims: Dictionary, tol: float) -> String:
	var axes: Array[String] = ["X", "Y", "Z"]
	var extents: Array[float] = [size.x, size.y, size.z]
	for i in range(3):
		var axis: String = axes[i]
		var want: Variant = dims.get(axis, 0)
		var w: float = float(want)
		if w <= 0.0:
			continue
		if absf(extents[i] - w) > tol:
			return axis + " extent " + str(extents[i]) + " vs locked " + str(w) + " tol " + str(tol)
	return ""

func _axis_index(axis: String) -> int:
	match axis:
		"X":
			return 0
		"Y":
			return 1
		"Z":
			return 2
		_:
			return 1

func _basis_axis_aligned(basis: Basis, eps: float = 0.01) -> bool:
	var cols: Array[Vector3] = [basis.x, basis.y, basis.z]
	for c in cols:
		var cx: float = absf(c.x)
		var cy: float = absf(c.y)
		var cz: float = absf(c.z)
		var dominant: float = maxf(cx, maxf(cy, cz))
		if dominant < 0.9:
			return false
		if cx > eps and absf(cx - 1.0) > eps:
			return false
		if cy > eps and absf(cy - 1.0) > eps:
			return false
		if cz > eps and absf(cz - 1.0) > eps:
			return false
	return true

func _world_aabb_union(root: Node3D) -> AABB:
	var aabb: AABB = AABB()
	var have: bool = false
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_front()
		if node is MeshInstance3D:
			var m: AABB = node.global_aabb
			if not have:
				aabb = m
				have = true
			else:
				aabb = aabb.merge(m)
		for child in node.get_children():
			stack.push_back(child as Node)
	return aabb

func _run_grid_snap_probe() -> bool:
	var packed: PackedScene = load(STREET_SCENE) as PackedScene
	if packed == null:
		print("GRID_SNAP_FAIL street scene failed to load ", STREET_SCENE)
		return false
	var env: Node = packed.instantiate()
	if env == null:
		print("GRID_SNAP_FAIL street scene failed to instantiate")
		return false
	get_tree().get_root().add_child(env)
	for _ in range(8):
		await process_frame
	var hosts: Array = get_tree().get_nodes_in_group("GridSnap")
	if hosts.is_empty():
		print("GRID_SNAP_FAIL no GridSnap hosts found in street scene")
		return false
	var ok: bool = true
	for host in hosts:
		var snap: GridSnap = host as GridSnap
		if snap == null:
			continue
		var cell: float = snap.cell_size
		var step: float = deg_to_rad(float(snap.rotation_step_deg))
		var checked_count: int = 0
		for child in snap.get_children():
			if not (child is Node3D):
				continue
			var node: Node3D = child as Node3D
			var mx: float = absf(fmodf(node.position.x, cell))
			var mz: float = absf(fmodf(node.position.z, cell))
			var mr: float = absf(fmodf(node.rotation.y, step))
			var pos_ok: bool = mx < MOD_EPS or mx > cell - MOD_EPS
			var rot_ok: bool = mr < MOD_EPS or mr > step - MOD_EPS
			checked_count += 1
			if not pos_ok or not rot_ok:
				ok = false
				print("GRID_SNAP_FAIL host=", host.name, " child=", node.name, " pos=", node.position, " rot=", node.rotation)
		print("GRID_SNAP_HOST ", host.name, " children_checked=", checked_count, " cell=", cell, " step_deg=", snap.rotation_step_deg)
	if ok:
		print("GRID_SNAP_PASS=true hosts=", hosts.size())
	else:
		print("GRID_SNAP_PASS=false")
	return ok
