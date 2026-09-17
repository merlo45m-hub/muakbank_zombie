extends Area3D
class_name WeaponPickup

## WeaponPickup — Collectible weapon pickup
## Attach to Area3D root. Player walks over to collect the weapon.

signal picked_up(weapon_id)

@export var weapon_id: String = "bat"
@export var bob_height: float = 0.25
@export var bob_speed: float = 2.0
@export var rotate_speed: float = 1.5

var base_y: float = 0.0
var taken: bool = false

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	base_y = position.y
	add_to_group("weapon")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position.y = base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	rotation.y += rotate_speed * delta

func _on_body_entered(body: Node3D) -> void:
	if taken or not body.is_in_group("player"):
		return
	taken = true
	picked_up.emit(weapon_id)
	if body.has_method("equip_weapon"):
		body.equip_weapon(weapon_id)
	queue_free()
