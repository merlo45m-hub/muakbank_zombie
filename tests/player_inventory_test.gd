extends GdUnitTestSuite

## Unit tests for Player.gd's GLoot-backed food inventory public API.
##
## Grounded in the real codebase: instantiates the REAL player scene
## (scenes/characters/character_hunter.tscn, root script scripts/core/Player.gd)
## so the GLoot GootInventory child and the real
## get_food_count / get_food_heal / add_food / consume_food_type / has_food
## code paths are exercised — no mocks, no stubs.
##
## Run (Godot 4.7 headless on the VPS):
##   cd /root/muakbank_zombie
##   xvfb-run -a /root/Godot_v4.7-stable_linux.x86_64 --headless \
##       --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
##       -a res://tests --ignoreHeadlessMode
## (or ./addons/gdUnit4/runtest.sh with GODOT_BIN set)

const PLAYER_SCENE := "res://scenes/characters/character_hunter.tscn"

var _player: Node3D = null

func before_test() -> void:
	_player = load(PLAYER_SCENE).instantiate() as Node3D
	add_child(_player)
	await get_tree().process_frame

func after_test() -> void:
	if is_instance_valid(_player):
		_player.queue_free()
		_player = null
	await get_tree().process_frame

func test_fresh_player_reports_zero_for_unknown_food() -> void:
	assert_that(_player.get_food_count("pizza")).is_equal(0)
	assert_that(_player.get_food_count("nonexistent_food")).is_equal(0)
	assert_that(_player.get_food_heal("nonexistent_food")).is_equal(0)
	assert_that(_player.has_food("pizza")).is_false()

func test_add_food_increments_count_and_remembers_heal() -> void:
	_player.add_food("pizza", 25)
	assert_that(_player.get_food_count("pizza")).is_equal(1)
	assert_that(_player.get_food_heal("pizza")).is_equal(25)

	# A second pickup of the same type stacks into the same GLoot item.
	_player.add_food("pizza", 25)
	assert_that(_player.get_food_count("pizza")).is_equal(2)
	assert_that(_player.get_food_heal("pizza")).is_equal(25)

	# Different types stay distinct inventory items.
	_player.add_food("burger", 35)
	assert_that(_player.get_food_count("burger")).is_equal(1)
	assert_that(_player.get_food_heal("burger")).is_equal(35)
	assert_that(_player.get_food_count("pizza")).is_equal(2)
	assert_that(_player.has_food("pizza")).is_true()
	assert_that(_player.has_food("medkit")).is_false()

func test_consume_food_type_decrements_and_removes_empty_stack() -> void:
	_player.add_food("soda", 15)
	_player.add_food("soda", 15)
	assert_that(_player.consume_food_type("soda")).is_true()
	assert_that(_player.get_food_count("soda")).is_equal(1)
	assert_that(_player.consume_food_type("soda")).is_true()
	# Stack exhausted: item removed, count back to 0.
	assert_that(_player.get_food_count("soda")).is_equal(0)
	assert_that(_player.has_food("soda")).is_false()
	# Consuming an empty or unknown type returns false (no crash).
	assert_that(_player.consume_food_type("soda")).is_false()
	assert_that(_player.consume_food_type("takis")).is_false()

func test_heal_amount_used_by_game_consume_roundtrips() -> void:
	# Game.gd consume_food() reads get_food_heal() to heal the player, so the
	# heal value stored at pickup must survive unmutated for later use.
	_player.add_food("medkit", 50)
	assert_that(_player.get_food_heal("medkit")).is_equal(50)
	_player.add_food("fries", 12)
	assert_that(_player.get_food_heal("fries")).is_equal(12)
	_player.consume_food_type("fries")
	assert_that(_player.get_food_heal("fries")).is_equal(0)
	assert_that(_player.get_food_count("fries")).is_equal(0)
