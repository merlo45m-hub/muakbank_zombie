extends SceneTree
## Issue #63 I2 — runtime title-layout geometry probe.
## Emits the ACTUAL Control rects after layout so the Python gate can compute
## safe-area and zero-overlap verdicts from engine state, not tscn arithmetic.
## Env: CAP_LAYOUT_OUT (absolute JSON path). Run under Xvfb at 1600x900.

const LAYOUT_SCENE: String = "res://scenes/main/title_screen.tscn"
const WARMUP_FRAMES: int = 8

func _rect_dict(node: Node) -> Dictionary:
	var control: Control = node as Control
	if control == null:
		return {}
	var rect: Rect2 = control.get_rect()
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}

func _initialize() -> void:
	var out_path: String = OS.get_environment("CAP_LAYOUT_OUT")
	if out_path.is_empty():
		push_error("LAYOUT: CAP_LAYOUT_OUT required")
		quit(2)
		return

	var packed: PackedScene = load(LAYOUT_SCENE) as PackedScene
	if packed == null:
		push_error("LAYOUT: FAIL load " + LAYOUT_SCENE)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)

	var frame_index: int = 0
	while frame_index < WARMUP_FRAMES:
		await process_frame
		frame_index += 1
	await RenderingServer.frame_post_draw

	var viewport: Viewport = root as Viewport
	var vrect: Rect2 = viewport.get_viewport_rect()
	var ui: Node = instance.get_node_or_null("UI")
	var title: Node = instance.get_node_or_null("UI/TitleLabel")
	var buttons: Node = instance.get_node_or_null("UI/ButtonsBox")
	var footer: Node = instance.get_node_or_null("UI/FooterBrand")
	if ui == null or title == null or buttons == null or footer == null:
		push_error("LAYOUT: required UI nodes missing")
		quit(1)
		return

	var button_list: Array = []
	var vbox: VBoxContainer = buttons as VBoxContainer
	if vbox != null:
		var children: Array[Node] = vbox.get_children()
		var child: Node
		for c in children:
			child = c
			if child is Control:
				var rec: Dictionary = _rect_dict(child)
				rec["name"] = str(child.name)
				button_list.append(rec)

	var rects: Dictionary = {
		"TitleLabel": _rect_dict(title),
		"ButtonsBox": _rect_dict(buttons),
		"FooterBrand": _rect_dict(footer),
	}
	var report: Dictionary = {
		"scene": LAYOUT_SCENE,
		"width": int(vrect.size.x),
		"height": int(vrect.size.y),
		"frames": WARMUP_FRAMES,
		"safe_margin": 48,
		"button_separation": vbox.get_theme_constant("separation") if vbox != null else -1,
		"rects": rects,
		"buttons": button_list,
	}

	var handle: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if handle == null:
		push_error("LAYOUT: cannot write " + out_path)
		quit(1)
		return
	handle.store_string(JSON.stringify(report, "  "))
	handle.close()

	print("LAYOUT: scene=" + LAYOUT_SCENE)
	print("LAYOUT: dims=" + str(int(vrect.size.x)) + "x" + str(int(vrect.size.y)))
	print("LAYOUT: out=" + out_path)
	quit(0)
