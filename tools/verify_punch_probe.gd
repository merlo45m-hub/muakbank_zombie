extends Node

# =============================================================================
# Punch verification — catches BOTH failure modes of the "flop" bug.
# =============================================================================
#
# The first version of this probe passed while the game still flopped, because it
# only checked ProceduralAnimator._lunge_active. There were TWO independent flop
# sources and it tested one:
#
#   1. ProceduralAnimator.trigger_attack() -> the zombie pounce curve.
#      (fixed; still asserted here as a regression guard)
#   2. Player._trigger_attack_feedback() tweened _visual_root().rotation:x by
#      45 degrees — pitching the ENTIRE character model, not a weapon. This is
#      the one the player actually saw. (fixed by removing the tween)
#
# It also missed a third defect: _anim_state is a single shared variable that
# _update_skeletal_anim() re-derives from speed EVERY frame, so a one-shot
# "attack" state was clobbered on the next frame before the clip could be seen.
#
# THIS probe samples across MULTIPLE frames and asserts:
#   - no lunge
#   - the character root never pitches (|rotation.x| stays ~0)
#   - the melee clip is still playing several frames AFTER the press
#   - the anim state is not immediately stomped back to idle/walk

const TAG := "PUNCH"

const SAMPLE_FRAMES := 30


func _ready() -> void:
	await get_tree().process_frame

	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout

	var player: CharacterBody3D = game.get_node_or_null("Player")
	if player == null:
		print(TAG, " FAIL no Player")
		get_tree().quit(1)
		return

	var vis: Node3D = player.get_node_or_null("PlayerVisuals")
	var anim = vis.get_node_or_null("ProceduralAnimator") if vis else null
	var sk: AnimationPlayer = player.get("_skeletal")
	var visual_root: Node3D = player.call("_visual_root")

	print(TAG, " subtype=", anim.get("_subtype") if anim else "n/a")
	print(TAG, " visual_root=", visual_root.name if visual_root else "null")

	# Baseline pitch of the character model BEFORE any input.
	var base_pitch: float = visual_root.rotation.x if visual_root else 0.0
	print(TAG, " base_pitch=", snappedf(base_pitch, 0.001))

	# Press attack exactly as the mobile button does.
	if player.has_method("_on_mobile_attack"):
		player.call("_on_mobile_attack")
	else:
		player.call("_perform_attack")

	# Sample across many frames — a one-frame sample hides the clobbering bug.
	var max_pitch: float = 0.0
	var melee_frames := 0
	var first_melee_frame := -1
	var states: Array = []
	for i in range(SAMPLE_FRAMES):
		await get_tree().physics_frame
		if visual_root != null:
			max_pitch = maxf(max_pitch, absf(visual_root.rotation.x - base_pitch))
		if anim != null and bool(anim.get("_lunge_active")):
			print(TAG, " FAIL lunge active at frame ", i)
		if sk != null and sk.current_animation == "attack-melee-right":
			melee_frames += 1
			if first_melee_frame < 0:
				first_melee_frame = i
		states.append(player.get("_anim_state"))

	print(TAG, " sampled_frames=", SAMPLE_FRAMES)
	print(TAG, " melee_clip_frames=", melee_frames, " first_at_frame=", first_melee_frame)
	print(TAG, " max_pitch_delta=", snappedf(max_pitch, 0.001),
		" (whole-body pitch; must stay ~0)")
	print(TAG, " anim_states=", states.slice(0, min(12, states.size())))

	# --- assertions ---
	var no_lunge: bool = true
	if anim != null and bool(anim.get("_lunge_active")):
		no_lunge = false
	var no_body_pitch: bool = max_pitch < 0.05
	# The clip must survive beyond a single frame, proving _anim_state is not
	# being stomped back to idle/walk by _update_skeletal_anim().
	var clip_persists: bool = melee_frames >= 3

	var ok: bool = no_lunge and no_body_pitch and clip_persists
	var reason := ""
	if not no_lunge:
		reason += "lunge active; "
	if not no_body_pitch:
		reason += "body pitched %.3f rad (whole-model tween still present); " % max_pitch
	if not clip_persists:
		reason += "melee clip only %d frame(s) - state clobbered; " % melee_frames

	if ok:
		print(TAG, " RESULT PASS")
		get_tree().quit(0)
	else:
		print(TAG, " RESULT FAIL ", reason.strip_edges())
		get_tree().quit(1)
