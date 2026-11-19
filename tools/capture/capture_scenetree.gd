extends SceneTree
## Issue #23 — visual-capture harness. Requires a REAL GL context
## (Xvfb + LIBGL_ALWAYS_SOFTWARE=1 + gl_compatibility), NEVER --headless.
## Env: CAP_SCENE (res://), CAP_OUT (absolute .png), CAP_FRAMES (warm-up frames).
## If the scene has no current Camera3D (most of ours do not), a pinned camera
## is injected so 3D scenes render a deterministic frame; Control-only UI scenes
## need no camera because the 2D canvas renders directly into the viewport.
## Typing: explicit annotations everywhere (docs/GDSCRIPT_TYPING.md).

const DEFAULT_FRAMES: int = 8
const PINNED_CAM_POS: Vector3 = Vector3(0.0, 6.0, 14.0)
const PINNED_CAM_TARGET: Vector3 = Vector3(0.0, 1.0, 0.0)

func _find_node3d(node: Node) -> Node3D:
	if node is Node3D:
		return node as Node3D
	var children: Array[Node] = node.get_children()
	var child: Node
	for c in children:
		child = c
		var found: Node3D = _find_node3d(child)
		if found != null:
			return found
	return null

func _initialize() -> void:
	var scene_path: String = OS.get_environment("CAP_SCENE")
	var out_path: String = OS.get_environment("CAP_OUT")
	var frames_raw: String = OS.get_environment("CAP_FRAMES")
	var frames: int = DEFAULT_FRAMES
	if frames_raw != "":
		frames = int(frames_raw)
	var valid: bool = (not scene_path.is_empty()) and (not out_path.is_empty())
	if not valid:
		push_error("CAP: CAP_SCENE / CAP_OUT required")
		quit(2)
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("CAP: FAIL load " + scene_path)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)

	var viewport: Viewport = root as Viewport
	var existing_cam: Camera3D = viewport.get_camera_3d()
	var injected: bool = false
	if existing_cam == null:
		var n3d: Node3D = _find_node3d(instance)
		if n3d != null:
			var cam: Camera3D = Camera3D.new()
			cam.name = "CaptureCamera"
			instance.add_child(cam)
			cam.global_position = PINNED_CAM_POS
			cam.look_at(PINNED_CAM_TARGET, Vector3.UP)
			cam.current = true
			cam.fov = 60.0
			cam.far = 500.0
			injected = true

	var i: int = 0
	while i < frames:
		await process_frame
		i += 1
	await RenderingServer.frame_post_draw

	var tex: ViewportTexture = viewport.get_texture()
	var img: Image = tex.get_image()
	# NO flip_y(): proven 2026-11-19 against title_screen UI ground truth (red Nosifer
	# title band measured top28%%=45724px vs bottom28%%=1284px unflipped, mirrored when
	# flipped; anchor is offset_top=18 in the tscn). ViewportTexture->Image is already
	# top-down in Godot 4.7; the old flip inverted every CI capture artifact. Issue #63 I0.
	var err: Error = img.save_png(out_path)

	var report: Dictionary = {
		"scene": scene_path,
		"out": out_path,
		"width": img.get_width(),
		"height": img.get_height(),
		"err": int(err),
		"camera_injected": injected,
		"frames": frames,
	}
	var raw_keys: Array = report.keys()
	var keys: Array[String] = []
	keys.assign(raw_keys)
	keys.sort()
	var key: String = ""
	for k in keys:
		key = k
		print("CAP: " + key + "=" + str(report[key]))
	print("CAP: renderer=gl_compatibility/llvmpipe mobile-renderer-unverified")
	var ok: bool = (err == OK) and (img.get_width() > 0) and (img.get_height() > 0)
	quit(0 if ok else 1)
