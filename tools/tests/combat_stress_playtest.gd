extends SceneTree

## Active-combat frame-pacing stress (issue #30, engine-side half).
## Drives a sustained live wave through the REAL spawner + zombie AI for ~20s
## of simulated combat and measures per-tick pacing: mean, p95, worst stalls.
## Deterministic pass gate: no single frame exceeds STALL_MS and mean ms stays
## under budget. Headless on a 2-core VPS = conservative lower bound vs device.

const WAVE_TARGET := 24          # simultaneous hostiles pressure level
const SIM_SECONDS := 20.0
const TICK_MS := 1.0 / 60.0 * 1000.0
const STALL_MS := 80.0           # any measured tick slower than this fails
const BUDGET_MEAN_MS := 30.0     # mean must stay under (VPS is slow-shared host)

func _initialize() -> void:
	print("=== Combat frame-pacing stress ===")
	var spawner_script: GDScript = load("res://scripts/characters/ZombieSpawner3D.gd")
	assert(spawner_script != null and spawner_script.can_instantiate(), "spawner script compile failed")
		var packed_game: PackedScene = load("res://scenes/main/game.tscn")
	if packed_game == null:
		print("STRESS_ERROR: game.tscn not found")
		quit(1)
		return
	var game: Node = packed_game.instantiate()
	root.add_child.call_deferred(game)
	for _i in range(6):
		await process_frame
	if game.has_method("start_game"):
		game.call("start_game")
		for _i in range(4):
			await process_frame
	var spawner: Node = game.find_child("ZombieSpawner", true, false)
	if spawner == null:
		var grp: Array = get_nodes_in_group("zombie_spawner")
		spawner = grp[0] if grp.size() > 0 else null
	if spawner == null:
		print("STRESS_ERROR: no zombie_spawner reachable from game.tscn")
		quit(1)
		return
	if not spawner.has_method("get_live_enemies"):
		print("STRESS_ERROR: spawner lacks cached-list API")
		quit(1)
		return
	# crank spawn pressure
	spawner.set("max_zombies", WAVE_TARGET)
	spawner.set("spawn_interval", 0.5)
	spawner.set("can_spawn", true)
	if spawner.has_method("start_spawning"):
		spawner.call("start_spawning")
	var player: Node = get_first_node_in_group("player")
	if player == null:
		print("STRESS_WARN: no real player found; using stub")
		player = Node3D.new()
		player.name = "StressPlayer"
		player.add_to_group("player")
		root.add_child.call_deferred(player)
		await process_frame
var samples: Array[float] = []
	var sim_t := 0.0
	var tick_count := 0
	while sim_t < SIM_SECONDS * 1000.0:
		var t0 := Time.get_ticks_msec()
		await process_frame
		var dt_ms := float(Time.get_ticks_msec() - t0)
		# step the world logic at fixed 16.6ms so pacing measures OUR loop +
		# scene physics ticks the frame actually ran
		spawner.call("_process", TICK_MS / 1000.0)
		samples.append(dt_ms)
		sim_t += TICK_MS
		tick_count += 1
		if tick_count % 300 == 0:
			print("  live=%d t=%.0fms" % [int(spawner.call("get_live_enemies").size()), sim_t])
	samples.sort()
	var n: int = samples.size()
	var total := 0.0
	for s in samples:
		total += s
	var mean_ms := total / float(maxi(n, 1))
	var p95: float = samples[int(n * 0.95)] if n > 10 else float(samples[n - 1])
	var worst: float = samples[n - 1]
	var live_final: int = int(spawner.call("get_live_enemies").size())
	print("STRESS samples=%d live_final=%d mean=%.2fms p95=%.2fms worst=%.0fms" % [n, live_final, mean_ms, p95, worst])
	var ok := worst <= STALL_MS and mean_ms <= BUDGET_MEAN_MS and live_final >= 6
	print("STRESS_PASS=%s (gate: worst<=%.0f mean<=%.0f live>=6)" % [ok, STALL_MS, BUDGET_MEAN_MS])
	print("STRESS_JSON=" + JSON.stringify({"samples": n, "mean_ms": mean_ms, "p95_ms": p95, "worst_ms": worst, "live_final": live_final, "wave_target": WAVE_TARGET, "sim_seconds": SIM_SECONDS}))
	if not ok:
		quit(1)
	else:
		quit(0)
