## secret_transport_trigger_probe.gd — Issue #83 runtime proof.
## Extends SceneTree: entry point is _initialize(), not _ready().
extends SceneTree

const ST := preload("res://scripts/world/SecretTransportTriggers.gd")
const WP_STUB := preload("res://tools/tests/stubs/mock_world_progression.gd")
const HOP_STUB := preload("res://tools/tests/stubs/mock_world_hop_manager.gd")

var _failures: int = 0

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
	else:
		_failures += 1
		printerr("  FAIL: ", message)

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	var wp: Node = WP_STUB.new()
	wp.name = "WorldProgression"
	root.add_child(wp)
	var hop: Node = HOP_STUB.new()
	hop.name = "WorldHopManager"
	root.add_child(hop)
	var triggers: Node3D = ST.new()
	triggers.name = "SecretTransportTriggersProbe"
	root.add_child(triggers)
	await process_frame

	# Unreachable link must not spawn a trigger.
	triggers.spawn_triggers_for_region(1)
	_assert(triggers.get_trigger_positions().is_empty(), "unreachable W1->2 spawns no trigger")

	# Reachable link spawns a named trigger.
	wp.set_reachable(1, 2, true)
	triggers.spawn_triggers_for_region(1)
	var trigger: Node = triggers.find_child("secret_crypt_to_industrial", true, false)
	_assert(trigger != null, "reachable W1->2 trigger exists")
	if trigger == null:
		printerr("SECRET_TRANSPORT_PROBE_FAIL: no trigger")
		quit(1)
		return

	var area: Area3D = trigger as Area3D
	_assert(area != null, "trigger is Area3D")
	_assert(area.get_collision_mask_value(2), "trigger masks player layer 2")

	# Simulate a player entering twice: hop exactly once.
	var body: Node3D = Node3D.new()
	body.name = "ProbePlayer"
	body.add_to_group("player")
	root.add_child(body)
	area.emit_signal("body_entered", body)
	area.emit_signal("body_entered", body)
	var calls: Array[int] = hop.calls
	_assert(calls.size() == 1, "body_entered fires request_secret_hop once: %d" % calls.size())
	_assert(calls[0] == 2, "hop target is region 2")

	# Region change clears triggers.
	triggers.clear_triggers()
	_assert(triggers.find_child("secret_crypt_to_industrial", true, false) == null, "clear_triggers removes old triggers")

	if _failures == 0:
		print("SECRET_TRANSPORT_PROBE_PASS=true")
		quit(0)
	else:
		printerr("SECRET_TRANSPORT_PROBE_FAIL: %d assertions failed" % _failures)
		quit(1)
