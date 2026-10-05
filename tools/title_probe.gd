extends Node
## Title-screen render probe: loads the real title scene under Xvfb + GL and
## screenshots it after the 3D backdrop and UI tweens settle. Same invocation
## as the other probes (Xvfb + real GL, NOT --headless).

const TAG := "TSP "
const SHOT_PATH := "res://tools/title_shot.png"


func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/main/title_screen.tscn") as PackedScene
	if packed == null:
		print(TAG, "FAIL load title_screen.tscn")
		get_tree().quit(1)
		return
	var t: Node = packed.instantiate()
	get_tree().root.add_child(t)
	get_tree().current_scene = t
	# Let the backdrop, zombie shamblers and UI tweens settle.
	for i in range(150):
		await get_tree().process_frame
	if not is_instance_valid(t):
		print(TAG, "FAIL title scene freed early")
		get_tree().quit(1)
		return
	# Diagnostics: what actually rendered.
	var cam: Node = t.get_node_or_null("Background/Camera")
	if cam and cam is Camera3D:
		print(TAG, "bg camera current=", (cam as Camera3D).is_current(), " pos=", (cam as Camera3D).global_position, " fov=", (cam as Camera3D).fov)
	var z: Node = t.get_node_or_null("Background/Zombies")
	if z != null:
		var zk: Array[String] = []
		for c in z.get_children():
			zk.append(String(c.name))
		print(TAG, "zombies in backdrop: ", zk)
	var btn: Node = t.get_node_or_null("UI/ButtonsBox/PlayBtn")
	if btn != null:
		print(TAG, "PlayBtn rect=", (btn as Control).get_global_rect())
	var tl: Node = t.get_node_or_null("UI/TitleLabel")
	if tl != null:
		print(TAG, "TitleLabel rect=", (tl as Control).get_global_rect())
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(SHOT_PATH)
	if err == OK:
		print(TAG, "shot ok ", img.get_size())
	else:
		print(TAG, "FAIL shot err=", err)
	# Second shot with the wordmark hidden: isolates 3D-scene artifacts from
	# anything the title label itself draws (shadow/outline ghosts).
	var tl2: Node = t.get_node_or_null("UI/TitleLabel")
	if tl2 and tl2 is CanvasItem:
		(tl2 as CanvasItem).visible = false
		for i in range(10):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2: Image = get_viewport().get_texture().get_image()
		var err2: int = img2.save_png("res://tools/title_shot2.png")
		print(TAG, "shot2 (title hidden) err=", err2)
	print(TAG, "RESULT ", "PASS" if err == OK else "FAIL")
	get_tree().quit(0 if err == OK else 1)