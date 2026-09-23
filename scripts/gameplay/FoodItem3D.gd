extends Area3D
class_name FoodItem3D

## Food Item — 3D pickup
## Walk over to pick up, eat to restore HP

signal collected(player)
signal eaten(player, food_type, health_amount)

@export var food_type: String = "burger"
@export var health_amount: int = 20
@export var bob_height: float = 0.3
@export var bob_speed: float = 2.0

var is_collected: bool = false
var start_y: float = 0.0
var time_offset: float = 0.0

@onready var mesh: Node3D = $Mesh

func _ready() -> void:
	add_to_group("food")
	start_y = position.y
	time_offset = randf() * 10.0
	_update_appearance()

func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Bob up and down
	position.y = start_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed + time_offset) * bob_height
	
	# Slow rotation
	if mesh:
		mesh.rotation.y += delta * 1.5

func collect(player: Node3D) -> void:
	if is_collected:
		return
	
	is_collected = true
	emit_signal("collected", player)
	
	var game = get_tree().get_first_node_in_group("game")
	if game and game.has_method("on_food_eaten"):
		game.on_food_eaten(food_type, health_amount)
	
	if player.has_method("eat"):
		player.eat(food_type, health_amount)
	
	queue_free()

func _writable_material() -> StandardMaterial3D:
	# `mesh` may be a Node3D container (no surface API at all) — resolve to an
	# owned, mutable material on the first MeshInstance3D we can find.
	var mi: MeshInstance3D = mesh if mesh is MeshInstance3D else null
	if not mi:
		for c in mesh.get_children():
			if c is MeshInstance3D:
				mi = c
				break
	if not mi:
		for c in mesh.get_children():
			for g in c.get_children():
				if g is MeshInstance3D:
					mi = g
					break
			if mi:
				break
	if not mi:
		return null
	var m: StandardMaterial3D = mi.material_override
	if not m:
		m = StandardMaterial3D.new()
		mi.material_override = m
	return m


func _update_appearance() -> void:
	if not mesh:
		return
	
	var mat := _writable_material()
	if not mat:
		return
	
	match food_type:
		"burger":
			mat.albedo_color = Color(0.85, 0.65, 0.3)
		"pizza":
			mat.albedo_color = Color(0.9, 0.75, 0.4)
		"noodles":
			mat.albedo_color = Color(0.95, 0.9, 0.7)
		"donut":
			mat.albedo_color = Color(0.95, 0.7, 0.85)
		"soda":
			mat.albedo_color = Color(0.85, 0.1, 0.1)
		"fries":
			mat.albedo_color = Color(0.95, 0.85, 0.65)
		"sushi":
			mat.albedo_color = Color(0.95, 0.93, 0.88)
		"takis":
			mat.albedo_color = Color(0.9, 0.45, 0.15)
		"medkit":
			mat.albedo_color = Color(0.95, 0.95, 0.98)
		"coffee":
			mat.albedo_color = Color(0.2, 0.2, 0.25)
		"battery":
			mat.albedo_color = Color(0.3, 0.75, 0.4)
		"ammo":
			mat.albedo_color = Color(0.5, 0.6, 0.4)
		_:
			mat.albedo_color = Color(0.8, 0.8, 0.8)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_collected:
		collect(body)
