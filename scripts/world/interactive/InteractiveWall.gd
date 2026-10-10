extends Node3D
class_name InteractiveWall

## Interactive Wall — Single-shot punch reaction: flash + ripple + impact sound.
## The wall is a StaticBody3D with a BoxMesh. Punching it runs a brief scaled
## animation (squash-stretch) and plays impact audio. No damage is applied to the
## player for punching a wall — it is a feedback prop, not a hazard.

@export var punch_flash_duration: float = 0.25              # seconds the flash material is visible
@export var punch_scale_amp: float = 0.12                   # scale.y dip on impact (squash)
@export var impact_sound: StringName = "wall_impact"
@export var flash_material_override: StandardMaterial3D = null  # optional: bright flash mat

# State
var is_punching: bool = false
var flash_timer: float = 0.0
var original_material: Material = null
var mesh_node: MeshInstance3D = null
var body_node: StaticBody3D = null

# HitFeedback ref for spark particles
var hit_feedback: HitFeedback = null

func _ready() -> void:
	add_to_group("interactive_prop")
	mesh_node = get_node_or_null("Mesh")  # the BoxMesh visual
	body_node = get_node_or_null("Collision") or get_node_or_null("Body")  # StaticBody3D
	# Discover HitFeedback from the level
	hit_feedback = get_tree().get_first_node_in_group("hit_feedback")
	if not hit_feedback:
		# Try direct path from scene root
		hit_feedback = get_node_or_null("/root/HitFeedback") if has_node("/root/HitFeedback") else null

	# Store original material
	if mesh_node:
		original_material = mesh_node.material_override

	# Resolve impact sound
	if Audio:
		impact_sound = "wall_impact" if Audio.has_sound("wall_impact") else ""

# ── PUNCH (called by player interaction) ────────────────────────────────────────

## Punch the wall. Safe to call from anywhere.
func interact() -> void:
	punch()

func punch() -> void:
	if is_punching:
		return
	is_punching = true
	flash_timer = punch_flash_duration

	# Scale animation: quick squash via tween on this node's scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Squash: shrink Y, expand X/Z
	tween.tween_property(self, "scale:y", 1.0 - punch_scale_amp, 0.08)
	tween.tween_property(self, "scale:x", 1.0 + punch_scale_amp * 0.5, 0.08)
	tween.tween_property(self, "scale:z", 1.0 + punch_scale_amp * 0.5, 0.08)
	# Recover
	tween.tween_property(self, "scale:y", 1.0, 0.20)
	tween.tween_property(self, "scale:x", 1.0, 0.20).set_delay(0.08)
	tween.tween_property(self, "scale:z", 1.0, 0.20).set_delay(0.08)
	tween.tween_callback(func(): is_punching = false)

	# Flash material
	if mesh_node and flash_material_override:
		mesh_node.material_override = flash_material_override

	# Spark particles
	if hit_feedback and hit_feedback.has_method("emit_spark"):
		hit_feedback.emit_spark(global_transform.origin + Vector3(0, 1.2, 0))

	# Impact sound
	_play_impact_sound()

	# Input haptics
	Input.vibrate_handheld(20)

# ── PROCESS (flash decay) ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			# Restore original material
			if mesh_node:
				mesh_node.material_override = original_material
			flash_timer = 0.0

# ── AUDIO ────────────────────────────────────────────────────────────────────────

func _play_impact_sound() -> void:
	if Audio and impact_sound != "":
		Audio.play_sound(impact_sound)
