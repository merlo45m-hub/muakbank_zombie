extends Node

## Minigame winnability probe — loads each REAL minigame .tscn, drives the REAL
## controller state machine (_process) directly to its WIN transition, and reports.
## Read-only: new file only; never edits game scripts.

const TAG := "MINIWIN "

var results := {}

# Minimal but API-true player stub (group "player").
func make_player() -> Node3D:
	var p := Node3D.new()
	p.name = "ProbePlayer"
	p.add_to_group("player")
	p.set("health", 100)
	p.set("max_health", 100)
	p.set("is_dead", false)
	p.set("move_speed", 4.5)
	p.set("sprint_speed", 7.5)
	p.set("velocity", Vector3.ZERO)
	var inv := {"pizza": {"count": 200, "heal": 25}}
	p.set("_inventory", inv)
	var ws := load("res://scripts/gameplay/WeaponSystem.gd").new()
	ws.name = "WeaponSystem"
	p.add_child(ws)
	p.set("weapon_system", ws)
	return p

func _ready() -> void:
	await get_tree().process_frame
	if get_tree().root.find_child("ObjectiveManager", true, false) == null:
		var om := load("res://scripts/gameplay/ObjectiveManager.gd").new()
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
	var ctrl := inst.get_node_or_null("Controller")
	var player := make_player()
	inst.add_child(player)
	player.global_position = inst.global_position
	# ensure fuel-feeding works through real hopper path: set player food via real API
	for f in ["pizza","burger","medkit"]:
		player.call("add_food", f, 25)
	await get_tree().process_frame

	if ctrl == null:
		results["generator"] = {"win": false, "state": -1, "note": "no Controller node"}
	else:
		ctrl.interact()   # real _start_run
		await get_tree().process_frame
		var start_state := int(ctrl.get("state"))
		# Feed to near-cap via real hopper, then fast-forward the real _process.
		var hopper := inst.get_node_or_null("Hopper")
		var step := 1.0
		var sim := 0.0
		var guard := 0
		var won := false
		var last_note := ""
		while guard < 200 and sim <= 92.0:
			# top up fuel through the hopper (real consume+add_fuel path)
			if float(ctrl.get("fuel")) < 60.0 and player.has_food("pizza"):
				hopper.interact()
			# kill any enemies that spawn so they cannot chew hp
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(99999)
			# run real _process by one step
			ctrl._process(step)
			sim += step
			last_note = "sim=%.0f fuel=%.1f hp=%d stage=%d" % [sim, float(ctrl.get("fuel")), int(ctrl.get("generator_hp")), int(ctrl.get("wave_stage"))]
			if int(ctrl.get("state")) == BioGeneratorController.RunState.WON:
				won = true
				last_note += "  <<WON"
				break
			if int(ctrl.get("state")) == BioGeneratorController.RunState.FAILED:
				last_note += "  <<FAILED"
				break
			guard += 1
		results["generator"] = {"win": won, "state": int(ctrl.get("state")), "note": "starting_fuel=%.0f start_state=%d | %s" % [float(ctrl.get("STARTING_FUEL")), start_state, last_note]}
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
	var ctrl := inst.get_node_or_null("Controller")
	var player := make_player()
	inst.add_child(player)
	player.global_position = inst.global_position
	await get_tree().process_frame

	if ctrl == null:
		results["spoilsave"] = {"win": false, "state": -1, "note": "no Controller node"}
	else:
		ctrl.interact()  # _start_round -> ACTIVE
		await get_tree().process_frame
		var start_state := int(ctrl.get("state"))
		# eat real dishes through real slot path until WIN / time runs out
		var sguard := 0
		var won := false
		var last_note := ""
		while sguard < 400 and int(ctrl.get("state")) == SpoilAndSurviveController.RunState.ACTIVE:
			var slots := inst.get_node_or_null("Platters")
			var ate := false
			if slots:
				for slot in slots.get_children():
					if is_instance_valid(slot) and slot.has_method("has_dish") and bool(slot.has_dish()) and not bool(slot.is_tainted()):
						slot.set("player_in_zone", player)
						slot.interact()
						ate = true
			last_note = "time=%.1f dishes=%d tainted_seen=%s" % [float(ctrl.get("time_remaining")), int(ctrl.get("dishes_eaten")), str(ate)]
			if int(ctrl.get("state")) == SpoilAndSurviveController.RunState.WON:
				won = true
				last_note += "  <<WON"
				break
			if int(ctrl.get("state")) == SpoilAndSurviveController.RunState.FAILED:
				last_note += "  <<FAILED"
				break
			ctrl._process(1.0)
			sguard += 1
		results["spoilsave"] = {"win": won, "state": int(ctrl.get("state")), "note": "slots=%d start=%d | %s" % [len(inst.get_node_or_null("Platters").get_children()) if inst.get_node_or_null("Platters") else -1, start_state, last_note]}
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
	var ctrl := inst.get_node_or_null("Controller")
	var player := make_player()
	inst.add_child(player)
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
		while guard < 800 and (int(ctrl.get("state")) == 1 or int(ctrl.get("state")) == 2 or int(ctrl.get("state")) == 3):
			# keep player inside perimeter
			player.global_position = inst.global_position + Vector3(0, 0, 1.0)
			# kill all active enemies through real take_damage so 'died' fires and
			# _on_enemy_died removes them from active_enemies
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(99999)
			last_note = "wave=%d timer=%.1f enemies_active=%d" % [int(ctrl.get("wave")), float(ctrl.get("timer")), len(ctrl.get("active_enemies"))]
			ctrl._process(1.0)
			if int(ctrl.get("state")) == LastStandStationController.TrialState.WON:
				won = true
				last_note += "  <<WON"
				break
			if int(ctrl.get("state")) == LastStandStationController.TrialState.FAILED:
				last_note += "  <<FAILED"
				break
			guard += 1
		results["laststand"] = {"win": won, "state": int(ctrl.get("state")), "note": "start=%d | %s" % [start_state, last_note]}
	inst.queue_free()
	await get_tree().process_frame
