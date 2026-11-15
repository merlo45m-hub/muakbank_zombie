extends Node
## DebrisPool (autoload) — bounded object pool for detached dismantle parts.
## GDD §6 "cap active debris count and auto-despawn detached parts after
## collection". Recycle, do NOT queue_free: keeps the active node count bounded
## under multi-prop destruction stress (the 60 FPS guardrail).

const MAX_ACTIVE: int = 48

var _free: Array[Node] = []
var _active: Array[Node] = []


func acquire(scene: PackedScene, at: Vector3) -> Node:
	if scene == null:
		return null
	# Cap reached: recycle the oldest active part instead of growing the tree.
	if _active.size() >= MAX_ACTIVE:
		var oldest: Node = _active.pop_front() as Node
		_recycle_one(oldest)
	var inst: Node = null
	if not _free.is_empty():
		inst = _free.pop_back() as Node
	else:
		inst = scene.instantiate()
		add_child(inst)
	if inst == null:
		return null
	_active.append(inst)
	if inst is Node3D:
		var n3d: Node3D = inst as Node3D
		n3d.visible = true
		n3d.global_position = at
	elif inst is CanvasItem:
		(inst as CanvasItem).visible = true
	return inst


func recycle_all(nodes: Array) -> void:
	for n in nodes:
		if n is Node:
			_recycle_one(n as Node)


func _recycle_one(node: Node) -> void:
	if node == null:
		return
	_hide(node)
	_active.erase(node)
	if not _free.has(node):
		_free.append(node)


func _hide(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	elif node is CanvasItem:
		(node as CanvasItem).visible = false


func active_count() -> int:
	return _active.size()


func free_count() -> int:
	return _free.size()
