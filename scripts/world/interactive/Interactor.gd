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
		# Skip if prop is too far
		var dist := player_pos.distance_to(prop.global_transform.origin)
		if dist > nearest_dist:
			continue
		# Check if prop has an interaction zone the player is inside
		var zone := prop.get_node_or_null("InteractionZone")
		if zone and zone.has_method("has_overlapping_bodies"):
			# Only interact if player is actually in the zone
			var overlapping := zone.get_overlapping_bodies()
			var player_in_zone := false
			for body in overlapping:
				if body.is_in_group("player"):
					player_in_zone = true
					break
			if not player_in_zone:
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
