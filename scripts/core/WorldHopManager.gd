## WorldHopManager.gd — Issue #11 P3, autoload "WorldHopManager".
## The SINGLE world-region loader. Regions are instanced under a persistent
## WorldRoot via threaded loading — NEVER change_scene_to_file, so autoloads,
## spawners, timers and DayNightCycle keep ticking across a hop.
##
## State machine: IDLE -> GATES_CHECKED -> LOADING -> RELOCATING_PLAYER -> ACTIVE -> IDLE
##               any step -> FAILED (recoverable on the next request).
## One in-flight hop only; `generation` increments per request so a stale
## threaded-load callback from a superseded request is discarded.
extends Node

enum HopState { IDLE, GATES_CHECKED, LOADING, RELOCATING_PLAYER, ACTIVE, FAILED }

# Optional explicit overrides. When empty, WorldRoot is resolved/created under
# get_tree().current_scene and tagged in group "world_root"; player is resolved by
# group "player" (Player.gd does add_to_group("player")).
@export var world_root_path: NodePath
@export var player_fallback_path: NodePath

var state: HopState = HopState.IDLE
var generation: int = 0
var current_region_instance: Node = null

# Issue #18 — structured transient-state snapshot captured BEFORE an old region
# is unloaded. Player stats + active spawner state are JSON-serializable.
var last_transient_snapshot: Dictionary = {}
var snapshot_count: int = 0

var _gen: int = 0
var _path: String = ""
var _target_region: int = 0
var _spawn: Vector3 = Vector3.ZERO
var _world_root: Node = null


func _wp() -> Node:
	return get_node_or_null("/root/WorldProgression")


func adopt(instance: Node) -> void:
	"""Game.gd calls this after its synchronous startup load so the first hop
	frees the initial environment instead of stacking a second one on top."""
	current_region_instance = instance


func is_busy() -> bool:
	return state == HopState.LOADING or state == HopState.RELOCATING_PLAYER \
		or state == HopState.GATES_CHECKED


func request_hop(to_region: int) -> void:
	# Single in-flight hop: a second trigger is a no-op (idempotent entry).
	# FAILED is recoverable so a transient load error does not wedge the manager.
	if state != HopState.IDLE and state != HopState.FAILED:
		return
	var wp := _wp()
	if wp == null:
		_fail(&"no_world_progression")
		return
	if not wp.can_hop(to_region):
		_fail(&"region_locked")
		return
	var def = wp.get_def(to_region)
	if def == null:
		_fail(&"unknown_region")
		return
	var scene_path: String = def.scene_path
	if not ResourceLoader.exists(scene_path):
		_fail(&"scene_missing")
		return

	generation += 1
	_gen = generation
	_target_region = to_region
	_path = scene_path
	_spawn = def.spawn_point
	state = HopState.GATES_CHECKED
	wp.report_hop_started(wp.current_region, to_region)

	var err := ResourceLoader.load_threaded_request(_path)
	if err != OK:
		_fail(&"thread_request_failed")
		return
	state = HopState.LOADING


func _process(_delta: float) -> void:
	if state != HopState.LOADING:
		return
	var st := ResourceLoader.load_threaded_get_status(_path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		# A superseded request's callback must not instance a stale region.
		if _gen != generation:
			state = HopState.IDLE
			return
		var packed: Resource = ResourceLoader.load_threaded_get(_path)
		if packed == null:
			_fail(&"thread_instance_null")
			return
		_on_load_complete(packed)
	elif st == ResourceLoader.THREAD_LOAD_FAILED \
			or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if _gen != generation:
			state = HopState.IDLE
			return
		_fail(&"thread_load_failed")


func _ensure_world_root() -> Node:
	if _world_root != null and is_instance_valid(_world_root):
		return _world_root
	if not world_root_path.is_empty():
		var explicit := get_node_or_null(world_root_path)
		if explicit != null:
			_world_root = explicit
			return _world_root
	var existing := get_tree().get_first_node_in_group("world_root")
	if existing != null:
		_world_root = existing
		return _world_root
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var wr := scene.get_node_or_null("WorldRoot")
	if wr == null:
		wr = Node3D.new()
		wr.name = "WorldRoot"
		scene.add_child(wr)
	wr.add_to_group("world_root")
	_world_root = wr
	return _world_root


func _find_player() -> Node3D:
	var p := get_tree().get_first_node_in_group("player")
	if p is Node3D:
		return p as Node3D
	if not player_fallback_path.is_empty():
		var f := get_node_or_null(player_fallback_path)
		if f is Node3D:
			return f as Node3D
	return null


func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Issue #18 — structured serialization of transient game state BEFORE the old
## region is freed. Player stats/position and active spawner flag/timer are
## captured as plain JSON-safe values (Vector3 -> Array). Spawners are siblings
## of the region (they survive instancing), so we record their live state rather
## than reparenting them. The snapshot is kept on the manager and can be applied
## back with restore_transient_state() after a transition.
## Resolve the node that owns the spawners. In real runtime current_scene IS the
## Game scene; in a headless --script probe the game is a child of root named
## "Game" and current_scene is null. Handle both so the snapshot is not empty.
func _game_root() -> Node:
	var scene := get_tree().current_scene
	if scene != null and (scene.has_node("ZombieSpawner") or scene.has_node("FoodSpawner")):
		return scene
	var direct := get_tree().root.get_node_or_null("Game")
	if direct != null and (direct.has_node("ZombieSpawner") or direct.has_node("FoodSpawner")):
		return direct
	for child in get_tree().root.get_children():
		if child.has_node("ZombieSpawner") or child.has_node("FoodSpawner"):
			return child
	return null


func snapshot_transient_state() -> Dictionary:
	var snap: Dictionary = {
		"from_region": 0,
		"to_region": _target_region,
		"ts_msec": Time.get_ticks_msec(),
		"player": {},
		"spawners": {},
	}
	var wp := _wp()
	if wp != null:
		snap["from_region"] = int(wp.current_region)

	var player := _find_player()
	if player != null:
		var p: Dictionary = {"position": _v3(player.global_position)}
		for prop in ["health", "max_health", "stamina", "max_stamina", "score", "kills"]:
			var v = player.get(prop)
			if v != null:
				p[prop] = v
		snap["player"] = p

	var scene := _game_root()
	if scene != null:
		for spawner_name in ["ZombieSpawner", "FoodSpawner"]:
			var sp := scene.get_node_or_null(spawner_name)
			if sp == null:
				continue
			var s: Dictionary = {}
			var can = sp.get("can_spawn")
			if can != null:
				s["can_spawn"] = bool(can)
			var timer := sp.get_node_or_null("SpawnTimer") as Timer
			if timer != null:
				s["time_left"] = timer.time_left
			snap["spawners"][spawner_name] = s
	return snap


## Apply a previously captured snapshot back onto live nodes. Returns true when a
## player was found and restored. Position is intentionally NOT restored: the hop
## deliberately relocates the player to the new region's spawn point.
func restore_transient_state(snap: Dictionary) -> bool:
	var player := _find_player()
	if player == null:
		return false
	var p: Dictionary = snap.get("player", {})
	for prop in ["health", "max_health", "stamina", "max_stamina", "score", "kills"]:
		if p.has(prop) and player.get(prop) != null:
			player.set(prop, p[prop])
	return true


func _on_load_complete(packed: Resource) -> void:
	state = HopState.RELOCATING_PLAYER
	var root := _ensure_world_root()
	var inst := (packed as PackedScene).instantiate()
	root.add_child(inst)

	var player := _find_player()
	if player != null:
		player.global_position = _spawn

	# Issue #18: serialize transient state BEFORE the old region is unloaded.
	last_transient_snapshot = snapshot_transient_state()
	snapshot_count += 1

	# Free the old region only AFTER the new one is in the tree, preserving the
	# persistent WorldRoot and every sibling (spawners/timers/day-night).
	var old := current_region_instance
	current_region_instance = inst
	if old != null and is_instance_valid(old) and old != inst:
		old.queue_free()

	state = HopState.ACTIVE
	var wp := _wp()
	if wp != null:
		wp.report_hop_completed(_target_region)
	state = HopState.IDLE


func _fail(reason: StringName) -> void:
	state = HopState.FAILED
	var wp := _wp()
	if wp != null:
		wp.report_hop_failed(reason)
