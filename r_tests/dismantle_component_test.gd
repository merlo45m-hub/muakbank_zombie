extends GdUnitTestSuite

# DismantleComponent — tool-tier gate and loot descriptor (GDD §2 / §7).
# Stateless driver: tier gate is a pure no-op below required_tool_tier;
# loot_descriptor reports the rolled loot array.

var dc: DismantleComponent

func before() -> void:
	dc = DismantleComponent.new()
	add_child(dc)

func after() -> void:
	if dc:
		dc.queue_free()
	dc = null

func test_can_dismantle_rejects_below_tier() -> void:
	dc.required_tool_tier = 3
	assert_that(dc.can_dismantle(0)).is_equal(false)
	assert_that(dc.can_dismantle(1)).is_equal(false)
	assert_that(dc.can_dismantle(2)).is_equal(false)
	assert_that(dc.can_dismantle(3)).is_equal(true)

func test_apply_damage_below_tier_is_noop_clink() -> void:
	dc.required_tool_tier = 2
	dc.hitpoints = 100.0
	assert_that(dc.apply_damage(50.0, 1)).is_equal(false)
	assert_that(dc.current_hp()).is_equal(100.0)
	assert_that(dc.is_depleted()).is_equal(false)

func test_apply_damage_at_tier_applies_damage() -> void:
	dc.required_tool_tier = 2
	dc.hitpoints = 100.0
	assert_that(dc.apply_damage(40.0, 2)).is_equal(true)
	assert_that(dc.current_hp()).is_equal(60.0)
	assert_that(dc.is_depleted()).is_equal(false)

func test_loot_descriptor_defaults_to_empty_array() -> void:
	assert_that(dc.loot_descriptor()).is_equal([])
	assert_that(typeof(dc.loot_descriptor())).is_equal(TYPE_ARRAY)
