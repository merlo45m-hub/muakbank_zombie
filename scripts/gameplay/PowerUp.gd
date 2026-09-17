extends Area3D
class_name PowerUp

## PowerUp — Collectible power-up pickup
## Attach to Area3D root. Player walks over to collect.

signal collected(powerup_type)

@export var powerup_type: String = "health"  # health, speed, damage, shield, frenzy
@export var bob_height: float = 0.3
@export var bob_speed: float = 2.0
@export var rotate_speed: float = 2.0

var base_y: float = 0.0
var collected_flag: bool = false

@onready var mesh: MeshInstance3D = $Mesh
@onready var collision: CollisionShape3D = $Collision

func _ready() -> void:
	base_y = position.y
	add_to_group("powerup")
	body_entered.connect(_on_body_entered)
	_apply_type_visual()

func _process(delta: float) -> void:
	# Bob up and down
	position.y = base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	# Rotate
	rotation.y += rotate_speed * delta

func _apply_type_visual() -> void:
	if not mesh:
		return
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	match powerup_type:
		"health":
			mat.albedo_color = Color(0.2, 0.9, 0.3)
			mat.emission = Color(0.2, 0.9, 0.3)
		"speed":
			mat.albedo_color = Color(0.2, 0.5, 0.9)
			mat.emission = Color(0.2, 0.5, 0.9)
		"damage":
			mat.albedo_color = Color(0.9, 0.3, 0.2)
			mat.emission = Color(0.9, 0.3, 0.2)
		"shield":
			mat.albedo_color = Color(0.9, 0.8, 0.2)
			mat.emission = Color(0.9, 0.8, 0.2)
		"frenzy":
			mat.albedo_color = Color(0.8, 0.2, 0.8)
			mat.emission = Color(0.8, 0.2, 0.8)
	mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if collected_flag or not body.is_in_group("player"):
		return
	collected_flag = true
	collected.emit(powerup_type)
	queue_free()
