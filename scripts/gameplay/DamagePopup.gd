extends Node3D
class_name DamagePopup

## DamagePopup — Floating damage numbers
## Spawn a popup at a 3D position showing damage dealt.

@export var popup_scene: PackedScene = null
@export var popup_lifetime: float = 0.8
@export var popup_rise_speed: float = 2.0

func spawn_damage(amount: int, world_pos: Vector3, is_critical: bool = false) -> void:
	var label = Label3D.new()
	label.text = str(amount)
	label.font_size = 24 if not is_critical else 36
	label.modulate = Color(1, 0.9, 0.2) if is_critical else Color(1, 1, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = world_pos
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", world_pos.y + 1.5, popup_lifetime)
	tween.parallel().tween_property(label, "modulate:a", 0.0, popup_lifetime)
	tween.tween_callback(label.queue_free)
