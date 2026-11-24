## boss_catalyst_probe.gd — Issue #86 runtime proof.
## Extends SceneTree: entry point is _initialize(), not _ready(). No get_tree().
## Proves the boss/catalyst contract at real sinks:
##   (a) WaveManager._spawn_boss blocks boss spawn when WorldProgression active
##       loot tier < world level, and allows it when >= (boss_gate_blocked signal).
##   (b) AchievementManager.record_boss_defeat grants exactly one catalyst per
##       defeated world via CollectionManager.record_item (CureCatalysts ids).
##   (c) can_synthesize_cure fails without all catalysts, succeeds with them, and
##       synthesize_cure consumes each catalyst exactly once via consume_item.
##   (d) missing CollectionManager / Save / WorldProgression nodes do not crash.
## Fixtures: bare node "Save" stub, mock CollectionManager
## (tools/tests/stubs/mock_catalyst_collection.gd), WorldProgression driven as a
## controlled fixture. Production scripts are loaded by path and driven via
## call() (duck typing) — no compile-time class_name dependency on autoload
## registration under --script.
extends SceneTree

var AM_SCRIPT: GDScript = null
var WP_SCRIPT: GDScript = null
var WM_SCRIPT: GDScript = null
var CC_SCRIPT: GDScript = null
var MOCK_CM: GDScript = null
var SAVE_STUB: GDScript = null

const WORLD_1 := 1
const WORLD_2 := 2
const WORLD_3 := 3

var _failures: int = 0
var _gate_blocked: bool = false
var _gate_required: int = 0
var _gate_actual: int = 0

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
	else:
		_failures += 1
		printerr("  FAIL: ", message)

func _on_gate_blocked(required: int, actual: int) -> void:
	_gate_blocked = true
	_gate_required = required
	_gate_actual = actual

func _initialize() -> void:
	AM_SCRIPT = load("res://scripts/core/AchievementManager.gd") as GDScript
	WP_SCRIPT = load("res://scripts/core/WorldProgression.gd") as GDScript
	WM_SCRIPT = load("res://scripts/gameplay/WaveManager.gd") as GDScript
	CC_SCRIPT = load("res://scripts/gameplay/CureCatalysts.gd") as GDScript
	MOCK_CM = load("res://tools/tests/stubs/mock_catalyst_collection.gd") as GDScript
	SAVE_STUB = load("res://tools/tests/stubs/mock_catalyst_save.gd") as GDScript
	for _i in range(4):
		await process_frame

	print("=== Issue #86: Boss Catalyst Tier Gate ===")
	# Autoloads ARE registered under --script; remove real ones so stubs occupy
	# the exact absolute paths production code resolves.
	for _node_name in ["Save", "WorldProgression", "CollectionManager", "AchievementManager"]:
		var _old: Node = root.get_node_or_null(_node_name)
		if _old != null:
			root.remove_child(_old)
			_old.free()

	# --- fixtures under root (autoloads are NOT registered under --script) ---
	var save: Node = Node.new()
	save.name = "Save"
	save.set_script(SAVE_STUB)
	root.add_child(save)

	var wp: Node = WP_SCRIPT.new()
	wp.name = "WorldProgression"
	root.add_child(wp)
	# get_active_loot_tier() follows current_region: region 1 -> tier 1,
	# region 2 -> tier 2, region 3 -> tier 3 (resources/world/regions.tres).

	var cm: Node = MOCK_CM.new()
	cm.name = "CollectionManager"
	root.add_child(cm)

	var am: Node = AM_SCRIPT.new()
	am.name = "AchievementManager"
	root.add_child(am)

	# Register the CureCatalysts class so AchievementManager can resolve it at runtime.
	load("res://scripts/gameplay/CureCatalysts.gd")

	# ---- (a) boss tier gate at the real WaveManager._spawn_boss sink ------
	var wm: Node = WM_SCRIPT.new()
	wm.name = "WaveManager"
	wm.boss_gate_blocked.connect(_on_gate_blocked)
	root.add_child(wm)

	# WorldProgression region 1 => active tier 1 < world level 2 => blocked.
	wp.set("current_region", 1)
	wm.set("_level", 2)
	_gate_blocked = false
	wm.call("_spawn_boss")
	_assert(_gate_blocked, "boss spawn blocked: active tier 1 < world level 2")
	_assert(_gate_required == 2 and _gate_actual == 1, "gate reports required %d actual %d" % [_gate_required, _gate_actual])

	# Region 2 => active tier 2 >= world level 2 => allowed.
	wp.set("current_region", 2)
	wm.set("_level", 2)
	_gate_blocked = false
	wm.call("_spawn_boss")
	_assert(not _gate_blocked, "boss spawn allowed: active tier 2 >= world level 2")

	# World level 1 with active tier 1 also allowed.
	wm.set("_level", 1)
	_gate_blocked = false
	wm.call("_spawn_boss")
	_assert(not _gate_blocked, "boss spawn allowed: active tier 1 >= world level 1")

	# ---- (b) record_boss_defeat grants one catalyst per defeated world ------
	cm.call("clear")
	am.call("record_boss_defeat", WORLD_1, "suburban_boss")
	var items: Dictionary = cm.call("get_items") as Dictionary
	_assert(int(items.get("catalyst_suburban", 0)) == 1, "one suburban catalyst granted after W1 boss defeat")

	am.call("record_boss_defeat", WORLD_2, "industrial_boss")
	am.call("record_boss_defeat", WORLD_3, "biolab_boss")
	items = cm.call("get_items") as Dictionary
	_assert(int(items.get("catalyst_industrial", 0)) == 1, "one industrial catalyst granted after W2 boss defeat")
	_assert(int(items.get("catalyst_biolab", 0)) == 1, "one biolab catalyst granted after W3 boss defeat")
	_assert(bool(am.call("are_all_world_bosses_defeated")) == true, "all three world bosses recorded defeated")

	# ---- (c) cure synthesis: catalyst gate, then exactly-once consumption ---
	am.call("register_achievement", "a_w1_0", "World 1 achievement", "desc", WORLD_1)
	am.call("register_achievement", "a_w1_1", "World 1 achievement", "desc", WORLD_1)
	am.call("register_achievement", "a_w2_0", "World 2 achievement", "desc", WORLD_2)
	am.call("register_achievement", "a_w3_0", "World 3 achievement", "desc", WORLD_3)
	for id in ["a_w1_0", "a_w1_1", "a_w2_0", "a_w3_0"]:
		am.call("unlock", id)
	_assert(bool(am.call("has_majority_achievements")) == true, "majority achievement threshold reached")

	# Without all catalysts the production sink must refuse synthesis.
	cm.call("clear")
	_assert(bool(am.call("can_synthesize_cure")) == false, "can_synthesize_cure false without catalysts")
	_assert(bool(am.call("synthesize_cure")) == false, "synthesize_cure false without catalysts")
	_assert(bool(am.call("is_post_cure")) == false, "post_cure stays false without catalysts")

	# One catalyst per defeated world (granted in step b): synthesis now allowed.
	var catalyst_ids: Array = CC_SCRIPT.call("get_all_catalyst_ids") as Array
	for cid in catalyst_ids:
		cm.call("record_item", cid, 1)
	_assert(bool(am.call("can_synthesize_cure")) == true, "can_synthesize_cure true with all catalysts, bosses and majority")
	_assert(bool(am.call("synthesize_cure")) == true, "synthesize_cure succeeds with catalysts")
	items = cm.call("get_items") as Dictionary
	for cid in catalyst_ids:
		_assert(int(items.get(cid, 0)) <= 0, "catalyst %s consumed exactly once" % cid)
	_assert(bool(am.call("is_post_cure")) == true, "post_cure set after synthesis")

	# A second synthesis hits the post_cure shortcut and consumes nothing more.
	var leftover: int = int(items.get("catalyst_suburban", 0))
	am.call("synthesize_cure")
	items = cm.call("get_items") as Dictionary
	_assert(int(items.get("catalyst_suburban", 0)) == leftover, "catalysts not consumed a second time")

	# ---- (d) missing manager/gate nodes => no crash ------------------------
	var existing: Node = root.get_node_or_null("CollectionManager")
	root.remove_child(existing)
	existing.free()
	am.call("record_boss_defeat", WORLD_1, "suburban_boss")   # no CollectionManager: guarded, no crash

	existing = root.get_node_or_null("Save")
	root.remove_child(existing)
	existing.free()
	am.call("record_boss_defeat", WORLD_2, "industrial_boss")   # no Save: no crash

	existing = root.get_node_or_null("WorldProgression")
	root.remove_child(existing)
	existing.free()
	wm.set("_level", 2)
	_gate_blocked = false
	wm.call("_spawn_boss")   # no WorldProgression: default tier 1 < level 2, no crash
	_assert(_gate_blocked, "gate blocks with default tier without WorldProgression node")

	if _failures == 0:
		print("BOSS_CATALYST_PROBE_PASS=true")
		quit(0)
	else:
		printerr("BOSS_CATALYST_PROBE_FAIL: %d assertions failed" % _failures)
		quit(1)
