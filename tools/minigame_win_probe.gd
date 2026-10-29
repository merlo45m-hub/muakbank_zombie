extends Node

## Minigame winnability probe — loads each REAL minigame .tscn, drives the REAL
## controller state machine to its WIN transition, and reports. Read-only: new
## files only; never edits game scripts.

const TAG := "MINIWIN "

var results := {}

func make_player(stub_dir_parent: Node) -> Node3D:
	var p: Node3D = load("res://tools/player_stub.gd").new()
	p.name = "ProbePlayer"
	stub_dir_parent.add_child(p)
	for f in ["pizza", "burger", "medkit", "soda", "fries", "takis", "sushi", "coffee", "battery"]:
		p.call("add_food", f, 25)
	for i in range(50):
		p.call("add_food", "pizza", 25)
	return p

func _ready() -> void:
	await get_tree().process_frame
	if get_tree().root.find_child("ObjectiveManager", true, false) == null:
		var om: Node = load("res://scripts/gameplay/ObjectiveManager.gd").new()
		om.name = "ObjectiveManager"
		get_tree().root.add_child(om)

	await _results_generator()
	await _results_spoil()
	await _results_laststand()

	var any_fail := false
	for k in results:
		any_fail = any_fail or not results[k]["win"]
		print(TAG + "%s: WON=%s state=%d note=[%s]" % [k, results[k]["win"], results[k]["state"], results[k]["note"]])
	print(TAG + "RESULT %s" % ("ALL WIN REACHABLE" if not any_fail else "SOME NOT WIN"))
	get_tree().quit(0 if not any_fail else 1)

# ── GENERATOR ─────────────────────────────────────────────────────────────
func _results_generator() -> void:
	var packed := load("res://scenes/minigames/keep_generator_fed.tscn") as PackedScene
	if packed == null:
		results["generator"] = {"win": false, "state": -1, "note": "scene load FAIL"}
		return
	var inst := packed.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node_or_null("Controller")
	var player: Node3D = make_player(inst)
	player.global_position = inst.global_position
	await get_tree().process_frame

	if ctrl == null:
		results["generator"] = {"win": false, "state": -1, "note": "no Controller node"}
	else:
		ctrl.set("player", player)
		ctrl.interact()
		await get_tree().process_frame
		var start_state := int(ctrl.get("state"))
		var hopper: Node = inst.get_node_or_null("Hopper")
		# Bind player into the hopper's zone, the way body_entered would.
		if hopper:
			hopper.set("player", player)
		var step := 1.0
		var sim := 0.0
		var guard := 0
		var won := false
		var last_note := ""
		while guard < 300 and sim <= 92.0 and int(ctrl.get("state")) != 3:
			# Deposit food through the REAL hopper path each time fuel runs low.
			if is_instance_valid(player) and float(ctrl.get("fuel")) < 50.0:
				hopper.interact()
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(99999)
			ctrl._process(step)
			sim += step
			last_note = "sim=%.0f fuel=%.1f hp=%d stage=%d feeds_made" % [sim, float(ctrl.get("fuel")), int(ctrl.get("generator_hp")), int(ctrl.get("wave_stage"))]
			if int(ctrl.get("state")) == 2:
				won = true
				last_note += "  <<WON"
				break
			if int(ctrl.get("state")) == 3:
				last_note += "  <<FAILED"
				break
			guard += 1
		results["generator"] = {"win": won, "state": int(ctrl.get("state")), "note": "starting_fuel=%s start=%d player_food=%s | %s" % [str(ctrl.get("STARTING_FUEL")), start_state, str(player.get_food_count("pizza")) if player else "-", last_note]}
	inst.queue_free()
	await get_tree().process_frame

# ── SPOIL & SURVIVE ──────────────────────────────────────────────────────
func _results_spoil() -> void:
	var packed := load("res://scenes/minigames/spoil_and_survive.tscn") as PackedScene
	if packed == null:
		results["spoilsave"] = {"win": false, "state": -1, "note": "scene load FAIL"}
		return
	var inst := packed.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node_or_null("Controller")
	var player: Node3D = make_player(inst)
	player.global_position = inst.global_position
	await get_tree().process_frame

	if ctrl == null:
		results["spoilsave"] = {"win": false, "state": -1, "note": "no Controller node"}
	else:
		ctrl.interact()
		await get_tree().process_frame
		var start_state := int(ctrl.get("state"))
		var slots: Node = inst.get_node_or_null("Platters")
		var slot_list: Array = slots.get_children() if slots else []
		var sguard := 0
		var won := false
		var last_note := ""
		# A skilled player eats only fresh dishes, ~one slot/sec. Tick each slot's
		# real _process (cooldown+replenish) and the controller clock each step.
		while sguard < 200 and int(ctrl.get("state")) not in [2, 3]:
			for slot in slot_list:
				if is_instance_valid(slot) and slot.has_method("_process"):
					slot._process(0.7)
			ctrl._process(1.0)
			for slot in slot_list:
				if is_instance_valid(slot) and slot.has_method("has_dish") and bool(slot.has_dish()) and not bool(slot.is_tainted()):
					slot.set("player_in_zone", player)
					slot.interact()
			last_note = "time=%.0f dishes=%d" % [float(ctrl.get("time_remaining")), int(ctrl.get("dishes_eaten"))]
			if int(ctrl.get("state")) == 2:
				won = true
				last_note += "  <<WON"
				break
			if int(ctrl.get("state")) == 3:
				last_note += "  <<FAILED"
				break
			sguard += 1
		results["spoilsave"] = {"win": won, "state": int(ctrl.get("state")), "note": "slots=%d start=%d | %s" % [len(slot_list), start_state, last_note]}
	inst.queue_free()
	await get_tree().process_frame

# ── LAST STAND ───────────────────────────────────────────────────────────
func _results_laststand() -> void:
	var packed := load("res://scenes/minigames/last_stand_station.tscn") as PackedScene
	if packed == null:
		results["laststand"] = {"win": false, "state": -1, "note": "scene load FAIL"}
		return
	var inst := packed.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	var ctrl: Node = inst.get_node_or_null("Controller")
	var player: Node3D = make_player(inst)
	player.global_position = inst.global_position
	await get_tree().process_frame

	if ctrl == null:
		results["laststand"] = {"win": false, "state": -1, "note": "no Controller node"}
	else:
		ctrl.start_trial()
		await get_tree().process_frame
		var start_state := int(ctrl.get("state"))
		var guard := 0
		var won := false
		var last_note := ""
		while guard < 900 and (int(ctrl.get("state")) in [1, 2, 3]):
			player.global_position = inst.global_position + Vector3(0, 0, 1.0)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(99999)
			ctrl._process(1.0)
			last_note = "wave=%d timer=%.1f active=%d desertion=%.1f" % [int(ctrl.get("wave")), float(ctrl.get("timer")), int(ctrl.get("active_enemies").size()), float(ctrl.get("desertion_time"))]
			if int(ctrl.get("state")) == 4:
				won = true
				last_note += "  <<WON"
				break
			if int(ctrl.get("state")) == 5:
				last_note += "  <<FAILED"
				break
			guard += 1
		results["laststand"] = {"win": won, "state": int(ctrl.get("state")), "note": "start=%d | %s" % [start_state, last_note]}
	inst.queue_free()
	await get_tree().process_frame
