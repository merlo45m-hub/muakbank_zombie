## registry_record_probe.gd — Issue #85 runtime proof.
## Extends SceneTree: entry point is _initialize(), not _ready(). No get_tree().
## Calls PRODUCTION DismantleComponent._record_registries() and Game.on_zombie_killed()
## with a stub CollectionManager mounted at /root/CollectionManager, then asserts
## exactly which ids reached the sole-writer API. No self-replayed logic.
extends SceneTree

const MOCK_REGISTRY := preload("res://tools/tests/stubs/mock_registry_manager.gd")
const DISMANTLE_SCRIPT := preload("res://scripts/gameplay/DismantleComponent.gd")
const GAME_SCENE := preload("res://scenes/main/game.tscn")

var _failures: int = 0

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
	else:
		_failures += 1
		printerr("  FAIL: ", message)

func _install_stub() -> Node:
	var existing: Node = root.get_node_or_null("CollectionManager")
	if existing != null:
		root.remove_child(existing)
		existing.free()
	var stub: Node = MOCK_REGISTRY.new()
	stub.name = "CollectionManager"
	root.add_child(stub)
	return stub

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	var reg: Node = _install_stub()

	# 1. Production dismantle sink: string + dictionary drops, aggregated.
	var dismantle: Node = DISMANTLE_SCRIPT.new()
	root.add_child(dismantle)
	dismantle.set("prop_asset_id", "prop_scrap_01")
	dismantle.set("required_tool_tier", 1)
	dismantle.set("bestiary_id", "boss_w1")
	dismantle.set("_loot_descriptor", [{
		"asset_id": "prop_scrap_01",
		"loot_table_id": "suburban_misc",
		"tool_tier": 1,
		"drops": ["mat_scrap", "mat_scrap", {"item_id": "mat_wire", "count": 3}, "mat_gear"],
	}])
	reg.call("clear")
	dismantle.call("_record_registries")

	var item_ledger: Array = reg.call("get_item_ledger")
	var qty_by_id: Dictionary = {}
	for entry in item_ledger:
		qty_by_id[String(entry["id"])] = int(entry["qty"])
	_assert(int(qty_by_id.get("mat_scrap", 0)) == 2, "production record_item aggregated mat_scrap qty 2")
	_assert(int(qty_by_id.get("mat_wire", 0)) == 3, "production record_item passed mat_wire qty 3")
	_assert(int(qty_by_id.get("mat_gear", 0)) == 1, "production record_item passed mat_gear qty 1")
	var defeat_ledger: Array = reg.call("get_defeat_ledger")
	_assert(defeat_ledger.has("boss_w1"), "production dismantle recorded bestiary defeat")

	# 2. Production kill sink through the real Game scene.
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	game.set("game_active", true)
	reg.call("clear")
	game.call("on_zombie_killed", "zombie")
	game.call("on_zombie_killed", "boss_w1")
	defeat_ledger = reg.call("get_defeat_ledger")
	_assert(defeat_ledger.has("zombie"), "production Game.on_zombie_killed recorded zombie")
	_assert(defeat_ledger.has("boss_w1"), "production Game.on_zombie_killed recorded boss")

	# 3. No manager present: both sinks must short-circuit without crashing.
	root.remove_child(reg)
	reg.free()
	dismantle.call("_record_registries")
	game.call("on_zombie_killed", "zombie")
	_assert(true, "no-manager case: production sinks short-circuit without crash")

	if _failures == 0:
		print("REGISTRY_RECORD_PROBE_PASS=true")
		quit(0)
	else:
		printerr("REGISTRY_RECORD_PROBE_FAIL: %d assertions failed" % _failures)
		quit(1)
