extends Node3D

## Zombie Spawner — Spawns all 5 enemy types with object pooling + vector-field navigation
## Zombies are pooled and reused; navigation uses a pre-computed VFN field instead of per-zombie pathfinding

signal zombie_killed(zombie_type)

@export var max_zombies: int = 12
@export var spawn_interval: float = 3.0
@export var spawn_radius: float = 15.0
@export var min_spawn_distance: float = 8.0

# --- Scene preloads ---
var zombie_dog_scene = preload("res://scenes/characters/zombie_dog.tscn")
var zombie_cat_scene = preload("res://scenes/characters/zombie_cat.tscn")
var zombie_bear_scene = preload("res://scenes/characters/zombie_bear.tscn")
var zombie_rabbit_scene = preload("res://scenes/characters/zombie_rabbit.tscn")
var zombie_chicken_scene = preload("res://scenes/characters/zombie_chicken.tscn")
var zombie_runner_scene = preload("res://scenes/characters/zombie_runner.tscn")
var zombie_spitter_scene = preload("res://scenes/characters/zombie_spitter.tscn")

var player: Node3D = null
var active_zombies: Array = []
var can_spawn: bool = false
var difficulty_manager: Node = null
var current_level: int = 1

@onready var spawn_timer: Timer = $SpawnTimer

# --- Object pools: one per zombie type ---
var pools: Dictionary = {}

# --- Vector field navigation ---
var vfn_map: VFNMap = null
var vfn_field: VFNField = null
var vfn_field_ready: bool = false

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("[ZombieSpawner] No player found!")

	# --- Initialise object pools ---
	_init_pools()

	# SpawnTimer.timeout was never wired (not in game.tscn, not in code), so the
	# timer ticked into the void and NO zombie ever spawned. Connect it here;
	# idempotent so a future scene-level connection can't double-fire it.
	if not spawn_timer.timeout.is_connected(_spawn_random_zombie):
		spawn_timer.timeout.connect(_spawn_random_zombie)

	# --- Find DifficultyManager for dynamic spawn tuning ---
	# It is a child of the Game root, NOT an autoload — "/root/DifficultyManager"
	# resolved to null forever and the whole tuning path silently fell back to the
	# exported defaults. The spawner is a sibling of it under Game.
	difficulty_manager = get_node_or_null("../DifficultyManager")

	# --- Try to find a VFN map in the scene ---
	vfn_map = get_node_or_null("VFNMap")
	if not vfn_map:
		push_warning("[ZombieSpawner] VFNMap node not found — zombies will use legacy direct-chase AI")
		return

	# Wait for map to be ready (it waits for process_frame internally)
	await get_tree().process_frame

	# Create the navigation field
	if vfn_map:
		vfn_field = vfn_map.create_field()
		if vfn_field:
			# Weight the default mod fields if they exist
			vfn_field.set_modfield("margin", 1.0)
			vfn_field.effort_cutoff = 5000.0
			vfn_field.climb_factor = 0.0
			vfn_field.drop_factor = 0.0
			vfn_field_ready = true
			push_warning("[ZombieSpawner] VFN field created successfully")
		else:
			push_warning("[ZombieSpawner] Failed to create VFN field")
	else:
		push_warning("[ZombieSpawner] No VFNMap node in scene — zombies will use legacy direct-chase AI")


# ──────────────────────────────────────────────
#  OBJECT POOL INITIALISATION
# ──────────────────────────────────────────────

func _init_pools() -> void:
	# Build a pool config: [scene, prefix, types_list]
	var configs = [
		[zombie_dog_scene,     "zombie_dog",     ["dog"]],
		[zombie_cat_scene,     "zombie_cat",     ["cat"]],
		[zombie_bear_scene,    "zombie_bear",    ["bear"]],
		[zombie_rabbit_scene,  "zombie_rabbit",  ["rabbit"]],
		[zombie_chicken_scene, "zombie_chicken", ["chicken"]],
		[zombie_runner_scene,  "zombie_runner",  ["runner"]],
		[zombie_spitter_scene, "zombie_spitter", ["spitter"]]
	]

	for cfg in configs:
		var scene = cfg[0]
		var prefix = cfg[1]
		var types = cfg[2]
		if scene == null:
			push_warning("[ZombieSpawner] Scene for '" + prefix + "' is null — skipping pool")
			continue
		# Pool size: enough for max_zombies / number_of_types + safety margin
		var pool_size = max(1, (max_zombies / types.size()) + 2)
		var pool = _create_pool(pool_size, prefix, scene)
		if pool:
			pools[prefix] = {"pool": pool, "types": types}
			print("[ZombieSpawner] Pool '" + prefix + "' created with " + str(pool_size) + " slots")
		else:
			push_warning("[ZombieSpawner] Failed to create pool for '" + prefix + "'")


func _create_pool(size: int, prefix: String, scene) -> Object:
	# The godot-object-pool pool.gd expects (size, prefix, scene) in _init
	# Instancing a script resource directly works in Godot 4.x
	var pool_script = preload("res://addons/godot-object-pool/pool.gd")
	var pool = pool_script.new(size, prefix, scene)
	pool.add_to_node(self)

	# The addon's add_to_node() parents the DEAD (parked) instances too, which
	# drops every pooled zombie at the spawner's origin — on top of the player
	# spawn — fully collidable and attack-ready. Parked instances must not exist
	# in the world at all: take them back out of the tree and make them inert.
	# get_first_dead() + the spawner's add_child() re-enters them on checkout.
	for i in pool.dead:
		var p: Node = i.get_parent()
		if p:
			p.remove_child(i)
		if i is CollisionObject3D:
			i.collision_layer = 0
			i.collision_mask = 0
		i.process_mode = Node.PROCESS_MODE_DISABLED
		if i is Node3D:
			i.visible = false
	return pool


func _get_pool_for_type(zombie_type: String) -> Dictionary:
	for key in pools.keys():
		var entry = pools[key]
		if zombie_type in entry["types"]:
			return entry
	return {}


# ──────────────────────────────────────────────
#  SPAWNING
# ──────────────────────────────────────────────

func start_spawning() -> void:
	can_spawn = true
	current_level = Save.get_current_level()
	spawn_timer.start(spawn_interval)
	print("[ZombieSpawner] Started spawning zombies")


func stop_spawning() -> void:
	can_spawn = false
	spawn_timer.stop()
	# Return all active zombies to their pools instead of queue_free
	for z in active_zombies:
		if is_instance_valid(z):
			_return_to_pool(z)
	active_zombies.clear()
	print("[ZombieSpawner] Stopped spawning, all zombies returned to pools")


func _spawn_random_zombie() -> void:
	if not can_spawn or not player:
		return
	# Use dynamic limits from DifficultyManager when available; fall back to
	# the exported defaults so the spawner works standalone.
	# Difficulty SCALES the configured values rather than replacing them, so the
	# WaveManager (which sets max_zombies per wave) stays the authority.
	var effective_max = max_zombies
	var effective_interval = spawn_interval
	if difficulty_manager:
		if difficulty_manager.has_method("get_max_zombies_multiplier"):
			effective_max = int(max_zombies * difficulty_manager.get_max_zombies_multiplier())
		if difficulty_manager.has_method("get_spawn_interval"):
			effective_interval = spawn_interval * difficulty_manager.get_spawn_interval()
	if active_zombies.size() >= effective_max:
		spawn_timer.start(effective_interval)
		return

	# Pick a random type
	var scenes = [
		zombie_dog_scene,
		zombie_cat_scene,
		zombie_bear_scene,
		zombie_rabbit_scene,
		zombie_chicken_scene,
		zombie_runner_scene,
		zombie_spitter_scene
	]
	var zombie_types = ["dog", "cat", "bear", "rabbit", "chicken", "runner", "spitter"]
	var type_index = randi() % scenes.size()
	var zombie_type = zombie_types[type_index]

	# Borrow a zombie from the pool
	var pool_entry = _get_pool_for_type(zombie_type)
	if pool_entry.is_empty():
		print("[ZombieSpawner] No pool found for type '" + zombie_type + "' — skipping")
		return

	var pool = pool_entry["pool"]
	var zombie = pool.get_first_dead()
	if zombie == null:
		# Pool exhausted — expand it
		print("[ZombieSpawner] Pool exhausted for '" + zombie_type + "', expanding pool")
		pool.size += 2
		pool.init()
		zombie = pool.get_first_dead()
		if zombie == null:
			print("[ZombieSpawner] Still no zombie after pool expansion — skipping")
		return

	# Position the zombie
	var angle = randf() * TAU
	var dist = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
	var spawn_pos = player.global_transform.origin + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	# Ground detection via raycast. Start the ray LOW (just above head height):
	# casting from +50 hits rooftops/awnings and strands zombies on top of
	# buildings where they idle forever, invisible and unreachable.
	var space_state = get_world_3d().direct_space_state
	if space_state:
		var query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 3, 0), spawn_pos + Vector3(0, -60, 0))
		var result = space_state.intersect_ray(query)
		if result:
			spawn_pos.y = result.position.y
	# Any spawn still high above the player's level is a bogus surface — put it at
	# the player's ground level instead of leaving a zombie stranded in the sky.
	if spawn_pos.y > player.global_transform.origin.y + 3.0:
		spawn_pos.y = player.global_transform.origin.y

	# --- Spawn wall check ---
	# Cast from the player's chest toward the proposed spawn. The player is excluded
	# (its own capsule would otherwise register as a hit) and only horizontal
	# distance counts — the 1.5m lift would make a real wall read as >1m away.
	# A rejected angle retries next timer tick (SpawnTimer is not one-shot).
	var wall_query = PhysicsRayQueryParameters3D.create(
		player.global_transform.origin + Vector3(0, 1.5, 0),
		spawn_pos + Vector3(0, 1.5, 0)
	)
	if player is CollisionObject3D:
		wall_query.exclude = [player.get_rid()]
	var wall_result = space_state.intersect_ray(wall_query) if space_state else null
	if wall_result:
		var hit_flat = Vector2(wall_result.position.x, wall_result.position.z)
		var spawn_flat = Vector2(spawn_pos.x, spawn_pos.z)
		if hit_flat.distance_to(spawn_flat) < 1.0:
			blocked_spawns += 1
			return

	# Mark as pool-managed and restore pristine state before it re-enters the world
	zombie.set("pooled", true)
	if zombie.has_method("reset_for_pool"):
		zombie.reset_for_pool()

	add_child(zombie)
	zombie.global_transform.origin = spawn_pos
	print("[SPAWN] %s at %s  player=%s  dist=%.2f  (min=%.1f radius=%.1f)" % [
		zombie_type, str(spawn_pos), str(player.global_transform.origin),
		spawn_pos.distance_to(player.global_transform.origin), min_spawn_distance, spawn_radius])
	active_zombies.append(zombie)
	zombie.set("zombie_type", zombie_type)

	# Connect the died signal. The handler is bound with arguments, so the bound
	# Callable is NOT the same object as the bare method reference — disconnect()
	# with the bare name silently fails ("nonexistent connection") on every spawn.
	# Keep the exact bound Callable on the zombie so a pooled reuse can drop its
	# previous connection instead of firing the handler twice.
	if zombie.has_signal("died"):
		# Untyped: get() returns Nil on a zombie's first spawn (the property does not
		# exist yet) and assigning that to a typed Callable is itself an error.
		var prev = zombie.get("_died_callable")
		if prev is Callable and prev.is_valid() and zombie.died.is_connected(prev):
			zombie.died.disconnect(prev)
		var bound := _on_zombie_died.bind(zombie, zombie_type)
		zombie.died.connect(bound)
		zombie.set("_died_callable", bound)

	# Store a reference to the pool entry on the zombie so _on_zombie_died can return it
	zombie.set("pool_entry", pool_entry)

	# Hand the zombie its target immediately. Detection ranges are 10-12 while
	# spawn distance is 8-15, so roughly half of all spawns landed outside the
	# zombie's own detection sphere and idled in place forever (the world looked
	# empty because nothing ever walked toward the player).
	if zombie.has_method("set_target"):
		zombie.set_target(player)

	# Apply vector-field navigation if available
	if vfn_field_ready and vfn_field:
		if zombie.has_method("set_vfn_field"):
			zombie.set_vfn_field(vfn_field)

	# Apply difficulty-based stat scaling
	if difficulty_manager and difficulty_manager.has_method("get_level_difficulty"):
		var diff_mult = difficulty_manager.get_level_difficulty(current_level)
		if zombie.has_method("apply_difficulty"):
			zombie.apply_difficulty(diff_mult)

	# Trigger spawn scale-in on the animator (duck-typed — safe if absent).
	var _sa := zombie.get_node_or_null("ProceduralAnimator") as Node
	if _sa and _sa.has_method("trigger_spawn"):
		_sa.trigger_spawn()

	spawn_timer.start(effective_interval)


func _return_to_pool(zombie: Node3D) -> void:
	if not zombie:
		return
	var pool_entry = zombie.get("pool_entry")
	if pool_entry == null:
		# Fallback: if no pool entry was stored, just queue_free
		if zombie.get_parent():
			zombie.get_parent().remove_child(zombie)
		zombie.queue_free()
		return

	var pool = pool_entry.get("pool")
	if pool == null:
		if zombie.get_parent():
			zombie.get_parent().remove_child(zombie)
		zombie.queue_free()
		return

	# Tell the zombie to die (triggers the 'died' signal which the pool handles)
	if zombie.has_method("kill"):
		zombie.kill()
	elif zombie.has_method("queue_free"):
		# Fallback: manually return to dead pool by emitting killed signal
		pool._on_killed(zombie)
		if zombie.get_parent():
			zombie.get_parent().remove_child(zombie)


# ──────────────────────────────────────────────
#  ZOMBIE DEATH
# ──────────────────────────────────────────────

func _on_zombie_died(zombie: Node3D, zombie_type: String = "zombie") -> void:
	if not zombie:
		return
	active_zombies.erase(zombie)
	# Drop loot at the zombie's position before returning it to the pool
	_drop_loot(zombie.global_transform.origin, zombie_type)
	_return_to_pool(zombie)
	emit_signal("zombie_killed", zombie_type)
	print("[ZombieSpawner] Zombie killed: ", zombie_type, ". Active: ", active_zombies.size())

func _drop_loot(world_pos: Vector3, zombie_type: String) -> void:
	"""Spawn a food pickup at the death position using the LootTable node if present."""
	var loot_table = get_node_or_null("LootTable")
	if loot_table and loot_table.has_method("spawn_drops"):
		loot_table.spawn_drops(world_pos)


# ──────────────────────────────────────────────
#  VFN FIELD TARGET UPDATE
# ──────────────────────────────────────────────

func _update_vfn_target() -> void:
	if not vfn_field_ready or not vfn_field or not player:
		return
	# Re-calc the field with the player as the target
	vfn_field.clear_targets()
	var player_pos = player.global_transform.origin
	vfn_field.add_target_from_world(player_pos)
	vfn_field.calculate_threaded()


var _vfn_recalc_timer: float = 0.0
# Counts spawn attempts rejected by the wall check. Without it a bug in that check
# just looks like "fewer zombies than expected" — indistinguishable from tuning.
var blocked_spawns: int = 0
# 0.5s, not 0.25s: the field is recalculated with the player as its ONLY target,
# so halving the interval doubles the thread wakeups for a marginally fresher
# player position. The zombie positions are not part of the field.
const VFN_RECALC_INTERVAL: float = 0.5

func _process(delta: float) -> void:
	# Throttle VFN field recalculation — calculate_threaded() on a 50x50 field
	# is expensive and every-frame recalc is a perf disaster on mobile.
	if vfn_field_ready and vfn_field:
		_vfn_recalc_timer += delta
		if _vfn_recalc_timer >= VFN_RECALC_INTERVAL:
			_vfn_recalc_timer = 0.0
			_update_vfn_target()
