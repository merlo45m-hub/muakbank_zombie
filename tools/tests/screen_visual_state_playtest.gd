extends SceneTree
## Verify the WatchSkill-extracted visual state is loadable and usable as game state.

func _initialize() -> void:
	var labels: Array = ScreenVisualState.screen_labels()
	print("SCREEN_LABELS=", labels)
	print("SCREEN_COUNT=", labels.size())
	for label in ["start", "player", "level", "final"]:
		var d: Dictionary = ScreenVisualState.get_screen(label)
		var txt: Array = ScreenVisualState.ui_text(label)
		var markers: Array = ScreenVisualState.markers_detected(label)
		var items: Array = ScreenVisualState.ocr_items(label)
		var vis: Dictionary = ScreenVisualState.visual(label)
		print("SCREEN=", label, " keys=", d.keys().size(),
			" ui_text=", txt.size(), " markers=", markers.size(),
			" ocr_items=", items.size(), " brightness=", ScreenVisualState.brightness(label),
			" dark=", ScreenVisualState.is_dark_scene(label),
			" confident=", ScreenVisualState.classification_confident(label),
			" sha=", ScreenVisualState.sha256(label).substr(0, 12))
	print("HAS_START_PLAY=", ScreenVisualState.has_ui_text("start", "PLAY"))
	print("HAS_LEVEL_SELECT=", ScreenVisualState.has_ui_text("level", "SELECT YOUR NIGHT"))
	print("HAS_FINAL_WAVE=", ScreenVisualState.has_ui_text("final", "WAVE"))
	var ok: bool = (labels.size() == 4
		and ScreenVisualState.ui_text("start").size() == 6
		and ScreenVisualState.ui_text("final").size() >= 20
		and ScreenVisualState.is_dark_scene("level")
		and not ScreenVisualState.is_dark_scene("start")
		and ScreenVisualState.classification_confident("player")
		and ScreenVisualState.has_ui_text("start", "PLAY")
		and ScreenVisualState.has_ui_text("level", "SELECT YOUR NIGHT")
		and ScreenVisualState.has_ui_text("final", "WAVE"))
	print("GAME_STATE_PASS=", ok)
	quit(0 if ok else 1)
