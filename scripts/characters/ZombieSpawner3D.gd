extends Node3D

## Zombie Spawner — Spawns all 5 enemy types with object pooling + vector-field navigation
## Zombies are pooled and reused; navigation uses a pre-computed VFN field instead of per-zombie pathfinding

signal zombie_killed(zombie_type)

@export var max_zombies: int = 12
@export var spawn_interval: float = 3.0
@export var spawn_radius: float = 15.0
@export var min_spawn_distance: float = 8.0

# --- Scene preloads (5 zombie types) ---
var zombie_dog_scene = preload("res://scenes/characters/zombie_dog.tscn")
var zombie_cat_scene = preload("res://scenes/characters/zombie_cat.tscn")
var zombie_bear_scene = preload("res://scenes/characters/zombie_bear.tscn")
var zombie_rabbit_scene = preload("res://scenes/characters/zombie_rabbit.tscn")
var zombie_chicken_scene = preload("res://scenes/characters/zombie_chicken.tscn")

var player: Node3D = null
var active_zombies: Array = []
var can_spawn: bool = false

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

	# --- Try to find a VFN map in the scene ---
	vfn_map = get_node_or_null("VFNMap")
	if vfn_map:
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
		[zombie_dog_scene,    "zombie_dog",    ["dog"]],
		[zombie_cat_scene,    "zombie_cat",    ["cat"]],
		[zombie_bear_scene,   "zombie_bear",   ["bear"]],
		[zombie_rabbit_scene, "zombie_rabbit", ["rabbit"]],
		[zombie_chicken_scene,"zombie_chicken","chicken"]
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
	if active_zombies.size() >= max_zombies:
		spawn_timer.start(spawn_interval)
		return

	# Pick a random type
	var scenes = [
		zombie_dog_scene,
		zombie_cat_scene,
		zombie_bear_scene,
		zombie_rabbit_scene,
		zombie_chicken_scene
	]
	var zombie_types = ["dog", "cat", "bear", "rabbit", "chicken"]
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

	# Ground detection via raycast
	var space_state = get_world_3d().direct_space_state
	if space_state:
		var query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 50, 0), spawn_pos + Vector3(0, -50, 0))
		var result = space_state.intersect_ray(query)
		if result:
			spawn_pos.y = result.position.y

	zombie.global_transform.origin = spawn_pos
	add_child(zombie)
	active_zombies.append(zombie)
	zombie.set("zombie_type", zombie_type)

	# Connect the died signal
	if zombie.has_signal("died") and not zombie.is_connected("died", _on_zombie_died):
		zombie.died.connect(_on_zombie_died.bind(zombie, zombie_type))

	# Store a reference to the pool entry on the zombie so _on_zombie_died can return it
	zombie.set("pool_entry", pool_entry)

	# Apply vector-field navigation if available
	if vfn_field_ready and vfn_field:
		if zombie.has_method("set_vfn_field"):
			zombie.set_vfn_field(vfn_field)

	spawn_timer.start(spawn_interval)


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
	_return_to_pool(zombie)
	emit_signal("zombie_killed", zombie_type)
	print("[ZombieSpawner] Zombie killed: ", zombie_type, ". Active: ", active_zombies.size())


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


func _process(delta: float) -> void:
	# Periodically recompute the VFN field so zombies home in on the player
	if vfn_field_ready and vfn_field:
		_update_vfn_target()
