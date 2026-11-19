extends SceneTree

## Perf control-path playtest — validates the control-path performance fixes.
## Spawns 12 zombies via the real ZombieSpawner3D, advances frames, and asserts:
##   (a) separation still resolves overlaps (no two alive zombies within 0.3 m after settling)
##   (b) an attack still damages the enemy in front
##   (c) the cached live-enemy list count matches live instances after killing 3
##       zombies and returning them to the pool
## Prints PERF_PATH_PASS=true when every assertion passes.
##
## Run (headless, VPS): tools/hgs_run.sh script res://tools/tests/perf_control_path_playtest.gd

var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _alive_zombies() -> Array:
	# Live zombies actually in the world: in tree, not dead, not parked.
	# Parked pool instances sit out of tree (dead flag true); dead-and-returned
	# zombies are removed from the tree too, so both filters are belt-and-braces.
	var out: Array = []
	for z in get_tree().get_nodes_in_group("enemies"):
		if z is ZombieBase and z.is_inside_tree() and not z.is_dead and not z.dead:
			out.append(z)
	return out

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	print("=== Perf control-path playtest ===")

	# --- engine singletons addressed by bare name (Level.get_enemy_pool,
	# --- Audio.play_*) --- autoloads are not wired into the tree under --script,
	# --- so register minimal stubs so the real spawner / zombie code paths run.
	var level_stub: Node = _LevelStub.new()
	level_stub.name = "LevelStub"
	Engine.add_singleton("Level", level_stub)
	var audio_stub: Node = _AudioStub.new()
	audio_stub.name = "AudioStub"
	Engine.add_singleton("Audio", audio_stub)

	# --- stub player (group "player") so the spawner locates a target ---
	var player: Node3D = Node3D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	player.global_transform.origin = Vector3(0, 0, 0)
	root.add_child(player)

	# --- stub DifficultyManager (spawner looks for ../DifficultyManager) ---
	var diff: Node = _DifficultyStub.new()
	diff.name = "DifficultyManager"
	root.add_child(diff)

	# --- real spawner ---
	var spawner_script: GDScript = preload("res://scripts/characters/ZombieSpawner3D.gd")
	var spawner: Node3D = spawner_script.new()
	spawner.name = "ZombieSpawner"
	# spawn_timer is @onready $SpawnTimer — parent a Timer child before entering the tree.
	var timer: Timer = Timer.new()
	timer.name = "SpawnTimer"
	spawner.add_child(timer)
	spawner.can_spawn = true
	spawner.max_zombies = 64
	spawner.spawn_interval = 120.0  # timer-driven spawns disabled for the test
	spawner.spawn_radius = 6.0
	spawner.min_spawn_distance = 3.5
	root.add_child(spawner)

	# Let spawner._ready run (pools, group registration, player lookup).
	await process_frame

	var zs: ZombieSpawner3D = spawner as ZombieSpawner3D
	if zs == null:
		print("PERF_PATH_FAIL: spawner is not ZombieSpawner3D")
		quit(1)
		return

	# --- spawn 12 zombies via the real spawner (checkout/recycle path) ---
	for _i in range(12):
		zs._spawn_random_zombie()
	await process_frame

	var alive: Array = _alive_zombies()
	_assert(alive.size() == 12, "12 zombies spawned via the real spawner (got %d)" % alive.size())

	# (a) let separation settle, then assert no two alive zombies within 0.3 m
	for _i in range(400):
		await process_frame
	alive = _alive_zombies()
	var pair_ok: bool = true
	for i in range(alive.size()):
		for j in range(i + 1, alive.size()):
			var a: ZombieBase = alive[i]
			var b: ZombieBase = alive[j]
			if is_instance_valid(a) and is_instance_valid(b):
				if a.global_transform.origin.distance_to(b.global_transform.origin) < 0.3:
					pair_ok = false
	_assert(pair_ok, "no two alive zombies within 0.3 m after separation settled (%d alive)" % alive.size())

	# (b) an attack still damages the enemy in front
	var dummy: _DamageDummy = _DamageDummy.new()
	dummy.name = "DamageDummy"
	root.add_child(dummy)
	var z0: ZombieBase = alive[0] if alive.size() > 0 else null
	if z0 != null and is_instance_valid(z0):
		dummy.global_transform.origin = z0.global_transform.origin - z0.global_transform.basis.z * 1.0
		z0.attack(dummy)
		await process_frame
	_assert(dummy.damage_taken > 0, "attack damages the enemy in front (took %d)" % dummy.damage_taken)

	# (c) kill 3 zombies via the real take_damage path; cache must match live instances
	var killed: int = 0
	for z in alive:
		if killed >= 3:
			break
		if z is ZombieBase and not z.is_dead:
			z.take_damage(1000)
			killed += 1
	# Let death tweens finish so the died signal / pool return completes.
	for _i in range(200):
		await process_frame

	var cache_size: int = zs.get_live_enemies().size()
	var live_in_tree: int = _alive_zombies().size()
	_assert(cache_size == 9, "cached live-enemy count after killing 3 (got %d)" % cache_size)
	_assert(live_in_tree == 9, "live zombie instances in tree after recycle (got %d)" % live_in_tree)
	_assert(cache_size == live_in_tree, "cache matches live instances after recycle")

	if _failures == 0:
		print("PERF_PATH_PASS=true")
		quit(0)
	else:
		printerr("PERF_PATH_FAIL: %d assertions failed" % _failures)
		quit(1)

# --- stubs (inner classes) ---

class _LevelStub extends Node:
	func get_enemy_pool(level: int) -> Array:
		return ["dog", "cat", "bear", "rabbit", "chicken", "runner", "spitter"]

class _AudioStub extends Node:
	func play_zombie_hit() -> void:
		pass
	func play_zombie_die() -> void:
		pass
	func play_zombie_reach() -> void:
		pass

class _DifficultyStub extends Node:
	func get_spawn_interval() -> float:
		return 1.0
	func get_max_zombies_multiplier() -> float:
		return 1.0
	func get_level_difficulty(level: int) -> float:
		return 1.0

class _DamageDummy extends Node3D:
	var damage_taken: int = 0

	func take_damage(amount: int) -> void:
		damage_taken += amount
