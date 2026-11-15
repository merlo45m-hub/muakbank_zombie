extends Node
## In-engine FPS monitor for verification (Issues #30 / #21).
##
## Uses Performance.get_monitor(Performance.TIME_FPS) — the engine's own
## frame-rate counter — sampled every frame and aggregated over a rolling
## window. Every REPORT_INTERVAL_SEC it emits a logcat line tagged [FPSMON]
## (Godot print() -> logcat tag 'godot' on Android), so the on-device combat
## stress harness can grep REAL in-engine FPS during active combat. This is the
## honest FPS number that SurfaceFlinger --latency / gfxinfo framestats cannot
## provide for this Vulkan SurfaceView on this Samsung build.
##
## No on-screen label by design: Issue #30 is a UI-declutter pass, so verification
## instrumentation must not add HUD clutter. get_report() exposes the last window
## for programmatic/headless checks.

const REPORT_INTERVAL_SEC: float = 2.0
const JANK_FPS_THRESHOLD: float = 50.0   # below the 60 FPS phone budget -> flag
const BUDGET_FPS: float = 60.0
const SAMPLE_CAP: int = 600              # bounded memory (<=10 s at 60 fps)

var _samples: Array[float] = []
var _last_report_msec: int = 0
var _last_report: Dictionary = {}
var _total_reports: int = 0


func _ready() -> void:
	# Wall-clock trigger, not delta summation: real elapsed time is reliable on
	# device AND in headless --script SceneTree runs (where delta may not advance).
	_last_report_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	_samples.append(fps)
	if _samples.size() > SAMPLE_CAP:
		_samples.remove_at(0)
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_report_msec >= int(REPORT_INTERVAL_SEC * 1000.0):
		_last_report_msec = now_msec
		_last_report = _build_report()
		_total_reports += 1
		print("[FPSMON] " + JSON.stringify(_last_report))
		_samples.clear()


func _build_report() -> Dictionary:
	var n: int = _samples.size()
	if n == 0:
		return {"samples": 0, "budget_fps": BUDGET_FPS}
	var total: float = 0.0
	var min_fps: float = _samples[0]
	var max_fps: float = _samples[0]
	var jank: int = 0
	var v: float
	for s in _samples:
		v = s
		total += v
		if v < min_fps:
			min_fps = v
		if v > max_fps:
			max_fps = v
		if v < JANK_FPS_THRESHOLD:
			jank += 1
	var sorted_samples: Array[float] = []
	sorted_samples.assign(_samples)
	sorted_samples.sort()
	var p05: float = sorted_samples[int(float(n) * 0.05)]
	return {
		"samples": n,
		"avg_fps": snappedf(total / float(n), 0.1),
		"min_fps": snappedf(min_fps, 0.1),
		"max_fps": snappedf(max_fps, 0.1),
		"p05_fps": snappedf(p05, 0.1),
		"jank_frames": jank,
		"jank_pct": snappedf(100.0 * float(jank) / float(n), 0.1),
		"budget_fps": BUDGET_FPS,
		"window": int(_total_reports),
	}


func get_report() -> Dictionary:
	"""Return the last aggregated window (empty dict until the first interval)."""
	return _last_report.duplicate(true)


func report_count() -> int:
	return _total_reports
