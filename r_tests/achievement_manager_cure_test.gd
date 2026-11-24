extends GdUnitTestSuite

# AchievementManager — cure synthesis gate (GDD §5, §7 / Issue #28).
# Places a CollectionManager at /root/CollectionManager so
# AchievementManager can look it up via get_node_or_null("/root/CollectionManager").

var cm: CollectionManager
var am: AchievementManager

func before() -> void:
	var root := get_tree().root
	cm = CollectionManager.new()
	cm.name = "CollectionManager"
	root.add_child(cm)
	am = AchievementManager.new()
	add_child(am)

func after() -> void:
	if am:
		am.queue_free()
	am = null
	if cm:
		cm.queue_free()
	cm = null

func _register_world_one_achievements() -> void:
	for id in ["kill_10_zombies", "dismantle_5_props", "survive_night"]:
		am.register_achievement(id, id, "desc", 1)

func test_cure_gate_requires_all_world_bosses() -> void:
	_register_world_one_achievements()
	for id in ["kill_10_zombies", "dismantle_5_props", "survive_night"]:
		am.unlock(id)  # majority 3/3
	cm.record_item("catalyst_suburban", 1)
	cm.record_item("catalyst_industrial", 1)
	cm.record_item("catalyst_biolab", 1)
	am.world_bosses_defeated = {1: true, 2: true, 3: false}
	assert_that(am.can_synthesize_cure()).is_equal(false)
	assert_that(am.synthesize_cure()).is_equal(false)
	assert_that(am.is_post_cure()).is_equal(false)

func test_cure_gate_requires_majority_achievements() -> void:
	cm.record_item("catalyst_suburban", 1)
	cm.record_item("catalyst_industrial", 1)
	cm.record_item("catalyst_biolab", 1)
	am.world_bosses_defeated = {1: true, 2: true, 3: true}
	assert_that(am.has_majority_achievements()).is_equal(false)
	assert_that(am.can_synthesize_cure()).is_equal(false)

func test_cure_gate_requires_all_catalysts() -> void:
	_register_world_one_achievements()
	for id in ["kill_10_zombies", "dismantle_5_props", "survive_night"]:
		am.unlock(id)
	am.world_bosses_defeated = {1: true, 2: true, 3: true}
	cm.record_item("catalyst_suburban", 1)
	cm.record_item("catalyst_industrial", 1)
	# catalyst_biolab missing
	assert_that(am.can_synthesize_cure()).is_equal(false)

func test_cure_synthesize_consumes_catalysts_and_enters_post_cure() -> void:
	_register_world_one_achievements()
	for id in ["kill_10_zombies", "dismantle_5_props", "survive_night"]:
		am.unlock(id)
	am.world_bosses_defeated = {1: true, 2: true, 3: true}
	cm.record_item("catalyst_suburban", 1)
	cm.record_item("catalyst_industrial", 1)
	cm.record_item("catalyst_biolab", 1)
	assert_that(am.synthesize_cure()).is_equal(true)
	assert_that(am.is_post_cure()).is_equal(true)
	assert_that(am.is_unlocked("cure_synthesized")).is_equal(true)
	assert_that(cm.get_items().has("catalyst_suburban")).is_equal(false)
	assert_that(cm.get_items().has("catalyst_industrial")).is_equal(false)
	assert_that(cm.get_items().has("catalyst_biolab")).is_equal(false)

func test_synthesize_cure_is_idempotent() -> void:
	_register_world_one_achievements()
	for id in ["kill_10_zombies", "dismantle_5_props", "survive_night"]:
		am.unlock(id)
	am.world_bosses_defeated = {1: true, 2: true, 3: true}
	cm.record_item("catalyst_suburban", 1)
	cm.record_item("catalyst_industrial", 1)
	cm.record_item("catalyst_biolab", 1)
	assert_that(am.synthesize_cure()).is_equal(true)
	assert_that(am.synthesize_cure()).is_equal(true)
	assert_that(am.is_post_cure()).is_equal(true)
