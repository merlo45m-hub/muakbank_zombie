extends Node3D
class_name BreakableSupplyCrate

## BreakableSupplyCrate — activity-only supply crate for Quarantine Breach
## (spec: docs/specs/LEVEL1_MINIGAMES_B.md §2). Reuses FoodCrate's interaction
## conventions (one-shot open, Lid + CrateInteractionZone child layout) but the
## first interact CRACKS it for the round: the configured heavy supply case is
## released at the crate's drop point and two ammo pickups spawn. It never
## spawns food and never resets while the activity owns it. Ordinary world
## FoodCrates are untouched (this is a separate script/scene).

const AMMO_SCENE: PackedScene = preload("res://scenes/world/food_ammo.tscn")

@export var supply_case_path: NodePath = ^"../../Cases/CaseA"
@export var ammo_drop_count: int = 2
@export var drop_height: float = 0.45

var is_cracked: bool = false
var player_near: bool = false

var lid_node: MeshInstance3D = null
var interaction_zone: Area3D = null

func _ready() -> void:
	add_to_group("interactive_prop")
	lid_node = get_node_or_null("Lid") as MeshInstance3D
	interaction_zone = get_node_or_null("CrateInteractionZone") as Area3D
	if interaction_zone == null:
		interaction_zone = get_node_or_null("InteractionZone") as Area3D
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

func _on_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true

func _on_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false

func interact() -> void:
	if is_cracked or not player_near:
		return
	is_cracked = true
	if lid_node:
		lid_node.rotation.x = deg_to_rad(75.0)
	if interaction_zone:
		interaction_zone.set_deferred("monitoring", false)
	# Release the heavy supply case (the door brace) at the drop point.
	var case_node := get_node_or_null(supply_case_path)
	if case_node and case_node.has_method("release"):
		case_node.call("release")
	elif case_node:
		case_node.global_position = global_position + Vector3(0, drop_height, 0.5)
	# Two standard ammo pickups alongside the case.
	for i in range(ammo_drop_count):
		var ammo := AMMO_SCENE.instantiate()
		get_tree().current_scene.add_child(ammo)
		ammo.global_position = global_position + Vector3((0.4 if i == 0 else -0.4), drop_height, 0.8)

func reset_crate() -> void:
	is_cracked = false
	player_near = false
	if interaction_zone:
		interaction_zone.monitoring = true
	if lid_node:
		lid_node.rotation.x = 0.0
