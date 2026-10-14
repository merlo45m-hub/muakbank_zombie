extends SceneTree

# Muakbank Zombie logic tests (headless-godot-skill-kit harness).
#
# The kit ships a template harness that asserts against ITS starter project
# (res://main.tscn plus a metrics_tracker API). This project's entry scene is
# res://scenes/main/title_screen.tscn and has no metrics tracker, so the stock
# harness fails on arrival. The unmodified kit version is kept alongside this
# file as run_tests_kit_template.gd for reference.
#
# Run via: tools/hgs_run.sh test

const MAIN_SCENE := "res://scenes/main/title_screen.tscn"

var _failures: int = 0
var _checks: int = 0


func _assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  ", message)
	else:
		_failures += 1
		printerr("  FAIL  ", message)


func _initialize() -> void:
	print("=== Muakbank Zombie logic tests ===")

	# --- 1. The project's entry scene must load and instantiate -------------
	var packed := load(MAIN_SCENE) as PackedScene
	_assert_true(packed != null, "entry scene loads as PackedScene (%s)" % MAIN_SCENE)
	if packed == null:
		_finish()
		return

	var game: Node = packed.instantiate()
	_assert_true(game != null, "entry scene instantiates")

	# --- 2. Autoloads the game depends on must be DECLARED -----------------
	# Checked against project.godot's [autoload] block rather than /root/<name>,
	# because a SceneTree script runs with autoloads UNREGISTERED — they are only
	# wired when a real game loop boots (verified: [GameAudioManager] Ready appears
	# in a normal run but /root/Audio is null under --script). Asserting on /root
	# here would report a false failure for a perfectly healthy project.
	var cfg := ConfigFile.new()
	var cfg_err := cfg.load("res://project.godot")
	_assert_true(cfg_err == OK, "project.godot parses")
	_assert_true(cfg.has_section("autoload"), "[autoload] section exists")
	# Autoload entries are KEYS inside the [autoload] section, so read them by
	# name rather than asking for a single value under the section.
	for singleton in ["Audio", "Save", "Level", "SceneManager"]:
		_assert_true(cfg.has_section_key("autoload", singleton),
			"autoload declared in project.godot: %s" % singleton)

	# --- 3. The entry scene must actually enter the tree cleanly ------------
	# Adding it to the live root runs _ready, which is where autoload misuse and
	# broken node references surface. If this throws, the game cannot boot.
	if game != null:
		root.add_child(game)
		await process_frame
		await process_frame
		_assert_true(game.is_inside_tree(), "entry scene stays in the tree after 2 frames")

	# --- 4. The level scene must load (the one the whole loop edits) --------
	var level := load("res://scenes/world/environment/old_town_enhanced.tscn") as PackedScene
	_assert_true(level != null, "Level 1 (old_town_enhanced) loads as PackedScene")

	# --- 5. The mini-game scenes must load ---------------------------------
	for mg in [
		"res://scenes/minigames/spoil_and_survive.tscn",
		"res://scenes/minigames/keep_generator_fed.tscn",
	]:
		var s := load(mg) as PackedScene
		_assert_true(s != null, "mini-game scene loads: %s" % mg.get_file())

	_finish()


func _finish() -> void:
	print("=== %d checks, %d failed ===" % [_checks, _failures])
	if _failures > 0:
		print("tests failed: %d" % _failures)
		quit(1)
	else:
		print("tests passed")
		quit(0)
