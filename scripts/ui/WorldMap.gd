## WorldMap.gd — Issue #11 P2 world-map UI.
## Displays each region's unlock gates + loot tier, and lets the player hop to
## any unlocked region via SceneManager.change_region() (which delegates to the
## threaded WorldHopManager). Pure listener of WorldProgression signals.
extends Control

const REGION_IDS: Array[int] = [1, 2, 3]

var _rows: Dictionary = {}  # region_id -> {label, hop_button}
var _tier_label: Label = null
var _status_label: Label = null


func _ready() -> void:
	_build_ui()
	_connect_signals()
	refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "WORLD MAP — REGION HOP"
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_tier_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for rid in REGION_IDS:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 6)
		hbox.add_child(card)

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 15)
		card.add_child(lbl)

		var btn := Button.new()
		btn.text = "HOP HERE"
		btn.disabled = true
		var captured := rid
		btn.pressed.connect(func(): _on_hop_pressed(captured))
		card.add_child(btn)
		_rows[rid] = {"label": lbl, "hop_button": btn}

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.modulate = Color(1, 0.85, 0.4)
	vbox.add_child(_status_label)


func _connect_signals() -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp == null:
		return
	# Signal arities differ (1..4). Callable.unbind(n) drops the signal's args so
	# the zero-arg refresh() is callable from every one of them.
	var arity := {
		"region_unlocked": 2, "tech_collected": 4, "transport_repaired": 1,
		"milestone_reached": 2, "max_loot_tier_changed": 1,
		"hop_completed": 1, "hop_failed": 1,
	}
	for sig in arity:
		if not wp.has_signal(sig):
			continue
		var cb: Callable = Callable(self, "refresh").unbind(int(arity[sig]))
		wp.connect(sig, cb)


func refresh() -> void:
	var wp := get_node_or_null("/root/WorldProgression")
	if wp == null:
		if _status_label:
			_status_label.text = "WorldProgression unavailable"
		return
	if _tier_label:
		_tier_label.text = "LOOT TIER CAP: %d" % int(wp.get_loot_tier_cap())
	for rid in REGION_IDS:
		var row: Dictionary = _rows.get(rid, {})
		if row.is_empty():
			continue
		var def = wp.get_def(rid)
		var name_txt: String = String(def.display_name) if def != null else ("Region %d" % rid)
		var gates: Dictionary = wp.evaluate_gates(rid)
		var unlocked: bool = wp.can_hop(rid)
		var line: String = "%d. %s  [tier %d]\n" % [rid, name_txt, def.loot_tier if def != null else 0]
		line += "  tech:%s transport:%s milestones:%s prereq:%s\n" % [
			_tick(gates.get("tech", false)), _tick(gates.get("transport", false)),
			_tick(gates.get("milestones", false)), _tick(gates.get("prerequisite", false))]
		line += "  %s" % ("UNLOCKED" if unlocked else "LOCKED")
		(row["label"] as Label).text = line
		var btn: Button = row["hop_button"] as Button
		btn.disabled = not unlocked or rid == int(wp.current_region)
	if _status_label:
		_status_label.text = "Current region: %d" % int(wp.current_region)


func _tick(ok: bool) -> String:
	return "OK" if ok else "--"


func _on_hop_pressed(region_id: int) -> void:
	var sm := get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("change_region"):
		if _status_label:
			_status_label.text = "Hopping to region %d..." % region_id
		sm.change_region(region_id)
	elif _status_label:
		_status_label.text = "SceneManager unavailable"
