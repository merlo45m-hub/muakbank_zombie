## addon_probe.gd — headless verification that:
##  (a) the player's food inventory is GLoot-backed (create Player, add food,
##      assert counts + consume), and
##  (b) the Dialogue Manager resource loads without parse error.
## Run: xvfb-run godot --headless --path /root/muakbank_zombie res://tools/addon_probe.tscn
extends Node

const PLAYER_GROUP := "player"

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var failures: Array[String] = []

	# ---- PHASE A: GLoot inventory via the real Player scene ----
	var player: Node = null
	for scene_root in get_tree().get_nodes_in_group("player"):
		player = scene_root
		break
	if player == null:
		player = $Player

	if player == null or not player.has_method("add_food"):
		print("PROBE_RESULT: FAIL player not present or lacks add_food")
		get_tree().quit(1)
		return

	print("PROBE: player class = ", player.get_class())
	print("PROBE: player has GootInventory child = ", player.get_node_or_null("GootInventory") != null)
	var inv: Node = player.get_node_or_null("GootInventory")
	print("PROBE: GootInventory node type = ", inv.get_class() if inv else "NONE")

	var started: int = player.get_food_count("pizza")
	player.add_food("pizza", 25)
	var after_add: int = player.get_food_count("pizza")
	print("PROBE: pizza count %d -> %d (add_food(25))" % [started, after_add])
	if after_add != started + 1:
		failures.append("add_food did not increment — GLoot-backed inventory not wired")

	# Second stack should merge into the same item, keeping heal=25.
	player.add_food("pizza", 25)
	var after_add2: int = player.get_food_count("pizza")
	print("PROBE: pizza count after 2nd add = ", after_add2)
	if after_add2 != started + 3 and after_add2 != started + 2:
		failures.append("double add gave unexpected count: %d" % after_add2)

	var heal: int = player.get_food_heal("pizza")
	print("PROBE: pizza heal = ", heal)
	if heal != 25:
		failures.append("get_food_heal returned %d, expected 25" % heal)

	if not player.has_food("pizza"):
		failures.append("has_food returned false after adding")

	# A brand-new type (no bacon in a fresh game) must report 0.
	print("PROBE: bacon count (fresh) = ", player.get_food_count("bacon"))
	if player.get_food_count("bacon") != 0:
		failures.append("unknown food type reported non-zero count")

	# Consume one.
	var consumed: bool = player.consume_food_type("pizza")
	var after_consume: int = player.get_food_count("pizza")
	print("PROBE: consume_food_type(pizza) = ", consumed, " -> remaining ", after_consume)
	if not consumed:
		failures.append("consume_food_type returned false on existing stock")
	if after_consume != after_add2 - 1:
		failures.append("consume_food_type did not decrement")

	# ---- PHASE B: Dialogue resource loads + parses ----
	var res_path := "res://resources/dialogue/tutorial_intro.dialogue"
	var dlg: Resource = load(res_path)
	if dlg == null:
		print("PROBE: FAIL dialogue resource did not load")
		get_tree().quit(1)
		return
	var is_dialogue: bool = dlg is DialogueResource
	print("PROBE: dialogue loaded, is DialogueResource = ", is_dialogue)
	if not is_dialogue:
		failures.append("res://resources/dialogue/tutorial_intro.dialogue is not a DialogueResource")
	else:
		var dr := dlg as DialogueResource
		print("PROBE: dialogue first_cue = ", dr.first_cue)
		print("PROBE: dialogue cue_count = ", dr.get_cues().size())
		print("PROBE: dialogue line_count = ", dr.lines.size())
		if dr.lines.is_empty():
			failures.append("dialogue resource has zero compiled lines (parse produced nothing)")
		if dr.first_cue.is_empty():
			failures.append("dialogue resource has no first_cue")

	# ---- Also verify the Tutorial autoload + balloon class exist ----
	var has_autoload: bool = get_node_or_null("/root/Tutorial") != null
	print("PROBE: /root/Tutorial autoload present = ", has_autoload)
	var balloon_ok: bool = ResourceLoader.exists("res://scenes/ui/tutorial_dialogue.tscn")
	print("PROBE: tutorial_dialogue.tscn exists = ", balloon_ok)
	print("PROBE: TutorialDialogue class script exists = ", "TutorialDialogue" in ClassDB.get_class_list() or ResourceLoader.exists("res://scripts/ui/tutorial_dialogue.gd"))

	if failures.is_empty():
		print("PROBE_RESULT: PASS")
		get_tree().quit(0)
	else:
		print("PROBE_RESULT: FAIL")
		for f in failures:
			print("  FAIL: ", f)
		get_tree().quit(1)
