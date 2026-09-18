extends Node

## SceneManager — Scene transitions with a fade loading screen (Godot 4)
## Autoload as "SceneManager"

# Transition types
enum TransitionType {
	FADE,
	FADE_WHITE,
	NONE
}

# Current state
var _is_transitioning: bool = false
var _loading_screen: ColorRect = null
var _status_label: Label = null

# Transition settings
var fade_out_duration: float = 0.3
var fade_in_duration: float = 0.3
var loading_screen_color: Color = Color(0, 0, 0, 1)


func _ready() -> void:
	_setup_loading_screen()
	print("[SceneManager] Ready")


func _setup_loading_screen() -> void:
	"""Create the loading screen overlay (added to the root, drawn on top)."""
	var layer = CanvasLayer.new()
	layer.layer = 100
	layer.name = "SceneManagerOverlay"
	# Deferred: the root is still busy setting up children during _ready.
	get_tree().root.add_child.call_deferred(layer)
	
	_loading_screen = ColorRect.new()
	_loading_screen.color = loading_screen_color
	_loading_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_screen.visible = false
	layer.add_child(_loading_screen)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_screen.add_child(center)
	
	_status_label = Label.new()
	_status_label.text = "Loading..."
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_status_label.add_theme_font_size_override("font_size", 20)
	center.add_child(_status_label)


func change_scene(scene_path: String, transition: TransitionType = TransitionType.FADE, status_text: String = "Loading...") -> void:
	"""Change scene with a transition effect."""
	if _is_transitioning:
		print("[SceneManager] Already transitioning, request ignored")
		return
	if not ResourceLoader.exists(scene_path):
		print("[SceneManager] Scene not found: ", scene_path)
		return
	
	_is_transitioning = true
	_status_label.text = status_text
	_loading_screen.visible = true
	
	match transition:
		TransitionType.FADE:
			await _fade_transition(scene_path, Color(0, 0, 0))
		TransitionType.FADE_WHITE:
			await _fade_transition(scene_path, Color(1, 1, 1))
		_:
			_instant_change(scene_path)


func _fade_transition(scene_path: String, fade_color: Color) -> void:
	"""Fade to color, change scene, fade back in."""
	_loading_screen.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	var t = create_tween()
	t.tween_property(_loading_screen, "color", fade_color, fade_out_duration)
	await t.finished
	
	var err = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		print("[SceneManager] Failed to change scene: ", err)
		_reset_transition()
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var t2 = create_tween()
	t2.tween_property(_loading_screen, "color", Color(fade_color.r, fade_color.g, fade_color.b, 0.0), fade_in_duration)
	await t2.finished
	
	_reset_transition()


func _instant_change(scene_path: String) -> void:
	"""Instant scene change with loading screen."""
	_loading_screen.visible = true
	var err = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		print("[SceneManager] Failed to change scene: ", err)
	_reset_transition()


func _reset_transition() -> void:
	"""Reset transition state."""
	if _loading_screen:
		_loading_screen.visible = false
		_loading_screen.color = loading_screen_color
	_is_transitioning = false


func is_transitioning() -> bool:
	return _is_transitioning
