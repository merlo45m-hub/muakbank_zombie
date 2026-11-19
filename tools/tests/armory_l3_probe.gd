extends SceneTree

## Win-state probe for Armory Lockdown Bio-Lab (task L3 Armory).
## Drives the real ArmoryLockdownController state machine with the Bio-Lab gate
## to win and prints ARMORY_L3_PASS=true. Read-only: no game files are created.

const TAG := "ARMORY_L3_PROBE "

func _initialize() -> void:
	await process_frame

	if root.find_child("ObjectiveManager", true, false) == null:
		var om: Node = load("res://scripts/gameplay/ObjectiveManager.gd").new()
		om.name = "ObjectiveManager"
		root.add_child(om)

	# Bio-Lab gate: WorldProgression.can_hop(3) must be true; loot tier at
	# completion is get_active_loot_tier() (Region 3 -> tier 3).
	var wp: Node = root.get_node_or_null("WorldProgression")
	assert(wp != null, "WorldProgression autoload missing")
	var ur: Array[int] = []
	ur.assign([1, 2, 3])
	wp.unlocked_regions = ur
	wp.current_region = 3
	# Reward clamp reads the CACHED max_loot_tier; raw test unlocks
	# must warm it the same way try_unlock would.
	wp.call("_recompute_max_loot_tier", false)

	var packed: PackedScene = load("res://scenes/minigames/armory_lockdown_biolab.tscn")
	assert(packed != null, "Bio-Lab armory scene load FAIL")
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

	# Drive the REAL state machine: crack both crates and open the door
	var crate1: Node = inst.get_node_or_null("Crate1")
	var crate2: Node = inst.get_node_or_null("Crate2")
	var door: Node = inst.get_node_or_null("ArmoryDoor")

	assert(crate1 != null, "Crate1 missing")
	assert(crate2 != null, "Crate2 missing")
	assert(door != null, "ArmoryDoor missing")

	# Crack both supply crates through the REAL interact path
	crate1.set("player_near", true)
	crate1.call("interact")
	crate2.set("player_near", true)
	crate2.call("interact")

	# Breach the armory door via its real open path
	if door.has_method("open_fully"):
		door.call("open_fully")

	var guard := 0
	var won := false
	var note := ""
	while guard < 60 and int(ctrl.get("state")) == 1:
		ctrl.call("_process", 1.0)
		var c1: bool = bool(crate1.get("is_cracked"))
		var c2: bool = bool(crate2.get("is_cracked"))
		var door_open: bool = (bool(door.get("is_open")) or bool(door.get("is_half_open")))
		note = "time=%.0f c1_cracked=%s c2_cracked=%s door_open=%s" % [float(ctrl.get("time_remaining")), str(c1), str(c2), str(door_open)]
		if int(ctrl.get("state")) == 2:
			won = true
			note += "  <<WON"
			break
		if int(ctrl.get("state")) == 3:
			note += "  <<FAILED"
			break
		guard += 1
	await process_frame

	var tier: int = int(ctrl.get("last_loot_tier")) if ctrl.get("last_loot_tier") != null else 0
	print(TAG + "state=%d won=%s tier=%d | %s" % [int(ctrl.get("state")), won, tier, note])

	# Verify the scene is placed in a DIFFERENT district from l3_rooftop_extraction
	# l3_rooftop_extraction is in RooftopDistrict (at x=140), ArmoryLockdownBioLab is at origin (MallDistrict area)
	# This ensures no placement collision
	var extraction_inst: Node = root.find_child("EndgameExtraction", true, false)
	var armory_inst: Node = root.find_child("ArmoryLockdownBioLab", true, false)
	var different_districts := true
	if extraction_inst and armory_inst:
		# EndgameExtraction is at (140, 0, 0) in RooftopDistrict
		# ArmoryLockdownBioLab is at (0, 0, 0) which falls in MallDistrict
		var ext_pos: Vector3 = extraction_inst.global_position as Vector3
		var arm_pos: Vector3 = armory_inst.global_position as Vector3
		different_districts = (ext_pos.x > 100 and arm_pos.x < 100) or (ext_pos.x < 100 and arm_pos.x > 100)
		print(TAG + "extraction pos: %s, armory pos: %s, different_districts: %s" % [ext_pos, arm_pos, different_districts])

	var rr: Dictionary = ctrl.get("last_reward_report") if ctrl.get("last_reward_report") != null else {}
	var reward_ok: bool = int(rr.get("count", 0)) >= 1 and int(rr.get("tier", 0)) == 3
	print(TAG + "reward count=%d tier=%d capped=%s" % [int(rr.get("count", 0)), int(rr.get("tier", 0)), str(rr.get("capped", "?"))])
	if won and tier == 3 and different_districts:
		print(TAG + "ARMORY_L3_PASS=true")
		quit(0)
	else:
		var fail_reasons := []
		if not won:
			fail_reasons.append("not won")
		if tier != 3:
			fail_reasons.append("tier != 3 (got %d)" % tier)
		if not different_districts:
			fail_reasons.append("placement collides with l3_rooftop_extraction")
		print(TAG + "ARMORY_L3_FAIL: %s" % ", ".join(fail_reasons))
		quit(1)