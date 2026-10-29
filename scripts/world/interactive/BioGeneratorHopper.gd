extends Node3D
class_name BioGeneratorHopper

const FUEL_VALUES: Dictionary = {
	"burger": 22.0,
	"pizza": 28.0,
	"fries": 18.0,
	"takis": 18.0,
	"sushi": 18.0,
	"soda": 12.0,
	"coffee": 12.0,
	"medkit": 35.0,
	"battery": 35.0,
}
const FOOD_PRIORITY: Array[String] = ["pizza", "medkit", "battery", "burger", "sushi", "fries", "takis", "coffee", "soda"]

@export var controller_path: NodePath = ^"../Controller"

var player: Node3D
var controller: Node

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt: Label3D = $Prompt

func _ready() -> void:
	add_to_group("interactive_prop")
	controller = get_node_or_null(controller_path)
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)
	_refresh_prompt()

func _process(_delta: float) -> void:
	_refresh_prompt()

func interact() -> void:
	if not is_instance_valid(player) or not controller or int(controller.get("state")) != BioGeneratorController.RunState.ACTIVE:
		return
	var food_type := _find_food_type(player)
	if food_type.is_empty():
		return
	if not player.consume_food_type(food_type):
		return
	controller.add_fuel(float(FUEL_VALUES[food_type]))
	_refresh_prompt()

func _find_food_type(target: Node) -> String:
	for food_type in FOOD_PRIORITY:
		if target.has_method("has_food") and target.has_food(food_type):
			return food_type
	return ""

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body
		_refresh_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
		_refresh_prompt()

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt):
		return
	var active := controller and int(controller.get("state")) == BioGeneratorController.RunState.ACTIVE
	prompt.visible = is_instance_valid(player) and active
	prompt.text = "FEED HOPPER [ATTACK]"
