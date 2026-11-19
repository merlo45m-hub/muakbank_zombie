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
	var guard := 0
	var won := false
	var note := ""
	while guard < 600 and int(ctrl.get("state")) == 1:
		# Move braces to sockets for current step
		var current_step: String = String(ctrl.get("current_step"))
		var door: Node = doors.get_node_or_null("Door%s" % current_step)
		if door and is_instance_valid(door):
			# Find the brace for this door
			var brace_type: String = String(door.get("assigned_brace"))
			var brace: Node = _find_brace(inst, brace_type)
			if brace:
				var socket: Node = door.get_node_or_null("BraceSocket")
				if socket:
					brace.global_position = socket.global_position
					brace.linear_velocity = Vector3.ZERO
					brace.angular_velocity = Vector3.ZERO
		ctrl.call("_process", 1.0)
		note = "time=%.0f step=%s state=%d" % [float(ctrl.get("time_remaining")), current_step, int(ctrl.get("state"))]
		if int(ctrl.get("state")) == 2:
			won = true
			note += " <<WON"
			break
		if int(ctrl.get("state")) == 3:
			note += " <<FAILED"
			break
		guard += 1

	var tier: int = int(ctrl.get("last_loot_tier")) if ctrl.get("last_loot_tier") != null else 0
	print(TAG + "state=%d won=%s tier=%d | %s" % [int(ctrl.get("state")), won, tier, note])
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