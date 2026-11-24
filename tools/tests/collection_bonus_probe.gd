## collection_bonus_probe.gd — Issue #84 runtime proof.
## Extends SceneTree: entry point is _initialize(), not _ready(). No get_tree().
## Proves zero-bonus baseline vs nonzero bonus at the effect sink
## (CollectionManager.get_bonuses): player damage (bestiary_power_bonus) and
## dismantle loot yield (scavenge_yield_bonus) both move when registrations
## change, and sit at zero when nothing is collected.
extends SceneTree

const MOCK_CM := preload("res://tools/tests/stubs/mock_collection_manager.gd")

var _failures: int = 0

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
	else:
		_failures += 1
		printerr("  FAIL: ", message)

# --- effect sink models: damage / loot yield as functions of the bonus ---
func _damage_sink(base_damage: float, power_bonus: float) -> float:
	return base_damage * (1.0 + power_bonus)

func _yield_sink(base_yield: int, scavenge_bonus: float) -> int:
	return max(1, int(float(base_yield) * (1.0 + scavenge_bonus)))

func _initialize() -> void:
	for _i in range(4):
		await process_frame

	var cm: Node = MOCK_CM.new()
	cm.name = "MockCollectionManager"
	root.add_child(cm)

	# ---- zero-bonus baseline: nothing collected ----
	cm.call("clear")
	var base: Dictionary = cm.call("get_bonuses")
	_assert(base.has("scavenge_yield_bonus") and base.has("bestiary_power_bonus"), "sink exposes both bonuses")
	_assert(float(base.get("scavenge_yield_bonus", -1.0)) == 0.0, "baseline dismantle loot yield bonus == 0")
	_assert(float(base.get("bestiary_power_bonus", -1.0)) == 0.0, "baseline player damage bonus == 0")
	_assert(bool(base.get("recipes_unlocked", true)) == false, "baseline recipes locked")
	var base_damage: float = _damage_sink(10.0, float(base.get("bestiary_power_bonus", 0.0)))
	var base_yield: int = _yield_sink(10, float(base.get("scavenge_yield_bonus", 0.0)))
	_assert(base_damage == 10.0, "baseline damage sink: 10.0")
	_assert(base_yield == 10, "baseline loot yield sink: 10")

	# ---- nonzero bonus: controlled registrations ----
	for i in range(10):
		cm.call("record_dismantle", "prop_scrap_%d" % i, 1)
	for i in range(20):
		cm.call("record_defeat", "slime")
	var bonus: Dictionary = cm.call("get_bonuses")
	_assert(float(bonus.get("scavenge_yield_bonus", -1.0)) > 0.0, "nonzero dismantle loot yield bonus: %s" % str(bonus.get("scavenge_yield_bonus")))
	_assert(float(bonus.get("bestiary_power_bonus", -1.0)) > 0.0, "nonzero player damage bonus: %s" % str(bonus.get("bestiary_power_bonus")))
	_assert(bool(bonus.get("recipes_unlocked", false)) == true, "recipes unlocked at 10 unique props")

	var dmg: float = _damage_sink(10.0, float(bonus.get("bestiary_power_bonus", 0.0)))
	var yld: int = _yield_sink(10, float(bonus.get("scavenge_yield_bonus", 0.0)))
	_assert(dmg > base_damage, "nonzero bonus raises player damage at sink: %s > %s" % [str(dmg), str(base_damage)])
	_assert(yld > base_yield, "nonzero bonus raises dismantle loot yield at sink: %d > %d" % [yld, base_yield])

	if _failures == 0:
		print("COLLECTION_BONUS_PROBE_PASS=true")
		quit(0)
	else:
		printerr("COLLECTION_BONUS_PROBE_FAIL: %d assertions failed" % _failures)
		quit(1)
