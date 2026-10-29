extends Node3D
class_name Interactor

## Interactor — Player-side interaction dispatcher.
## Attached to the player. On attack button press (desktop or mobile), checks
## whether the player is near an interactive prop and routes the input to it.
##
## Priority: if the player is in melee range of an enemy, attack normally.
## Otherwise, if near an interactive prop, trigger its interaction.
## This keeps combat working while enabling prop interaction in the same button.

signal interacted_with(prop: Node3D)

# Config
@export var interact_range: float = 3.0                  # max distance to trigger prop
@export var interact_priority_prop: String = "door"      # prefer door over wall when both near

# Cached refs
var player_body: CharacterBody3D = null
var hit_feedback: HitFeedback = null

func _ready() -> void:
	player_body = get_parent() if get_parent() is CharacterBody3D else null
	# Find HitFeedback from the scene
	hit_feedback = get_tree().get_first_node_in_group("hit_feedback")
	if not hit_feedback:
		hit_feedback = get_node_or_null("/root/HitFeedback")

# ── PUBLIC API ──────────────────────────────────────────────────────────────────

## Called by Player._handle_attack when the player presses attack.
## Returns true if the interaction was consumed by a prop (no combat this press).
func try_interact() -> bool:
	if not player_body or not is_inside_tree():
		return false

	# Find nearest interactive prop
	var nearest := _find_nearest_interactive_prop()
	if not nearest:
		return false

	# Route to prop's interaction method
	if nearest.has_method("interact"):
		nearest.interact()
		interacted_with.emit(nearest)
		# HitFeedback tap for interaction feedback
		if hit_feedback and hit_feedback.has_method("emit_pickup"):
			hit_feedback.emit_pickup(nearest.global_transform.origin)
		Input.vibrate_handheld(12)
		return true

	if nearest.has_method("process_capture"):
		nearest.process_capture(0.0)
		return true

	if nearest.has_method("seal_tick"):
		nearest.seal_tick(0.0)
		return true

	# Fallback: if prop has a generic trigger method
	if nearest.has_method("trigger"):
		nearest.trigger()
		return true

	return false

# ── PROP FINDING ────────────────────────────────────────────────────────────────

func _find_nearest_interactive_prop() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = interact_range
	var player_pos := player_body.global_transform.origin if player_body else global_transform.origin

	for prop in get_tree().get_nodes_in_group("interactive_prop"):
		if not prop.is_inside_tree() or not is_instance_valid(prop):
			continue
		# Check if prop has an interaction zone the player is inside
		var zone: Area3D = null
		for child in prop.get_children():
			if child is Area3D and str(child.name).contains("InteractionZone"):
				zone = child
				break
		var check_pos: Vector3 = zone.global_transform.origin if zone != null else prop.global_transform.origin
		var dist := player_pos.distance_to(check_pos)
		var player_in_zone := false
		if zone:
			var overlapping: Array[Node3D] = zone.get_overlapping_bodies()
			for body in overlapping:
				if body.is_in_group("player"):
					player_in_zone = true
					break
			if not player_in_zone and dist <= 3.5:
				player_in_zone = true
			if not player_in_zone:
				continue
		elif dist > nearest_dist:
			continue

		# Found a candidate
		if nearest == null or dist < nearest_dist:
			nearest = prop
			nearest_dist = dist

	return nearest

# ── WALL PUNCH (called separately — wall needs a dedicated punch, not generic interact)

## Called when the player punches a wall specifically.
func punch_wall(wall: Node3D) -> void:
	if wall.has_method("punch"):
		wall.punch()
		interacted_with.emit(wall)
