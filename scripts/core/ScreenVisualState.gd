class_name ScreenVisualState
extends RefCounted
## Runtime access to the WatchSkill-extracted visual state of the four captured
## game screens (issue: feed verified screen data into the game state).
##
## Source: assets/data/screen_visual_state.json, produced on the VPS by
## watch-skill[standard,ocr] RapidOCR/onnxruntime perception over ADB captures of
## the title / character-select / level-select / gameplay screens. This is
## structured DATA (UI text, bounding boxes, confidence, brightness, markers),
## not a pass/fail verdict — the game can use it for UI-state assertions,
## onboarding hints, or layout checks.
##
## All types are explicit per docs/GDSCRIPT_TYPING.md: no `:=` on dynamic
## receivers (FileAccess.open / JSON.parse_string return Variant), and typed
## arrays are filled with .assign(), never assigned a plain Array literal.

const DATA_PATH: String = "res://assets/data/screen_visual_state.json"

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_cache = (parsed as Dictionary).duplicate(true)
	return _cache


static func screens() -> Dictionary:
	var root: Dictionary = _load()
	var s: Variant = root.get("screens", {})
	if s is Dictionary:
		return (s as Dictionary).duplicate(true)
	return {}


static func get_screen(label: String) -> Dictionary:
	var d: Variant = screens().get(label, {})
	if d is Dictionary:
		return (d as Dictionary).duplicate(true)
	return {}


static func ui_text(label: String) -> Array:
	"""All OCR'd UI strings for one screen, in reading order."""
	var d: Dictionary = get_screen(label)
	var a: Variant = d.get("ui_text", [])
	var out: Array = []
	if a is Array:
		out.assign(a as Array)
	return out


static func markers_detected(label: String) -> Array:
	var d: Dictionary = get_screen(label)
	var a: Variant = d.get("markers_detected", [])
	var out: Array = []
	if a is Array:
		out.assign(a as Array)
	return out


static func ocr_items(label: String) -> Array:
	"""Rich per-element data: {text, box, confidence}."""
	var d: Dictionary = get_screen(label)
	var a: Variant = d.get("ocr_items", [])
	var out: Array = []
	if a is Array:
		out.assign(a as Array)
	return out


static func visual(label: String) -> Dictionary:
	var d: Dictionary = get_screen(label)
	var v: Variant = d.get("visual", {})
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return {}


static func brightness(label: String) -> float:
	return float(visual(label).get("brightness", -1.0))


static func is_dark_scene(label: String) -> bool:
	return bool(visual(label).get("dark_scene", false))


static func sha256(label: String) -> String:
	return str(get_screen(label).get("sha256", ""))


static func classification_confident(label: String) -> bool:
	return bool(get_screen(label).get("classification_confident", false))


static func has_ui_text(label: String, needle: String) -> bool:
	var q: String = needle.to_upper()
	for t in ui_text(label):
		if q in str(t).to_upper():
			return true
	return false


static func screen_labels() -> Array:
	var out: Array = []
	out.assign(screens().keys())
	return out
