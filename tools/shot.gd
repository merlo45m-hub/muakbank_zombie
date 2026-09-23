extends Node
## Offscreen screenshot harness — needs a REAL GL context (run under xvfb, not --headless).
## Env: SHOT_SCENE (res:// path), SHOT_FRAMES (default 150), SHOT_OUT (abs path)

func _ready() -> void:
	var path := OS.get_environment("SHOT_SCENE")
	if path.is_empty():
		path = "res://scenes/main/title_screen.tscn"
	var frames := 150
	if OS.get_environment("SHOT_FRAMES") != "":
		frames = int(OS.get_environment("SHOT_FRAMES"))
	var out := OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "/game/shot.png"

	var packed: PackedScene = load(path)
	if packed == null:
		print("SHOT: FAIL — could not load %s" % path)
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	for i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT: %s -> %s (%dx%d) save_err=%d" % [path, out, img.get_width(), img.get_height(), err])
	get_tree().quit(0)
