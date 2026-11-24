extends GdUnitTestSuite

# CollectionManager — record_item / consume_item (GDD-2 registries).
# The suite runs headless without /root/Save or /root/WorldProgression, so
# _load / _persist resolve to a null Save and become no-ops; the in-memory
# registry is still exercised end-to-end.

var cm: CollectionManager

func before() -> void:
	cm = CollectionManager.new()

func after() -> void:
	if cm:
		cm.queue_free()
	cm = null

func test_record_item_increments_quantity() -> void:
	cm.record_item("catalyst_suburban", 1)
	assert_that(cm.is_seen("catalyst_suburban")).is_equal(true)
	assert_that(int(cm.get_items().get("catalyst_suburban", 0))).is_equal(1)
	cm.record_item("catalyst_suburban", 2)
	assert_that(int(cm.get_items().get("catalyst_suburban", 0))).is_equal(3)

func test_record_item_ignores_empty_id() -> void:
	var before := cm.get_items().duplicate()
	cm.record_item("", 5)
	assert_that(cm.get_items()).is_equal(before)

func test_consume_item_decrements_and_returns_true() -> void:
	cm.record_item("catalyst_industrial", 4)
	assert_that(cm.consume_item("catalyst_industrial", 2)).is_equal(true)
	assert_that(int(cm.get_items().get("catalyst_industrial", 0))).is_equal(2)

func test_consume_item_removes_when_depleted() -> void:
	cm.record_item("catalyst_biolab", 1)
	assert_that(cm.consume_item("catalyst_biolab", 1)).is_equal(true)
	assert_that(cm.get_items().has("catalyst_biolab")).is_equal(false)

func test_consume_item_returns_false_when_insufficient() -> void:
	cm.record_item("catalyst_suburban", 1)
	assert_that(cm.consume_item("catalyst_suburban", 5)).is_equal(false)
	assert_that(int(cm.get_items().get("catalyst_suburban", 0))).is_equal(1)

func test_consume_item_rejects_invalid_args() -> void:
	assert_that(cm.consume_item("", 1)).is_equal(false)
	assert_that(cm.consume_item("catalyst_suburban", 0)).is_equal(false)
	assert_that(cm.consume_item("catalyst_suburban", -1)).is_equal(false)
