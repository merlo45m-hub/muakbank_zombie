extends GdUnitTestSuite

## Sole-writer contract: CollectionManager persists collection / museum /
## bestiary state only through SaveManager's coercing setter (set_registry),
## never by mutating save_data directly.

const SAVE_PATH := "/root/Save"
const COLLECTION_PATH := "/root/CollectionManager"

var _save: Node = null
var _cm: Node = null

func before_test() -> void:
	_save = get_node_or_null(SAVE_PATH)
	assert_that(_save).is_not_null()
	_cm = get_node_or_null(COLLECTION_PATH)
	assert_that(_cm).is_not_null()
	_save.call("reset_progress")
	await get_tree().process_frame

func after_test() -> void:
	if is_instance_valid(_save):
		_save.call("reset_progress")
	await get_tree().process_frame

func test_collection_manager_writes_flow_through_save_manager_coercion() -> void:
	# Registry keys start at their coerced defaults.
	assert_that(_save.call("get_registry", "collection_items")).is_equal({})
	assert_that(_save.call("get_registry", "collection_regions")).is_equal({})
	assert_that(_save.call("get_registry", "museum_seen")).is_equal([])
	assert_that(_save.call("get_registry", "dismantled_props")).is_equal({})
	assert_that(_save.call("get_registry", "bestiary")).is_equal({})
	assert_that(_save.call("get_registry", "museum_version")).is_equal(2)

	# Sole-writer path: CollectionManager records.
	_cm.call("record_item", "scrap_plate", 3)
	_cm.call("record_dismantle", "prop_barrel", 1)
	_cm.call("record_defeat", "zombie_scavenger")

	# Reading via SaveManager's getter returns the coerced value.
	var items: Dictionary = _save.call("get_registry", "collection_items")
	assert_that(items).is_equal({"scrap_plate": 3})
	assert_that(items.get("scrap_plate")).is_equal(3)

	var seen: Array = _save.call("get_registry", "museum_seen")
	assert_that(seen).is_equal(["scrap_plate"])

	var props: Dictionary = _save.call("get_registry", "dismantled_props")
	assert_that(props.get("prop_barrel").get("qty")).is_equal(1)

	var bestiary: Dictionary = _save.call("get_registry", "bestiary")
	assert_that(bestiary.get("zombie_scavenger").get("kills")).is_equal(1)

	assert_that(_save.call("get_registry", "museum_version")).is_equal(2)
	assert_that((_save.call("get_registry", "museum_version") is int)).is_true()

	# The in-memory save_data holds the coerced value — no raw bypass mutation.
	var save_data: Dictionary = _save.get("save_data")
	assert_that(save_data.get("collection_items")).is_equal(items)
	assert_that(save_data.get("museum_version")).is_equal(2)
	assert_that((save_data.get("museum_version") is int)).is_true()
