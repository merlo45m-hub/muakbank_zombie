extends GdUnitTestSuite

# SaveSchema — field typing at the load/store boundary (GDD save schema).
# Pure static API; no scene tree or Save node required.

func test_deserialize_types_and_defaults() -> void:
	var raw := {
		"post_cure": "yes",
		"world_bosses_defeated": {"1": true, "2": false},
		"not_a_schema_field": 1234,
	}
	var out := SaveSchema.deserialize(raw)
	assert_that(out.get("post_cure")).is_equal("yes")
	# unknown key dropped
	assert_that(out.has("not_a_schema_field")).is_equal(false)
	# missing key returns its declared default
	assert_that(out.get("post_cure") == "yes").is_equal(true)
	assert_that(out.get("version")).is_equal(7)
	assert_that(out.get("high_score")).is_equal(0)

func test_deserialize_dict_int_bool_normalizes_keys() -> void:
	var raw := {"world_bosses_defeated": {"1": true, "2": false, "3": true}}
	var out := SaveSchema.deserialize(raw)
	var wb := out.get("world_bosses_defeated")
	assert_that(typeof(wb)).is_equal(TYPE_DICTIONARY)
	assert_that(wb.has(1)).is_equal(true)
	assert_that(wb.has(2)).is_equal(true)
	assert_that(wb.has(3)).is_equal(true)
	assert_that(wb.has("1")).is_equal(false)  # string key normalized to int
	assert_that(wb.get(1)).is_equal(true)
	assert_that(wb.get(2)).is_equal(false)

func test_deserialize_array_int_coerces_elements() -> void:
	var raw := {"unlocked_levels": [1, "2", 3.0]}
	var out := SaveSchema.deserialize(raw)
	var levels := out.get("unlocked_levels")
	assert_that(typeof(levels)).is_equal(TYPE_ARRAY)
	assert_that(levels.size()).is_equal(3)
	assert_that(int(levels[0])).is_equal(1)
	assert_that(int(levels[1])).is_equal(2)
	assert_that(int(levels[2])).is_equal(3)

func test_serialize_round_trip_keeps_typed_values() -> void:
	var data := SaveSchema.get_defaults()
	data["post_cure"] = true
	data["high_score"] = 42
	var ser := SaveSchema.serialize(data)
	assert_that(ser.get("post_cure")).is_equal(true)
	assert_that(ser.get("high_score")).is_equal(42)
	assert_that(ser.get("version")).is_equal(7)

func test_get_all_keys_covers_declared_fields() -> void:
	var keys := SaveSchema.get_all_keys()
	assert_that(keys.size() > 0).is_equal(true)
	assert_that(keys.has("post_cure")).is_equal(true)
	assert_that(keys.has("world_bosses_defeated")).is_equal(true)
	assert_that(keys.has("selected_character")).is_equal(true)
