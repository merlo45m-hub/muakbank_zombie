extends SceneTree

## Win-state probe for Triage Roundup Industrial (task 6a).
## Drives the real TriageRoundupController state machine with the L2 unit set
## to win and prints TRIAGE_L2_PASS=true. Read-only: no game files are created.

const TAG := "TRIAGE_L2_PROBE "

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

	var packed: PackedScene = load("res://scenes/minigames/triage_roundup_industrial.tscn")
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

	var pens: Node = inst.get_node_or_null("Pens")
	var animals: Node = inst.get_node_or_null("Animals")
	var guard := 0
	var won := false
	var note := ""
	while guard < 600 and int(ctrl.get("state")) == 1:
		for pen in pens.get_children():
			var t: String = String(pen.get("required_animal_type"))
			var unit: Node3D = _unit_of_type(animals, t)
			if unit and not bool(unit.get("delivered")):
				unit.global_position = pen.global_position + Vector3(0, 0.4, 0)
				unit.linear_velocity = Vector3.ZERO
		ctrl.call("_process", 1.0)
		note = "time=%.0f delivered=%d tier=%d" % [float(ctrl.get("time_remaining")), int(ctrl.get("delivered_types").size()), int(ctrl.get("last_loot_tier"))]
		if int(ctrl.get("state")) == 2:
			won = true
			note += " <<WON"
			break
		if int(ctrl.get("state")) == 3:
			note += " <<FAILED"
			break
		guard += 1

	var tier: int = int(ctrl.get("last_loot_tier"))
	print(TAG + "state=%d won=%s tier=%d | %s" % [int(ctrl.get("state")), won, tier, note])
	var rr: Dictionary = ctrl.get("last_reward_report") if ctrl.get("last_reward_report") != null else {}
	var reward_ok: bool = int(rr.get("count", 0)) >= 1 and int(rr.get("tier", 0)) == 2
	print(TAG + "reward count=%d tier=%d capped=%s" % [int(rr.get("count", 0)), int(rr.get("tier", 0)), str(rr.get("capped", "?"))])
	if won and tier == 2:
		print(TAG + "TRIAGE_L2_PASS=true")
		quit(0)
	else:
		print(TAG + "TRIAGE_L2_PASS=false")
		quit(1)

func _unit_of_type(animals: Node, t: String) -> Node3D:
	for a in animals.get_children():
		if String(a.get("unit_type")) == t:
			return a
	return null
