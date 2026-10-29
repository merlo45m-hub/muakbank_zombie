extends Node3D
class_name CheckpointArmoryTerminal

@export var controller_path: NodePath = ^"../Controller"

var controller: Node
var prompt: Label3D
var player_near: bool = false
var terminal_state: String = "IDLE"

func _ready() -> void:
	add_to_group("interactive_prop")
	controller = get_node_or_null(controller_path)
	prompt = get_node_or_null("Prompt") as Label3D
	var zone := get_node_or_null("InteractionZone") as Area3D
	if zone:
		zone.body_entered.connect(_on_zone_body_entered)
		zone.body_exited.connect(_on_zone_body_exited)
	_refresh_prompt()

func interact() -> void:
	if terminal_state != "IDLE" or not player_near:
		return
	if controller and controller.has_method("start_trial"):
		controller.start_trial()

func set_trial_state(value: String) -> void:
	terminal_state = value
	if value == "IDLE":
		add_to_group("interactive_prop")
	else:
		remove_from_group("interactive_prop")
	_refresh_prompt()

func _on_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true
		_refresh_prompt()

func _on_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		_refresh_prompt()

func _refresh_prompt() -> void:
	if prompt == null:
		return
	prompt.visible = player_near
	match terminal_state:
		"IDLE":
			prompt.text = "ACTIVATE LAST STAND TRIAL"
		"ACTIVE":
			prompt.text = "LOCKDOWN ACTIVE"
		"COMPLETED":
			prompt.text = "GATE CLEARED — TRANSIT OPEN"
		"FAILED":
			prompt.text = "TRIAL FAILED — REARM AND RETRY"
