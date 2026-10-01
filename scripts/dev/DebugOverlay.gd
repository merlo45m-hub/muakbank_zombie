extends CanvasLayer

const DevMode := preload("res://scripts/core/DevMode.gd")

var label: Label

func _ready() -> void:
	if not DevMode.is_active():
		visible = false
		set_process(false)
		return
		
	layer = 128
	
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	
	label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)

func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(label): return
	
	var fps = Engine.get_frames_per_second()
	var mem_mb = OS.get_static_memory_usage() / (1024.0 * 1024.0)
	
	var player_pos = "-"
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]) and players[0] is Node3D:
		var p = players[0].global_position
		player_pos = "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
		
	var enemies = get_tree().get_nodes_in_group("enemies").size()
	
	label.text = "FPS: %d\nMem: %.1f MB\nPlayer: %s\nEnemies: %d" % [fps, mem_mb, player_pos, enemies]
