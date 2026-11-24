extends SceneTree
## GDD Issue #25 / #83 — secret-transport trigger regression probe.
## Lightweight SceneTree probe — NO game scene boot, NO real autoloads.
## Instantiates the real SecretTransportTriggers helper programmatically per
## region and asserts:
##   1. trigger exists with correct target per region
##   2. unreachable link does not hop
##   3. reachable link calls request_secret_hop exactly once
##   4. no double fire on repeated enter

class SecretProgressionStub extends Node:
	var current_region: int = 1
	var unlocked_regions: Array[int] = [1]
	var reachable: Dictionary = {}   # "[from,to]" -> bool

	func is_secret_reachable(from_region: int, to_region: int) -> bool:
		return bool(reachable.get("[%d,%d]" % [from_region, to_region], false))

class SecretHopSpy extends Node:
	var calls: Array[int] = []

	func request_secret_hop(to_region: int) -> void:
		calls.append(to_region)

var _stub: SecretProgressionStub = null
var _spy: SecretHopSpy = null
var _helper: Node = null
var _failures: Array[String] = []

# Mirrors SecretTransportTriggers.TRIGGER_DEFS.
var DEFS: Array[Dictionary] = [
	{"from": 1, "to": 2, "label": "secret_crypt_to_industrial"},
	{"from": 2, "to": 3, "label": "secret_freight_to_biolab"},
	{"from": 3, "to": 1, "label": "secret_decon_to_suburban"},
	{"from": 3, "to": 2, "label": "secret_conduit_to_industrial"},
]

func _check(cond: bool, name: String) -> void:
	if cond:
		print("TRIGGER_OK ", name)
	else:
		print("TRIGGER_FAIL ", name)
		_failures.append(name)

func _initialize() -> void:
	await process_frame

	# --- stubs: WorldProgression + spy WorldHopManager under root -------
	_stub = SecretProgressionStub.new()
	_stub.name = "WorldProgression"
	get_root().add_child(_stub)

	_spy = SecretHopSpy.new()
	_spy.name = "WorldHopManager"
	get_root().add_child(_spy)

	# --- real trigger helper, instantiated programmatically -------------
	var helper_sc: GDScript = load("res://scripts/world/SecretTransportTriggers.gd") as GDScript
	_helper = helper_sc.new()
	get_root().add_child(_helper)
	await process_frame

	# All secret links reachable by default.
	for d in DEFS:
		_stub.set_reachable(int(d.get("from")), int(d.get("to")), true)

	var player: Node = Node.new()
	player.add_to_group("player")

	func fire(def: Dictionary) -> void:
		_helper.call("_on_body_entered", player, def)

	# --- 1) trigger exists with correct target per region ---------------
	for rid in [1, 2, 3]:
		_stub.current_region = rid
		_helper.call("spawn_triggers_for_region", rid)
		var expected: int = 0
		for d in DEFS:
			if int(d.get("from")) == rid and _stub.is_secret_reachable(rid, int(d.get("to"))):
				expected += 1
		var got: int = int(_helper.call("get_trigger_positions").size())
		_check(got == expected, "spawn_count_region_%d" % [rid])

	# --- 3) reachable link calls request_secret_hop exactly once --------
	_stub.current_region = 1
	_helper.call("spawn_triggers_for_region", 1)
	var n0: int = _spy.calls.size()
	fire({"from": 1, "to": 2, "label": "secret_crypt_to_industrial"})
	_check(_spy.calls.size() == n0 + 1 and _spy.calls[-1] == 2,
		"reachable_1_to_2_calls_once")
	_check(_spy.calls[-1] == 2, "correct_target_region_2")

	# --- 4) no double fire on repeated enter ----------------------------
	fire({"from": 1, "to": 2, "label": "secret_crypt_to_industrial"})
	fire({"from": 1, "to": 2, "label": "secret_crypt_to_industrial"})
	_check(_spy.calls.size() == n0 + 1, "no_double_fire_calls")

	# --- 2) unreachable link does not hop -------------------------------
	_stub.set_reachable(1, 2, false)
	_helper.call("spawn_triggers_for_region", 1)
	_check(int(_helper.call("get_trigger_positions").size()) == 0,
		"region1_no_triggers_when_unreachable")
	var n1: int = _spy.calls.size()
	fire({"from": 1, "to": 2, "label": "secret_crypt_to_industrial"})
	_check(_spy.calls.size() == n1, "unreachable_1_to_2_no_hop")

	# reachable cross-check on an always-open link (3->1).
	_stub.current_region = 3
	_helper.call("spawn_triggers_for_region", 3)
	_check(int(_helper.call("get_trigger_positions").size()) == 2, "region3_two_triggers")
	var n2: int = _spy.calls.size()
	fire({"from": 3, "to": 1, "label": "secret_decon_to_suburban"})
	_check(_spy.calls.size() == n2 + 1 and _spy.calls[-1] == 1,
		"reachable_3_to_1_calls_once")

	var ok: bool = _failures.is_empty()
	print("SECRET_TRANSPORT_TRIGGER_PASS=", ok)
	if not ok:
		print("FAILURES=", _failures)
	quit(0 if ok else 1)
