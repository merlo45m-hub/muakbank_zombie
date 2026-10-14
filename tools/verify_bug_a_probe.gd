extends Node

# Bug A verification — "punch = flop".
# Instantiates the REAL game scene (so project autoloads like `Audio` resolve and
# ProceduralAnimator.gd compiles), then drives the player's attack and inspects
# the animator. Runs headless; nothing here mutates project state.
#
# An earlier version used `--script` with a SceneTree. Under --script autoloads
# are NOT registered, so the bare `Audio` reference inside ProceduralAnimator
# failed to compile, ProceduralAnimator resolved to null, and the probe silently
# timed out without ever exercising the fix. This version avoids that trap.

const TAG := "BUG_A"


func _ready() -> void:
	await get_tree().process_frame
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout

	var player: CharacterBody3D = game.get_node_or_null("Player")
	if player == null:
		print(TAG, " FAIL no Player node")
		get_tree().quit(1)
		return

	var vis := player.get_node_or_null("PlayerVisuals")
	var anim = vis.get_node_or_null("ProceduralAnimator") if vis else null

	print(TAG, " in_group_player=", player.is_in_group("player"))
	print(TAG, " animator_present=", anim != null)
	print(TAG, " animator_process_enabled=", anim.is_processing() if anim else "n/a")

	if anim == null:
		print(TAG, " FAIL no animator on the player")
		get_tree().quit(1)
		return

	# Inspect the real subtype the animator resolved for the player body.
	var subtype: Variant = anim.get("_subtype")
	print(TAG, " subtype=", subtype)
	print(TAG, " lunge_active_before=", anim.get("_lunge_active"))

	# Drive the player attack exactly as the mobile button does.
	# NOTE: start sampling on the SAME frame as the attack. attack-melee-right is
	# a ~0.5s non-looping clip; the earlier revision sampled AFTER a 40-frame poll
	# loop, by which time the clip had already played and returned to idle, so it
	# reported false and proved nothing about the punch path.
	var saw_melee: bool = false
	var anim_state_seen: Variant = null
	var sk = player.get("_skeletal")
	var animator_ref = anim
	var lunge_during: bool = false

	if player.has_method("_on_mobile_attack"):
		player.call("_on_mobile_attack")
	else:
		player.call("_perform_attack")

	# Sample from the first frame of the swing.
	for i in range(45):
		await get_tree().physics_frame
		if bool(animator_ref.get("_lunge_active")):
			lunge_during = true
		if sk != null and (sk as AnimationPlayer).current_animation == "attack-melee-right":
			saw_melee = true
			anim_state_seen = player.get("_anim_state")

	print(TAG, " lunge_active_during_attack=", lunge_during)
	print(TAG, " melee_clip_seen_during_swing=", saw_melee,
		" _anim_state_during=", anim_state_seen)

	# Flop signal: the zombie pounce moves the body forward (pos.z) and
	# pitches it (rot.x). A punch must produce neither.
	var apos: Vector3 = anim.position
	var arot: Vector3 = anim.rotation
	print(TAG, " anim pos=", apos.snappedf(0.0001), " rot=", arot.snappedf(0.0001))

	var no_flop: bool = (not lunge_during) and absf(apos.z) < 0.02 and absf(arot.x) < 0.02
	print(TAG, " RESULT ", "PASS" if no_flop else "FAIL")
	get_tree().quit(0 if no_flop else 1)
