## level_probe.gd — renders the level select screen standalone for visual QA.
extends Node


func _ready() -> void:
	await get_tree().process_frame
	var s: Control = load("res://scenes/ui/level_select.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/level_render.png")

	var tiles := 0
	var play_now := false
	var cta := false
	for b in s.find_children("*", "Button", true, false):
		var bb := b as Button
		if bb.custom_minimum_size == Vector2(292, 262):
			tiles += 1
		for l in bb.find_children("*", "Label", true, false):
			if (l as Label).text == "PLAY NOW":
				play_now = true
	for l2 in s.find_children("*", "Label", true, false):
		if (l2 as Label).text.begins_with("TAP A LEVEL"):
			cta = true

	print("LSP tiles=", tiles, " play_now=", play_now, " cta=", cta)
	var ok := tiles > 0 and play_now and cta
	print("LSP RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)