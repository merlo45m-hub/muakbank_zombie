extends GdUnitTestSuite

## Unit tests for the mobile SPECIAL button: MobileControls.gd builds a SPECIAL
## button that emits special_pressed, and Player.gd routes that signal through the
## SAME handler the keyboard 'special' input (G key) uses in _handle_attack() —
## use_special_ability(). No mocks, no stubs.
##
## Grounded in the real codebase: instantiates the REAL player scene
## (scenes/characters/character_hunter.tscn, root script scripts/core/Player.gd)
## which embeds the real MobileControls node, so the full chain
##   special_btn.pressed -> special_pressed -> _on_mobile_special -> use_special_ability()
## is exercised end-to-end.
##
## Run (Godot 4.7 headless on the VPS):
##   cd /root/muakbank_zombie
##   xvfb-run -a /root/Godot_v4.7-stable_linux.x86_64 --headless \
##       --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
##       -a res://tests --ignoreHeadlessMode

const PLAYER_SCENE := "res://scenes/characters/character_hunter.tscn"
const CharacterStatsScript := preload("res://scripts/characters/CharacterStats.gd")

var _player: Node3D = null
var _controls: Control = null
# Member (not local) so the signal lambda mutates the real variable: GDScript
# lambdas capture enclosing LOCALS by value, so a local counter would stay 0.
var _special_signal_fired: int = 0

func before_test() -> void:
	_player = load(PLAYER_SCENE).instantiate() as Node3D
	add_child(_player)
	await get_tree().process_frame
	_controls = _player.mobile_controls

func after_test() -> void:
	if is_instance_valid(_player):
		_player.queue_free()
		_player = null
	_controls = null
	await get_tree().process_frame

## Deterministic heal ability regardless of the scene's default stats.
func _set_heal_stats() -> void:
	var stats = CharacterStatsScript.new()
	stats.special_ability = "heal"
	stats.special_cooldown = 10.0
	_player.character_stats = stats
	_player.max_health = 100
	_player.health = 50
	_player.special_timer = 0.0

func test_special_button_exists_on_mobile_controls() -> void:
	assert_that(_controls).is_not_null()
	assert_that(_controls.special_btn).is_not_null()
	assert_that(_controls.special_btn.text).is_equal("SPECIAL")
	# Mobile gate: on non-mobile platforms the whole MobileControls layer is
	# hidden in _ready(), so desktop keyboard players see no SPECIAL button
	# (same gate all the other mobile buttons already use).
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		assert_that(_controls.visible).is_false()

func test_special_button_press_runs_player_special_handler() -> void:
	_set_heal_stats()
	_controls.special_btn.pressed.emit()
	# use_special_ability() "heal" branch: +50 HP and the cooldown armed — the
	# same effect the keyboard G key produces via _handle_attack().
	assert_that(_player.health).is_equal(100)
	assert_that(_player.special_timer).is_equal(10.0)

func test_special_button_obeys_cooldown_like_keyboard() -> void:
	_set_heal_stats()
	_controls.special_btn.pressed.emit()
	var health_after_first: int = _player.health
	_controls.special_btn.pressed.emit()
	# Second press while the cooldown is armed is a no-op, exactly like keyboard.
	assert_that(_player.health).is_equal(health_after_first)
	assert_that(_player.special_timer).is_equal(10.0)

func test_special_signal_emitted_on_button_press() -> void:
	_set_heal_stats()
	_special_signal_fired = 0
	_controls.special_pressed.connect(func() -> void: _special_signal_fired += 1)
	_controls.special_btn.pressed.emit()
	assert_that(_special_signal_fired).is_equal(1)
