extends SceneTree

## Win-state probe for Quarantine Breach Industrial (task 6b).
## Drives the real QuarantineBreachController state machine with the L2 gate
## to win and prints QUARANTINE_L2_PASS=true. Read-only: no game files are created.

const TAG := "QUARANTINE_L2_PROBE "

func _initialize() -> void:
	await process_frame

	if root.find_child("ObjectiveManager", true, false) == null:
		var om: Node = load("res://scripts/gameplay/ObjectiveManager.gd").new()
		om.name = "ObjectiveManager"
		root.add_child(om)

	# Industrial gate: WorldProgression.can_hop(2) must be true; loot tier at
	# completion is get_active_loot_tier() (Region 2 -> tier 2).
	var wp: Node = root.get_node_or_null("WorldProgression")
	assert(wp != null, "WorldProgression autoload missing")
	var ur: Array[int] = []
	ur.assign([1, 2])
	wp.unlocked_regions = ur
	wp.current_region = 2
	# Reward clamp reads the CACHED max_loot_tier; raw test unlocks
	# must warm it the same way try_unlock would.
	wp.call("_recompute_max_loot_tier", false)

	var packed: PackedScene = load("res://scenes/minigames/quarantine_breach_industrial.tscn")
	assert(packed != null, "industrial scene load FAIL")
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await process_frame

	var ctrl: Node = inst.get_node_or_null("Controller")
	assert(ctrl != null, "no Controller node")

	var player: Node3D = Node3D.new()
	player.name = "ProbePlayer"
	player.add_to_group("player")
	inst.add_child(player)
	ctrl.set("player", player)
	await process_frame

	ctrl.call("interact")
	await process_frame

	var doors: Node = inst.get_node_or_null("Doors")
	var note := ""
	var won := false
	# Drive the REAL state machine: per ordered step, close the door, put the
	# matching brace in its socket, tick seal in 0.25s quanta (SEAL_DWELL=0.75;
	# oversized manual deltas overshot the unbraced-limit and failed the run -
	# the original lane bug). Total sim time stays under SPAWN_INTERVAL so no
	# leaker ever spawns and the win path is deterministic.
	for step_name in ["A", "B", "C"]:
		if int(ctrl.get("state")) != 1:
			break
		var current_step: String = String(ctrl.get("current_step"))
		if current_step != step_name:
			note = "order drift: want %s got %s" % [step_name, current_step]
			break
		var door: Node = doors.get_node_or_null("Door" + step_name)
		if door == null or not is_instance_valid(door):
			note = "no door " + step_name
			break
		door.call("toggle_to_closed")
		var brace_type: String = String(door.get("assigned_brace"))
		var brace: Node = _find_brace(inst, brace_type)
		if brace == null:
			note = "no brace for step " + step_name + " (want " + brace_type + ")"
			break
		var socket: Node = door.get_node_or_null("BraceSocket")
		if socket == null:
			note = "no socket on door " + step_name
			break
		brace.global_position = (socket as Node3D).global_position
		if brace.has_method("set_linear_velocity"):
			brace.call("set_linear_velocity", Vector3.ZERO)
			brace.call("set_angular_velocity", Vector3.ZERO)
		await process_frame
		var t := 0
		while t < 12 and not bool(door.get("sealed")) and int(ctrl.get("state")) == 1:
			ctrl.call("_process", 0.25)
			t += 1
		await process_frame
		if bool(door.get("sealed")):
			note = "sealed " + step_name
		else:
			note = "door " + step_name + " unsealed after dwell ticks"
			break
	won = int(ctrl.get("state")) == 2
	if not won:
		note += " | time=%.0f state=%d" % [float(ctrl.get("time_remaining")), int(ctrl.get("state"))]

	var tier: int = int(ctrl.get("last_loot_tier")) if ctrl.get("last_loot_tier") != null else 0
	print(TAG + "state=%d won=%s tier=%d | %s" % [int(ctrl.get("state")), won, tier, note])
		var rr: Dictionary = ctrl.get("last_reward_report") if ctrl.get("last_reward_report") != null else {}
	var reward_ok: bool = int(rr.get("count", 0)) >= 1 and int(rr.get("tier", 0)) == 2
	print(TAG + \"reward count=%d tier=%d capped=%s\" % [int(rr.get(\"count\", 0)), int(rr.get(\"tier\", 0)), str(rr.get(\"capped\", \"?\"))])
	if won and tier == 2:
		print(TAG + "QUARANTINE_L2_PASS=true")
		quit(0)
	else:
		print(TAG + "QUARANTINE_L2_FAIL: %s" % note)
		quit(1)

func _find_brace(inst: Node, brace_type: String) -> Node:
	var cases: Node = inst.get_node_or_null("Cases")
	if cases:
		for c in cases.get_children():
			if c.is_in_group("quarantine_brace") and String(c.get("brace_type")) == brace_type:
				return c
	var cart: Node = inst.get_node_or_null("ServiceCart")
	if cart and cart.is_in_group("quarantine_brace") and String(cart.get("brace_type")) == brace_type:
		return cart
	return null