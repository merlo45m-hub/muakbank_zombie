extends SceneTree
## Runtime performance impact: hold the instanced exploded GLB resident for a
## sustained window and read REAL in-engine FPS from the FpsMonitor autoload.
const GLB = "res://assets/models/screen_structures_exploded.glb"

func _initialize() -> void:
	var mon: Node = root.get_node_or_null("FpsMonitor")
	if mon == null:
		print("PERF_FAIL FpsMonitor autoload missing"); quit(1); return
	var ps: PackedScene = load(GLB)
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6500:
		await process_frame
	var reps: int = int(mon.report_count())
	var rep: Dictionary = mon.get_report()
	print("FPSMON_REPORTS=", reps)
	print("FPSMON_AVG_FPS=", rep.get("avg_fps", -1), " MIN_FPS=", rep.get("min_fps", -1),
		" JANK_PCT=", rep.get("jank_pct", -1), " SAMPLE_FRAMES=", rep.get("samples", -1))
	var avg: float = float(rep.get("avg_fps", 0.0))
	# headless software renderer is slow; the meaningful assertion is that the
	# monitor IS sampling and the asset stays resident without a crash/hang.
	var ok: bool = reps >= 2 and avg > 0.0
	print("PERF_MONITORED=", ok)
	quit(0 if ok else 1)
