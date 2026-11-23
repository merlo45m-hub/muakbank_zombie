extends SceneTree
## Issue #63 I3 — runtime typography and touch-target probe.
## Emits every title-screen Button/Label's font, size, rect and missing chars.
## Env: CAP_TYPO_OUT (absolute JSON path). Run under Xvfb at 1600x900.

const TYPO_SCENE: String = "res://scenes/main/title_screen.tscn"
const WARMUP_FRAMES: int = 8
const MIN_TARGET_PX: int = 48

func _check_chars(node_name: String, text: String, font: Font, missing: Array) -> void:
	if font == null:
		missing.append(node_name + "|NO_FONT")
		return
	var index: int = 0
	while index < text.length():
		var one: String = text.substr(index, 1)
		var code: int = one.unicode_at(0)
		if code != 10 and code != 13 and code != 32 and not font.has_char(code):
			missing.append(node_name + "|" + one)
		index += 1

func _collect(node: Node, report: Dictionary) -> void:
	var children: Array[Node] = node.get_children()
	var child: Node
	for c in children:
		child = c
		if child is Button:
			var button: Button = child as Button
			var font: Font = button.get_theme_font("font")
			var rec: Dictionary = {
				"name": str(button.name),
				"text": button.text,
				"font": font.resource_path if font != null else "",
				"font_size": button.get_theme_font_size("font_size"),
				"w": button.size.x,
				"h": button.size.y,
			}
			var buttons: Array = report["buttons"]
			buttons.append(rec)
			_check_chars(str(button.name), button.text, font, report["missing_glyphs"])
			if button.size.x < MIN_TARGET_PX or button.size.y < MIN_TARGET_PX:
				var small: Array = report["small_targets"]
				small.append(str(button.name))
		elif child is Label:
			var label: Label = child as Label
			var settings: LabelSettings = label.label_settings
			var font: Font = settings.font if settings != null else label.get_theme_font("font")
			var size: int = settings.font_size if settings != null else label.get_theme_font_size("font_size")
			var rec: Dictionary = {
				"name": str(label.name),
				"text": label.text,
				"font": font.resource_path if font != null else "",
				"font_size": size,
			}
			var labels: Array = report["labels"]
			labels.append(rec)
			_check_chars(str(label.name), label.text, font, report["missing_glyphs"])
		_collect(child, report)

func _initialize() -> void:
	print("TYPO: start")
	var out_path: String = OS.get_environment("CAP_TYPO_OUT")
	if out_path.is_empty():
		push_error("TYPO: CAP_TYPO_OUT required")
		quit(2)
		return
	var packed: PackedScene = load(TYPO_SCENE) as PackedScene
	if packed == null:
		push_error("TYPO: FAIL load " + TYPO_SCENE)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	var frame_index: int = 0
	while frame_index < WARMUP_FRAMES:
		await process_frame
		frame_index += 1

	var report: Dictionary = {
		"scene": TYPO_SCENE,
		"frames": WARMUP_FRAMES,
		"min_target_px": MIN_TARGET_PX,
		"missing_glyphs": [],
		"small_targets": [],
		"buttons": [],
		"labels": [],
	}
	var ui: Node = instance.get_node_or_null("UI")
	if ui == null:
		push_error("TYPO: UI node missing")
		quit(1)
		return
	_collect(ui, report)

	var handle: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if handle == null:
		push_error("TYPO: cannot write " + out_path)
		quit(1)
		return
	handle.store_string(JSON.stringify(report, "  "))
	handle.close()
	print("TYPO: buttons=" + str((report["buttons"] as Array).size()))
	print("TYPO: labels=" + str((report["labels"] as Array).size()))
	print("TYPO: out=" + out_path)
	quit(0)
